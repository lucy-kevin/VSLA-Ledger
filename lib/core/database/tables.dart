import 'package:drift/drift.dart';
import 'package:vsla_ledger/core/models/entry_type.dart';
import 'package:vsla_ledger/core/models/group.dart';
import 'package:vsla_ledger/core/models/ledger_entry.dart';
import 'package:vsla_ledger/core/models/member.dart';
import 'package:vsla_ledger/core/models/outbox_item.dart';

// There are no foreign key constraints on purpose. Records from other phones
// can arrive in any order during a sync, for example an entry before the
// member it belongs to. A constraint would make that sync fail.

@UseRowClass(Group, generateInsertable: true)
class Groups extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get joinCode => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  IntColumn get monthlyChargePercent =>
      integer().withDefault(const Constant(0))();
  IntColumn get sharePriceUgx => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@UseRowClass(Member, generateInsertable: true)
@TableIndex(name: 'members_by_group', columns: {#groupId})
class Members extends Table {
  TextColumn get id => text()();
  TextColumn get groupId => text()();
  TextColumn get name => text()();
  TextColumn get phone => text().nullable()();
  DateTimeColumn get joinedAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Append-only. The database itself refuses UPDATE and DELETE on this table
/// (see the triggers in app_database.dart).
@UseRowClass(LedgerEntry, generateInsertable: true)
@TableIndex(name: 'entries_by_member', columns: {#memberId})
@TableIndex(name: 'entries_by_group', columns: {#groupId})
@TableIndex(name: 'entries_by_corrected_entry', columns: {#correctsEntryId})
class LedgerEntries extends Table {
  TextColumn get id => text()();
  TextColumn get groupId => text()();
  TextColumn get memberId => text()();
  TextColumn get type => textEnum<EntryType>()();

  /// Whole Uganda shillings, always positive (see [customConstraints]).
  IntColumn get amountUgx => integer()();
  DateTimeColumn get createdAt => dateTime()();
  TextColumn get deviceId => text()();
  DateTimeColumn get serverReceivedAt => dateTime().nullable()();
  TextColumn get correctsEntryId => text().nullable()();

  /// For a repayment: the id of the loan entry it pays back.
  TextColumn get loanId => text().nullable()();

  /// The meeting day (stored as a date at midnight). Null on older rows.
  DateTimeColumn get meetingDate => dateTime().nullable()();
  IntColumn get shares => integer().nullable()();
  IntColumn get monthlyChargePercent => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};

  // A correction cancels an entry by pointing at it, never with a negative
  // amount, so every amount in the ledger is above zero.
  @override
  List<String> get customConstraints => ['CHECK (amount_ugx > 0)'];
}

@UseRowClass(OutboxItem)
class Outbox extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get entityType => textEnum<OutboxEntityType>()();
  TextColumn get entityId => text()();
  TextColumn get payloadJson => text()();
  DateTimeColumn get createdAt => dateTime()();
  IntColumn get attempts => integer().withDefault(const Constant(0))();
  TextColumn get lastError => text().nullable()();
}

/// Small key-value store for sync bookkeeping, such as
/// `lastPulledAt:<groupId>`.
class SyncState extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}
