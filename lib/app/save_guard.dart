import 'package:flutter/material.dart';
import 'package:vsla_ledger/core/ledger/ledger_rule_broken.dart';
import 'package:vsla_ledger/features/ledger/ledger_labels.dart';
import 'package:vsla_ledger/l10n/app_localizations.dart';

/// Runs a save and, if it fails, tells the treasurer why. Returns true when
/// the record was saved.
///
/// A ledger rule that was broken gets its own message ("more than the member
/// owes"). Anything else, such as a full phone, gets a general one. Without
/// this a failed save looks like nothing happened, which is the worst thing
/// an app that promises "never lose a record" can do.
Future<bool> saveOrExplain(
  BuildContext context,
  Future<void> Function() save,
) async {
  // Taken before the await: the screen may be gone when the save ends.
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);

  try {
    await save();
    return true;
  } on LedgerRuleBroken catch (refusal) {
    messenger.showSnackBar(
      SnackBar(content: Text(ledgerRuleMessage(l10n, refusal.rule))),
    );
  } on Exception {
    messenger.showSnackBar(SnackBar(content: Text(l10n.saveFailed)));
  }
  return false;
}
