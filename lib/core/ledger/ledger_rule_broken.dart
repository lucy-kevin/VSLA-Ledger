/// The reasons the app refuses to record an entry.
///
/// Each one maps to a message in the ARB files, so screens can explain the
/// problem to the treasurer in their own language.
enum LedgerRule {
  /// Amounts must be at least 1 shilling.
  amountMustBePositive,

  /// Amounts above [maxAmountUgx] are almost certainly a typing mistake.
  amountTooLarge,

  /// The entry to correct, or the loan to repay, does not exist.
  entryNotFound,

  /// A repayment must point at a loan entry for the same member.
  notALoanOfThisMember,

  /// A cancelled loan cannot be repaid.
  loanIsCancelled,

  /// The entry has already been cancelled.
  alreadyCancelled,

  /// A correction cannot itself be cancelled. Record the right entry again
  /// instead.
  cannotCancelACorrection,

  /// A loan with repayments cannot be cancelled. Cancel the repayments first.
  loanHasRepayments,
}

/// The largest single amount the app accepts, in Uganda shillings.
///
/// Provisional: still to be confirmed by Kevin and Julian (see context.md).
const maxAmountUgx = 50000000;

/// Thrown when a write would break one of the [LedgerRule]s. Nothing is
/// saved when this is thrown.
class LedgerRuleBroken implements Exception {
  const LedgerRuleBroken(this.rule);

  final LedgerRule rule;

  @override
  String toString() => 'LedgerRuleBroken: ${rule.name}';
}
