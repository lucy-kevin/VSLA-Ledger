import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:vsla_ledger/core/database/app_database.dart';

/// A fresh, empty database in memory. Each test gets its own.
AppDatabase newTestDatabase() => AppDatabase(
  DatabaseConnection(
    NativeDatabase.memory(),
    closeStreamsSynchronously: true,
  ),
);
