import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vsla_ledger/core/sync/delayed_remote.dart';
import 'package:vsla_ledger/remote/fake_remote.dart';

import '../helpers/test_app.dart';

/// The talk demo: the same save, our way and the online-only way.
void main() {
  Future<void> openSarah(WidgetTester tester, TestApp app) async {
    Future<void> tapText(String text) async {
      await tester.tap(find.text(text).last);
      await app.settle(tester);
    }

    await app.start(tester);
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
  }

  testWidgets('the Compare screen is not there in a normal build', (
    tester,
  ) async {
    final app = TestApp();
    await openSarah(tester, app);

    expect(find.text('Compare'), findsNothing);
    await app.stop(tester);
  });

  testWidgets('both ways save on a slow network, and both count', (
    tester,
  ) async {
    final server = FakeLedgerRemote();
    final app = TestApp(
      withDemoScreens: true,
      remote: DelayedRemote(server, const Duration(milliseconds: 300)),
    );
    await openSarah(tester, app);
    await tester.tap(find.text('Compare'));
    await app.settle(tester);

    await tester.tap(find.text('Save on phone'));
    await app.settle(tester);
    await tester.tap(find.text('Wait for server'));
    await app.settle(tester);

    expect(find.textContaining('Saved in'), findsNWidgets(2));
    expect(
      server.entries.where((e) => e.amountUgx == 1000),
      isNotEmpty,
      reason: 'the online-only save reached the server',
    );

    await tester.pageBack();
    await app.settle(tester);
    expect(
      find.text('UGX 2,000'),
      findsOneWidget,
      reason: 'savings counts both',
    );
    await app.stop(tester);
  });

  testWidgets('offline: the phone way still saves, the server way cannot', (
    tester,
  ) async {
    final app = TestApp(withDemoScreens: true);
    await openSarah(tester, app);
    await tester.tap(find.text('Compare'));
    await app.settle(tester);
    app.goOffline();
    await app.settle(tester);

    await tester.tap(find.text('Save on phone'));
    await app.settle(tester);
    await tester.tap(find.text('Wait for server'));
    await app.settle(tester);

    expect(find.textContaining('Saved in'), findsOneWidget);
    expect(find.textContaining('Not saved. Gave up after'), findsOneWidget);
    await app.stop(tester);
  });
}
