import 'package:flutter_test/flutter_test.dart';
import 'package:vsla_ledger/core/ledger/loan_status.dart';
import 'package:vsla_ledger/core/models/entry_type.dart';
import 'package:vsla_ledger/core/models/ledger_entry.dart';

LedgerEntry entry(
  String id,
  EntryType type,
  int amountUgx, {
  String? loanId,
  String? correctsEntryId,
}) => LedgerEntry(
  id: id,
  groupId: 'group-1',
  memberId: 'member-sarah',
  type: type,
  amountUgx: amountUgx,
  createdAt: DateTime.utc(2026, 10, 19),
  deviceId: 'phone-a',
  loanId: loanId,
  correctsEntryId: correctsEntryId,
);

void main() {
  test('no entries, no loans', () {
    expect(loanStatuses([]), isEmpty);
  });

  test('what is owed is the loan minus its repayments', () {
    final statuses = loanStatuses([
      entry('loan-1', EntryType.loan, 50000),
      entry('loan-2', EntryType.loan, 10000),
      entry('r-1', EntryType.repayment, 20000, loanId: 'loan-1'),
      entry('r-2', EntryType.repayment, 10000, loanId: 'loan-2'),
      entry('c-1', EntryType.contribution, 5000),
    ]);

    expect(
      {for (final s in statuses) s.loan.id: s.owedUgx},
      {'loan-1': 30000, 'loan-2': 0},
    );
    expect(statuses.last.isRepaid, isTrue);
    expect(statuses.first.hasRepayments, isTrue);
  });

  test('a cancelled loan is not listed', () {
    final statuses = loanStatuses([
      entry('loan-1', EntryType.loan, 50000),
      entry('x', EntryType.correction, 50000, correctsEntryId: 'loan-1'),
    ]);

    expect(statuses, isEmpty);
  });

  test('a cancelled repayment does not reduce what is owed', () {
    final statuses = loanStatuses([
      entry('loan-1', EntryType.loan, 50000),
      entry('r-1', EntryType.repayment, 20000, loanId: 'loan-1'),
      entry('x', EntryType.correction, 20000, correctsEntryId: 'r-1'),
    ]);

    expect(statuses.single.owedUgx, 50000);
    expect(statuses.single.hasRepayments, isFalse);
  });
}
