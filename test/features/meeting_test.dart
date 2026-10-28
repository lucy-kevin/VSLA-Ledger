import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vsla_ledger/core/groups/group_repository.dart';

import '../helpers/test_app.dart';

/// Running a meeting: many members, one screen, a few taps each.
void main() {
  late TestApp app;

  setUp(() => app = TestApp());

  Future<void> tapText(WidgetTester tester, String text) async {
    await tester.tap(find.text(text).last);
    await app.settle(tester);
  }

  Future<void> seed(WidgetTester tester, {int? sharePrice}) async {
    await tester.runAsync(() async {
      final people = GroupRepository(db: app.db);
      final group = await people.createGroup(
        'Tukolere Wamu',
        sharePriceUgx: sharePrice,
      );
      for (final name in ['Sarah', 'Peter', 'Mary']) {
        await people.addMember(groupId: group.id, name: name);
      }
    });
  }

  Future<void> openMeeting(WidgetTester tester) async {
    await app.start(tester);
    await tapText(tester, 'Tukolere Wamu');
    await tapText(tester, 'Run a meeting');
  }

  /// Taps "Record" on the [row]th member, types an amount and saves.
  Future<void> saveAmount(WidgetTester tester, int row, String amount) async {
    await tester.tap(find.text('Record').at(row));
    await app.settle(tester);
    await tester.enterText(
      find.widgetWithText(TextField, 'Amount (UGX)'),
      amount,
    );
    await tester.pump();
    await tapText(tester, 'Save');
  }

  testWidgets('lists every member, with nothing recorded yet', (tester) async {
    await seed(tester);
    await openMeeting(tester);

    expect(find.text('Sarah'), findsOneWidget);
    expect(find.text('Peter'), findsOneWidget);
    expect(find.text('Mary'), findsOneWidget);
    expect(find.text('0 of 3 members have saved'), findsOneWidget);
    await app.stop(tester);
  });

  testWidgets('record savings for three members without leaving', (
    tester,
  ) async {
    await seed(tester);
    await openMeeting(tester);

    await saveAmount(tester, 0, '5000');
    await saveAmount(tester, 1, '3000');
    await saveAmount(tester, 2, '2000');

    expect(find.text('3 of 3 members have saved'), findsOneWidget);
    // The meeting's total, and each member's own line.
    expect(find.text('Savings UGX 10,000'), findsOneWidget);
    expect(find.text('Savings UGX 5,000'), findsOneWidget);
    expect(find.text('Savings UGX 2,000'), findsOneWidget);
    // Still on the meeting screen.
    expect(find.text('Meeting'), findsOneWidget);
    await app.stop(tester);
  });

  testWidgets('a fine and a social fund go on the same screen', (tester) async {
    await seed(tester);
    await openMeeting(tester);

    await tester.tap(find.text('Record').first);
    await app.settle(tester);
    await tapText(tester, 'Fine');
    await tester.enterText(
      find.widgetWithText(TextField, 'Amount (UGX)'),
      '500',
    );
    await tester.pump();
    await tapText(tester, 'Save');

    expect(find.text('Fines UGX 500'), findsWidgets);
    expect(find.text('0 of 3 members have saved'), findsOneWidget);
    await app.stop(tester);
  });

  testWidgets('an amount of zero is explained on the form itself', (
    tester,
  ) async {
    await seed(tester);
    await openMeeting(tester);

    await saveAmount(tester, 0, '0');

    expect(find.text('The amount must be more than zero.'), findsOneWidget);
    // The form is still open, so the treasurer can fix it.
    expect(find.textContaining('Record for'), findsOneWidget);
    await app.stop(tester);
  });

  testWidgets('in a share group, the treasurer picks shares per member', (
    tester,
  ) async {
    await seed(tester, sharePrice: 2000);
    await openMeeting(tester);

    await tester.tap(find.text('Record').first);
    await app.settle(tester);
    await tapText(tester, '3');
    expect(find.text('UGX 6,000'), findsOneWidget);
    await tapText(tester, 'Save');

    expect(find.text('Savings UGX 6,000 (3 shares)'), findsWidgets);
    expect(find.text('1 of 3 members have saved'), findsOneWidget);
    await app.stop(tester);
  });

  testWidgets('too many shares at one meeting is refused on the form', (
    tester,
  ) async {
    await seed(tester, sharePrice: 2000);
    await openMeeting(tester);
    for (final count in ['5', '1']) {
      await tester.tap(find.text('Record').first);
      await app.settle(tester);
      await tapText(tester, count);
      await tapText(tester, 'Save');
    }

    expect(
      find.text('A member can buy 1 to 5 shares at one meeting.'),
      findsOneWidget,
    );
    await app.stop(tester);
  });
}
