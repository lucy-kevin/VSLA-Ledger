import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vsla_ledger/core/database/app_database.dart';
import 'package:vsla_ledger/core/groups/group_repository.dart';
import 'package:vsla_ledger/core/groups/join_group.dart';
import 'package:vsla_ledger/core/ledger/ledger_repository.dart';
import 'package:vsla_ledger/core/models/balance.dart';
import 'package:vsla_ledger/core/models/entry_line.dart';
import 'package:vsla_ledger/core/models/group.dart';
import 'package:vsla_ledger/core/models/ledger_entry.dart';
import 'package:vsla_ledger/core/models/member.dart';
import 'package:vsla_ledger/core/sync/connection.dart';
import 'package:vsla_ledger/core/sync/ledger_remote.dart';
import 'package:vsla_ledger/core/sync/sync_service.dart';
import 'package:vsla_ledger/core/sync/sync_trigger.dart';

part 'providers.g.dart';

// --- Set in main.dart -------------------------------------------------------
// These three are filled in when the app starts (and by tests), so nothing
// here decides which database file or which server to use.

@Riverpod(keepAlive: true)
AppDatabase appDatabase(Ref ref) =>
    throw UnimplementedError('Overridden in main.dart');

@Riverpod(keepAlive: true)
String deviceId(Ref ref) => throw UnimplementedError('Overridden in main.dart');

/// The server. main.dart picks it from `--dart-define=BACKEND`.
@Riverpod(keepAlive: true)
LedgerRemote ledgerRemote(Ref ref) =>
    throw UnimplementedError('Overridden in main.dart');

/// Talk demo only: show the Compare screen (lib/features/demo/). main.dart
/// sets it from `--dart-define=DEMO=true`; tests switch it on directly.
@Riverpod(keepAlive: true)
bool showDemoScreens(Ref ref) => false;

// --- Writing -----------------------------------------------------------------

@Riverpod(keepAlive: true)
LedgerRepository ledgerRepository(Ref ref) => LedgerRepository(
  db: ref.watch(appDatabaseProvider),
  deviceId: ref.watch(deviceIdProvider),
);

@Riverpod(keepAlive: true)
GroupRepository groupRepository(Ref ref) =>
    GroupRepository(db: ref.watch(appDatabaseProvider));

@Riverpod(keepAlive: true)
GroupJoiner groupJoiner(Ref ref) => GroupJoiner(
  db: ref.watch(appDatabaseProvider),
  remote: ref.watch(ledgerRemoteProvider),
  sync: ref.watch(syncServiceProvider),
);

/// Kept alive, because it remembers whether a sync is already running.
@Riverpod(keepAlive: true)
SyncService syncService(Ref ref) => SyncService(
  db: ref.watch(appDatabaseProvider),
  remote: ref.watch(ledgerRemoteProvider),
);

/// The phone's online status now, then each change. Tests replace this.
@Riverpod(keepAlive: true)
Stream<bool> onlineChanges(Ref ref) => watchOnline(Connectivity());

/// Syncs after writes and when the phone comes online. The app keeps this
/// alive for as long as it runs (see VslaApp).
@Riverpod(keepAlive: true)
SyncTrigger syncTrigger(Ref ref) {
  final trigger = SyncTrigger(
    sync: ref.watch(syncServiceProvider),
    outbox: ref.watch(appDatabaseProvider).outboxDao,
  );
  ref
    ..listen(onlineChangesProvider, (previous, next) {
      final online = next.valueOrNull;
      if (online != null) trigger.onlineChanged(online: online);
    }, fireImmediately: true)
    ..onDispose(trigger.stop);
  return trigger;
}

// --- Reading: live streams from the database --------------------------------
// Screens only ever read through these. When the database changes, the
// screen updates by itself.

@riverpod
Stream<List<Group>> groups(Ref ref) =>
    ref.watch(appDatabaseProvider).groupDao.watchAllGroups();

@riverpod
Stream<Group?> group(Ref ref, String groupId) =>
    ref.watch(appDatabaseProvider).groupDao.watchGroup(groupId);

@riverpod
Stream<List<Member>> members(Ref ref, String groupId) =>
    ref.watch(appDatabaseProvider).memberDao.watchMembersOfGroup(groupId);

@riverpod
Stream<Member?> member(Ref ref, String memberId) =>
    ref.watch(appDatabaseProvider).memberDao.watchMember(memberId);

@riverpod
Stream<List<EntryLine>> memberHistory(Ref ref, String memberId) =>
    ref.watch(appDatabaseProvider).ledgerDao.watchHistoryForMember(memberId);

@riverpod
Stream<List<LedgerEntry>> memberEntries(Ref ref, String memberId) =>
    ref.watch(appDatabaseProvider).ledgerDao.watchEntriesForMember(memberId);

@riverpod
Stream<Balance> memberBalance(Ref ref, String memberId) =>
    ref.watch(appDatabaseProvider).ledgerDao.watchMemberBalance(memberId);

@riverpod
Stream<Balance> groupBalance(Ref ref, String groupId) =>
    ref.watch(appDatabaseProvider).ledgerDao.watchGroupBalance(groupId);

/// Records the server keeps refusing. They stay on the phone.
@riverpod
Stream<int> stuckRecords(Ref ref) =>
    ref.watch(appDatabaseProvider).outboxDao.watchStuckCount();

@riverpod
Stream<int> recordsWaitingToSync(Ref ref) =>
    ref.watch(appDatabaseProvider).outboxDao.watchPendingCount();
