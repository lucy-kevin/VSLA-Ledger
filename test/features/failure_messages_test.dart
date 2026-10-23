import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vsla_ledger/app/startup_error_app.dart';
import 'package:vsla_ledger/core/database/daos/outbox_dao.dart';
import 'package:vsla_ledger/core/groups/group_repository.dart';
import 'package:vsla_ledger/core/models/member.dart';
import 'package:vsla_ledger/core/models/outbox_item.dart';
import 'package:vsla_ledger/core/providers.dart';
import 'package:vsla_ledger/features/groups/sync_panel.dart';
import 'package:vsla_ledger/features/members/add_member_screen.dart';
import 'package:vsla_ledger/l10n/app_localizations.dart';
import 'package:vsla_ledger/remote/fake_remote.dart';

import '../helpers/test_database.dart';

/// A repository whose database is full.
class _FullPhoneGroupRepository implements GroupRepository {
  @override
  Future<Member> addMember({
    required String groupId,
    required String name,
    String? phone,
  }) => throw Exception('database or disk is full');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget _app(Widget home, List<Override> overrides) => ProviderScope(
  overrides: overrides,
  child: MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: home,
  ),
);

void main() {
  testWidgets('a failed save says so and lets the treasurer try again', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(const AddMemberScreen(groupId: 'g'), [
        groupRepositoryProvider.overrideWithValue(_FullPhoneGroupRepository()),
      ]),
    );

    await tester.enterText(find.byType(TextFormField).first, 'Sarah');
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    expect(find.textContaining('Could not save'), findsOneWidget);
    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNotNull);
  });

  testWidgets('the start-up error screen shows the reason', (tester) async {
    await tester.pumpWidget(
      StartupErrorApp(error: UnsupportedError('Unknown BACKEND "oops".')),
    );
    await tester.pumpAndSettle();

    expect(find.text('The app could not start'), findsOneWidget);
    expect(find.textContaining('Unknown BACKEND "oops"'), findsOneWidget);
  });

  testWidgets('records the server keeps refusing are shown', (tester) async {
    final db = newTestDatabase();
    addTearDown(() => tester.runAsync(db.close));
    await tester.runAsync(() async {
      await db.outboxDao.enqueue(
        entityType: OutboxEntityType.ledgerEntry,
        entityId: 'bad',
        payloadJson: '{}',
        createdAt: DateTime.utc(2026, 10, 23),
      );
      final item = (await db.outboxDao.nextBatch(limit: 1)).single;
      for (var i = 0; i < maxRefusals; i++) {
        await db.outboxDao.recordRefusal(item.id);
      }
    });

    await tester.pumpWidget(
      _app(const Scaffold(body: SyncPanel()), [
        appDatabaseProvider.overrideWithValue(db),
        ledgerRemoteProvider.overrideWithValue(FakeLedgerRemote()),
      ]),
    );
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();

    expect(find.text('1 record could not be sent'), findsOneWidget);
  });
}
