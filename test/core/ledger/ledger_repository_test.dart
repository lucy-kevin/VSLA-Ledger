import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:vsla_ledger/core/database/app_database.dart';
import 'package:vsla_ledger/core/ledger/ledger_repository.dart';
import 'package:vsla_ledger/core/ledger/ledger_rule_broken.dart';
import 'package:vsla_ledger/core/models/entry_type.dart';
import 'package:vsla_ledger/core/models/ledger_entry.dart';
import 'package:vsla_ledger/core/models/outbox_item.dart';

import '../../helpers/test_database.dart';

const groupId = 'group-1';
const sarah = 'member-sarah';
const peter = 'member-peter';

Matcher breaks(LedgerRule rule) => throwsA(
  isA<LedgerRuleBroken>().having((error) => error.rule, 'rule', rule),
);

void main() {
  late AppDatabase db;
  late LedgerRepository ledger;
  var nextId = 0;

  setUp(() {
    db = newTestDatabase();
    nextId = 0;
    ledger = LedgerRepository(
      db: db,
      deviceId: 'phone-a',
      now: () => DateTime.utc(2026, 10, 19, 9),
      newId: () => 'entry-${nextId++}',
    );
  });
  tearDown(() => db.close());

  Future<List<LedgerEntry>> entriesOf(String memberId) =>
      db.ledgerDao.watchEntriesForMember(memberId).first;

  Future<int> savingsOf(String memberId) async =>
      (await db.ledgerDao.watchMemberBalance(memberId).first).savingsUgx;

  Future<int> loansOutstandingOf(String memberId) async =>
      (await db.ledgerDao.watchMemberBalance(memberId).first)
          .loansOutstandingUgx;

  Future<LedgerEntry> contribute(int amountUgx, {String memberId = sarah}) =>
      ledger.recordContribution(
        groupId: groupId,
        memberId: memberId,
        amountUgx: amountUgx,
      );

  Future<LedgerEntry> lend(int amountUgx, {String memberId = sarah}) =>
      ledger.issueLoan(
        groupId: groupId,
        memberId: memberId,
        amountUgx: amountUgx,
      );

  Future<LedgerEntry> repay(
    String loanId,
    int amountUgx, {
    String memberId = sarah,
  }) => ledger.recordRepayment(
    groupId: groupId,
    memberId: memberId,
    loanId: loanId,
    amountUgx: amountUgx,
  );

  group('every write is saved together with its outbox item', () {
    test('a contribution is saved and queued for sync', () async {
      final entry = await contribute(10000);

      expect(await entriesOf(sarah), [entry]);
      final queued = (await db.outboxDao.nextBatch()).single;
      expect(queued.entityType, OutboxEntityType.ledgerEntry);
      expect(queued.entityId, entry.id);
      expect(
        LedgerEntry.fromJson(
          jsonDecode(queued.payloadJson) as Map<String, dynamic>,
        ),
        entry,
      );
    });

    test(
      'the entry is stamped with this phone, the time and a new id',
      () async {
        final entry = await contribute(10000);

        expect(entry.id, 'entry-0');
        expect(entry.deviceId, 'phone-a');
        expect(entry.createdAt, DateTime.utc(2026, 10, 19, 9));
        expect(entry.serverReceivedAt, isNull);
      },
    );

    test('if queueing fails, the entry is not saved either', () async {
      // Break the outbox so the second half of the transaction fails.
      await db.customStatement('DROP TABLE outbox');

      await expectLater(contribute(10000), throwsA(anything));

      expect(await entriesOf(sarah), isEmpty);
    });

    test('a refused write saves nothing at all', () async {
      await expectLater(contribute(0), breaks(LedgerRule.amountMustBePositive));

      expect(await entriesOf(sarah), isEmpty);
      expect(await db.outboxDao.nextBatch(), isEmpty);
    });
  });

  group('amounts', () {
    test('zero and negative amounts are refused', () async {
      await expectLater(contribute(0), breaks(LedgerRule.amountMustBePositive));
      await expectLater(lend(-5000), breaks(LedgerRule.amountMustBePositive));
    });

    test(
      'the largest allowed amount is accepted, one more is refused',
      () async {
        await contribute(maxAmountUgx);

        await expectLater(
          contribute(maxAmountUgx + 1),
          breaks(LedgerRule.amountTooLarge),
        );
      },
    );
  });

  group('repayments', () {
    test('a repayment reduces the loan outstanding', () async {
      final loan = await lend(50000);

      final repayment = await repay(loan.id, 20000);

      expect(repayment.loanId, loan.id);
      expect(await loansOutstandingOf(sarah), 30000);
    });

    test('repaying a loan that does not exist is refused', () async {
      await expectLater(
        repay('no-such-loan', 1000),
        breaks(LedgerRule.entryNotFound),
      );
    });

    test('repaying something that is not a loan is refused', () async {
      final contribution = await contribute(10000);

      await expectLater(
        repay(contribution.id, 1000),
        breaks(LedgerRule.notALoanOfThisMember),
      );
    });

    test("repaying another member's loan is refused", () async {
      final petersLoan = await lend(50000, memberId: peter);

      await expectLater(
        repay(petersLoan.id, 1000),
        breaks(LedgerRule.notALoanOfThisMember),
      );
    });

    test('paying back exactly what is owed clears the loan', () async {
      final loan = await lend(50000);
      await repay(loan.id, 20000);

      await repay(loan.id, 30000);

      expect(await loansOutstandingOf(sarah), 0);
    });

    test('paying back more than is owed is refused', () async {
      final loan = await lend(50000);
      await repay(loan.id, 20000);

      await expectLater(
        repay(loan.id, 30001),
        breaks(LedgerRule.repaymentMoreThanOwed),
      );
      expect(await loansOutstandingOf(sarah), 30000);
    });

    test('a cancelled repayment no longer reduces what is owed', () async {
      final loan = await lend(50000);
      final mistake = await repay(loan.id, 50000);
      await ledger.cancelEntry(mistake.id);

      await repay(loan.id, 50000);

      expect(await loansOutstandingOf(sarah), 0);
    });

    test('repaying a cancelled loan is refused', () async {
      final loan = await lend(50000);
      await ledger.cancelEntry(loan.id);

      await expectLater(
        repay(loan.id, 1000),
        breaks(LedgerRule.loanIsCancelled),
      );
    });
  });

  group('cancelling entries', () {
    test('cancel the wrong entry, record the right one', () async {
      // The treasurer typed 12,000 instead of 10,000.
      final wrong = await contribute(12000);

      final correction = await ledger.cancelEntry(wrong.id);
      await contribute(10000);

      expect(correction.type, EntryType.correction);
      expect(correction.correctsEntryId, wrong.id);
      expect(correction.amountUgx, 12000);
      expect(correction.memberId, sarah);
      expect(await savingsOf(sarah), 10000);
      expect(await entriesOf(sarah), contains(wrong));
    });

    test('the correction is queued for sync too', () async {
      final wrong = await contribute(12000);

      final correction = await ledger.cancelEntry(wrong.id);

      expect(
        (await db.outboxDao.nextBatch()).map((item) => item.entityId),
        [wrong.id, correction.id],
      );
    });

    test('cancelling an entry that does not exist is refused', () async {
      await expectLater(
        ledger.cancelEntry('no-such-entry'),
        breaks(LedgerRule.entryNotFound),
      );
    });

    test('cancelling the same entry twice is refused', () async {
      final wrong = await contribute(12000);
      await ledger.cancelEntry(wrong.id);

      await expectLater(
        ledger.cancelEntry(wrong.id),
        breaks(LedgerRule.alreadyCancelled),
      );
    });

    test('a correction cannot be cancelled', () async {
      final wrong = await contribute(12000);
      final correction = await ledger.cancelEntry(wrong.id);

      await expectLater(
        ledger.cancelEntry(correction.id),
        breaks(LedgerRule.cannotCancelACorrection),
      );
      expect(await savingsOf(sarah), 0);
    });

    test('a loan with repayments cannot be cancelled', () async {
      final loan = await lend(50000);
      await repay(loan.id, 20000);

      await expectLater(
        ledger.cancelEntry(loan.id),
        breaks(LedgerRule.loanHasRepayments),
      );
      expect(await loansOutstandingOf(sarah), 30000);
    });

    test(
      'once its repayments are cancelled, the loan can be cancelled',
      () async {
        final loan = await lend(50000);
        final repayment = await repay(loan.id, 20000);

        await ledger.cancelEntry(repayment.id);
        await ledger.cancelEntry(loan.id);

        expect(await loansOutstandingOf(sarah), 0);
      },
    );
  });
}
