import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:vsla_ledger/app/background_sync.dart';
import 'package:vsla_ledger/core/database/app_database.dart';
import 'package:vsla_ledger/core/ledger/ledger_repository.dart';
import 'package:vsla_ledger/remote/fake_remote.dart';

import '../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late FakeLedgerRemote server;

  setUp(() async {
    db = newTestDatabase();
    server = FakeLedgerRemote();
    await LedgerRepository(db: db, deviceId: 'phone-a').recordContribution(
      groupId: 'group-1',
      memberId: 'member-sarah',
      amountUgx: 10000,
    );
  });
  // The background sync closes the database itself; closing again is safe.
  tearDown(() => db.close());

  test('a background sync sends what is waiting and says it is done', () async {
    final done = await runBackgroundSync(
      openDatabase: () => db,
      connect: () async => server,
    );

    expect(done, isTrue);
    expect(server.entries, hasLength(1));
  });

  test('with the server down, it asks Android to try again later', () async {
    server.offline = true;

    final done = await runBackgroundSync(
      openDatabase: () => db,
      connect: () async => server,
    );

    expect(done, isFalse);
    expect(server.entries, isEmpty);
  });

  test('if the server cannot even be set up, it tries again later', () async {
    final done = await runBackgroundSync(
      openDatabase: () => db,
      connect: () async => throw const SocketException('no route'),
    );

    expect(done, isFalse);
  });

  test('the database is closed when the background sync ends', () async {
    await runBackgroundSync(
      openDatabase: () => db,
      connect: () async => server,
    );

    await expectLater(
      db.outboxDao.watchPendingCount().first,
      throwsA(anything),
    );
  });

  test('the fake server never syncs in the background', () {
    expect(syncsInBackground('fake'), isFalse);
    expect(syncsInBackground('pocketbase'), isTrue);
    expect(syncsInBackground('firebase'), isTrue);
  });

  test('the phone database waits instead of failing when busy', () {
    final raw = sqlite3.openInMemory();
    addTearDown(raw.dispose);

    prepareSharedFile(raw);

    expect(raw.select('PRAGMA busy_timeout').first.values.first, 5000);
  });
}
