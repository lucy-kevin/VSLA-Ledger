import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:sqlite3/common.dart';
import 'package:vsla_ledger/core/database/daos/group_dao.dart';
import 'package:vsla_ledger/core/database/daos/ledger_dao.dart';
import 'package:vsla_ledger/core/database/daos/member_dao.dart';
import 'package:vsla_ledger/core/database/daos/outbox_dao.dart';
import 'package:vsla_ledger/core/database/daos/sync_state_dao.dart';
import 'package:vsla_ledger/core/database/tables.dart';
import 'package:vsla_ledger/core/models/entry_type.dart';
import 'package:vsla_ledger/core/models/group.dart';
import 'package:vsla_ledger/core/models/ledger_entry.dart';
import 'package:vsla_ledger/core/models/member.dart';
import 'package:vsla_ledger/core/models/outbox_item.dart';

part 'app_database.g.dart';

/// The phone's database: the real copy of every record.
@DriftDatabase(
  tables: [Groups, Members, LedgerEntries, Outbox, SyncState],
  daos: [GroupDao, MemberDao, LedgerDao, OutboxDao, SyncStateDao],
)
class AppDatabase extends _$AppDatabase {
  /// Pass an in-memory executor in tests.
  AppDatabase(super.e);

  /// The database file on the phone.
  AppDatabase.onDevice()
    : super(
        driftDatabase(
          name: 'vsla_ledger',
          native: const DriftNativeOptions(setup: prepareSharedFile),
        ),
      );

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await _protectLedgerFromChanges();
    },
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        // Meetings, service charge, shares, social fund and fines. Every new
        // column is optional or has a default, so old rows stay as they are.
        await m.addColumn(groups, groups.monthlyChargePercent);
        await m.addColumn(groups, groups.sharePriceUgx);
        await m.addColumn(ledgerEntries, ledgerEntries.meetingDate);
        await m.addColumn(ledgerEntries, ledgerEntries.shares);
        await m.addColumn(ledgerEntries, ledgerEntries.monthlyChargePercent);
      }
    },
  );

  // A safety net under the "append-only" rule: even a bug or a careless
  // query cannot change or remove a money record.
  Future<void> _protectLedgerFromChanges() async {
    for (final action in ['UPDATE', 'DELETE']) {
      await customStatement('''
        CREATE TRIGGER ledger_entries_no_${action.toLowerCase()}
        BEFORE $action ON ledger_entries
        BEGIN
          SELECT RAISE(ABORT, 'ledger_entries is append-only: add a correction');
        END;
      ''');
    }
  }
}

/// Settings for the database file, which the open app and the background
/// sync (a separate engine, with its own connection) may use at once.
///
/// - WAL mode: readers do not block the writer, so the screens keep working
///   while a sync writes.
/// - Busy timeout: if both write at the same moment, one waits up to five
///   seconds for the other instead of failing straight away.
void prepareSharedFile(CommonDatabase db) {
  db
    ..execute('PRAGMA journal_mode = WAL;')
    ..execute('PRAGMA busy_timeout = 5000;');
}
