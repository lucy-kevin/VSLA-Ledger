import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vsla_ledger/core/groups/group_repository.dart';
import 'package:vsla_ledger/core/models/entry_type.dart';
import 'package:vsla_ledger/core/models/ledger_entry.dart';

import '../helpers/test_app.dart';

/// The app must never let a test build pass for a real one, and must make a
/// typing slip (an extra zero) easy to see.
void main() {
  Future<void> tapText(TestApp app, WidgetTester tester, String text) async {
    await tester.tap(find.text(text).last);
    await app.settle(tester);
  }

  Future<void> enter(WidgetTester tester, String label, String text) async {
    await tester.enterText(find.widgetWithText(TextFormField, label), text);
    await tester.pump();
  }

  Future<void> openSarah(TestApp app, WidgetTester tester) async {
    await app.start(tester);
    await tapText(app, tester, 'Create a group');
    await enter(tester, 'Group name', 'Tukolere Wamu');
    await tapText(app, tester, 'Save');
    await tapText(app, tester, 'Add member');
    await enter(tester, 'Name', 'Sarah');
    await tapText(app, tester, 'Save');
    await tapText(app, tester, 'Sarah');
  }

  testWidgets('the fake server shows a test-mode banner', (tester) async {
    final app = TestApp(usesFakeBackend: true);
    await app.start(tester);

    expect(find.textContaining('TEST MODE'), findsOneWidget);
    await app.stop(tester);
  });

  testWidgets('a real server shows no banner', (tester) async {
    final app = TestApp();
    await app.start(tester);

    expect(find.textContaining('TEST MODE'), findsNothing);
    await app.stop(tester);
  });

  testWidgets('with the fake server, synced says "Synced (test)"', (
    tester,
  ) async {
    final app = TestApp(usesFakeBackend: true);
    await openSarah(app, tester);

    await tapText(app, tester, 'Savings');
    await enter(tester, 'Amount (UGX)', '10000');
    await tapText(app, tester, 'Save');

    expect(find.textContaining('Synced (test)'), findsOneWidget);
    await app.stop(tester);
  });

  testWidgets('the groups screen says to use demo data only', (tester) async {
    final app = TestApp();
    await app.start(tester);

    expect(find.textContaining('Demo version'), findsOneWidget);
    await app.stop(tester);
  });

  testWidgets('the amount is shown in full while typing', (tester) async {
    final app = TestApp();
    await openSarah(app, tester);
    await tapText(app, tester, 'Savings');

    await enter(tester, 'Amount (UGX)', '600000');

    expect(find.text('UGX 600,000'), findsOneWidget);
    await app.stop(tester);
  });

  testWidgets('a negative loan balance is flagged, not hidden', (
    tester,
  ) async {
    final app = TestApp();
    // A repayment on a loan that was cancelled on another phone.
    await tester.runAsync(() async {
      final people = GroupRepository(db: app.db);
      final group = await people.createGroup('Tukolere Wamu');
      final sarah = await people.addMember(groupId: group.id, name: 'Sarah');

      LedgerEntry entry(
        String id,
        EntryType type, {
        String? loanId,
        String? corrects,
      }) => LedgerEntry(
        id: id,
        groupId: group.id,
        memberId: sarah.id,
        type: type,
        amountUgx: type == EntryType.repayment ? 2000 : 5000,
        createdAt: DateTime.utc(2026, 10, 23),
        deviceId: 'phone-b',
        loanId: loanId,
        correctsEntryId: corrects,
      );

      final dao = app.db.ledgerDao;
      await dao.insertEntry(entry('l1', EntryType.loan));
      await dao.insertEntry(
        entry('c1', EntryType.correction, corrects: 'l1'),
      );
      await dao.insertEntry(
        entry('r1', EntryType.repayment, loanId: 'l1'),
      );
    });
    await app.start(tester);
    await tapText(app, tester, 'Tukolere Wamu');
    await tapText(app, tester, 'Sarah');

    expect(find.textContaining('Check the history'), findsOneWidget);
    await app.stop(tester);
  });
}
