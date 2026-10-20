import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:vsla_ledger/core/database/app_database.dart';
import 'package:vsla_ledger/core/groups/group_repository.dart';
import 'package:vsla_ledger/core/models/group.dart';
import 'package:vsla_ledger/core/models/member.dart';
import 'package:vsla_ledger/core/models/outbox_item.dart';

import '../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late GroupRepository groups;
  var nextId = 0;

  setUp(() {
    db = newTestDatabase();
    nextId = 0;
    groups = GroupRepository(
      db: db,
      now: () => DateTime.utc(2026, 10, 19, 9),
      newId: () => 'id-${nextId++}',
      random: Random(1),
    );
  });
  tearDown(() => db.close());

  test('a new group is saved and queued for sync', () async {
    final group = await groups.createGroup('  Tukolere Wamu  ');

    expect(group.name, 'Tukolere Wamu');
    expect(await db.groupDao.watchAllGroups().first, [group]);
    final queued = (await db.outboxDao.nextBatch(limit: 50)).single;
    expect(queued.entityType, OutboxEntityType.group);
    expect(
      Group.fromJson(jsonDecode(queued.payloadJson) as Map<String, dynamic>),
      group,
    );
  });

  test('a new member is saved and queued for sync', () async {
    final member = await groups.addMember(
      groupId: 'group-1',
      name: 'Sarah',
      phone: ' 0772 123456 ',
    );

    expect(member.phone, '0772 123456');
    expect(await db.memberDao.watchMember(member.id).first, member);
    final queued = (await db.outboxDao.nextBatch(limit: 50)).single;
    expect(queued.entityType, OutboxEntityType.member);
    expect(
      Member.fromJson(jsonDecode(queued.payloadJson) as Map<String, dynamic>),
      member,
    );
  });

  test('a blank phone number is stored as no phone number', () async {
    final member = await groups.addMember(
      groupId: 'group-1',
      name: 'Abel',
      phone: '   ',
    );

    expect(member.phone, isNull);
  });

  test('a blank name is refused and nothing is saved', () async {
    await expectLater(groups.createGroup('   '), throwsArgumentError);
    await expectLater(
      groups.addMember(groupId: 'group-1', name: ''),
      throwsArgumentError,
    );

    expect(await db.outboxDao.nextBatch(limit: 50), isEmpty);
  });

  test('join codes are 6 characters with no look-alike letters', () {
    final random = Random(42);
    for (var i = 0; i < 500; i++) {
      final code = makeJoinCode(random);
      expect(code, hasLength(6));
      expect(code, matches(RegExp(r'^[A-HJKMNP-Z2-9]{6}$')));
    }
  });
}
