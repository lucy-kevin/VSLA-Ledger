import 'package:freezed_annotation/freezed_annotation.dart';

part 'balance.freezed.dart';

/// Money totals for a member or a whole group, worked out from the ledger.
///
/// Balances are never stored. They are always added up from the entries,
/// so they can never drift out of step with the records.
@freezed
class Balance with _$Balance {
  const factory Balance({
    /// Total contributions, in whole Uganda shillings.
    required int savingsUgx,

    /// Loans given minus repayments, in whole Uganda shillings.
    required int loansOutstandingUgx,
  }) = _Balance;
}
