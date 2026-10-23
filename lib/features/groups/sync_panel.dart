import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vsla_ledger/core/providers.dart';
import 'package:vsla_ledger/core/sync/sync_service.dart';
import 'package:vsla_ledger/l10n/app_localizations.dart';

/// "N records waiting to sync" and a "Sync now" button.
///
/// Calm when everything is synced, warmer when records are waiting, and red
/// for records the server keeps refusing.
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
    final scheme = Theme.of(context).colorScheme;
    final waiting = ref.watch(recordsWaitingToSyncProvider).valueOrNull ?? 0;
    final stuck = ref.watch(stuckRecordsProvider).valueOrNull ?? 0;
    final allSynced = waiting == 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.only(left: 16, right: 8),
          decoration: BoxDecoration(
            color: allSynced
                ? scheme.surfaceContainerLow
                : scheme.tertiaryContainer,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Icon(
                allSynced ? Icons.cloud_done_outlined : Icons.cloud_upload,
                color: allSynced ? scheme.primary : scheme.onTertiaryContainer,
                size: 22,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  l10n.recordsWaiting(waiting),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: allSynced
                        ? scheme.onSurface
                        : scheme.onTertiaryContainer,
                    fontWeight: allSynced ? null : FontWeight.w600,
                  ),
                ),
              ),
              TextButton(
                onPressed: _syncing ? null : _syncNow,
                child: _syncing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l10n.syncNowButton),
              ),
            ],
          ),
        ),
        if (stuck > 0)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: scheme.errorContainer,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.warning_amber, color: scheme.onErrorContainer),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.recordsStuck(stuck),
                          style: TextStyle(
                            color: scheme.onErrorContainer,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          l10n.recordsStuckHelp,
                          style: TextStyle(color: scheme.onErrorContainer),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
