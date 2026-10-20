import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vsla_ledger/core/database/app_database.dart';
import 'package:vsla_ledger/core/groups/group_repository.dart';
import 'package:vsla_ledger/core/ledger/ledger_repository.dart';
import 'package:vsla_ledger/core/sync/sync_service.dart';
import 'package:vsla_ledger/remote/firebase_remote.dart';

import '../helpers/test_database.dart';

/// Runs the real sync against an in-memory stand-in for Firestore, so no
/// Firebase project or network is needed. The security rules are not
/// checked here; that needs the real Firestore.
class Phone {
  Phone(String deviceId, FirebaseFirestore firestore) : db = newTestDatabase() {
    groups = GroupRepository(db: db);
    ledger = LedgerRepository(db: db, deviceId: deviceId);
    sync = SyncService(db: db, remote: FirebaseRemote(firestore));
  }

  final AppDatabase db;
  late final GroupRepository groups;
  late final LedgerRepository ledger;
  late final SyncService sync;
}

void main() {
  late FakeFirebaseFirestore firestore;
  late Phone phoneA;
  late Phone phoneB;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    phoneA = Phone('phone-a', firestore);
    phoneB = Phone('phone-b', firestore);
  });
  tearDown(() async {
    await phoneA.db.close();
    await phoneB.db.close();
  });

  test('records are stored by the id the phone made', () async {
    final group = await phoneA.groups.createGroup('Tukolere Wamu');
    final sarah = await phoneA.groups.addMember(
      groupId: group.id,
      name: 'Sarah',
    );
    final entry = await phoneA.ledger.recordContribution(
      groupId: group.id,
      memberId: sarah.id,
      amountUgx: 10000,
    );

    expect(await phoneA.sync.run(), isTrue);

    final stored = await firestore
        .collection('ledger_entries')
        .doc(entry.id)
        .get();
    expect(stored.exists, isTrue);
    expect(stored.data()!['amountUgx'], 10000);
    expect(stored.data()!['serverUpdatedAt'], isA<Timestamp>());
    expect(stored.data()!.containsKey('serverReceivedAt'), isFalse);
    expect(
      (await firestore.collection('groups').doc(group.id).get()).exists,
      isTrue,
    );
    expect(await phoneA.db.outboxDao.watchPendingCount().first, 0);
  });

  test('an entry from one phone reaches the other', () async {
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
    await phoneA.sync.run();

    await phoneB.db.groupDao.insertGroup(group);
    expect(await phoneB.sync.run(), isTrue);

    final onB = await phoneB.db.ledgerDao.watchEntriesForMember(sarah.id).first;
    expect(onB.single.id, saved.id);
    expect(onB.single.serverReceivedAt, isNotNull);
    expect(await phoneB.db.memberDao.watchMember(sarah.id).first, isNotNull);
    expect(
      (await phoneB.db.ledgerDao.watchMemberBalance(sarah.id).first).savingsUgx,
      10000,
    );
  });

  test('syncing again does not duplicate anything', () async {
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

    expect(
      await phoneA.db.ledgerDao.watchEntriesForMember(sarah.id).first,
      hasLength(1),
    );
    expect(
      (await firestore.collection('ledger_entries').get()).docs,
      hasLength(1),
    );
  });

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
  });

  test('a pull only brings records from the asked-for group', () async {
    final ours = await phoneA.groups.createGroup('Tukolere Wamu');
    final theirs = await phoneA.groups.createGroup('Another group');
    await phoneA.groups.addMember(groupId: theirs.id, name: 'Peter');
    await phoneA.sync.run();

    final result = await FirebaseRemote(firestore).pullSince(ours.id, null);

    expect(result.groups.map((g) => g.id), [ours.id]);
    expect(result.members, isEmpty);
  });
}
