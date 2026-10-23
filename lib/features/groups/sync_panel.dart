import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vsla_ledger/core/providers.dart';
import 'package:vsla_ledger/core/sync/sync_service.dart';
import 'package:vsla_ledger/l10n/app_localizations.dart';

/// "N records waiting to sync" and a "Sync now" button.
class SyncPanel extends ConsumerStatefulWidget {
  const SyncPanel({super.key});

  @override
  ConsumerState<SyncPanel> createState() => _SyncPanelState();
}

class _SyncPanelState extends ConsumerState<SyncPanel> {
  bool _syncing = false;

  Future<void> _syncNow() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _syncing = true);

    final result = await ref.read(syncServiceProvider).run();

    if (!mounted) return;
    setState(() => _syncing = false);
    final message = switch (result) {
      SyncResult.ok => l10n.syncDone,
      SyncResult.unreachable => l10n.syncFailed,
      SyncResult.refused => l10n.syncRefused,
    };
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final waiting = ref.watch(recordsWaitingToSyncProvider).valueOrNull ?? 0;
    final stuck = ref.watch(stuckRecordsProvider).valueOrNull ?? 0;

    return Column(
      children: [
        ListTile(
          leading: Icon(waiting == 0 ? Icons.cloud_done : Icons.cloud_upload),
          title: Text(l10n.recordsWaiting(waiting)),
          trailing: FilledButton.tonal(
            onPressed: _syncing ? null : _syncNow,
            child: Text(l10n.syncNowButton),
          ),
        ),
        if (stuck > 0)
          ListTile(
            leading: Icon(
              Icons.warning_amber,
              color: Theme.of(context).colorScheme.error,
            ),
            title: Text(l10n.recordsStuck(stuck)),
            subtitle: Text(l10n.recordsStuckHelp),
          ),
      ],
    );
  }
}
