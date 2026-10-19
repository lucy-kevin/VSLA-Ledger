import 'package:drift/drift.dart';
import 'package:vsla_ledger/core/database/app_database.dart';
import 'package:vsla_ledger/core/database/tables.dart';
import 'package:vsla_ledger/core/models/balance.dart';
import 'package:vsla_ledger/core/models/entry_type.dart';
import 'package:vsla_ledger/core/models/ledger_entry.dart';

part 'ledger_dao.g.dart';

/// Reads and appends ledger entries.
///
/// There is deliberately no update or delete method here. Mistakes are fixed
/// by appending a correction entry that cancels the wrong one.
@DriftAccessor(tables: [LedgerEntries])
class LedgerDao extends DatabaseAccessor<AppDatabase> with _$LedgerDaoMixin {
  LedgerDao(super.attachedDatabase);

  /// An entry that arrives twice (from the server or another phone) is
  /// stored once.
  ///
  /// This is not INSERT OR IGNORE on purpose: that also silently skips rows
  /// that break a rule, such as an amount of zero, and the entry would be
  /// lost without any error. Here only a duplicate id is skipped.
  Future<void> insertEntry(LedgerEntry entry) => into(ledgerEntries).insert(
    entry.toInsertable(),
    onConflict: DoNothing(target: [ledgerEntries.id]),
  );

  Future<LedgerEntry?> getEntry(String id) => (select(
    ledgerEntries,
  )..where((e) => e.id.equals(id))).getSingleOrNull();

  /// Whether any correction points at this entry.
  Future<bool> isCancelled(String entryId) async {
    final correction =
        await (select(ledgerEntries)
              ..where(
                (e) =>
                    e.type.equalsValue(EntryType.correction) &
                    e.correctsEntryId.equals(entryId),
              )
              ..limit(1))
            .getSingleOrNull();
    return correction != null;
  }

  Future<List<LedgerEntry>> getRepaymentsForLoan(String loanId) =>
      (select(ledgerEntries)..where(
            (e) =>
                e.type.equalsValue(EntryType.repayment) &
                e.loanId.equals(loanId),
          ))
          .get();

  /// Every entry for a member, newest first, including corrections and the
  /// entries they cancel, so the history reads like the paper ledger.
  Stream<List<LedgerEntry>> watchEntriesForMember(String memberId) =>
      (select(ledgerEntries)
            ..where((e) => e.memberId.equals(memberId))
            ..orderBy([(e) => OrderingTerm.desc(e.createdAt)]))
          .watch();

  /// Ids of entries that a correction has cancelled, so the screen can show
  /// them crossed out.
  Stream<Set<String>> watchCancelledEntryIds(String groupId) {
    final query = selectOnly(ledgerEntries)
      ..addColumns([ledgerEntries.correctsEntryId])
      ..where(
        ledgerEntries.groupId.equals(groupId) &
            ledgerEntries.type.equalsValue(EntryType.correction),
      );
    return query.watch().map(
      (rows) => {
        for (final row in rows) row.read(ledgerEntries.correctsEntryId)!,
      },
    );
  }

  Stream<Balance> watchMemberBalance(String memberId) =>
      _watchBalance(column: 'member_id', id: memberId);

  Stream<Balance> watchGroupBalance(String groupId) =>
      _watchBalance(column: 'group_id', id: groupId);

  // One query for both balances. `column` is only ever one of the two fixed
  // names above, never user input, so putting it in the SQL is safe.
  //
  // An entry counts unless it is a correction, or a correction cancels it.
  Stream<Balance> _watchBalance({required String column, required String id}) {
    final contribution = EntryType.contribution.name;
    final loan = EntryType.loan.name;
    final repayment = EntryType.repayment.name;
    final correction = EntryType.correction.name;

    return customSelect(
      '''
      SELECT
        COALESCE(SUM(CASE WHEN e.type = '$contribution'
                          THEN e.amount_ugx END), 0) AS savings,
        COALESCE(SUM(CASE WHEN e.type = '$loan'
                          THEN e.amount_ugx END), 0)
          - COALESCE(SUM(CASE WHEN e.type = '$repayment'
                              THEN e.amount_ugx END), 0) AS loans_outstanding
      FROM ledger_entries e
      WHERE e.$column = ?
        AND e.type != '$correction'
        AND NOT EXISTS (
          SELECT 1 FROM ledger_entries c
          WHERE c.type = '$correction' AND c.corrects_entry_id = e.id
        )
      ''',
      variables: [Variable.withString(id)],
      readsFrom: {ledgerEntries},
    ).watchSingle().map(
      (row) => Balance(
        savingsUgx: row.read<int>('savings'),
        loansOutstandingUgx: row.read<int>('loans_outstanding'),
      ),
    );
  }
}
