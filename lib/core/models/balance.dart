import 'package:freezed_annotation/freezed_annotation.dart';

part 'balance.freezed.dart';

/// Money totals for a member or a whole group, worked out from the ledger.
///
/// Balances are never stored. They are always added up from the entries
/// (see `computeBalance`), so they can never drift out of step with the
/// records.
@freezed
class Balance with _$Balance {
  const factory Balance({
    /// Total savings, in whole Uganda shillings.
    required int savingsUgx,

    /// Everything still owed on loans: money lent that is not paid back, plus
    /// service charges that are not paid yet.
    required int loansOutstandingUgx,

    /// How many shares were bought (groups that save in shares).
    @Default(0) int sharesCount,

    /// The part of [loansOutstandingUgx] that is service charge.
    @Default(0) int chargesOwedUgx,

    /// Paid into the social fund. Not part of the savings.
    @Default(0) int socialFundUgx,

    /// Fines paid. Not part of the savings.
    @Default(0) int finesUgx,

    /// Repayments whose loan has been cancelled (see `computeBalance`). Above
    /// zero means the history needs a look.
    @Default(0) int repaymentsWithoutLoanUgx,
  }) = _Balance;
}
