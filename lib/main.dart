import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vsla_ledger/app/app.dart';
import 'package:vsla_ledger/core/database/app_database.dart';
import 'package:vsla_ledger/core/ledger/device_id.dart';
import 'package:vsla_ledger/core/providers.dart';
import 'package:vsla_ledger/core/sync/connection.dart';
import 'package:vsla_ledger/core/sync/ledger_remote.dart';
import 'package:vsla_ledger/remote/fake_remote.dart';
import 'package:vsla_ledger/remote/firebase_remote.dart';
import 'package:vsla_ledger/remote/pocketbase_remote.dart';

/// Which server to use: `flutter run --dart-define=BACKEND=fake`.
/// `fake` needs no server and no internet, so it is the default.
const backend = String.fromEnvironment('BACKEND', defaultValue: 'fake');

/// Where the PocketBase server is. `10.0.2.2` is the Android emulator's name
/// for the laptop it runs on; on a real phone use the laptop's IP address.
const pocketBaseUrl = String.fromEnvironment(
  'PB_URL',
  defaultValue: 'http://10.0.2.2:8090',
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final db = AppDatabase.onDevice();
  final deviceId = await loadDeviceId(db.syncStateDao);
  final remote = await remoteFor(backend);

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

Future<LedgerRemote> remoteFor(String backend) async => switch (backend) {
  'fake' => await fakeThatFollowsTheConnection(Connectivity()),
  'pocketbase' => PocketBaseRemote.connect(pocketBaseUrl),
  // Needs android/app/google-services.json: see server/firebase/README.md.
  'firebase' => await FirebaseRemote.connect(),
  _ => throw UnsupportedError(
    'Unknown BACKEND "$backend". Use fake, pocketbase or firebase.',
  ),
};

/// The fake server lives inside the app, so on its own it would keep
/// "working" in airplane mode. This makes it go offline whenever the phone
/// does, so the airplane-mode demo behaves like a real server.
///
/// The first status is read before the app starts, so no sync can slip
/// through while the phone is already offline.
Future<FakeLedgerRemote> fakeThatFollowsTheConnection(
  Connectivity connectivity,
) async {
  final fake = FakeLedgerRemote()
    ..offline = !isOnline(await connectivity.checkConnectivity());
  connectivity.onConnectivityChanged.listen(
    (results) => fake.offline = !isOnline(results),
  );
  return fake;
}
