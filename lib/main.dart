import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vsla_ledger/app/app.dart';
import 'package:vsla_ledger/core/database/app_database.dart';
import 'package:vsla_ledger/core/ledger/device_id.dart';
import 'package:vsla_ledger/core/providers.dart';
import 'package:vsla_ledger/core/sync/ledger_remote.dart';
import 'package:vsla_ledger/remote/fake_remote.dart';

/// Which server to use: `flutter run --dart-define=BACKEND=fake`.
/// `fake` needs no server and no internet, so it is the default.
const backend = String.fromEnvironment('BACKEND', defaultValue: 'fake');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final db = AppDatabase.onDevice();
  final deviceId = await loadDeviceId(db.syncStateDao);

  runApp(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        deviceIdProvider.overrideWithValue(deviceId),
        // This one line is the whole "swap the backend" story.
        ledgerRemoteProvider.overrideWithValue(remoteFor(backend)),
      ],
      child: const VslaApp(),
    ),
  );
}

LedgerRemote remoteFor(String backend) => switch (backend) {
  'fake' => FakeLedgerRemote(),
  _ => throw UnsupportedError(
    'Unknown BACKEND "$backend". Use: fake. '
    'PocketBase and Firebase arrive in Week 2.',
  ),
};
