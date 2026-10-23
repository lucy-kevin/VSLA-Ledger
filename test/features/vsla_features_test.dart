import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vsla_ledger/core/groups/group_repository.dart';
import 'package:vsla_ledger/core/ledger/ledger_repository.dart';

import '../helpers/test_app.dart';

/// The screens for service charge, shares, social fund and fines.
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

  /// A group with Sarah in it, made ahead of time.
  Future<void> seedGroup(
    WidgetTester tester, {
    int charge = 10,
    int? sharePrice,
    Future<void> Function(
      LedgerRepository ledger,
      String groupId,
      String memberId,
    )?
    then,
  }) async {
    await tester.runAsync(() async {
      final people = GroupRepository(
        db: app.db,
        now: () => DateTime.now().subtract(const Duration(days: 70)),
      );
      final group = await people.createGroup(
        'Tukolere Wamu',
        monthlyChargePercent: charge,
        sharePriceUgx: sharePrice,
      );
      final sarah = await people.addMember(groupId: group.id, name: 'Sarah');
      await then?.call(
        LedgerRepository(db: app.db, deviceId: 'phone-a'),
        group.id,
        sarah.id,
      );
    });
  }

  Future<void> openSarah(WidgetTester tester) async {
    await app.start(tester);
    await tapText(tester, 'Tukolere Wamu');
    await tapText(tester, 'Sarah');
  }

  testWidgets('a new group can set its loan charge and share price', (
    tester,
  ) async {
    await app.start(tester);
    await tapText(tester, 'Create a group');

    await enter(tester, 'Group name', 'Tukolere Wamu');
    await enter(tester, 'Loan charge each month (%)', '5');
    await enter(tester, 'Price of one share (UGX), optional', '2000');
    await tapText(tester, 'Save');

    final group = (await tester.runAsync(app.db.groupDao.getAllGroups))!.single;
    expect(group.monthlyChargePercent, 5);
    expect(group.sharePriceUgx, 2000);
    await app.stop(tester);
  });

  testWidgets('a charge above 100 percent is not accepted', (tester) async {
    await app.start(tester);
    await tapText(tester, 'Create a group');

    await enter(tester, 'Group name', 'Tukolere Wamu');
    await enter(tester, 'Loan charge each month (%)', '150');
    await tapText(tester, 'Save');

    expect(find.text('Enter a whole number from 0 to 100'), findsOneWidget);
    await app.stop(tester);
  });

  testWidgets('in a share group, savings are bought as shares', (tester) async {
    await seedGroup(tester, sharePrice: 2000);
    await openSarah(tester);

    await tapText(tester, 'Savings');
    expect(find.text('Shares bought'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Amount (UGX)'), findsNothing);

    await tapText(tester, '3');
    expect(find.text('UGX 6,000'), findsOneWidget);
    await tapText(tester, 'Save');

    expect(find.text('3 shares'), findsWidgets);
    final groups = await tester.runAsync(app.db.groupDao.getAllGroups);
    final balance = await tester.runAsync(
      () => app.db.ledgerDao.watchGroupBalance(groups!.single.id).first,
    );
    expect(balance!.savingsUgx, 6000);
    expect(balance.sharesCount, 3);
    await app.stop(tester);
  });

  testWidgets('saving shares without choosing how many is explained', (
    tester,
  ) async {
    await seedGroup(tester, sharePrice: 2000);
    await openSarah(tester);

    await tapText(tester, 'Savings');
    await tapText(tester, 'Save');

    expect(find.text('Choose how many shares were bought.'), findsOneWidget);
    await app.stop(tester);
  });

  testWidgets('social fund and fines show on their own lines', (tester) async {
    await seedGroup(tester);
    await openSarah(tester);

    await tapText(tester, 'Social fund');
    await enter(tester, 'Amount (UGX)', '1000');
    await tapText(tester, 'Save');
    await tapText(tester, 'Fine');
    await enter(tester, 'Amount (UGX)', '500');
    await tapText(tester, 'Save');

    expect(find.text('UGX 1,000'), findsWidgets);
    expect(find.text('Fines'), findsOneWidget);
    expect(find.text('Social fund'), findsWidgets);
    // Neither is part of the savings.
    expect(find.text('UGX 0'), findsWidgets);
    await app.stop(tester);
  });

  testWidgets('the loan form says what the charge is', (tester) async {
    await seedGroup(tester);
    await openSarah(tester);

    await tapText(tester, 'Loan');

    expect(
      find.text('Service charge: 10% each month on what is not yet paid back.'),
      findsOneWidget,
    );
    await app.stop(tester);
  });

  testWidgets('a loan from two months ago shows the charge built up', (
    tester,
  ) async {
    await seedGroup(
      tester,
      then: (ledger, groupId, memberId) => ledger.issueLoan(
        groupId: groupId,
        memberId: memberId,
        amountUgx: 100000,
        meetingDate: DateTime.now().subtract(const Duration(days: 65)),
      ),
    );

    await openSarah(tester);

    expect(find.text('UGX 120,000'), findsOneWidget);
    expect(find.text('includes UGX 20,000 service charge'), findsOneWidget);
    await app.stop(tester);
  });

  testWidgets('the form shows today as the meeting date', (tester) async {
    await seedGroup(tester);
    await openSarah(tester);

    await tapText(tester, 'Savings');

    expect(find.text('Meeting date'), findsOneWidget);
    expect(find.text('Change'), findsOneWidget);
    await app.stop(tester);
  });
}
