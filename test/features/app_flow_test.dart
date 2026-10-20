import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_app.dart';

/// Walks through the app the way a treasurer would, on the fake server.
void main() {
  late TestApp app;

  setUp(() => app = TestApp());

  Future<void> tapText(WidgetTester tester, String text) async {
    await tester.tap(find.text(text).last);
    await app.settle(tester);
  }

  Future<void> enter(WidgetTester tester, String label, String text) async {
    await tester.enterText(find.widgetWithText(TextFormField, label), text);
    await tester.pump();
  }

  Future<void> createGroupWithSarah(WidgetTester tester) async {
    await app.start(tester);
    await tapText(tester, 'Create a group');
    await enter(tester, 'Group name', 'Tukolere Wamu');
    await tapText(tester, 'Save');
    await tapText(tester, 'Add member');
    await enter(tester, 'Name', 'Sarah');
    await tapText(tester, 'Save');
    await tapText(tester, 'Sarah');
  }

  Future<void> record(
    WidgetTester tester,
    String button,
    String amount,
  ) async {
    await tapText(tester, button);
    await enter(tester, 'Amount (UGX)', amount);
    await tapText(tester, 'Save');
  }

  testWidgets('a new phone starts with no groups', (tester) async {
    await app.start(tester);

    expect(
      find.text('No groups yet. Create one to start recording savings.'),
      findsOneWidget,
    );

    await app.stop(tester);
  });

  testWidgets('a blank group name is not saved', (tester) async {
    await app.start(tester);
    await tapText(tester, 'Create a group');

    await tapText(tester, 'Save');

    expect(find.text("Enter the group's name"), findsOneWidget);
    await app.stop(tester);
  });

  testWidgets('online, a new record syncs on its own', (tester) async {
    await createGroupWithSarah(tester);

    await record(tester, 'Savings', '10000');

    expect(find.text('Savings  UGX 10,000'), findsOneWidget);
    expect(find.textContaining('Synced'), findsOneWidget);
    expect(app.server.entries.single.amountUgx, 10000);
    await app.stop(tester);
  });

  testWidgets('airplane mode: saved on phone, synced when back online', (
    tester,
  ) async {
    await createGroupWithSarah(tester);
    app.goOffline();
    await app.settle(tester);

    await record(tester, 'Savings', '10000');

    expect(find.textContaining('Saved on phone'), findsOneWidget);
    expect(app.server.entries, isEmpty);

    app.goOnline();
    await app.settle(tester);

    expect(find.textContaining('Synced'), findsOneWidget);
    expect(app.server.entries.single.amountUgx, 10000);
    await app.stop(tester);
  });

  testWidgets('when the server is down, records stay safe on the phone', (
    tester,
  ) async {
    await app.start(tester);
    app.goOffline();
    await app.settle(tester);
    await tapText(tester, 'Create a group');
    await enter(tester, 'Group name', 'Tukolere Wamu');
    await tapText(tester, 'Save');
    expect(find.text('1 record waiting to sync'), findsOneWidget);

    await tapText(tester, 'Sync now');

    expect(
      find.text(
        'Could not reach the server. Your records are safe on this phone.',
      ),
      findsOneWidget,
    );
    expect(find.text('1 record waiting to sync'), findsOneWidget);
    await app.stop(tester);
  });

  testWidgets('Sync now sends what is waiting', (tester) async {
    await app.start(tester);
    // The server is down, but the phone still thinks it is online.
    app.server.offline = true;
    await tapText(tester, 'Create a group');
    await enter(tester, 'Group name', 'Tukolere Wamu');
    await tapText(tester, 'Save');
    expect(find.text('1 record waiting to sync'), findsOneWidget);

    app.server.offline = false;
    await tapText(tester, 'Sync now');

    expect(find.text('Everything is synced.'), findsOneWidget);
    expect(find.text('Everything is synced'), findsOneWidget);
    await app.stop(tester);
  });

  testWidgets('cancel a wrong entry, then record the right one', (
    tester,
  ) async {
    await createGroupWithSarah(tester);
    await record(tester, 'Savings', '12000');

    await tester.tap(find.byType(PopupMenuButton<void>));
    await app.settle(tester);
    await tapText(tester, 'Cancel this entry');
    await tapText(tester, 'Cancel entry');
    await record(tester, 'Savings', '10000');

    final crossedOut = tester.widget<Text>(find.text('Savings  UGX 12,000'));
    expect(crossedOut.style?.decoration, TextDecoration.lineThrough);
    expect(find.text('Cancellation  UGX 12,000'), findsOneWidget);
    // The savings figure only counts the right entry.
    expect(find.text('UGX 10,000'), findsOneWidget);
    await app.stop(tester);
  });

  testWidgets('a repayment is chosen against an open loan', (tester) async {
    await createGroupWithSarah(tester);

    await tapText(tester, 'Repayment');
    expect(find.text('This member has no loan to repay.'), findsOneWidget);
    await tester.pageBack();
    await app.settle(tester);

    await record(tester, 'Loan', '50000');
    await tapText(tester, 'Repayment');
    expect(
      find.text('Loan of UGX 50,000, UGX 50,000 still owed'),
      findsOneWidget,
    );

    await enter(tester, 'Amount (UGX)', '60000');
    await tapText(tester, 'Save');
    expect(
      find.text('That is more than the member still owes on this loan.'),
      findsOneWidget,
    );

    await enter(tester, 'Amount (UGX)', '20000');
    await tapText(tester, 'Save');
    expect(find.text('Repayment  UGX 20,000'), findsOneWidget);
    expect(find.text('UGX 30,000'), findsOneWidget);
    await app.stop(tester);
  });

  testWidgets('an amount of zero is refused with a clear message', (
    tester,
  ) async {
    await createGroupWithSarah(tester);

    await record(tester, 'Savings', '0');

    expect(find.text('The amount must be more than zero.'), findsOneWidget);
    await app.stop(tester);
  });
}
