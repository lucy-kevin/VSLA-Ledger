import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:vsla_ledger/core/models/entry_type.dart';
import 'package:vsla_ledger/core/models/ledger_entry.dart';
import 'package:vsla_ledger/core/models/outbox_item.dart';
import 'package:vsla_ledger/remote/fake_remote.dart';

void main() {
  var clock = DateTime.utc(2026, 10, 19, 9);
  late FakeLedgerRemote server;

  setUp(() {
    clock = DateTime.utc(2026, 10, 19, 9);
    server = FakeLedgerRemote(now: () => clock);
  });

  OutboxItem itemFor(LedgerEntry entry, {required int id}) => OutboxItem(
    id: id,
    entityType: OutboxEntityType.ledgerEntry,
    entityId: entry.id,
    payloadJson: jsonEncode(entry.toJson()),
    createdAt: entry.createdAt,
  );

  LedgerEntry entry(String id, {String groupId = 'group-1'}) => LedgerEntry(
    id: id,
    groupId: groupId,
    memberId: 'member-sarah',
    type: EntryType.contribution,
    amountUgx: 1000,
    createdAt: DateTime.utc(2026, 10, 19, 8),
    deviceId: 'phone-a',
  );

  test('while offline, push and pull both fail', () async {
    server.offline = true;

    await expectLater(server.push([]), throwsA(isA<FakeServerOffline>()));
    await expectLater(
      server.pullSince('group-1', null),
      throwsA(isA<FakeServerOffline>()),
    );
  });

  test('every pushed item is accepted', () async {
    final accepted = await server.push([
      itemFor(entry('a'), id: 7),
      itemFor(entry('b'), id: 8),
    ]);

    expect(accepted, {7, 8});
  });

  test('a pull only returns the asked-for group', () async {
    await server.push([
      itemFor(entry('a'), id: 1),
      itemFor(entry('b', groupId: 'group-2'), id: 2),
    ]);

    final result = await server.pullSince('group-1', null);

    expect(result.entries.map((e) => e.id), ['a']);
  });

  test(
    'a pull returns what arrived since the last pull, and the server time',
    () async {
      await server.push([itemFor(entry('a'), id: 1)]);
      clock = DateTime.utc(2026, 10, 19, 10);
      final first = await server.pullSince('group-1', null);

      clock = DateTime.utc(2026, 10, 19, 11);
      await server.push([itemFor(entry('b'), id: 2)]);
      final second = await server.pullSince('group-1', first.serverTime);

      expect(first.serverTime, DateTime.utc(2026, 10, 19, 10));
      expect(second.entries.map((e) => e.id), ['b']);
    },
  );

  test(
    'an entry received in the same moment as a pull is not missed',
    () async {
      final pull = await server.pullSince('group-1', null);
      await server.push([itemFor(entry('a'), id: 1)]);

      final next = await server.pullSince('group-1', pull.serverTime);

      expect(next.entries.map((e) => e.id), ['a']);
    },
  );

  test('the first copy of a ledger entry is kept', () async {
    await server.push([itemFor(entry('a'), id: 1)]);
    clock = DateTime.utc(2026, 10, 19, 12);
    await server.push([itemFor(entry('a'), id: 2)]);

    expect(
      server.entries.single.serverReceivedAt,
      DateTime.utc(2026, 10, 19, 9),
    );
  });
}
