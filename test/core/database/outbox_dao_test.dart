import 'package:flutter_test/flutter_test.dart';
import 'package:vsla_ledger/core/database/app_database.dart';
import 'package:vsla_ledger/core/models/outbox_item.dart';

import '../../helpers/test_database.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = newTestDatabase());
  tearDown(() => db.close());

  Future<void> enqueue(String entityId) => db.outboxDao.enqueue(
    entityType: OutboxEntityType.ledgerEntry,
    entityId: entityId,
    payloadJson: '{"id":"$entityId"}',
    createdAt: DateTime.utc(2026, 10, 19, 9),
  );

  test('items come out oldest first, a batch at a time', () async {
    for (var i = 0; i < 5; i++) {
      await enqueue('entry-$i');
    }

    final batch = await db.outboxDao.nextBatch(limit: 3);

    expect(batch.map((item) => item.entityId), [
      'entry-0',
      'entry-1',
      'entry-2',
    ]);
  });

  test('a new item has no failures', () async {
    await enqueue('entry-0');

    final item = (await db.outboxDao.nextBatch(limit: 50)).single;

    expect(item.attempts, 0);
    expect(item.lastError, isNull);
  });

  test('a failed push is counted and its reason kept', () async {
    await enqueue('entry-0');
    final id = (await db.outboxDao.nextBatch(limit: 50)).single.id;

    await db.outboxDao.recordFailure(id, 'No connection');
    await db.outboxDao.recordFailure(id, 'Server busy');

    final item = (await db.outboxDao.nextBatch(limit: 50)).single;
    expect(item.attempts, 2);
    expect(item.lastError, 'Server busy');
  });

  test('sent items leave the queue and the others stay', () async {
    await enqueue('entry-0');
    await enqueue('entry-1');
    final first = (await db.outboxDao.nextBatch(limit: 50)).first;

    await db.outboxDao.removeSent([first.id]);

    expect(
      (await db.outboxDao.nextBatch(limit: 50)).map((item) => item.entityId),
      ['entry-1'],
    );
  });

  test('pending count and ids follow the queue', () async {
    expect(await db.outboxDao.watchPendingCount().first, 0);

    await enqueue('entry-0');
    await enqueue('entry-1');

    expect(await db.outboxDao.watchPendingCount().first, 2);
    expect(
      await db.outboxDao.watchPendingEntityIds().first,
      {'entry-0', 'entry-1'},
    );
  });
}
