import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vsla_ledger/app/app.dart';
import 'package:vsla_ledger/app/backend.dart';
import 'package:vsla_ledger/app/background_sync.dart';
import 'package:vsla_ledger/core/database/app_database.dart';
import 'package:vsla_ledger/core/ledger/device_id.dart';
import 'package:vsla_ledger/core/providers.dart';
import 'package:workmanager/workmanager.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final db = AppDatabase.onDevice();
  final deviceId = await loadDeviceId(db.syncStateDao);
  final remote = await remoteFor(backend);
  await startBackgroundSync(backgroundSyncEntryPoint);

  runApp(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        deviceIdProvider.overrideWithValue(deviceId),
        // This one line is the whole "swap the backend" story.
        ledgerRemoteProvider.overrideWithValue(remote),
      ],
      child: const VslaApp(),
    ),
  );
}

/// Where Android starts the app's code for a background sync. It runs on its
/// own, without the app's screens, so it opens its own database and server
/// connection.
@pragma('vm:entry-point')
void backgroundSyncEntryPoint() {
  Workmanager().executeTask(
    (taskName, inputData) => runBackgroundSync(
      openDatabase: AppDatabase.onDevice,
      connect: () => remoteFor(backend),
    ),
  );
}
