import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vsla_ledger/app/save_guard.dart';
import 'package:vsla_ledger/app/theme.dart';
import 'package:vsla_ledger/core/models/entry_line.dart';
import 'package:vsla_ledger/core/models/entry_type.dart';
import 'package:vsla_ledger/core/providers.dart';
import 'package:vsla_ledger/features/ledger/ledger_labels.dart';
import 'package:vsla_ledger/l10n/app_localizations.dart';

/// One line of history: what, how much, and whether it has synced. The day
/// is the heading the line sits under.
///
/// A cancelled entry stays visible but crossed out, like on paper.
class EntryTile extends ConsumerWidget {
  const EntryTile({required this.line, super.key});

  final EntryLine line;

  bool get _canBeCancelled =>
      !line.isCancelled && line.entry.type != EntryType.correction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final entry = line.entry;
    final style = entryStyleOf(context, entry.type);
    // A cancelled line fades and is crossed out, whatever its colour was.
    final color = line.isCancelled ? theme.disabledColor : style.color;
    final strike = line.isCancelled ? TextDecoration.lineThrough : null;

    final synced = ref.watch(usesFakeBackendProvider)
        ? l10n.statusSyncedTest
        : l10n.statusSynced;
    final status = line.isWaitingToSync ? l10n.statusSavedOnPhone : synced;
    final details = [
      if (entry.shares != null) l10n.sharesBought(entry.shares!),
      status,
      if (line.isCancelled) l10n.entryCancelled,
    ];

    return ListTile(
      minVerticalPadding: 12,
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.14),
        child: Icon(style.icon, color: color),
      ),
      // One piece of text ("Savings  UGX 10,000") so a screen reader reads
      // the whole line, with the amount in bold.
      title: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: entryTypeLabel(l10n, entry.type),
              style: TextStyle(decoration: strike),
            ),
            const TextSpan(text: '  '),
            TextSpan(
              text: l10n.amountUgx(entry.amountUgx),
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: line.isCancelled ? null : color,
                decoration: strike,
              ),
            ),
          ],
        ),
      ),
      subtitle: Row(
        children: [
          Icon(
            line.isWaitingToSync
                ? Icons.phone_android
                : Icons.cloud_done_outlined,
            size: 14,
            color: theme.colorScheme.onSurfaceVariant,
            semanticLabel: status,
          ),
          const SizedBox(width: 6),
          Flexible(child: Text(details.join(' · '))),
        ],
      ),
      trailing: _canBeCancelled
          ? PopupMenuButton<void>(
              itemBuilder: (context) => [
                PopupMenuItem(
                  onTap: () => _confirmCancel(context, ref),
                  child: Text(l10n.cancelEntryAction),
                ),
              ],
            )
          : null,
    );
  }

  Future<void> _confirmCancel(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(l10n.cancelEntryQuestion(line.entry.amountUgx)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.keepEntryButton),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.cancelEntryConfirm),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    if (!context.mounted) return;
    await saveOrExplain(
      context,
      () => ref.read(ledgerRepositoryProvider).cancelEntry(line.entry.id),
    );
  }
}
