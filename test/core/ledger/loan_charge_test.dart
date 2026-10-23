import 'package:flutter_test/flutter_test.dart';
import 'package:vsla_ledger/core/ledger/loan_status.dart';
import 'package:vsla_ledger/core/models/entry_type.dart';
import 'package:vsla_ledger/core/models/ledger_entry.dart';

LedgerEntry entry(
  String id,
  EntryType type,
  int amountUgx, {
  required DateTime day,
  String? loanId,
  String? corrects,
  int? percent,
}) => LedgerEntry(
  id: id,
  groupId: 'group-1',
  memberId: 'member-sarah',
  type: type,
  amountUgx: amountUgx,
  createdAt: day.add(const Duration(hours: 12)),
  deviceId: 'phone-a',
  loanId: loanId,
  correctsEntryId: corrects,
  meetingDate: day,
  monthlyChargePercent: percent,
);

DateTime day(int year, int month, int date) => DateTime.utc(year, month, date);

/// What is owed on one loan of [amount] at [percent] a month, given on
/// [loanDay], with [repayments] as (day, amount), looked at on [today].
LoanStatus owed(
  int amount,
  int? percent,
  DateTime loanDay,
  DateTime today, {
  List<(DateTime, int)> repayments = const [],
}) => loanStatuses(
  [
    entry('loan', EntryType.loan, amount, day: loanDay, percent: percent),
    for (final (i, (repaidOn, money)) in repayments.indexed)
      entry('r$i', EntryType.repayment, money, day: repaidOn, loanId: 'loan'),
  ],
  today: today,
).single;

void main() {
  final august1 = day(2026, 8, 1);

  group('service charge', () {
    test('none in the first month', () {
      final status = owed(100000, 10, august1, day(2026, 8, 31));

      expect(status.chargesOwedUgx, 0);
      expect(status.owedUgx, 100000);
    });

    test('the first charge comes after one full month', () {
      final status = owed(100000, 10, august1, day(2026, 9, 1));

      expect(status.chargesOwedUgx, 10000);
      expect(status.principalOwedUgx, 100000);
      expect(status.owedUgx, 110000);
    });

    test('one charge for each month that has passed', () {
      final status = owed(100000, 10, august1, day(2026, 10, 23));

      expect(status.chargesOwedUgx, 20000);
    });

    test('a loan dated in the past already shows its charges', () {
      // The treasurer records, today, a loan from two months ago.
      final status = owed(50000, 10, day(2026, 8, 23), day(2026, 10, 23));

      expect(status.chargesOwedUgx, 10000);
    });

    test('no rate, or a rate of zero, means no charge ever', () {
      expect(owed(100000, null, august1, day(2027, 8, 1)).chargesOwedUgx, 0);
      expect(owed(100000, 0, august1, day(2027, 8, 1)).chargesOwedUgx, 0);
    });

    test('a repayment pays the charges first, then the loan', () {
      final status = owed(
        100000,
        10,
        august1,
        day(2026, 9, 20),
        repayments: [(day(2026, 9, 15), 4000)],
      );

      // 10,000 charged on 1 Sept, 4,000 paid: charges left, loan untouched.
      expect(status.chargesOwedUgx, 6000);
      expect(status.principalOwedUgx, 100000);
    });

    test('later charges are on what is left of the loan, not on charges', () {
      final status = owed(
        100000,
        10,
        august1,
        day(2026, 10, 23),
        repayments: [(day(2026, 9, 15), 40000)],
      );

      // 1 Sept: charge 10,000. 15 Sept: 40,000 pays 10,000 of charge and
      // 30,000 of loan, leaving 70,000. 1 Oct: charge 7,000.
      expect(status.principalOwedUgx, 70000);
      expect(status.chargesOwedUgx, 7000);
      expect(status.owedUgx, 77000);
    });

    test('a repayment on a charge day counts before that charge', () {
      final status = owed(
        100000,
        10,
        august1,
        day(2026, 9, 1),
        repayments: [(day(2026, 9, 1), 100000)],
      );

      expect(status.owedUgx, 0);
      expect(status.isRepaid, isTrue);
    });

    test(
      'a loan from the 31st is charged on the last day of a short month',
      () {
        final loanDay = day(2026, 1, 31);

        expect(owed(100000, 10, loanDay, day(2026, 2, 27)).chargesOwedUgx, 0);
        expect(
          owed(100000, 10, loanDay, day(2026, 2, 28)).chargesOwedUgx,
          10000,
        );
        expect(
          owed(100000, 10, loanDay, day(2026, 3, 31)).chargesOwedUgx,
          20000,
        );
      },
    );

    test('a charge is rounded to whole shillings, half up', () {
      // 10% of 1,005 is 100.5, and 10% of 1,004 is 100.4.
      expect(owed(1005, 10, august1, day(2026, 9, 1)).chargesOwedUgx, 101);
      expect(owed(1004, 10, august1, day(2026, 9, 1)).chargesOwedUgx, 100);
    });

    test('a cancelled repayment does not count', () {
      final statuses = loanStatuses(
        [
          entry('loan', EntryType.loan, 100000, day: august1, percent: 10),
          entry(
            'r1',
            EntryType.repayment,
            50000,
            day: day(2026, 8, 15),
            loanId: 'loan',
          ),
          entry(
            'c1',
            EntryType.correction,
            50000,
            day: day(2026, 8, 16),
            corrects: 'r1',
          ),
        ],
        today: day(2026, 8, 20),
      );

      expect(statuses.single.principalOwedUgx, 100000);
      expect(statuses.single.hasRepayments, isFalse);
    });

    test('a loan with no meeting date counts from the day it was made', () {
      final old = LedgerEntry(
        id: 'loan',
        groupId: 'group-1',
        memberId: 'member-sarah',
        type: EntryType.loan,
        amountUgx: 100000,
        createdAt: DateTime.utc(2026, 8, 1, 12),
        deviceId: 'phone-a',
        monthlyChargePercent: 10,
      );

      final status = loanStatuses([old], today: day(2026, 9, 2)).single;

      expect(status.chargesOwedUgx, 10000);
    });
  });
}
