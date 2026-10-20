import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vsla_ledger/core/providers.dart';
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

    final succeeded = await ref.read(syncServiceProvider).run();

    if (!mounted) return;
    setState(() => _syncing = false);
    messenger.showSnackBar(
      SnackBar(content: Text(succeeded ? l10n.syncDone : l10n.syncFailed)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final waiting = ref.watch(recordsWaitingToSyncProvider).valueOrNull ?? 0;

    return ListTile(
      leading: Icon(waiting == 0 ? Icons.cloud_done : Icons.cloud_upload),
      title: Text(l10n.recordsWaiting(waiting)),
      trailing: FilledButton.tonal(
        onPressed: _syncing ? null : _syncNow,
        child: Text(l10n.syncNowButton),
      ),
    );
  }
}
