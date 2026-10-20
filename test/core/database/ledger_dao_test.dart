import 'package:flutter_test/flutter_test.dart';
import 'package:vsla_ledger/core/database/app_database.dart';
import 'package:vsla_ledger/core/models/balance.dart';
import 'package:vsla_ledger/core/models/entry_type.dart';
import 'package:vsla_ledger/core/models/ledger_entry.dart';

import '../../helpers/test_database.dart';

const groupId = 'group-1';
const sarah = 'member-sarah';
const peter = 'member-peter';

var _nextId = 0;

LedgerEntry entry(
  EntryType type,
  int amountUgx, {
  String memberId = sarah,
  String? correctsEntryId,
  String? loanId,
}) => LedgerEntry(
  id: 'entry-${_nextId++}',
  groupId: groupId,
  memberId: memberId,
  type: type,
  amountUgx: amountUgx,
  createdAt: DateTime.utc(2026, 10, 19, 9).add(Duration(milliseconds: _nextId)),
  deviceId: 'phone-a',
  correctsEntryId: correctsEntryId,
  loanId: loanId,
);

/// Matches a database error whose message contains [text].
Matcher _errorMentioning(String text) =>
    predicate((error) => error.toString().contains(text), text);

void main() {
  late AppDatabase db;

  setUp(() => db = newTestDatabase());
  tearDown(() => db.close());

  Future<Balance> memberBalance(String memberId) =>
      db.ledgerDao.watchMemberBalance(memberId).first;

  group('storing entries', () {
    test('an entry comes back exactly as it was saved', () async {
      final saved = entry(EntryType.contribution, 10000);

      await db.ledgerDao.insertEntry(saved);

      expect(await db.ledgerDao.watchEntriesForMember(sarah).first, [saved]);
    });

    test('saving the same entry twice keeps one copy', () async {
      final saved = entry(EntryType.contribution, 10000);

      await db.ledgerDao.insertEntry(saved);
      await db.ledgerDao.insertEntry(saved);

      expect(
        await db.ledgerDao.watchEntriesForMember(sarah).first,
        hasLength(1),
      );
    });

    test('entries are listed newest first', () async {
      final first = entry(EntryType.contribution, 10000);
      final second = entry(EntryType.contribution, 5000);

      await db.ledgerDao.insertEntry(first);
      await db.ledgerDao.insertEntry(second);

      expect(
        await db.ledgerDao.watchEntriesForMember(sarah).first,
        [second, first],
      );
    });
  });

  group('the ledger is append-only', () {
    test('the database refuses to change an entry', () async {
      await db.ledgerDao.insertEntry(entry(EntryType.contribution, 10000));

      expect(
        () => db.customStatement('UPDATE ledger_entries SET amount_ugx = 1'),
        throwsA(_errorMentioning('append-only')),
      );
    });

    test('the database refuses to delete an entry', () async {
      await db.ledgerDao.insertEntry(entry(EntryType.contribution, 10000));

      expect(
        () => db.customStatement('DELETE FROM ledger_entries'),
        throwsA(_errorMentioning('append-only')),
      );
    });

    for (final badAmount in [0, -500]) {
      test('the database refuses an amount of $badAmount', () async {
        expect(
          () => db.ledgerDao.insertEntry(
            entry(EntryType.contribution, badAmount),
          ),
          throwsA(_errorMentioning('CHECK constraint failed')),
        );
      });
    }
  });

  group('balances', () {
    test('a member with no entries has zero balances', () async {
      expect(
        await memberBalance(sarah),
        const Balance(savingsUgx: 0, loansOutstandingUgx: 0),
      );
    });

    test('contributions, loans and repayments add up', () async {
      final loan = entry(EntryType.loan, 50000);
      await db.ledgerDao.insertEntry(entry(EntryType.contribution, 10000));
      await db.ledgerDao.insertEntry(entry(EntryType.contribution, 5000));
      await db.ledgerDao.insertEntry(loan);
      await db.ledgerDao.insertEntry(
        entry(EntryType.repayment, 20000, loanId: loan.id),
      );

      expect(
        await memberBalance(sarah),
        const Balance(savingsUgx: 15000, loansOutstandingUgx: 30000),
      );
    });

    test(
      'a correction cancels the wrong entry, and the right one counts',
      () async {
        // The treasurer wrote 12,000 by mistake, then fixed it to 10,000.
        final wrong = entry(EntryType.contribution, 12000);
        await db.ledgerDao.insertEntry(wrong);
        await db.ledgerDao.insertEntry(
          entry(EntryType.correction, 12000, correctsEntryId: wrong.id),
        );
        await db.ledgerDao.insertEntry(entry(EntryType.contribution, 10000));

        expect(
          await memberBalance(sarah),
          const Balance(savingsUgx: 10000, loansOutstandingUgx: 0),
        );
      },
    );

    test('two phones cancelling the same entry only cancel it once', () async {
      final wrong = entry(EntryType.contribution, 12000);
      await db.ledgerDao.insertEntry(entry(EntryType.contribution, 3000));
      await db.ledgerDao.insertEntry(wrong);
      await db.ledgerDao.insertEntry(
        entry(EntryType.correction, 12000, correctsEntryId: wrong.id),
      );
      await db.ledgerDao.insertEntry(
        entry(EntryType.correction, 12000, correctsEntryId: wrong.id),
      );

      expect((await memberBalance(sarah)).savingsUgx, 3000);
    });

    test(
      'the original entry is still in the history after a correction',
      () async {
        final wrong = entry(EntryType.contribution, 12000);
        await db.ledgerDao.insertEntry(wrong);
        await db.ledgerDao.insertEntry(
          entry(EntryType.correction, 12000, correctsEntryId: wrong.id),
        );

        expect(
          await db.ledgerDao.watchEntriesForMember(sarah).first,
          contains(wrong),
        );
        final history = await db.ledgerDao.watchHistoryForMember(sarah).first;
        final wrongLine = history.singleWhere(
          (line) => line.entry.id == wrong.id,
        );
        expect(wrongLine.isCancelled, isTrue);
        expect(
          history.where((line) => line.entry.id != wrong.id).single.isCancelled,
          isFalse,
        );
      },
    );

    test('a member balance only counts that member', () async {
      await db.ledgerDao.insertEntry(entry(EntryType.contribution, 10000));
      await db.ledgerDao.insertEntry(
        entry(EntryType.contribution, 7000, memberId: peter),
      );

      expect((await memberBalance(sarah)).savingsUgx, 10000);
      expect((await memberBalance(peter)).savingsUgx, 7000);
    });

    test('the group balance counts every member', () async {
      await db.ledgerDao.insertEntry(entry(EntryType.contribution, 10000));
      await db.ledgerDao.insertEntry(
        entry(EntryType.contribution, 7000, memberId: peter),
      );
      await db.ledgerDao.insertEntry(
        entry(EntryType.loan, 4000, memberId: peter),
      );

      expect(
        await db.ledgerDao.watchGroupBalance(groupId).first,
        const Balance(savingsUgx: 17000, loansOutstandingUgx: 4000),
      );
    });

    test('a watched balance updates when an entry is added', () async {
      final balances = db.ledgerDao.watchMemberBalance(sarah);

      final expectation = expectLater(
        balances.map((b) => b.savingsUgx),
        emitsInOrder([0, 10000]),
      );
      await Future<void>.delayed(Duration.zero);
      await db.ledgerDao.insertEntry(entry(EntryType.contribution, 10000));

      await expectation;
    });
  });
}
