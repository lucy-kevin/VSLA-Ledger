import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:vsla_ledger/core/database/app_database.dart';

/// A fresh, empty database in memory. Each test gets its own.
///
/// Some tests play two phones at once, each with its own separate database.
/// Drift warns when the database class is opened twice, because sharing one
/// file that way is dangerous; separate in-memory databases are safe, so the
/// warning is switched off for tests only.
AppDatabase newTestDatabase() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  return _openInMemory();
}

AppDatabase _openInMemory() => AppDatabase(
  DatabaseConnection(
    NativeDatabase.memory(),
    closeStreamsSynchronously: true,
  ),
);
