import 'package:vsla_ledger/core/ledger/ledger_rule_broken.dart';
import 'package:vsla_ledger/core/models/entry_type.dart';
import 'package:vsla_ledger/l10n/app_localizations.dart';

/// The words shown for each kind of entry.
String entryTypeLabel(AppLocalizations l10n, EntryType type) => switch (type) {
  EntryType.contribution => l10n.entryTypeContribution,
  EntryType.loan => l10n.entryTypeLoan,
  EntryType.repayment => l10n.entryTypeRepayment,
  EntryType.correction => l10n.entryTypeCorrection,
};

/// The message shown when the app refuses a write. Adding a new rule without
/// a message here is a compile error, so no refusal is ever left unexplained.
String ledgerRuleMessage(AppLocalizations l10n, LedgerRule rule) =>
    switch (rule) {
      LedgerRule.amountMustBePositive => l10n.ruleAmountMustBePositive,
      LedgerRule.amountTooLarge => l10n.ruleAmountTooLarge,
      LedgerRule.entryNotFound => l10n.ruleEntryNotFound,
      LedgerRule.notALoanOfThisMember => l10n.ruleNotALoanOfThisMember,
      LedgerRule.loanIsCancelled => l10n.ruleLoanIsCancelled,
      LedgerRule.repaymentMoreThanOwed => l10n.ruleRepaymentMoreThanOwed,
      LedgerRule.alreadyCancelled => l10n.ruleAlreadyCancelled,
      LedgerRule.cannotCancelACorrection => l10n.ruleCannotCancelACorrection,
      LedgerRule.loanHasRepayments => l10n.ruleLoanHasRepayments,
    };
