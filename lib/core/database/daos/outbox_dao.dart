import 'package:drift/drift.dart';
import 'package:vsla_ledger/core/database/app_database.dart';
import 'package:vsla_ledger/core/database/tables.dart';
import 'package:vsla_ledger/core/models/outbox_item.dart';

part 'outbox_dao.g.dart';

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
  /// were made.
  Future<List<OutboxItem>> nextBatch({int limit = 50}) =>
      (select(outbox)
            ..orderBy([(o) => OrderingTerm.asc(o.id)])
            ..limit(limit))
          .get();

  /// Called once the server has accepted these items.
  Future<void> removeSent(List<int> ids) =>
      (delete(outbox)..where((o) => o.id.isIn(ids))).go();

  Future<void> recordFailure(int id, String error) =>
      (update(outbox)..where((o) => o.id.equals(id))).write(
        OutboxCompanion.custom(
          attempts: outbox.attempts + const Constant(1),
          lastError: Variable.withString(error),
        ),
      );

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
