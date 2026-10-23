// Draws the main screens to PNG files so a design change can be looked at
// without a phone. Not a real test: it checks nothing, and is skipped unless
// asked for:
//
//   flutter test test/tool/screenshots_test.dart \
//     --dart-define=SCREENSHOTS_DIR=C:/some/folder
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vsla_ledger/core/groups/group_repository.dart';
import 'package:vsla_ledger/core/ledger/ledger_repository.dart';

import '../helpers/test_app.dart';

const outDir = String.fromEnvironment('SCREENSHOTS_DIR');

/// The test environment draws every letter as a box. Real fonts from the
/// Flutter SDK make the pictures readable.
Future<void> loadFonts() async {
  final root = Platform.environment['FLUTTER_ROOT']!;
  final fonts = '$root/bin/cache/artifacts/material_fonts';
  final roboto = FontLoader('Roboto')
    ..addFont(_read('$fonts/Roboto-Regular.ttf'))
    ..addFont(_read('$fonts/Roboto-Medium.ttf'))
    ..addFont(_read('$fonts/Roboto-Bold.ttf'));
  await roboto.load();
  final icons = FontLoader('MaterialIcons')
    ..addFont(_read('$fonts/MaterialIcons-Regular.otf'));
  await icons.load();
}

Future<ByteData> _read(String path) async {
  // The SDK names some font files in lower case.
  final file = File(path).existsSync()
      ? File(path)
      : File(
          '${File(path).parent.path}/${File(path).uri.pathSegments.last.toLowerCase()}',
        );
  return ByteData.sublistView(await file.readAsBytes());
}

void main() {
  late TestApp app;

  Future<void> shot(WidgetTester tester, String name) async {
    final boundary =
        tester.renderObject(find.byType(RepaintBoundary).first)
            as RenderRepaintBoundary;
    final bytes = await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 2);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      return data!.buffer.asUint8List();
    });
    File('$outDir/$name.png')
      ..createSync(recursive: true)
      ..writeAsBytesSync(bytes!);
  }

  Future<void> tapText(WidgetTester tester, String text) async {
    // Scroll to it first: a long list does not even build rows far below.
    if (find.text(text).evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        find.text(text),
        300,
        scrollable: find.byType(Scrollable).first,
      );
    }
    await tester.ensureVisible(find.text(text).last);
    await tester.pump();
    await tester.tap(find.text(text).last);
    await app.settle(tester);
  }

  Future<void> seed(WidgetTester tester) async {
    await tester.runAsync(() async {
      final people = GroupRepository(
        db: app.db,
        now: () => DateTime.now().subtract(const Duration(days: 90)),
      );
      final group = await people.createGroup(
        'Tukolere Wamu',
        monthlyChargePercent: 10,
        sharePriceUgx: 2000,
      );
      await people.createGroup('Abakyala Twekembe');
      final ledger = LedgerRepository(db: app.db, deviceId: 'phone-a');
      final names = {
        'Sarah Nakato': '0772 123456',
        'Peter Okello': null,
        'Mary Achieng': '0701 555 010',
        'John Mugisha': null,
      };
      final ids = <String>[];
      for (final MapEntry(:key, :value) in names.entries) {
        ids.add(
          (await people.addMember(
            groupId: group.id,
            name: key,
            phone: value,
          )).id,
        );
      }
      DateTime ago(int days) => DateTime.now().subtract(Duration(days: days));
      await ledger.recordContribution(
        groupId: group.id,
        memberId: ids[0],
        shares: 3,
        meetingDate: ago(14),
      );
      await ledger.recordContribution(
        groupId: group.id,
        memberId: ids[0],
        shares: 5,
        meetingDate: ago(7),
      );
      await ledger.issueLoan(
        groupId: group.id,
        memberId: ids[0],
        amountUgx: 200000,
        meetingDate: ago(65),
      );
      await ledger.recordSocialFund(
        groupId: group.id,
        memberId: ids[0],
        amountUgx: 2000,
        meetingDate: ago(7),
      );
      final fine = await ledger.recordFine(
        groupId: group.id,
        memberId: ids[0],
        amountUgx: 1000,
        meetingDate: ago(7),
      );
      await ledger.cancelEntry(fine.id);
      await ledger.recordContribution(
        groupId: group.id,
        memberId: ids[1],
        shares: 2,
        meetingDate: ago(7),
      );
      await ledger.recordContribution(
        groupId: group.id,
        memberId: ids[2],
        shares: 4,
        meetingDate: ago(7),
      );
    });
  }

  Future<void> walk(
    WidgetTester tester, {
    required String tag,
    Brightness brightness = Brightness.light,
    double textScale = 1,
  }) async {
    app = TestApp();
    tester.view
      ..physicalSize = const Size(1080, 2200)
      ..devicePixelRatio = 3;
    tester.platformDispatcher
      ..textScaleFactorTestValue = textScale
      ..platformBrightnessTestValue = brightness;
    addTearDown(() {
      tester.view.reset();
      tester.platformDispatcher.clearAllTestValues();
    });
    await seed(tester);
    await app.start(tester);
    await shot(tester, '$tag-1-groups');

    await tapText(tester, 'Tukolere Wamu');
    await shot(tester, '$tag-2-group');

    await tapText(tester, 'Sarah Nakato');
    await shot(tester, '$tag-3-member');

    await tapText(tester, 'Savings');
    await tester.tap(find.text('3').last);
    await app.settle(tester);
    await shot(tester, '$tag-4-record-shares');
    await tester.pageBack();
    await app.settle(tester);

    await tapText(tester, 'Loan');
    await tester.enterText(find.byType(TextFormField).last, '150000');
    await tester.pump();
    await shot(tester, '$tag-5-record-loan');
    await tester.pageBack();
    await app.settle(tester);
    await tester.pageBack();
    await app.settle(tester);

    await tapText(tester, 'Run a meeting');
    await shot(tester, '$tag-6-meeting');
    await tester.tap(find.text('Record').first);
    await app.settle(tester);
    await shot(tester, '$tag-7-meeting-sheet');
    await app.stop(tester);
  }

  // Skipped unless SCREENSHOTS_DIR is set.
  final skip = outDir.isEmpty;

  setUpAll(() async {
    if (outDir.isNotEmpty) await loadFonts();
  });

  testWidgets('light', (tester) => walk(tester, tag: 'light'), skip: skip);
  testWidgets(
    'dark',
    (tester) => walk(tester, tag: 'dark', brightness: Brightness.dark),
    skip: skip,
  );
  testWidgets(
    'large text',
    (tester) => walk(tester, tag: 'large', textScale: 1.6),
    skip: skip,
  );
}
