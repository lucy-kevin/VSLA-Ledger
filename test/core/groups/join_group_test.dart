import 'package:flutter_test/flutter_test.dart';
import 'package:vsla_ledger/core/database/app_database.dart';
import 'package:vsla_ledger/core/groups/group_repository.dart';
import 'package:vsla_ledger/core/groups/join_group.dart';
import 'package:vsla_ledger/core/ledger/ledger_repository.dart';
import 'package:vsla_ledger/core/models/group.dart';
import 'package:vsla_ledger/core/sync/sync_service.dart';
import 'package:vsla_ledger/remote/fake_remote.dart';

import '../../helpers/test_database.dart';

void main() {
  late FakeLedgerRemote server;
  late AppDatabase treasurerPhone;
  late AppDatabase secretaryPhone;
  late GroupJoiner joiner;

  setUp(() {
    server = FakeLedgerRemote();
    treasurerPhone = newTestDatabase();
    secretaryPhone = newTestDatabase();
    joiner = GroupJoiner(
      db: secretaryPhone,
      remote: server,
      sync: SyncService(db: secretaryPhone, remote: server),
    );
  });
  tearDown(() async {
    await treasurerPhone.close();
    await secretaryPhone.close();
  });

  /// The treasurer makes a group with one member and one entry, and syncs.
  Future<Group> treasurerSetsUpGroup() async {
    final groups = GroupRepository(db: treasurerPhone);
    final group = await groups.createGroup('Tukolere Wamu');
    final sarah = await groups.addMember(groupId: group.id, name: 'Sarah');
    await LedgerRepository(
      db: treasurerPhone,
      deviceId: 'treasurer',
    ).recordContribution(
      groupId: group.id,
      memberId: sarah.id,
      amountUgx: 10000,
    );
    await SyncService(db: treasurerPhone, remote: server).run();
    return group;
  }

  test('joining brings the group, its members and its entries', () async {
    final group = await treasurerSetsUpGroup();

    final result = await joiner.join(group.joinCode);

    expect(result, isA<Joined>());
    expect((result as Joined).group, group);
    expect(await secretaryPhone.groupDao.watchAllGroups().first, [group]);
    final members = await secretaryPhone.memberDao
        .watchMembersOfGroup(group.id)
        .first;
    expect(members.map((m) => m.name), ['Sarah']);
    expect(
      (await secretaryPhone.ledgerDao.watchGroupBalance(group.id).first)
          .savingsUgx,
      10000,
    );
  });

  test('the joined group is not sent back to the server', () async {
    final group = await treasurerSetsUpGroup();

    await joiner.join(group.joinCode);

    expect(await secretaryPhone.outboxDao.watchPendingCount().first, 0);
  });

  test('a code typed in lower case or with a space still works', () async {
    final group = await treasurerSetsUpGroup();
    final typed =
        '${group.joinCode.substring(0, 3).toLowerCase()} '
        '${group.joinCode.substring(3)}';

    expect(await joiner.join(typed), isA<Joined>());
  });

  test(
    'a code of the wrong shape is refused without asking the server',
    () async {
      server.offline = true;

      expect(await joiner.join('ABC'), isA<InvalidJoinCode>());
      expect(await joiner.join('ABCD0O'), isA<InvalidJoinCode>());
    },
  );

  test('an unknown code finds nothing', () async {
    await treasurerSetsUpGroup();

    expect(await joiner.join('ZZZZZZ'), isA<GroupNotFound>());
    expect(await secretaryPhone.groupDao.watchAllGroups().first, isEmpty);
  });

  test('without the internet, joining says so and saves nothing', () async {
    final group = await treasurerSetsUpGroup();
    server.offline = true;

    expect(await joiner.join(group.joinCode), isA<JoinNeedsConnection>());
    expect(await secretaryPhone.groupDao.watchAllGroups().first, isEmpty);
  });

  test('normalizeJoinCode ignores case, spaces and dashes', () {
    expect(normalizeJoinCode(' tkw-482 '), 'TKW482');
    expect(isValidJoinCode('TKW482'), isTrue);
    expect(isValidJoinCode('TKW48'), isFalse);
    expect(isValidJoinCode('TKW4O1'), isFalse, reason: 'O and 1 are not used');
  });
}
