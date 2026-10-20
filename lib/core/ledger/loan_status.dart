import 'package:vsla_ledger/core/models/entry_type.dart';
import 'package:vsla_ledger/core/models/ledger_entry.dart';

/// A loan and how much of it is still owed.
class LoanStatus {
  const LoanStatus({required this.loan, required this.owedUgx});

  final LedgerEntry loan;
  final int owedUgx;

  bool get isRepaid => owedUgx == 0;

  /// True once at least one repayment counts against this loan.
  bool get hasRepayments => owedUgx < loan.amountUgx;
}

/// Works out every loan of one member that has not been cancelled, and how
/// much is still owed on each.
///
/// [memberEntries] must be all of the member's entries, including
/// corrections, because a correction is what cancels an entry. The screens
/// and the repository both use this, so they always agree on what is owed.
List<LoanStatus> loanStatuses(List<LedgerEntry> memberEntries) {
  final cancelledIds = {
    for (final entry in memberEntries)
      if (entry.type == EntryType.correction) entry.correctsEntryId,
  };
  final counting = memberEntries.where(
    (entry) =>
        entry.type != EntryType.correction && !cancelledIds.contains(entry.id),
  );

  return [
    for (final loan in counting.where((e) => e.type == EntryType.loan))
      LoanStatus(
        loan: loan,
        owedUgx:
            loan.amountUgx -
            counting
                .where(
                  (e) => e.type == EntryType.repayment && e.loanId == loan.id,
                )
                .fold(0, (sum, repayment) => sum + repayment.amountUgx),
      ),
  ];
}
