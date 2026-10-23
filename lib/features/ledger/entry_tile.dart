import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vsla_ledger/app/save_guard.dart';
import 'package:vsla_ledger/core/models/entry_line.dart';
import 'package:vsla_ledger/core/models/entry_type.dart';
import 'package:vsla_ledger/core/providers.dart';
import 'package:vsla_ledger/features/ledger/ledger_labels.dart';
import 'package:vsla_ledger/l10n/app_localizations.dart';

/// One line of history: what, how much, when, and whether it has synced.
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
    final entry = line.entry;
    final crossedOut = line.isCancelled
        ? const TextStyle(decoration: TextDecoration.lineThrough)
        : null;

    final synced = ref.watch(usesFakeBackendProvider)
        ? l10n.statusSyncedTest
        : l10n.statusSynced;
    final details = [
      l10n.entryDate(entry.createdAt.toLocal()),
      if (line.isWaitingToSync) l10n.statusSavedOnPhone else synced,
      if (line.isCancelled) l10n.entryCancelled,
    ];

    return ListTile(
      leading: Icon(
        line.isWaitingToSync ? Icons.phone_android : Icons.cloud_done,
        semanticLabel: line.isWaitingToSync ? l10n.statusSavedOnPhone : synced,
      ),
      title: Text(
        '${entryTypeLabel(l10n, entry.type)}  '
        '${l10n.amountUgx(entry.amountUgx)}',
        style: crossedOut,
      ),
      subtitle: Text(details.join(' · ')),
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
