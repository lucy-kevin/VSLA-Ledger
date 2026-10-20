import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:vsla_ledger/core/models/entry_type.dart';
import 'package:vsla_ledger/core/models/ledger_entry.dart';
import 'package:vsla_ledger/core/models/outbox_item.dart';
import 'package:vsla_ledger/remote/pocketbase_remote.dart';

/// These tests use a pretend HTTP connection, so they need no server.
/// The tests that talk to a real PocketBase are in
/// pocketbase_remote_server_test.dart.
void main() {
  OutboxItem item(int id, {int amountUgx = 1000}) {
    final entry = LedgerEntry(
      id: 'entry-$id',
      groupId: 'group-1',
      memberId: 'member-sarah',
      type: EntryType.contribution,
      amountUgx: amountUgx,
      createdAt: DateTime.utc(2026, 10, 20, 9),
      deviceId: 'phone-a',
    );
    return OutboxItem(
      id: id,
      entityType: OutboxEntityType.ledgerEntry,
      entityId: entry.id,
      payloadJson: jsonEncode(entry.toJson()),
      createdAt: entry.createdAt,
    );
  }

  /// A pretend server that refuses any batch containing an amount of 13.
  PocketBaseRemote remoteWhere(
    Future<http.Response> Function(List<Map<String, dynamic>> bodies) answer,
  ) => PocketBaseRemote(
    PocketBase(
      'http://pb.test',
      httpClientFactory: () => MockClient((request) {
        final requests =
            (jsonDecode(request.body) as Map<String, dynamic>)['requests']
                as List<dynamic>;
        return answer([
          for (final r in requests)
            (r as Map<String, dynamic>)['body'] as Map<String, dynamic>,
        ]);
      }),
    ),
  );

  http.Response ok(int count) => http.Response(
    jsonEncode([
      for (var i = 0; i < count; i++)
        {'status': 200, 'body': <String, dynamic>{}},
    ]),
    200,
  );

  final refused = http.Response(
    jsonEncode({'status': 400, 'message': 'Batch transaction failed.'}),
    400,
  );

  test('every item is accepted when the batch succeeds', () async {
    final batchSizes = <int>[];
    final remote = remoteWhere((bodies) async {
      batchSizes.add(bodies.length);
      return ok(bodies.length);
    });

    final accepted = await remote.push([item(1), item(2), item(3)]);

    expect(accepted, {1, 2, 3});
    expect(batchSizes, [3], reason: 'all three go in one request');
  });

  test('records are sent without serverReceivedAt', () async {
    late Map<String, dynamic> sent;
    final remote = remoteWhere((bodies) async {
      sent = bodies.single;
      return ok(1);
    });

    await remote.push([item(1)]);

    expect(sent.containsKey('serverReceivedAt'), isFalse);
    expect(sent['amountUgx'], 1000);
  });

  test('one refused record does not hold up the others', () async {
    final remote = remoteWhere((bodies) async {
      final hasBadOne = bodies.any((body) => body['amountUgx'] == 13);
      return hasBadOne ? refused : ok(bodies.length);
    });

    final accepted = await remote.push([
      item(1),
      item(2, amountUgx: 13),
      item(3),
    ]);

    expect(accepted, {1, 3});
  });

  test(
    'no connection is an error, so the whole batch is tried again later',
    () async {
      final remote = PocketBaseRemote(
        PocketBase(
          'http://pb.test',
          httpClientFactory: () => MockClient(
            (request) => throw http.ClientException('No route to host'),
          ),
        ),
      );

      await expectLater(
        remote.push([item(1)]),
        throwsA(isA<ClientException>()),
      );
    },
  );

  test('a server error is an error too, not a refusal', () async {
    final remote = remoteWhere(
      (bodies) async => http.Response('{"message":"oops"}', 500),
    );

    await expectLater(remote.push([item(1)]), throwsA(isA<ClientException>()));
  });

  test('pushing nothing sends nothing', () async {
    var calls = 0;
    final remote = remoteWhere((bodies) async {
      calls++;
      return ok(0);
    });

    expect(await remote.push([]), isEmpty);
    expect(calls, 0);
  });
}
