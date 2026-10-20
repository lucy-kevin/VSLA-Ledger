import 'package:flutter_test/flutter_test.dart';
import 'package:vsla_ledger/core/models/outbox_item.dart';
import 'package:vsla_ledger/core/sync/push_with_fallback.dart';

class Refused implements Exception {}

class Offline implements Exception {}

OutboxItem item(int id) => OutboxItem(
  id: id,
  entityType: OutboxEntityType.ledgerEntry,
  entityId: 'entry-$id',
  payloadJson: '{}',
  createdAt: DateTime.utc(2026, 10, 20),
);

void main() {
  final items = [item(1), item(2), item(3)];
  bool isRefusal(Object error) => error is Refused;

  test('a good batch goes in one request', () async {
    final sent = <List<int>>[];

    final accepted = await pushWithFallback(
      items,
      send: (batch) async => sent.add([for (final i in batch) i.id]),
      isRefusal: isRefusal,
    );

    expect(accepted, {1, 2, 3});
    expect(sent, [
      [1, 2, 3],
    ]);
  });

  test('a refused batch is retried one by one, skipping the bad one', () async {
    final accepted = await pushWithFallback(
      items,
      send: (batch) async {
        if (batch.any((i) => i.id == 2)) throw Refused();
      },
      isRefusal: isRefusal,
    );

    expect(accepted, {1, 3});
  });

  test('no connection is passed on, not retried one by one', () async {
    var calls = 0;

    await expectLater(
      pushWithFallback(
        items,
        send: (batch) async {
          calls++;
          throw Offline();
        },
        isRefusal: isRefusal,
      ),
      throwsA(isA<Offline>()),
    );
    expect(calls, 1);
  });

  test(
    'losing the connection halfway through the retries is passed on',
    () async {
      await expectLater(
        pushWithFallback(
          items,
          send: (batch) async {
            if (batch.length > 1) throw Refused();
            if (batch.single.id == 3) throw Offline();
          },
          isRefusal: isRefusal,
        ),
        throwsA(isA<Offline>()),
      );
    },
  );

  test('nothing to send, nothing sent', () async {
    var calls = 0;

    final accepted = await pushWithFallback(
      [],
      send: (batch) async => calls++,
      isRefusal: isRefusal,
    );

    expect(accepted, isEmpty);
    expect(calls, 0);
  });
}
