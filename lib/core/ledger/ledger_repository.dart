import 'dart:convert';

import 'package:uuid/uuid.dart';
import 'package:vsla_ledger/core/clock.dart';
import 'package:vsla_ledger/core/database/app_database.dart';
import 'package:vsla_ledger/core/ledger/ledger_rule_broken.dart';
import 'package:vsla_ledger/core/ledger/loan_status.dart';
import 'package:vsla_ledger/core/models/entry_type.dart';
import 'package:vsla_ledger/core/models/ledger_entry.dart';
import 'package:vsla_ledger/core/models/outbox_item.dart';

/// The only way the app records money.
///
/// Every method checks the ledger rules, then saves the entry and its outbox
/// item in one database transaction. Either both are saved or neither is,
/// so a record can never be on the phone without being queued for sync.
///
/// Every method takes an optional `meetingDate`: the day of the meeting the
/// record belongs to. Left out, it is today. It cannot be after today, or
/// before the day the group was made.
class LedgerRepository {
  LedgerRepository({
    required AppDatabase db,
    required String deviceId,
    DateTime Function()? now,
    String Function()? newId,
  }) : _db = db,
       _deviceId = deviceId,
       _now = now ?? nowUtc,
       _newId = newId ?? const Uuid().v4;

  final AppDatabase _db;
  final String _deviceId;
  final DateTime Function() _now;
  final String Function() _newId;

  /// A member saves money with the group.
  ///
  /// In a group that saves in shares (the group has a share price), give
  /// [shares] and leave [amountUgx] out: the amount is shares times the
  /// price. Otherwise give [amountUgx] and no shares.
  Future<LedgerEntry> recordContribution({
    required String groupId,
    required String memberId,
    int? amountUgx,
    int? shares,
    DateTime? meetingDate,
  }) async {
    final group = await _db.groupDao.getGroup(groupId);
    final price = group?.sharePriceUgx ?? 0;
    final savesInShares = price > 0;

    if (savesInShares && shares == null) {
      throw const LedgerRuleBroken(LedgerRule.sharesRequired);
    }
    if (!savesInShares && shares != null) {
      throw const LedgerRuleBroken(LedgerRule.groupHasNoShares);
    }
    if (savesInShares && (shares! < 1 || shares > maxSharesPerMeeting)) {
      throw const LedgerRuleBroken(LedgerRule.tooManyShares);
    }
    if (!savesInShares && amountUgx == null) {
      throw const LedgerRuleBroken(LedgerRule.amountMustBePositive);
    }

    return _append(
      groupId: groupId,
      memberId: memberId,
      type: EntryType.contribution,
      amountUgx: savesInShares ? shares! * price : amountUgx!,
      meetingDate: meetingDate,
      shares: shares,
      checkBeforeSaving: savesInShares
          ? () => _checkSharesForMeeting(
              memberId,
              shares!,
              _meetingDay(meetingDate),
            )
          : null,
    );
  }

  /// A member pays into the group's social fund.
  Future<LedgerEntry> recordSocialFund({
    required String groupId,
    required String memberId,
    required int amountUgx,
    DateTime? meetingDate,
  }) => _append(
    groupId: groupId,
    memberId: memberId,
    type: EntryType.socialFund,
    amountUgx: amountUgx,
    meetingDate: meetingDate,
  );

  /// A member pays a fine.
  Future<LedgerEntry> recordFine({
    required String groupId,
    required String memberId,
    required int amountUgx,
    DateTime? meetingDate,
  }) => _append(
    groupId: groupId,
    memberId: memberId,
    type: EntryType.fine,
    amountUgx: amountUgx,
    meetingDate: meetingDate,
  );

  /// The group lends money to a member. The group's service charge is copied
  /// onto the loan now, so changing it later never alters this loan.
  Future<LedgerEntry> issueLoan({
    required String groupId,
    required String memberId,
    required int amountUgx,
    DateTime? meetingDate,
  }) async {
    final group = await _db.groupDao.getGroup(groupId);
    return _append(
      groupId: groupId,
      memberId: memberId,
      type: EntryType.loan,
      amountUgx: amountUgx,
      meetingDate: meetingDate,
      monthlyChargePercent: group?.monthlyChargePercent,
    );
  }

  /// A member pays back part or all of a loan (charges first, then the loan).
  Future<LedgerEntry> recordRepayment({
    required String groupId,
    required String memberId,
    required String loanId,
    required int amountUgx,
    DateTime? meetingDate,
  }) => _append(
    groupId: groupId,
    memberId: memberId,
    type: EntryType.repayment,
    amountUgx: amountUgx,
    loanId: loanId,
    meetingDate: meetingDate,
    checkBeforeSaving: () => _checkLoanCanBeRepaid(
      loanId,
      memberId,
      amountUgx,
      _meetingDay(meetingDate),
    ),
  );

  /// Cancels a wrong entry by adding a correction that points at it.
  ///
  /// The wrong entry stays in the ledger. To fix a mistake, cancel the wrong
  /// entry, then record the right one as a normal entry.
  Future<LedgerEntry> cancelEntry(String entryId) async {
    final original = await _db.ledgerDao.getEntry(entryId);
    if (original == null) {
      throw const LedgerRuleBroken(LedgerRule.entryNotFound);
    }

    return _append(
      groupId: original.groupId,
      memberId: original.memberId,
      type: EntryType.correction,
      amountUgx: original.amountUgx,
      correctsEntryId: original.id,
      checkBeforeSaving: () => _checkCanBeCancelled(original),
    );
  }

  /// Today, by the phone's calendar.
  DateTime get _today => dateOnly(_now().toLocal());

  DateTime _meetingDay(DateTime? chosen) =>
      chosen == null ? _today : dateOnly(chosen);

  Future<LedgerEntry> _append({
    required String groupId,
    required String memberId,
    required EntryType type,
    required int amountUgx,
    String? loanId,
    String? correctsEntryId,
    DateTime? meetingDate,
    int? shares,
    int? monthlyChargePercent,
    Future<void> Function()? checkBeforeSaving,
  }) async {
    _checkAmount(amountUgx);
    final meetingDay = _meetingDay(meetingDate);
    await _checkMeetingDay(groupId, meetingDay);

    final entry = LedgerEntry(
      id: _newId(),
      groupId: groupId,
      memberId: memberId,
      type: type,
      amountUgx: amountUgx,
      createdAt: _now(),
      deviceId: _deviceId,
      loanId: loanId,
      correctsEntryId: correctsEntryId,
      meetingDate: meetingDay,
      shares: shares,
      monthlyChargePercent: monthlyChargePercent,
    );

    // The checks run inside the transaction, so nothing can change between
    // checking a rule and saving the entry.
    return _db.transaction(() async {
      await checkBeforeSaving?.call();
      await _db.ledgerDao.insertEntry(entry);
      await _db.outboxDao.enqueue(
        entityType: OutboxEntityType.ledgerEntry,
        entityId: entry.id,
        payloadJson: jsonEncode(entry.toJson()),
        createdAt: entry.createdAt,
      );
      return entry;
    });
  }

  void _checkAmount(int amountUgx) {
    if (amountUgx <= 0) {
      throw const LedgerRuleBroken(LedgerRule.amountMustBePositive);
    }
    if (amountUgx > maxAmountUgx) {
      throw const LedgerRuleBroken(LedgerRule.amountTooLarge);
    }
  }

  /// A meeting is not in the future, and not before the group existed.
  Future<void> _checkMeetingDay(String groupId, DateTime meetingDay) async {
    if (meetingDay.isAfter(_today)) {
      throw const LedgerRuleBroken(LedgerRule.meetingDateInFuture);
    }
    final group = await _db.groupDao.getGroup(groupId);
    if (group != null &&
        meetingDay.isBefore(dateOnly(group.createdAt.toLocal()))) {
      throw const LedgerRuleBroken(LedgerRule.meetingDateBeforeGroup);
    }
  }

  /// A member buys at most [maxSharesPerMeeting] shares at one meeting.
  Future<void> _checkSharesForMeeting(
    String memberId,
    int shares,
    DateTime meetingDay,
  ) async {
    final entries = await _db.ledgerDao.getEntriesForMember(memberId);
    final alreadyBought = entriesThatCount(entries)
        .where(
          (e) => e.type == EntryType.contribution && e.meetingDay == meetingDay,
        )
        .fold(0, (sum, e) => sum + (e.shares ?? 0));
    if (alreadyBought + shares > maxSharesPerMeeting) {
      throw const LedgerRuleBroken(LedgerRule.tooManyShares);
    }
  }

  Future<void> _checkLoanCanBeRepaid(
    String loanId,
    String memberId,
    int amountUgx,
    DateTime meetingDay,
  ) async {
    final loan = await _db.ledgerDao.getEntry(loanId);
    if (loan == null) throw const LedgerRuleBroken(LedgerRule.entryNotFound);
    if (loan.type != EntryType.loan || loan.memberId != memberId) {
      throw const LedgerRuleBroken(LedgerRule.notALoanOfThisMember);
    }
    if (meetingDay.isBefore(loan.meetingDay)) {
      throw const LedgerRuleBroken(LedgerRule.repaymentBeforeLoan);
    }
    final status = await _statusOf(loan);
    if (status == null) {
      throw const LedgerRuleBroken(LedgerRule.loanIsCancelled);
    }
    // What is owed includes the service charge built up so far.
    if (amountUgx > status.owedUgx) {
      throw const LedgerRuleBroken(LedgerRule.repaymentMoreThanOwed);
    }
  }

  Future<void> _checkCanBeCancelled(LedgerEntry original) async {
    if (original.type == EntryType.correction) {
      throw const LedgerRuleBroken(LedgerRule.cannotCancelACorrection);
    }
    if (await _db.ledgerDao.isCancelled(original.id)) {
      throw const LedgerRuleBroken(LedgerRule.alreadyCancelled);
    }
    if (original.type == EntryType.loan &&
        ((await _statusOf(original))?.hasRepayments ?? false)) {
      throw const LedgerRuleBroken(LedgerRule.loanHasRepayments);
    }
  }

  /// How much is owed on [loan], worked out the same way the screens do.
  /// Null if the loan has been cancelled.
  Future<LoanStatus?> _statusOf(LedgerEntry loan) async {
    final entries = await _db.ledgerDao.getEntriesForMember(loan.memberId);
    return loanStatuses(
      entries,
      today: _today,
    ).where((status) => status.loan.id == loan.id).firstOrNull;
  }
}
