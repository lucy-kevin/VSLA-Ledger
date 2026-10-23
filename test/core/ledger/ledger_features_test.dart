import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:vsla_ledger/core/database/app_database.dart';
import 'package:vsla_ledger/core/ledger/ledger_repository.dart';
import 'package:vsla_ledger/core/ledger/ledger_rule_broken.dart';
import 'package:vsla_ledger/core/models/entry_type.dart';
import 'package:vsla_ledger/core/models/group.dart';
import 'package:vsla_ledger/core/models/ledger_entry.dart';

import '../../helpers/test_database.dart';

const groupId = 'group-1';
const sarah = 'member-sarah';

Matcher breaks(LedgerRule rule) => throwsA(
  isA<LedgerRuleBroken>().having((error) => error.rule, 'rule', rule),
);

/// Meetings, service charge, shares, social fund and fines.
void main() {
  late AppDatabase db;
  late LedgerRepository ledger;
  var nextId = 0;

  Future<void> makeGroup({int chargePercent = 10, int? sharePrice}) =>
      db.groupDao.insertGroup(
        Group(
          id: groupId,
          name: 'Tukolere Wamu',
          joinCode: 'TKW482',
          createdAt: DateTime.utc(2026, 8, 1, 9),
          updatedAt: DateTime.utc(2026, 8, 1, 9),
          monthlyChargePercent: chargePercent,
          sharePriceUgx: sharePrice,
        ),
      );

  setUp(() {
    db = newTestDatabase();
    nextId = 0;
    // Today is 19 October 2026, midday, so the same day in any time zone.
    ledger = LedgerRepository(
      db: db,
      deviceId: 'phone-a',
      now: () => DateTime.utc(2026, 10, 19, 12),
      newId: () => 'entry-${nextId++}',
    );
  });
  tearDown(() => db.close());

  Future<LedgerEntry> saved(String id) async =>
      (await db.ledgerDao.getEntry(id))!;

  group('meeting date', () {
    test('is today when none is given', () async {
      await makeGroup();

      final entry = await ledger.recordSocialFund(
        groupId: groupId,
        memberId: sarah,
        amountUgx: 1000,
      );

      expect(entry.meetingDate, DateTime.utc(2026, 10, 19));
    });

    test('can be an earlier day, and is a day with no time', () async {
      await makeGroup();

      final entry = await ledger.recordFine(
        groupId: groupId,
        memberId: sarah,
        amountUgx: 500,
        meetingDate: DateTime(2026, 10, 12, 17, 45),
      );

      expect(entry.meetingDate, DateTime.utc(2026, 10, 12));
      // The real time it was typed is kept separately.
      expect(entry.createdAt, DateTime.utc(2026, 10, 19, 12));
    });

    test('cannot be after today', () async {
      await makeGroup();

      await expectLater(
        ledger.recordFine(
          groupId: groupId,
          memberId: sarah,
          amountUgx: 500,
          meetingDate: DateTime(2026, 10, 20),
        ),
        breaks(LedgerRule.meetingDateInFuture),
      );
    });

    test('cannot be before the group was made', () async {
      await makeGroup();

      await expectLater(
        ledger.recordFine(
          groupId: groupId,
          memberId: sarah,
          amountUgx: 500,
          meetingDate: DateTime(2026, 7, 31),
        ),
        breaks(LedgerRule.meetingDateBeforeGroup),
      );
    });

    test('a refused date saves nothing', () async {
      await makeGroup();
      await expectLater(
        ledger.recordFine(
          groupId: groupId,
          memberId: sarah,
          amountUgx: 500,
          meetingDate: DateTime(2026, 10, 20),
        ),
        throwsA(anything),
      );

      expect(await db.outboxDao.nextBatch(limit: 10), isEmpty);
      expect(await db.ledgerDao.getEntriesForMember(sarah), isEmpty);
    });

    test('travels in the outbox payload', () async {
      await makeGroup();
      await ledger.recordSocialFund(
        groupId: groupId,
        memberId: sarah,
        amountUgx: 1000,
        meetingDate: DateTime(2026, 10, 12),
      );

      final payload =
          jsonDecode(
                (await db.outboxDao.nextBatch(limit: 1)).single.payloadJson,
              )
              as Map<String, dynamic>;

      expect(payload['meetingDate'], '2026-10-12T00:00:00.000Z');
    });
  });

  group('social fund and fines', () {
    test('are saved with their own type and queued for sync', () async {
      await makeGroup();

      final fund = await ledger.recordSocialFund(
        groupId: groupId,
        memberId: sarah,
        amountUgx: 1000,
      );
      final fine = await ledger.recordFine(
        groupId: groupId,
        memberId: sarah,
        amountUgx: 500,
      );

      expect((await saved(fund.id)).type, EntryType.socialFund);
      expect((await saved(fine.id)).type, EntryType.fine);
      expect(await db.outboxDao.nextBatch(limit: 10), hasLength(2));
    });

    test('are not savings, and can be cancelled', () async {
      await makeGroup();
      final fine = await ledger.recordFine(
        groupId: groupId,
        memberId: sarah,
        amountUgx: 500,
      );

      var balance = await db.ledgerDao.watchMemberBalance(sarah).first;
      expect(balance.savingsUgx, 0);
      expect(balance.finesUgx, 500);

      await ledger.cancelEntry(fine.id);

      balance = await db.ledgerDao.watchMemberBalance(sarah).first;
      expect(balance.finesUgx, 0);
    });

    test('zero is refused like any other amount', () async {
      await makeGroup();

      await expectLater(
        ledger.recordFine(groupId: groupId, memberId: sarah, amountUgx: 0),
        breaks(LedgerRule.amountMustBePositive),
      );
    });
  });

  group('loan service charge', () {
    test("the group's charge is copied onto the loan", () async {
      await makeGroup();

      final loan = await ledger.issueLoan(
        groupId: groupId,
        memberId: sarah,
        amountUgx: 100000,
      );

      expect((await saved(loan.id)).monthlyChargePercent, 10);
    });

    test('a group with no charge makes loans with none', () async {
      await makeGroup(chargePercent: 0);

      final loan = await ledger.issueLoan(
        groupId: groupId,
        memberId: sarah,
        amountUgx: 100000,
      );

      expect((await saved(loan.id)).monthlyChargePercent, 0);
    });

    test('what can be repaid includes the charge built up', () async {
      await makeGroup();
      // Lent on 19 August: charges on 19 September and 19 October.
      final loan = await ledger.issueLoan(
        groupId: groupId,
        memberId: sarah,
        amountUgx: 100000,
        meetingDate: DateTime(2026, 8, 19),
      );

      await expectLater(
        ledger.recordRepayment(
          groupId: groupId,
          memberId: sarah,
          loanId: loan.id,
          amountUgx: 120001,
        ),
        breaks(LedgerRule.repaymentMoreThanOwed),
      );
      await ledger.recordRepayment(
        groupId: groupId,
        memberId: sarah,
        loanId: loan.id,
        amountUgx: 120000,
      );

      final balance = await db.ledgerDao.watchMemberBalance(sarah).first;
      expect(balance.loansOutstandingUgx, 0);
    });

    test('a repayment cannot be dated before the loan', () async {
      await makeGroup();
      final loan = await ledger.issueLoan(
        groupId: groupId,
        memberId: sarah,
        amountUgx: 100000,
        meetingDate: DateTime(2026, 10, 12),
      );

      await expectLater(
        ledger.recordRepayment(
          groupId: groupId,
          memberId: sarah,
          loanId: loan.id,
          amountUgx: 1000,
          meetingDate: DateTime(2026, 10, 5),
        ),
        breaks(LedgerRule.repaymentBeforeLoan),
      );
    });
  });

  group('shares', () {
    Future<LedgerEntry> buy(int shares, {DateTime? meetingDate}) =>
        ledger.recordContribution(
          groupId: groupId,
          memberId: sarah,
          shares: shares,
          meetingDate: meetingDate,
        );

    test('the amount is shares times the share price', () async {
      await makeGroup(sharePrice: 2000);

      final entry = await buy(3);

      expect(entry.shares, 3);
      expect(entry.amountUgx, 6000);
      final balance = await db.ledgerDao.watchMemberBalance(sarah).first;
      expect(balance.savingsUgx, 6000);
      expect(balance.sharesCount, 3);
    });

    test('a group that saves in shares needs the number of shares', () async {
      await makeGroup(sharePrice: 2000);

      await expectLater(
        ledger.recordContribution(
          groupId: groupId,
          memberId: sarah,
          amountUgx: 6000,
        ),
        breaks(LedgerRule.sharesRequired),
      );
    });

    test('a group with no share price saves amounts, not shares', () async {
      await makeGroup();

      await expectLater(buy(2), breaks(LedgerRule.groupHasNoShares));
    });

    test('1 to 5 shares at a meeting, never 0 or 6', () async {
      await makeGroup(sharePrice: 2000);

      await expectLater(buy(0), breaks(LedgerRule.tooManyShares));
      await expectLater(buy(6), breaks(LedgerRule.tooManyShares));
      await buy(5);
    });

    test('the limit is for the whole meeting, not for each purchase', () async {
      await makeGroup(sharePrice: 2000);
      await buy(3);

      await expectLater(buy(3), breaks(LedgerRule.tooManyShares));
      await buy(2);
    });

    test('another meeting has its own limit', () async {
      await makeGroup(sharePrice: 2000);
      await buy(5);

      await buy(5, meetingDate: DateTime(2026, 10, 12));
    });

    test('a cancelled purchase frees up the limit', () async {
      await makeGroup(sharePrice: 2000);
      final first = await buy(5);
      await ledger.cancelEntry(first.id);

      await buy(5);
    });
  });
}
