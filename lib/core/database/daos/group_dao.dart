import 'package:drift/drift.dart';
import 'package:vsla_ledger/core/database/app_database.dart';
import 'package:vsla_ledger/core/database/tables.dart';
import 'package:vsla_ledger/core/models/group.dart';

part 'group_dao.g.dart';

@DriftAccessor(tables: [Groups])
class GroupDao extends DatabaseAccessor<AppDatabase> with _$GroupDaoMixin {
  GroupDao(super.attachedDatabase);

  /// Saving a group that is already here (for example one pulled from the
  /// server twice) does nothing. See `LedgerDao.insertEntry` for why this is
  /// not INSERT OR IGNORE.
  Future<void> insertGroup(Group group) => into(groups).insert(
    group.toInsertable(),
    onConflict: DoNothing(target: [groups.id]),
  );

  Future<List<Group>> getAllGroups() => select(groups).get();

  Stream<List<Group>> watchAllGroups() =>
      (select(groups)..orderBy([(g) => OrderingTerm.asc(g.name)])).watch();

  Stream<Group?> watchGroup(String id) =>
      (select(groups)..where((g) => g.id.equals(id))).watchSingleOrNull();
}
