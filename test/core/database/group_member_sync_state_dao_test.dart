import 'package:flutter_test/flutter_test.dart';
import 'package:vsla_ledger/core/database/app_database.dart';
import 'package:vsla_ledger/core/models/group.dart';
import 'package:vsla_ledger/core/models/member.dart';

import '../../helpers/test_database.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = newTestDatabase());
  tearDown(() => db.close());

  final group = Group(
    id: 'group-1',
    name: 'Tukolere Wamu',
    joinCode: 'TKW482',
    createdAt: DateTime.utc(2026, 10, 19, 9),
    updatedAt: DateTime.utc(2026, 10, 19, 9),
  );

  Member member(String id, String name) => Member(
    id: id,
    groupId: group.id,
    name: name,
    joinedAt: DateTime.utc(2026, 10, 19, 9),
    updatedAt: DateTime.utc(2026, 10, 19, 9),
  );

  test('a group comes back exactly as saved, and only once', () async {
    await db.groupDao.insertGroup(group);
    await db.groupDao.insertGroup(group);

    expect(await db.groupDao.watchAllGroups().first, [group]);
    expect(await db.groupDao.watchGroup(group.id).first, group);
  });

  test('members are listed by name, with optional phone kept', () async {
    final sarah = member('m-1', 'Sarah').copyWith(phone: '0772123456');
    final abel = member('m-2', 'Abel');
    await db.memberDao.insertMember(sarah);
    await db.memberDao.insertMember(abel);

    expect(await db.memberDao.watchMembersOfGroup(group.id).first, [
      abel,
      sarah,
    ]);
    expect(await db.memberDao.watchMember('m-1').first, sarah);
  });

  test('dates keep their milliseconds', () async {
    final precise = group.copyWith(
      createdAt: DateTime.utc(2026, 10, 19, 9, 30, 15, 123),
    );
    await db.groupDao.insertGroup(precise);

    final stored = await db.groupDao.watchGroup(group.id).first;

    expect(
      stored!.createdAt.millisecondsSinceEpoch,
      precise.createdAt.millisecondsSinceEpoch,
    );
  });

  test('sync state keeps the latest value for a key', () async {
    expect(await db.syncStateDao.read('lastPulledAt:group-1'), isNull);

    await db.syncStateDao.write('lastPulledAt:group-1', 'first');
    await db.syncStateDao.write('lastPulledAt:group-1', 'second');

    expect(await db.syncStateDao.read('lastPulledAt:group-1'), 'second');
  });
}
