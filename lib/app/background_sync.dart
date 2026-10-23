import 'dart:io';

import 'package:vsla_ledger/app/backend.dart';
import 'package:vsla_ledger/core/database/app_database.dart';
import 'package:vsla_ledger/core/sync/ledger_remote.dart';
import 'package:vsla_ledger/core/sync/sync_service.dart';
import 'package:workmanager/workmanager.dart';

const _taskName = 'vsla-background-sync';

/// Asks Android to sync about every 15 minutes, only when there is a
/// network, even while the app is closed. Records saved offline then reach
/// the server without the treasurer opening the app again.
///
/// Android only. Skipped for the fake server: it lives inside the app, so a
/// background task would start an empty fake of its own and "sync" to it.
///
/// [entryPoint] is the top-level function Android starts for each sync
/// (see `backgroundSyncEntryPoint` in main.dart).
Future<void> startBackgroundSync(void Function() entryPoint) async {
  if (!Platform.isAndroid || !syncsInBackground(backend)) return;

  await Workmanager().initialize(entryPoint);
  await Workmanager().registerPeriodicTask(
    _taskName,
    _taskName,
    // 15 minutes is the shortest gap Android allows.
    frequency: const Duration(minutes: 15),
    constraints: Constraints(networkType: NetworkType.connected),
    // If the app registers again on every start, keep the existing schedule.
    existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
    backoffPolicy: BackoffPolicy.exponential,
  );
}

bool syncsInBackground(String backend) => backend != 'fake';

/// One background sync. Returns true when it is done, false to ask Android
/// to try again later (with a growing wait between tries).
Future<bool> runBackgroundSync({
  required AppDatabase Function() openDatabase,
  required Future<LedgerRemote> Function() connect,
}) async {
  final db = openDatabase();
  try {
    final remote = await connect();
    final result = await SyncService(db: db, remote: remote).run();
    // A refusal will not go away by waiting, so only an unreachable server
    // asks Android to try again.
    return result != SyncResult.unreachable;
  } on Exception {
    return false;
  } finally {
    await db.close();
  }
}
