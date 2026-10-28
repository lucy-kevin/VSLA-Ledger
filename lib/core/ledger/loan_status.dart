import 'package:vsla_ledger/core/clock.dart';
import 'package:vsla_ledger/core/models/entry_type.dart';
import 'package:vsla_ledger/core/models/ledger_entry.dart';

/// A loan and how much of it is still owed.
class LoanStatus {
  const LoanStatus({
    required this.loan,
    required this.principalOwedUgx,
    required this.chargesOwedUgx,
    required this.repaymentCount,
  });

  final LedgerEntry loan;

  /// Part of the money lent that has not been paid back yet.
  final int principalOwedUgx;

  /// Service charges that have built up and have not been paid yet.
  final int chargesOwedUgx;

  /// How many repayments count against this loan (cancelled ones do not).
  final int repaymentCount;

  /// Everything the member still has to pay on this loan.
  int get owedUgx => principalOwedUgx + chargesOwedUgx;

  bool get isRepaid => owedUgx == 0;

  /// True once at least one repayment counts against this loan.
  bool get hasRepayments => repaymentCount > 0;
}

/// Works out every loan that has not been cancelled, and how much is still
/// owed on each, as of [today] (the phone's date when left out).
///
/// [entries] must include corrections, because a correction is what cancels
/// an entry. It can be one member's entries or a whole group's. The screens,
/// the balance and the repository all use this, so they always agree on what
/// is owed.
///
/// ## The service charge
///
/// A loan carries a charge of `monthlyChargePercent` of what is still
/// unpaid, added each time a full calendar month has passed since the loan's
/// meeting day. A loan of 1 October gets its first charge on 1 November.
/// (If the month is shorter, the last day of that month is used.)
///
/// - The charge is a percentage of the **unpaid loan**, not of the unpaid
///   charges, so charges do not grow on charges.
/// - It is rounded to whole shillings, half up.
/// - A repayment pays the charges first, then the loan.
/// - A repayment dated on a charge day counts before that charge is worked out.
///
/// Nothing here is stored. Change a repayment's date, cancel it, or let a
/// month pass, and the answer changes by itself.
List<LoanStatus> loanStatuses(List<LedgerEntry> entries, {DateTime? today}) {
  final day = dateOnly(today ?? DateTime.now());
  final counting = entriesThatCount(entries);

  return [
    for (final loan in counting.where((e) => e.type == EntryType.loan))
      _statusOf(
        loan,
        counting
            .where((e) => e.type == EntryType.repayment && e.loanId == loan.id)
            .toList(),
        day,
      ),
  ];
}

/// Entries that are neither corrections nor cancelled by one. These are the
/// ones that count towards any total.
List<LedgerEntry> entriesThatCount(List<LedgerEntry> entries) {
  final cancelledIds = {
    for (final entry in entries)
      if (entry.type == EntryType.correction) entry.correctsEntryId,
  };
  return [
    for (final entry in entries)
      if (entry.type != EntryType.correction &&
          !cancelledIds.contains(entry.id))
        entry,
  ];
}

LoanStatus _statusOf(
  LedgerEntry loan,
  List<LedgerEntry> repayments,
  DateTime today,
) {
  final rate = loan.monthlyChargePercent ?? 0;
  final ordered = [...repayments]
    ..sort((a, b) {
      final byDay = a.meetingDay.compareTo(b.meetingDay);
      return byDay != 0 ? byDay : a.createdAt.compareTo(b.createdAt);
    });

  var principal = loan.amountUgx;
  var charges = 0;
  var next = 0; // index of the next repayment not yet applied

  void applyRepaymentsUpTo(DateTime day) {
    while (next < ordered.length && !ordered[next].meetingDay.isAfter(day)) {
      var money = ordered[next].amountUgx;
      final towardsCharges = money < charges ? money : charges;
      charges -= towardsCharges;
      money -= towardsCharges;
      principal -= money < principal ? money : principal;
      next++;
    }
  }

  if (rate > 0) {
    for (var month = 1; ; month++) {
      final chargeDay = _monthsAfter(loan.meetingDay, month);
      if (chargeDay.isAfter(today)) break;
      applyRepaymentsUpTo(chargeDay);
      charges += (principal * rate + 50) ~/ 100;
    }
  }
  applyRepaymentsUpTo(DateTime.utc(9999));

  return LoanStatus(
    loan: loan,
    principalOwedUgx: principal,
    chargesOwedUgx: charges,
    repaymentCount: repayments.length,
  );
}

/// [start] plus [months] calendar months, keeping the day of the month, or
/// the last day of a shorter month (31 January plus one month is 28 February).
DateTime _monthsAfter(DateTime start, int months) {
  final monthIndex = start.month - 1 + months;
  final year = start.year + monthIndex ~/ 12;
  final month = monthIndex % 12 + 1;
  final lastDay = DateTime.utc(year, month + 1, 0).day;
  return DateTime.utc(year, month, start.day < lastDay ? start.day : lastDay);
}
