import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vsla_ledger/core/database/app_database.dart';
import 'package:vsla_ledger/core/ledger/ledger_repository.dart';
import 'package:vsla_ledger/core/sync/connection.dart';
import 'package:vsla_ledger/core/sync/sync_service.dart';
import 'package:vsla_ledger/core/sync/sync_trigger.dart';
import 'package:vsla_ledger/remote/fake_remote.dart';

import '../../helpers/test_database.dart';

/// Waits until [condition] is true, or fails after about two seconds.
Future<void> eventually(Future<bool> Function() condition) async {
  for (var i = 0; i < 200; i++) {
    if (await condition()) return;
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  fail('condition never became true');
}

void main() {
  late AppDatabase db;
  late FakeLedgerRemote server;
  late SyncTrigger trigger;
  late LedgerRepository ledger;

  setUp(() {
    db = newTestDatabase();
    server = FakeLedgerRemote();
    ledger = LedgerRepository(db: db, deviceId: 'phone-a');
    trigger = SyncTrigger(
      sync: SyncService(db: db, remote: server),
      outbox: db.outboxDao,
    );
  });
  tearDown(() async {
    await trigger.stop();
    await db.close();
  });

  Future<void> contribute() => ledger.recordContribution(
    groupId: 'group-1',
    memberId: 'member-sarah',
    amountUgx: 1000,
  );

  Future<int> waiting() => db.outboxDao.watchPendingCount().first;

  test('a new record syncs on its own when online', () async {
    trigger.onlineChanged(online: true);

    await contribute();

    await eventually(() async => server.entries.length == 1);
    expect(await waiting(), 0);
  });

  test('offline, a new record waits and nothing is tried', () async {
    server.offline = true;
    trigger.onlineChanged(online: false);

    await contribute();
    await Future<void>.delayed(const Duration(milliseconds: 100));

    final item = (await db.outboxDao.nextBatch(limit: 50)).single;
    // No failed attempt: the trigger did not try while offline.
    expect(item.attempts, 0);
  });

  test('coming back online sends what was waiting', () async {
    server.offline = true;
    trigger.onlineChanged(online: false);
    await contribute();
    await contribute();

    server.offline = false;
    trigger.onlineChanged(online: true);

    await eventually(() async => await waiting() == 0);
    expect(server.entries, hasLength(2));
  });

  test('coming back to the app sends what is waiting, if online', () async {
    server.offline = true;
    trigger.onlineChanged(online: false);
    await contribute();

    trigger.appResumed();
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(
      (await db.outboxDao.nextBatch(limit: 50)).single.attempts,
      0,
      reason: 'offline: nothing tried',
    );

    server.offline = false;
    trigger
      ..onlineChanged(online: true)
      ..appResumed();
    await eventually(() async => await waiting() == 0);
  });

  group('isOnline', () {
    test('no network at all is offline', () {
      expect(isOnline([ConnectivityResult.none]), isFalse);
      expect(isOnline([]), isFalse);
    });

    test('any kind of network is online', () {
      expect(isOnline([ConnectivityResult.wifi]), isTrue);
      expect(isOnline([ConnectivityResult.mobile]), isTrue);
      expect(
        isOnline([ConnectivityResult.none, ConnectivityResult.ethernet]),
        isTrue,
      );
    });
  });
}
