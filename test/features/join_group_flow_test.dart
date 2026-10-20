import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vsla_ledger/core/models/group.dart';
import 'package:vsla_ledger/core/models/member.dart';
import 'package:vsla_ledger/core/models/outbox_item.dart';

import '../helpers/test_app.dart';

/// A second phone joins a group that the treasurer's phone already sent to
/// the (fake) server.
void main() {
  late TestApp app;

  final group = Group(
    id: '0b6f5a52-3c1d-4f1e-9a7b-2d3c4e5f6a7b',
    name: 'Tukolere Wamu',
    joinCode: 'TKW482',
    createdAt: DateTime.utc(2026, 10, 20, 9),
    updatedAt: DateTime.utc(2026, 10, 20, 9),
  );
  final sarah = Member(
    id: '1c7a6b63-4d2e-4a2f-8b8c-3e4d5f6a7b8c',
    groupId: group.id,
    name: 'Sarah',
    joinedAt: DateTime.utc(2026, 10, 20, 9),
    updatedAt: DateTime.utc(2026, 10, 20, 9),
  );

  setUp(() async {
    app = TestApp();
    // What the treasurer's phone already sent.
    await app.server.push([
      OutboxItem(
        id: 1,
        entityType: OutboxEntityType.group,
        entityId: group.id,
        payloadJson: jsonEncode(group.toJson()),
        createdAt: group.createdAt,
      ),
      OutboxItem(
        id: 2,
        entityType: OutboxEntityType.member,
        entityId: sarah.id,
        payloadJson: jsonEncode(sarah.toJson()),
        createdAt: sarah.joinedAt,
      ),
    ]);
  });

  Future<void> joinWith(WidgetTester tester, String code) async {
    await tester.enterText(find.byType(TextField), code);
    await tester.tap(find.text('Join').last);
    await app.settle(tester);
  }

  testWidgets('join with the code and see the group and its members', (
    tester,
  ) async {
    await app.start(tester);
    await tester.tap(find.text('Join a group'));
    await app.settle(tester);

    await joinWith(tester, 'tkw 482');

    expect(find.text('Tukolere Wamu'), findsOneWidget);
    expect(find.text('Join code: TKW482'), findsOneWidget);
    expect(find.text('Sarah'), findsOneWidget);
    await app.stop(tester);
  });

  testWidgets('a wrong code says so and stays on the form', (tester) async {
    await app.start(tester);
    await tester.tap(find.text('Join a group'));
    await app.settle(tester);

    await joinWith(tester, 'ZZZZZZ');

    expect(
      find.text(
        'No group has that code. Check it, '
        'or ask the treasurer to sync their phone first.',
      ),
      findsOneWidget,
    );
    await joinWith(tester, 'AB');
    expect(find.text('A join code has 6 letters and numbers.'), findsOneWidget);
    await app.stop(tester);
  });

  testWidgets('offline, joining asks for the internet', (tester) async {
    await app.start(tester);
    app.goOffline();
    await app.settle(tester);
    await tester.tap(find.text('Join a group'));
    await app.settle(tester);

    await joinWith(tester, 'TKW482');

    expect(
      find.text('Joining needs the internet. Connect and try again.'),
      findsOneWidget,
    );
    await app.stop(tester);
  });
}
