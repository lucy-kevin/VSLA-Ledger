import 'package:vsla_ledger/core/database/app_database.dart';
import 'package:vsla_ledger/core/sync/ledger_remote.dart';

/// Moves records between the phone and the server.
///
/// One sync: push the outbox in batches, then pull what other phones have
/// sent. If the network fails, nothing is lost: unsent items stay in the
/// outbox and the next sync tries again.
class SyncService {
  SyncService({required AppDatabase db, required LedgerRemote remote})
    : _db = db,
      _remote = remote;

  /// How many outbox items go to the server in one request.
  static const batchSize = 50;

  final AppDatabase _db;
  final LedgerRemote _remote;

  Future<void>? _running;
  bool _runAgain = false;

  /// Runs one sync. Only one sync runs at a time.
  ///
  /// If a sync is already running, this waits for it, and makes it go round
  /// once more at the end, so a record saved during a sync is not left
  /// behind until the next one.
  Future<void> run() {
    final running = _running;
    if (running != null) {
      _runAgain = true;
      return running;
    }
    return _running = _runUntilNothingNew().whenComplete(() => _running = null);
  }

  Future<void> _runUntilNothingNew() async {
    do {
      _runAgain = false;
      final pushedEverything = await _push();
      if (pushedEverything) await _pull();
    } while (_runAgain);
  }

  /// Returns false if the server could not be reached or refused something.
  Future<bool> _push() async {
    while (true) {
      final batch = await _db.outboxDao.nextBatch(limit: batchSize);
      if (batch.isEmpty) return true;

      final Set<int> accepted;
      try {
        accepted = await _remote.push(batch);
      } on Exception catch (error) {
        for (final item in batch) {
          await _db.outboxDao.recordFailure(item.id, error.toString());
        }
        return false;
      }

      await _db.outboxDao.removeSent(accepted.toList());
      final refused = batch.where((item) => !accepted.contains(item.id));
      for (final item in refused) {
        await _db.outboxDao.recordFailure(item.id, 'Refused by the server');
      }
      // Stop rather than send the same refused items again in a loop.
      if (refused.isNotEmpty) return false;
    }
  }

  Future<void> _pull() async {
    for (final group in await _db.groupDao.getAllGroups()) {
      await _pullGroup(group.id);
    }
  }

  Future<void> _pullGroup(String groupId) async {
    final key = 'lastPulledAt:$groupId';
    final saved = await _db.syncStateDao.read(key);
    final since = saved == null ? null : DateTime.parse(saved);

    final PullResult result;
    try {
      result = await _remote.pullSince(groupId, since);
    } on Exception {
      // Keep lastPulledAt as it was; the next sync asks again.
      return;
    }

    // Records we already have are skipped by id, so pulling the same record
    // twice is harmless. Saving the new lastPulledAt in the same transaction
    // means we never move it forward without keeping what we pulled.
    await _db.transaction(() async {
      for (final group in result.groups) {
        await _db.groupDao.insertGroup(group);
      }
      for (final member in result.members) {
        await _db.memberDao.insertMember(member);
      }
      for (final entry in result.entries) {
        await _db.ledgerDao.insertEntry(entry);
      }
      await _db.syncStateDao.write(
        key,
        result.serverTime.toUtc().toIso8601String(),
      );
    });
  }
}
