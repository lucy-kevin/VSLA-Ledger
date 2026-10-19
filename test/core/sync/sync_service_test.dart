import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:vsla_ledger/core/database/app_database.dart';
import 'package:vsla_ledger/core/ledger/ledger_repository.dart';
import 'package:vsla_ledger/core/models/group.dart';
import 'package:vsla_ledger/core/models/ledger_entry.dart';
import 'package:vsla_ledger/core/models/outbox_item.dart';
import 'package:vsla_ledger/core/sync/ledger_remote.dart';
import 'package:vsla_ledger/core/sync/sync_service.dart';
import 'package:vsla_ledger/remote/fake_remote.dart';

import '../../helpers/test_database.dart';

const groupId = 'group-1';
const sarah = 'member-sarah';

final group = Group(
  id: groupId,
  name: 'Tukolere Wamu',
  joinCode: 'TKW482',
  createdAt: DateTime.utc(2026, 10, 19),
  updatedAt: DateTime.utc(2026, 10, 19),
);

/// One treasurer's phone: its own database, sharing a server with others.
class Phone {
  Phone(String deviceId, LedgerRemote server) : db = newTestDatabase() {
    ledger = LedgerRepository(db: db, deviceId: deviceId);
    sync = SyncService(db: db, remote: server);
  }

  final AppDatabase db;
  late final LedgerRepository ledger;
  late final SyncService sync;

  Future<void> joinGroup() => db.groupDao.insertGroup(group);

  Future<LedgerEntry> contribute(int amountUgx) => ledger.recordContribution(
    groupId: groupId,
    memberId: sarah,
    amountUgx: amountUgx,
  );

  Future<List<LedgerEntry>> entries() =>
      db.ledgerDao.watchEntriesForMember(sarah).first;

  Future<Set<String>> waitingToSync() =>
      db.outboxDao.watchPendingEntityIds().first;
}

/// Wraps a remote so a test can hold a push open and count calls.
class SlowRemote implements LedgerRemote {
  SlowRemote(this.inner);

  final LedgerRemote inner;
  final release = Completer<void>();
  int pushCalls = 0;

  @override
  Future<Set<int>> push(List<OutboxItem> items) async {
    pushCalls++;
    await release.future;
    return inner.push(items);
  }

  @override
  Future<PullResult> pullSince(String groupId, DateTime? since) =>
      inner.pullSince(groupId, since);
}

void main() {
  late FakeLedgerRemote server;
  late Phone phone;

  setUp(() {
    server = FakeLedgerRemote();
    phone = Phone('phone-a', server);
  });
  tearDown(() => phone.db.close());

  test('offline records sync once the network is back', () async {
    server.offline = true;
    final recorded = [
      for (var i = 1; i <= 5; i++) await phone.contribute(i * 1000),
    ];
    expect(
      await phone.waitingToSync(),
      {for (final entry in recorded) entry.id},
    );

    await phone.sync.run();

    final stillWaiting = await phone.db.outboxDao.nextBatch(limit: 50);
    expect(stillWaiting, hasLength(5));
    expect(stillWaiting.every((item) => item.attempts == 1), isTrue);
    expect(stillWaiting.first.lastError, 'No connection to the server');
    expect(server.entries, isEmpty);

    server.offline = false;
    await phone.sync.run();

    expect(await phone.waitingToSync(), isEmpty);
    expect(
      server.entries.map((entry) => entry.id).toSet(),
      {for (final entry in recorded) entry.id},
    );
  });

  test('the server stamps when it received each entry', () async {
    await phone.contribute(1000);

    await phone.sync.run();

    expect(server.entries.single.serverReceivedAt, isNotNull);
  });

  test('pushing the same entry twice stores it once on the server', () async {
    await phone.contribute(1000);
    final items = await phone.db.outboxDao.nextBatch(limit: 50);

    await server.push(items);
    await server.push(items);

    expect(server.entries, hasLength(1));
  });

  test('a big outbox goes up in batches of 50', () async {
    for (var i = 0; i < 120; i++) {
      await phone.contribute(1000);
    }

    await phone.sync.run();

    expect(server.pushedBatchSizes, [50, 50, 20]);
    expect(await phone.waitingToSync(), isEmpty);
  });

  test('an entry from another phone arrives on this phone', () async {
    final otherPhone = Phone('phone-b', server);
    addTearDown(otherPhone.db.close);
    await phone.joinGroup();
    await otherPhone.joinGroup();

    final fromOtherPhone = await otherPhone.contribute(7000);
    await otherPhone.sync.run();
    await phone.sync.run();

    final received = await phone.entries();
    expect(received.map((entry) => entry.id), [fromOtherPhone.id]);
    expect(received.single.deviceId, 'phone-b');
    // A pulled entry came from the server, so it is not queued to go back.
    expect(await phone.waitingToSync(), isEmpty);
    expect(
      (await phone.db.ledgerDao.watchMemberBalance(sarah).first).savingsUgx,
      7000,
    );
  });

  test('pulling again does not duplicate entries', () async {
    await phone.joinGroup();
    await phone.contribute(1000);

    await phone.sync.run();
    await phone.sync.run();
    await phone.sync.run();

    expect(await phone.entries(), hasLength(1));
    expect(
      await phone.db.syncStateDao.read('lastPulledAt:$groupId'),
      isNotNull,
    );
  });

  test('a failed pull keeps the old lastPulledAt', () async {
    await phone.joinGroup();
    await phone.sync.run();
    final before = await phone.db.syncStateDao.read('lastPulledAt:$groupId');

    server.offline = true;
    await phone.sync.run();

    expect(
      await phone.db.syncStateDao.read('lastPulledAt:$groupId'),
      before,
    );
  });

  test('only one sync runs at a time', () async {
    final slow = SlowRemote(server);
    final slowPhone = Phone('phone-c', slow);
    addTearDown(slowPhone.db.close);
    await slowPhone.contribute(1000);

    final first = slowPhone.sync.run();
    final second = slowPhone.sync.run();
    await Future<void>.delayed(Duration.zero);
    expect(slow.pushCalls, 1);

    slow.release.complete();
    await Future.wait([first, second]);

    expect(await slowPhone.waitingToSync(), isEmpty);
  });

  test('an entry saved during a sync is sent before the sync ends', () async {
    final slow = SlowRemote(server);
    final slowPhone = Phone('phone-c', slow);
    addTearDown(slowPhone.db.close);
    await slowPhone.contribute(1000);

    final running = slowPhone.sync.run();
    await Future<void>.delayed(Duration.zero);
    final savedDuringSync = await slowPhone.contribute(2000);
    final asked = slowPhone.sync.run();

    slow.release.complete();
    await Future.wait([running, asked]);

    expect(await slowPhone.waitingToSync(), isEmpty);
    expect(
      server.entries.map((entry) => entry.id),
      contains(savedDuringSync.id),
    );
  });
}
