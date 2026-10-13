import 'package:flutter_test/flutter_test.dart';
import 'package:vsla_ledger/core/models/outbox_item.dart';

void main() {
  final item = OutboxItem(
    id: 1,
    entityType: OutboxEntityType.ledgerEntry,
    entityId: 'b2c3d4e5-f6a7-4b8c-9d0e-1f2a3b4c5d6e',
    payloadJson: '{"amountUgx":10000}',
    createdAt: DateTime.utc(2026, 10, 13, 9),
  );

  test('a new item has never failed', () {
    expect(item.attempts, 0);
    expect(item.lastError, isNull);
  });

  test('survives a trip to JSON and back, including a failure', () {
    final failed = item.copyWith(attempts: 2, lastError: 'No connection');

    expect(OutboxItem.fromJson(failed.toJson()), failed);
  });

  test('entity type names stay the same, because they are stored', () {
    expect(
      OutboxEntityType.values.map((type) => type.name),
      ['group', 'member', 'ledgerEntry'],
    );
  });
}
