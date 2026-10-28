import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:vsla_ledger/core/sync/connection.dart';
import 'package:vsla_ledger/core/sync/delayed_remote.dart';
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

/// Talk demo only: shows the "Compare" screen (lib/features/demo/).
const demoMode = bool.fromEnvironment('DEMO');

/// Talk demo only: pretend the network is slow by waiting this long before
/// every request to the server. Set in milliseconds with DEMO_DELAY_MS;
/// unset means no delay.
// The linter only sees the unset value (0); the real one comes from the
// build command, so this cannot be written as Duration.zero.
// ignore: use_named_constants
const demoDelay = Duration(
  // Same reason: 0 is only the value when DEMO_DELAY_MS is not set.
  // ignore: avoid_redundant_argument_values
  milliseconds: int.fromEnvironment('DEMO_DELAY_MS'),
);

/// The one place that turns the BACKEND setting into a server. Both the app
/// (main.dart) and the background sync use it, so they always agree.
Future<LedgerRemote> remoteFor(String backend) async {
  final remote = await _serverFor(backend);
  if (demoDelay <= Duration.zero) return remote;
  return DelayedRemote(remote, demoDelay);
}

Future<LedgerRemote> _serverFor(String backend) async => switch (backend) {
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
