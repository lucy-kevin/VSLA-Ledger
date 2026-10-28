import 'package:drift/drift.dart';
import 'package:vsla_ledger/core/database/app_database.dart';
import 'package:vsla_ledger/core/database/tables.dart';
import 'package:vsla_ledger/core/models/outbox_item.dart';

part 'outbox_dao.g.dart';

/// Saved as `lastError` when the server looked at an item and said no.
/// Different from "could not reach the server", which is worth retrying
/// forever.
const refusedByServer = 'Refused by the server';

/// After this many refusals an item is left alone (it stays in the outbox,
/// so nothing is lost), so one bad record cannot make every sync fail.
const maxRefusals = 5;

/// The queue of changes waiting to be sent to the server.
@DriftAccessor(tables: [Outbox])
class OutboxDao extends DatabaseAccessor<AppDatabase> with _$OutboxDaoMixin {
  OutboxDao(super.attachedDatabase);

  Future<void> enqueue({
    required OutboxEntityType entityType,
    required String entityId,
    required String payloadJson,
    required DateTime createdAt,
  }) => into(outbox).insert(
    OutboxCompanion.insert(
      entityType: entityType,
      entityId: entityId,
      payloadJson: payloadJson,
      createdAt: createdAt,
    ),
  );

  /// The oldest items first, so the server sees changes in the order they
  /// were made. Items the server has refused [maxRefusals] times are skipped,
  /// and so are the ids in [exclude].
  Future<List<OutboxItem>> nextBatch({
    required int limit,
    List<int> exclude = const [],
  }) =>
      (select(outbox)
            ..where((o) => _isStuck(o).not() & o.id.isNotIn(exclude))
            ..orderBy([(o) => OrderingTerm.asc(o.id)])
            ..limit(limit))
          .get();

  Expression<bool> _isStuck($OutboxTable o) =>
      o.attempts.isBiggerOrEqualValue(maxRefusals) &
      o.lastError.equals(refusedByServer);

  /// Called once the server has accepted these items.
  Future<void> removeSent(List<int> ids) =>
      (delete(outbox)..where((o) => o.id.isIn(ids))).go();

  Future<void> _bumpAttempts(int id, String error) =>
      (update(outbox)..where((o) => o.id.equals(id))).write(
        OutboxCompanion.custom(
          attempts: outbox.attempts + const Constant(1),
          lastError: Variable.withString(error),
        ),
      );

  /// The server could not be reached; the item will be tried again.
  Future<void> recordFailure(int id, String error) => _bumpAttempts(id, error);

  /// The server looked at the item and refused it.
  Future<void> recordRefusal(int id) => _bumpAttempts(id, refusedByServer);

  /// Items that will not be sent again without help.
  Stream<int> watchStuckCount() {
    final count = outbox.id.count();
    return (selectOnly(outbox)
          ..addColumns([count])
          ..where(_isStuck(outbox)))
        .map((row) => row.read(count)!)
        .watchSingle();
  }

  /// For the "N records waiting to sync" message.
  Stream<int> watchPendingCount() {
    final count = outbox.id.count();
    return (selectOnly(
      outbox,
    )..addColumns([count])).map((row) => row.read(count)!).watchSingle();
  }

  /// Ids of records still waiting to sync. A record in this set shows
  /// "Saved on phone"; once it leaves, it shows "Synced".
  Stream<Set<String>> watchPendingEntityIds() =>
      (selectOnly(outbox)..addColumns([outbox.entityId])).watch().map(
        (rows) => {for (final row in rows) row.read(outbox.entityId)!},
      );
}
