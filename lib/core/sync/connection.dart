import 'package:connectivity_plus/connectivity_plus.dart';

/// Whether the phone has any network at all.
///
/// This is only a hint. Having Wi-Fi does not mean the server can be
/// reached, so a sync can still fail while this says "online". It is good
/// for one thing: knowing when it is worth trying again.
bool isOnline(List<ConnectivityResult> results) =>
    results.any((result) => result != ConnectivityResult.none);

/// The phone's online status now, then every time it changes.
Stream<bool> watchOnline(Connectivity connectivity) async* {
  yield isOnline(await connectivity.checkConnectivity());
  yield* connectivity.onConnectivityChanged.map(isOnline);
}
