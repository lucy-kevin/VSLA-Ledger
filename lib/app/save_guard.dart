import 'package:flutter/material.dart';
import 'package:vsla_ledger/core/ledger/ledger_rule_broken.dart';
import 'package:vsla_ledger/features/ledger/ledger_labels.dart';
import 'package:vsla_ledger/l10n/app_localizations.dart';

/// Runs a save and, if it fails, returns a message for the treasurer. Returns
/// null when the record was saved.
///
/// A ledger rule that was broken gets its own message ("more than the member
/// owes"). Anything else, such as a full phone, gets a general one. Without
/// this a failed save looks like nothing happened, which is the worst thing
/// an app that promises "never lose a record" can do.
///
/// Use this where the message belongs on the form itself (a bottom sheet
/// covers a snack bar). Elsewhere use [saveOrExplain].
Future<String?> saveOrMessage(
  BuildContext context,
  Future<void> Function() save,
) async {
  // Taken before the await: the screen may be gone when the save ends.
  final l10n = AppLocalizations.of(context);

  try {
    await save();
    return null;
  } on LedgerRuleBroken catch (refusal) {
    return ledgerRuleMessage(l10n, refusal.rule);
  } on Exception {
    return l10n.saveFailed;
  }
}

/// Like [saveOrMessage], but shows the message in a snack bar. Returns true
/// when the record was saved.
Future<bool> saveOrExplain(
  BuildContext context,
  Future<void> Function() save,
) async {
  final messenger = ScaffoldMessenger.of(context);

  final problem = await saveOrMessage(context, save);

  if (problem == null) return true;
  messenger.showSnackBar(SnackBar(content: Text(problem)));
  return false;
}
