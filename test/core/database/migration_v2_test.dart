import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vsla_ledger/core/database/app_database.dart';
import 'package:vsla_ledger/core/models/entry_type.dart';

import '../../drift/app_database/generated/schema.dart';

/// Version 2 adds meetings, service charge, shares, social fund and fines.
/// A phone that already holds real records must keep every one of them.
void main() {
  late SchemaVerifier verifier;

  setUpAll(() => verifier = SchemaVerifier(GeneratedHelper()));

  test(
    'a version 1 database keeps its records and gets the new columns',
    () async {
      final oldPhone = await verifier.schemaAt(1);
      oldPhone.rawDatabase
        ..execute('''
        INSERT INTO groups (id, name, join_code, created_at, updated_at)
        VALUES ('g1', 'Tukolere Wamu', 'TKW482',
                '2026-10-01T09:00:00.000Z', '2026-10-01T09:00:00.000Z')
      ''')
        ..execute('''
        INSERT INTO ledger_entries
          (id, group_id, member_id, type, amount_ugx, created_at, device_id)
        VALUES ('e1', 'g1', 'm1', 'contribution', 5000,
                '2026-10-08T09:00:00.000Z', 'phone-a')
      ''');

      final db = AppDatabase(oldPhone.newConnection());
      await verifier.migrateAndValidate(db, 2);

      final group = (await db.groupDao.getAllGroups()).single;
      expect(group.name, 'Tukolere Wamu');
      // Old groups carry no service charge and no shares.
      expect(group.monthlyChargePercent, 0);
      expect(group.sharePriceUgx, isNull);

      final entry = (await db.ledgerDao.getEntriesForMember('m1')).single;
      expect(entry.amountUgx, 5000);
      expect(entry.type, EntryType.contribution);
      // An old entry has no meeting date, so it counts on the day it was made.
      expect(entry.meetingDate, isNull);
      expect(entry.shares, isNull);
      expect(entry.monthlyChargePercent, isNull);

      await db.close();
    },
  );

  test('after upgrading, the ledger still refuses UPDATE and DELETE', () async {
    final oldPhone = await verifier.schemaAt(1);
    // The schema dump has no triggers, but a real version 1 phone does (they
    // are made when the database is first created). Add them to match.
    for (final action in ['UPDATE', 'DELETE']) {
      oldPhone.rawDatabase.execute('''
        CREATE TRIGGER ledger_entries_no_${action.toLowerCase()}
        BEFORE $action ON ledger_entries
        BEGIN SELECT RAISE(ABORT, 'append-only'); END;
      ''');
    }
    oldPhone.rawDatabase.execute('''
      INSERT INTO ledger_entries
        (id, group_id, member_id, type, amount_ugx, created_at, device_id)
      VALUES ('e1', 'g1', 'm1', 'contribution', 5000,
              '2026-10-08T09:00:00.000Z', 'phone-a')
    ''');
    final db = AppDatabase(oldPhone.newConnection());
    await verifier.migrateAndValidate(db, 2);

    await expectLater(
      db.customStatement('UPDATE ledger_entries SET amount_ugx = 1'),
      throwsA(anything),
    );
    await expectLater(
      db.customStatement('DELETE FROM ledger_entries'),
      throwsA(anything),
    );

    await db.close();
  });
}
