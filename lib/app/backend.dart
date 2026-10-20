import 'package:connectivity_plus/connectivity_plus.dart';
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

/// The one place that turns the BACKEND setting into a server. Both the app
/// (main.dart) and the background sync use it, so they always agree.
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
