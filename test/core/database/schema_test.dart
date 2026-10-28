import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vsla_ledger/core/database/app_database.dart';

import '../../helpers/test_database.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = newTestDatabase());
  tearDown(() => db.close());

  test('a fresh install creates exactly the schema the code expects', () async {
    await db.validateDatabaseSchema();
  });

  test('a fresh install creates the append-only triggers', () async {
    final triggers = await db
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'trigger' ORDER BY name",
        )
        .map((row) => row.read<String>('name'))
        .get();

    expect(triggers, ['ledger_entries_no_delete', 'ledger_entries_no_update']);
  });

  test('the schema version is 2', () {
    expect(db.schemaVersion, 2);
  });
}
