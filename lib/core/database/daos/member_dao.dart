import 'package:drift/drift.dart';
import 'package:vsla_ledger/core/database/app_database.dart';
import 'package:vsla_ledger/core/database/tables.dart';
import 'package:vsla_ledger/core/models/member.dart';

part 'member_dao.g.dart';

@DriftAccessor(tables: [Members])
class MemberDao extends DatabaseAccessor<AppDatabase> with _$MemberDaoMixin {
  MemberDao(super.attachedDatabase);

  /// Saving a member that is already here does nothing. See
  /// `LedgerDao.insertEntry` for why this is not INSERT OR IGNORE.
  Future<void> insertMember(Member member) => into(members).insert(
    member.toInsertable(),
    onConflict: DoNothing(target: [members.id]),
  );

  Stream<List<Member>> watchMembersOfGroup(String groupId) =>
      (select(members)
            ..where((m) => m.groupId.equals(groupId))
            ..orderBy([(m) => OrderingTerm.asc(m.name)]))
          .watch();

  Stream<Member?> watchMember(String id) =>
      (select(members)..where((m) => m.id.equals(id))).watchSingleOrNull();
}
