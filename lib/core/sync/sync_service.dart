import 'package:vsla_ledger/core/database/app_database.dart';
import 'package:vsla_ledger/core/sync/ledger_remote.dart';

/// How a sync ended.
enum SyncResult {
  /// Everything waiting was sent, and new records were fetched.
  ok,

  /// The server could not be reached (or answered with an error). Try again
  /// later.
  unreachable,

  /// The server was reached but refused at least one record.
  refused,
}

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

  Future<SyncResult>? _running;
  bool _runAgain = false;

  /// Runs one sync. Only one sync runs at a time.
  ///
  /// Says whether everything was sent and fetched, the server could not be
  /// reached, or the server refused something. Either way nothing is lost.
  ///
  /// If a sync is already running, this waits for it, and makes it go round
  /// once more at the end, so a record saved during a sync is not left
  /// behind until the next one.
  Future<SyncResult> run() {
    final running = _running;
    if (running != null) {
      _runAgain = true;
      return running;
    }
    return _running = _runUntilNothingNew().whenComplete(() => _running = null);
  }

  Future<SyncResult> _runUntilNothingNew() async {
    SyncResult result;
    do {
      _runAgain = false;
      result = await _once();
    } while (_runAgain);
    return result;
  }

  Future<SyncResult> _once() async {
    final pushed = await _push();
    // No point asking for more when the server cannot be reached.
    if (pushed == SyncResult.unreachable) return pushed;

    // A refused record must not stop us hearing from other phones, so the
    // pull runs even when the push was only partly accepted.
    final pulled = await _pull();
    if (pulled == SyncResult.unreachable) return pulled;
    return pushed;
  }

  Future<SyncResult> _push() async {
    // Refused in this sync: leave them out of the next batches, so the rest
    // of the queue still goes up.
    final refusedIds = <int>[];
    while (true) {
      final batch = await _db.outboxDao.nextBatch(
        limit: batchSize,
        exclude: refusedIds,
      );
      if (batch.isEmpty) {
        return refusedIds.isEmpty ? SyncResult.ok : SyncResult.refused;
      }

      final Set<int> accepted;
      try {
        accepted = await _remote.push(batch);
      } on Exception catch (error) {
        for (final item in batch) {
          await _db.outboxDao.recordFailure(item.id, error.toString());
        }
        return SyncResult.unreachable;
      }

      await _db.outboxDao.removeSent(accepted.toList());
      final refused = batch.where((item) => !accepted.contains(item.id));
      for (final item in refused) {
        await _db.outboxDao.recordRefusal(item.id);
        refusedIds.add(item.id);
      }
      // Refused items are tried again at the next sync, up to
      // [maxRefusals] times.
    }
  }

  Future<SyncResult> _pull() async {
    var result = SyncResult.ok;
    for (final group in await _db.groupDao.getAllGroups()) {
      if (!await _pullGroup(group.id)) result = SyncResult.unreachable;
    }
    return result;
  }

  Future<bool> _pullGroup(String groupId) async {
    final key = 'lastPulledAt:$groupId';
    final saved = await _db.syncStateDao.read(key);
    final since = saved == null ? null : DateTime.parse(saved);

    final PullResult result;
    try {
      result = await _remote.pullSince(groupId, since);
    } on Exception {
      // Keep lastPulledAt as it was; the next sync asks again.
      return false;
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
    return true;
  }
}
