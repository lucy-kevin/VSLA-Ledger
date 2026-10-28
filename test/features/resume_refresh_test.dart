import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_app.dart';

/// The background sync writes through its own database connection, so the
/// open app is not told. Coming back to the app must show the change.
void main() {
  testWidgets('after the app resumes, the screen shows what changed', (
    tester,
  ) async {
    final app = TestApp();
    Future<void> tapText(String text) async {
      await tester.tap(find.text(text).last);
      await app.settle(tester);
    }

    await app.start(tester);
    app.goOffline();
    await app.settle(tester);
    await tapText('Create a group');
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Group name'),
      'Tukolere Wamu',
    );
    await tapText('Save');
    await tapText('Add member');
    await tester.enterText(find.widgetWithText(TextFormField, 'Name'), 'Sarah');
    await tapText('Save');
    await tapText('Sarah');
    await tapText('Savings');
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Amount (UGX)'),
      '10000',
    );
    await tapText('Save');
    expect(find.textContaining('Saved on phone'), findsOneWidget);

    // What the background sync does, through a connection the screens do
    // not hear about: it empties the outbox after sending.
    await tester.runAsync(() => app.db.customStatement('DELETE FROM outbox'));
    await app.settle(tester);
    expect(
      find.textContaining('Saved on phone'),
      findsOneWidget,
      reason: 'the screen was not told yet',
    );

    // Leave the app and come back, through the states a phone goes through.
    [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ].forEach(tester.binding.handleAppLifecycleStateChanged);
    await app.settle(tester);

    expect(find.textContaining('Saved on phone'), findsNothing);
    expect(find.textContaining('Synced'), findsOneWidget);
    await app.stop(tester);
  });
}
