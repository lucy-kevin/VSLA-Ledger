import 'dart:convert';

import 'package:uuid/uuid.dart';
import 'package:vsla_ledger/core/database/app_database.dart';
import 'package:vsla_ledger/core/ledger/ledger_rule_broken.dart';
import 'package:vsla_ledger/core/models/entry_type.dart';
import 'package:vsla_ledger/core/models/ledger_entry.dart';
import 'package:vsla_ledger/core/models/outbox_item.dart';

/// The only way the app records money.
///
/// Every method checks the ledger rules, then saves the entry and its outbox
/// item in one database transaction. Either both are saved or neither is,
/// so a record can never be on the phone without being queued for sync.
class LedgerRepository {
  LedgerRepository({
    required AppDatabase db,
    required String deviceId,
    DateTime Function()? now,
    String Function()? newId,
  }) : _db = db,
       _deviceId = deviceId,
       _now = now ?? (() => DateTime.now().toUtc()),
       _newId = newId ?? const Uuid().v4;

  final AppDatabase _db;
  final String _deviceId;
  final DateTime Function() _now;
  final String Function() _newId;

  /// A member saves money with the group.
  Future<LedgerEntry> recordContribution({
    required String groupId,
    required String memberId,
    required int amountUgx,
  }) => _append(
    groupId: groupId,
    memberId: memberId,
    type: EntryType.contribution,
    amountUgx: amountUgx,
  );

  /// The group lends money to a member.
  Future<LedgerEntry> issueLoan({
    required String groupId,
    required String memberId,
    required int amountUgx,
  }) => _append(
    groupId: groupId,
    memberId: memberId,
    type: EntryType.loan,
    amountUgx: amountUgx,
  );

  /// A member pays back part or all of a loan.
  Future<LedgerEntry> recordRepayment({
    required String groupId,
    required String memberId,
    required String loanId,
    required int amountUgx,
  }) => _append(
    groupId: groupId,
    memberId: memberId,
    type: EntryType.repayment,
    amountUgx: amountUgx,
    loanId: loanId,
    checkBeforeSaving: () => _checkLoanCanBeRepaid(loanId, memberId, amountUgx),
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

  Future<LedgerEntry> _append({
    required String groupId,
    required String memberId,
    required EntryType type,
    required int amountUgx,
    String? loanId,
    String? correctsEntryId,
    Future<void> Function()? checkBeforeSaving,
  }) async {
    _checkAmount(amountUgx);

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

  Future<void> _checkLoanCanBeRepaid(
    String loanId,
    String memberId,
    int amountUgx,
  ) async {
    final loan = await _db.ledgerDao.getEntry(loanId);
    if (loan == null) throw const LedgerRuleBroken(LedgerRule.entryNotFound);
    if (loan.type != EntryType.loan || loan.memberId != memberId) {
      throw const LedgerRuleBroken(LedgerRule.notALoanOfThisMember);
    }
    if (await _db.ledgerDao.isCancelled(loan.id)) {
      throw const LedgerRuleBroken(LedgerRule.loanIsCancelled);
    }

    var stillOwed = loan.amountUgx;
    for (final repayment in await _repaymentsStillCounting(loan.id)) {
      stillOwed -= repayment.amountUgx;
    }
    if (amountUgx > stillOwed) {
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
        (await _repaymentsStillCounting(original.id)).isNotEmpty) {
      throw const LedgerRuleBroken(LedgerRule.loanHasRepayments);
    }
  }

  // Repayments that were themselves cancelled no longer count: they do not
  // reduce what is owed, and they do not stop the loan being cancelled.
  Future<List<LedgerEntry>> _repaymentsStillCounting(String loanId) async {
    final counting = <LedgerEntry>[];
    for (final repayment in await _db.ledgerDao.getRepaymentsForLoan(loanId)) {
      if (!await _db.ledgerDao.isCancelled(repayment.id)) {
        counting.add(repayment);
      }
    }
    return counting;
  }
}
