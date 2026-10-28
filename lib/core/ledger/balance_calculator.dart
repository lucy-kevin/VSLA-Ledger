import 'package:vsla_ledger/core/ledger/loan_status.dart';
import 'package:vsla_ledger/core/models/balance.dart';
import 'package:vsla_ledger/core/models/entry_type.dart';
import 'package:vsla_ledger/core/models/ledger_entry.dart';

/// Adds up a member's (or a whole group's) entries into the figures the
/// screens show.
///
/// This is the only place balances are worked out. They are never stored, so
/// they can never drift out of step with the records, and loan charges (see
/// [loanStatuses]) are always counted the same way here as in the forms.
///
/// An entry counts unless it is a correction, or a correction cancels it.
Balance computeBalance(List<LedgerEntry> entries, {DateTime? today}) {
  final counting = entriesThatCount(entries);

  int total(EntryType type) => counting
      .where((entry) => entry.type == type)
      .fold(0, (sum, entry) => sum + entry.amountUgx);

  final loans = loanStatuses(entries, today: today);
  final loanIds = {for (final status in loans) status.loan.id};

  return Balance(
    savingsUgx: total(EntryType.contribution),
    sharesCount: counting
        .where((entry) => entry.type == EntryType.contribution)
        .fold(0, (sum, entry) => sum + (entry.shares ?? 0)),
    loansOutstandingUgx: loans.fold(0, (sum, s) => sum + s.owedUgx),
    chargesOwedUgx: loans.fold(0, (sum, s) => sum + s.chargesOwedUgx),
    socialFundUgx: total(EntryType.socialFund),
    finesUgx: total(EntryType.fine),
    // Possible when two offline phones disagree: one cancels a loan while
    // the other records a repayment on it. The money was paid, so say so
    // instead of hiding it.
    repaymentsWithoutLoanUgx: counting
        .where(
          (entry) =>
              entry.type == EntryType.repayment &&
              !loanIds.contains(entry.loanId),
        )
        .fold(0, (sum, entry) => sum + entry.amountUgx),
  );
}
