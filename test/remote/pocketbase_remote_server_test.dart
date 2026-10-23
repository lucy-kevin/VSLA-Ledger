@Tags(['pocketbase'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';
import 'package:vsla_ledger/core/database/app_database.dart';
import 'package:vsla_ledger/core/groups/group_repository.dart';
import 'package:vsla_ledger/core/ledger/ledger_repository.dart';
import 'package:vsla_ledger/core/sync/sync_service.dart';
import 'package:vsla_ledger/remote/pocketbase_remote.dart';

import '../helpers/test_database.dart';

/// Runs the real sync against a real PocketBase server.
///
/// Start one first (see server/pocketbase/README.md). Without a server
/// these tests are skipped, so CI and new contributors are not blocked.
/// Run only these with: flutter test --tags pocketbase
const serverUrl = String.fromEnvironment(
  'PB_TEST_URL',
  defaultValue: 'http://127.0.0.1:8090',
);

Future<bool> serverIsRunning() async {
  try {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 2);
    final request = await client.getUrl(Uri.parse('$serverUrl/api/health'));
    final response = await request.close();
    client.close();
    return response.statusCode == 200;
  } on Object {
    return false;
  }
}

/// One phone: its own database, talking to the shared server.
class Phone {
  Phone(String deviceId) : db = newTestDatabase() {
    groups = GroupRepository(db: db);
    ledger = LedgerRepository(db: db, deviceId: deviceId);
    sync = SyncService(db: db, remote: PocketBaseRemote.connect(serverUrl));
  }

  final AppDatabase db;
  late final GroupRepository groups;
  late final LedgerRepository ledger;
  late final SyncService sync;
}

Future<void> main() async {
  final running = await serverIsRunning();
  final skip = running ? null : 'No PocketBase at $serverUrl';

  late Phone phoneA;
  late Phone phoneB;

  setUp(() {
    phoneA = Phone('phone-a-${const Uuid().v4()}');
    phoneB = Phone('phone-b-${const Uuid().v4()}');
  });
  tearDown(() async {
    await phoneA.db.close();
    await phoneB.db.close();
  });

  test(
    'a group, a member and an entry reach the server and the other phone',
    () async {
      final group = await phoneA.groups.createGroup('Tukolere Wamu');
      final sarah = await phoneA.groups.addMember(
        groupId: group.id,
        name: 'Sarah',
      );
      final saved = await phoneA.ledger.recordContribution(
        groupId: group.id,
        memberId: sarah.id,
        amountUgx: 10000,
      );

      expect(await phoneA.sync.run(), SyncResult.ok);
      expect(await phoneA.db.outboxDao.watchPendingCount().first, 0);

      // Phone B already knows the group (joining by code comes later).
      await phoneB.db.groupDao.insertGroup(group);
      expect(await phoneB.sync.run(), SyncResult.ok);

      final onB = await phoneB.db.ledgerDao
          .watchEntriesForMember(sarah.id)
          .first;
      expect(onB.single.id, saved.id);
      expect(onB.single.amountUgx, 10000);
      expect(onB.single.serverReceivedAt, isNotNull);
      expect(await phoneB.db.memberDao.watchMember(sarah.id).first, isNotNull);
      expect(
        (await phoneB.db.ledgerDao.watchMemberBalance(sarah.id).first)
            .savingsUgx,
        10000,
      );
    },
    skip: skip,
  );

  test('syncing again sends and fetches nothing twice', () async {
    final group = await phoneA.groups.createGroup('Tukolere Wamu');
    final sarah = await phoneA.groups.addMember(
      groupId: group.id,
      name: 'Sarah',
    );
    await phoneA.ledger.recordContribution(
      groupId: group.id,
      memberId: sarah.id,
      amountUgx: 5000,
    );

    await phoneA.sync.run();
    await phoneA.sync.run();
    await phoneA.sync.run();

    final entries = await phoneA.db.ledgerDao
        .watchEntriesForMember(sarah.id)
        .first;
    expect(entries, hasLength(1));
  }, skip: skip);

  test('a correction from one phone cancels the entry on the other', () async {
    final group = await phoneA.groups.createGroup('Tukolere Wamu');
    final sarah = await phoneA.groups.addMember(
      groupId: group.id,
      name: 'Sarah',
    );
    final wrong = await phoneA.ledger.recordContribution(
      groupId: group.id,
      memberId: sarah.id,
      amountUgx: 12000,
    );
    await phoneA.ledger.cancelEntry(wrong.id);
    await phoneA.ledger.recordContribution(
      groupId: group.id,
      memberId: sarah.id,
      amountUgx: 10000,
    );
    await phoneA.sync.run();

    await phoneB.db.groupDao.insertGroup(group);
    await phoneB.sync.run();

    expect(
      (await phoneB.db.ledgerDao.watchMemberBalance(sarah.id).first).savingsUgx,
      10000,
    );
  }, skip: skip);

  test('a group is found by its join code, and only that group', () async {
    final group = await phoneA.groups.createGroup('Tukolere Wamu');
    await phoneA.sync.run();
    final remote = PocketBaseRemote.connect(serverUrl);

    expect(await remote.findGroupByJoinCode(group.joinCode), group);
  }, skip: skip);

  test('an unknown join code finds nothing', () async {
    final remote = PocketBaseRemote.connect(serverUrl);

    // Contains 0 and 1, which join codes never use, so no group has it.
    expect(await remote.findGroupByJoinCode('ZZ0Z1Z'), isNull);
  }, skip: skip);

  test(
    'meetings, shares, charges, social fund and fines survive the trip',
    () async {
      // A group made a month ago, so last week's meeting is allowed.
      final group =
          await GroupRepository(
            db: phoneA.db,
            now: () => DateTime.now().subtract(const Duration(days: 30)),
          ).createGroup(
            'Tukolere Wamu',
            monthlyChargePercent: 10,
            sharePriceUgx: 2000,
          );
      final sarah = await phoneA.groups.addMember(
        groupId: group.id,
        name: 'Sarah',
      );
      final lastWeek = DateTime.now().subtract(const Duration(days: 7));
      await phoneA.ledger.recordContribution(
        groupId: group.id,
        memberId: sarah.id,
        shares: 3,
        meetingDate: lastWeek,
      );
      await phoneA.ledger.recordSocialFund(
        groupId: group.id,
        memberId: sarah.id,
        amountUgx: 1000,
      );
      final fine = await phoneA.ledger.recordFine(
        groupId: group.id,
        memberId: sarah.id,
        amountUgx: 500,
      );
      await phoneA.ledger.issueLoan(
        groupId: group.id,
        memberId: sarah.id,
        amountUgx: 100000,
        meetingDate: lastWeek,
      );
      await phoneA.ledger.cancelEntry(fine.id);
      expect(await phoneA.sync.run(), SyncResult.ok);

      // The group's settings come back from the server as they were sent.
      final found = await PocketBaseRemote.connect(
        serverUrl,
      ).findGroupByJoinCode(group.joinCode);
      expect(found!.monthlyChargePercent, 10);
      expect(found.sharePriceUgx, 2000);

      await phoneB.db.groupDao.insertGroup(found);
      expect(await phoneB.sync.run(), SyncResult.ok);

      final onA = await phoneA.db.ledgerDao.watchMemberBalance(sarah.id).first;
      final onB = await phoneB.db.ledgerDao.watchMemberBalance(sarah.id).first;
      expect(onB, onA);
      expect(onB.sharesCount, 3);
      expect(onB.savingsUgx, 6000);
      expect(onB.socialFundUgx, 1000);
      expect(onB.finesUgx, 0);
      final entries = await phoneB.db.ledgerDao.getEntriesForMember(sarah.id);
      final loan = entries.singleWhere((e) => e.type.name == 'loan');
      expect(loan.monthlyChargePercent, 10);
      expect(
        loan.meetingDay,
        DateTime.utc(lastWeek.year, lastWeek.month, lastWeek.day),
      );
    },
    skip: skip,
  );
}
