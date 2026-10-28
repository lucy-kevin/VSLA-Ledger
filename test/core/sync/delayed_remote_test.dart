import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:vsla_ledger/core/models/group.dart';
import 'package:vsla_ledger/core/models/outbox_item.dart';
import 'package:vsla_ledger/core/sync/delayed_remote.dart';
import 'package:vsla_ledger/remote/fake_remote.dart';

void main() {
  final group = Group(
    id: '0b6f5a52-3c1d-4f1e-9a7b-2d3c4e5f6a7b',
    name: 'Tukolere Wamu',
    joinCode: 'TKW482',
    createdAt: DateTime.utc(2026, 10, 20, 9),
    updatedAt: DateTime.utc(2026, 10, 20, 9),
  );
  final item = OutboxItem(
    id: 7,
    entityType: OutboxEntityType.group,
    entityId: group.id,
    payloadJson: jsonEncode(group.toJson()),
    createdAt: group.createdAt,
  );

  test('every request waits for the delay, then goes through', () async {
    final server = FakeLedgerRemote();
    final slow = DelayedRemote(server, const Duration(milliseconds: 150));
    final stopwatch = Stopwatch()..start();

    final accepted = await slow.push([item]);
    final found = await slow.findGroupByJoinCode('TKW482');
    final pulled = await slow.pullSince(found!.id, null);

    expect(
      stopwatch.elapsed,
      greaterThanOrEqualTo(const Duration(milliseconds: 450)),
    );
    expect(accepted, {7});
    expect(pulled.groups.single.name, 'Tukolere Wamu');
  });

  test('an offline server still fails, just later', () async {
    final server = FakeLedgerRemote()..offline = true;
    final slow = DelayedRemote(server, const Duration(milliseconds: 50));

    await expectLater(slow.push([item]), throwsA(isA<FakeServerOffline>()));
  });
}
