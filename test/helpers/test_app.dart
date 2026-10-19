import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vsla_ledger/app/app.dart';
import 'package:vsla_ledger/core/database/app_database.dart';
import 'package:vsla_ledger/core/providers.dart';
import 'package:vsla_ledger/remote/fake_remote.dart';

import 'test_database.dart';

/// The whole app, wired the way main.dart wires it, but with an in-memory
/// database and the fake server.
class TestApp {
  final AppDatabase db = newTestDatabase();
  final FakeLedgerRemote server = FakeLedgerRemote();

  Future<void> start(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          deviceIdProvider.overrideWithValue('test-phone'),
          ledgerRemoteProvider.overrideWithValue(server),
        ],
        child: const VslaApp(),
      ),
    );
    await settle(tester);
  }

  /// Lets database work and screen updates finish.
  ///
  /// The database runs real (not fake-timer) async work, so we give it a
  /// moment outside the test clock and then let the frames settle.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pumpAndSettle();
    }
  }

  /// Closes the database after the widget tree is gone, so no stream is
  /// left listening to a closed database.
  Future<void> stop(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(db.close);
  }
}
