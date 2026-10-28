import 'package:flutter_test/flutter_test.dart';
import 'package:vsla_ledger/core/ledger/balance_calculator.dart';
import 'package:vsla_ledger/core/models/entry_type.dart';
import 'package:vsla_ledger/core/models/ledger_entry.dart';

LedgerEntry entry(
  String id,
  EntryType type,
  int amountUgx, {
  String member = 'sarah',
  String? loanId,
  String? corrects,
  int? shares,
  int? percent,
}) => LedgerEntry(
  id: id,
  groupId: 'group-1',
  memberId: member,
  type: type,
  amountUgx: amountUgx,
  createdAt: DateTime.utc(2026, 8, 1, 12),
  deviceId: 'phone-a',
  meetingDate: DateTime.utc(2026, 8),
  loanId: loanId,
  correctsEntryId: corrects,
  shares: shares,
  monthlyChargePercent: percent,
);

void main() {
  final today = DateTime.utc(2026, 9);

  test('nothing recorded, nothing owed', () {
    expect(computeBalance([], today: today).savingsUgx, 0);
  });

  test('savings, shares, social fund and fines are kept apart', () {
    final balance = computeBalance([
      entry('a', EntryType.contribution, 6000, shares: 3),
      entry('b', EntryType.contribution, 4000, shares: 2),
      entry('c', EntryType.socialFund, 1000),
      entry('d', EntryType.fine, 500),
    ], today: today);

    expect(balance.savingsUgx, 10000);
    expect(balance.sharesCount, 5);
    expect(balance.socialFundUgx, 1000);
    expect(balance.finesUgx, 500);
  });

  test('a cancelled entry does not count, whatever its kind', () {
    final balance = computeBalance([
      entry('a', EntryType.fine, 500),
      entry('x', EntryType.correction, 500, corrects: 'a'),
      entry('b', EntryType.socialFund, 2000),
      entry('y', EntryType.correction, 2000, corrects: 'b'),
    ], today: today);

    expect(balance.finesUgx, 0);
    expect(balance.socialFundUgx, 0);
  });

  test('loans to repay include the service charge', () {
    final balance = computeBalance([
      entry('loan', EntryType.loan, 100000, percent: 10),
    ], today: today);

    expect(balance.chargesOwedUgx, 10000);
    expect(balance.loansOutstandingUgx, 110000);
  });

  test('a group adds up every member', () {
    final balance = computeBalance([
      entry('a', EntryType.contribution, 5000),
      entry('b', EntryType.contribution, 7000, member: 'peter'),
      entry('loan1', EntryType.loan, 10000),
      entry('loan2', EntryType.loan, 20000, member: 'peter'),
      entry('r', EntryType.repayment, 4000, member: 'peter', loanId: 'loan2'),
    ], today: today);

    expect(balance.savingsUgx, 12000);
    expect(balance.loansOutstandingUgx, 26000);
  });

  test('a repayment on a cancelled loan is flagged, not hidden', () {
    final balance = computeBalance([
      entry('loan', EntryType.loan, 5000),
      entry('x', EntryType.correction, 5000, corrects: 'loan'),
      entry('r', EntryType.repayment, 2000, loanId: 'loan'),
    ], today: today);

    expect(balance.loansOutstandingUgx, 0);
    expect(balance.repaymentsWithoutLoanUgx, 2000);
  });
}
