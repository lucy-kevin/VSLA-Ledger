import 'dart:async';

import 'package:vsla_ledger/core/database/daos/outbox_dao.dart';
import 'package:vsla_ledger/core/sync/sync_service.dart';

/// Decides when to sync, so the treasurer rarely has to press "Sync now".
///
/// It syncs:
/// - when something new lands in the outbox (any write: an entry, a group,
///   a member), if the phone is online;
/// - when the phone comes online, which also covers opening the app.
///
/// Writes do not call this directly. Watching the outbox means every kind
/// of write, now and in future, wakes up the sync without anyone having to
/// remember to.
class SyncTrigger {
  SyncTrigger({
    required SyncService sync,
    required OutboxDao outbox,
  }) : _sync = sync {
    _outboxSubscription = outbox.watchPendingCount().listen(_onOutboxCount);
  }

  final SyncService _sync;
  late final StreamSubscription<int> _outboxSubscription;

  // Assume online until told otherwise; a failed attempt loses nothing.
  bool _online = true;
  int _lastCount = 0;

  void _onOutboxCount(int count) {
    final somethingNew = count > _lastCount;
    _lastCount = count;
    if (somethingNew && _online) _requestSync();
  }

  /// The app came back to the screen. Anything saved while it was in the
  /// background (and not yet sent) goes now, if the phone is online.
  void appResumed() {
    if (_online) _requestSync();
  }

  /// Tell the trigger the phone's online status, now and on every change.
  void onlineChanged({required bool online}) {
    _online = online;
    if (online) _requestSync();
  }

  // Not awaited: the screen never waits for the network. SyncService only
  // runs one sync at a time, so asking often is cheap.
  void _requestSync() => unawaited(_sync.run());

  Future<void> stop() => _outboxSubscription.cancel();
}
