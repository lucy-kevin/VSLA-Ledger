import 'package:vsla_ledger/core/database/app_database.dart';
import 'package:vsla_ledger/core/groups/group_repository.dart';
import 'package:vsla_ledger/core/models/group.dart';
import 'package:vsla_ledger/core/sync/ledger_remote.dart';
import 'package:vsla_ledger/core/sync/sync_service.dart';

/// What happened when a phone tried to join a group.
sealed class JoinResult {
  const JoinResult();
}

/// The group is on this phone now, with whatever the server had for it.
class Joined extends JoinResult {
  const Joined(this.group);

  final Group group;
}

/// The code was typed in a shape no join code can have.
class InvalidJoinCode extends JoinResult {
  const InvalidJoinCode();
}

/// The server has no group with that code.
class GroupNotFound extends JoinResult {
  const GroupNotFound();
}

/// The server could not be reached. Joining is the one thing that needs the
/// internet: the phone has nothing to show until it has the group.
class JoinNeedsConnection extends JoinResult {
  const JoinNeedsConnection();
}

/// Lets a second phone (say, the secretary's) join a group made on another
/// phone, using the group's join code.
class GroupJoiner {
  GroupJoiner({
    required AppDatabase db,
    required LedgerRemote remote,
    required SyncService sync,
  }) : _db = db,
       _remote = remote,
       _sync = sync;

  final AppDatabase _db;
  final LedgerRemote _remote;
  final SyncService _sync;

  Future<JoinResult> join(String typedCode) async {
    final code = normalizeJoinCode(typedCode);
    if (!isValidJoinCode(code)) return const InvalidJoinCode();

    final Group? group;
    try {
      group = await _remote.findGroupByJoinCode(code);
    } on Exception {
      return const JoinNeedsConnection();
    }
    if (group == null) return const GroupNotFound();

    // The group came from the server, so it is not queued to go back:
    // no outbox item, just like records pulled during a sync.
    await _db.groupDao.insertGroup(group);

    // Fetch the members and entries now. If this sync fails, the group is
    // still joined, and the next sync brings the rest.
    await _sync.run();
    return Joined(group);
  }
}
