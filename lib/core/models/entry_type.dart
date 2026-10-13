/// What kind of money event a ledger entry records.
///
/// The names are stored in the database and sent to the server, so renaming
/// a value is a schema change, not a refactor.
enum EntryType {
  /// A member saved money with the group.
  contribution,

  /// The group lent money to a member.
  loan,

  /// A member paid back part or all of a loan.
  repayment,

  /// Fixes a mistake in an earlier entry. The earlier entry is never edited.
  correction,
}
