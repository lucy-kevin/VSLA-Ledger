import 'package:vsla_ledger/core/models/group.dart';
import 'package:vsla_ledger/core/models/ledger_entry.dart';
import 'package:vsla_ledger/core/models/member.dart';
import 'package:vsla_ledger/core/models/outbox_item.dart';

/// The only door between the app and a server.
///
/// PocketBase, Firebase and the fake server each implement this one
/// interface, in `lib/remote/`. Nothing else in the app knows which server
/// is in use, so swapping one for another is a one-line change.
abstract interface class LedgerRemote {
  /// Sends outbox items to the server and returns the ids of the items it
  /// accepted.
  ///
  /// The server must upsert by record id, so sending the same item twice is
  /// harmless. Throws if the server cannot be reached.
  Future<Set<int>> push(List<OutboxItem> items);

  /// Fetches the group's records that reached the server at or after
  /// [since]. A null [since] means everything.
  ///
  /// Throws if the server cannot be reached.
  Future<PullResult> pullSince(String groupId, DateTime? since);

  /// Finds the group with this join code, or null if there is none.
  ///
  /// This is how a second phone joins a group. [joinCode] is already
  /// cleaned up (see `normalizeJoinCode`). Throws if the server cannot be
  /// reached.
  Future<Group?> findGroupByJoinCode(String joinCode);
}

/// What a pull brings back from the server.
class PullResult {
  const PullResult({
    required this.serverTime,
    this.groups = const [],
    this.members = const [],
    this.entries = const [],
  });

  /// The server's clock when it answered. The next pull starts from here.
  /// We use the server's clock, not the phone's, because phone clocks are
  /// often wrong.
  final DateTime serverTime;

  final List<Group> groups;
  final List<Member> members;
  final List<LedgerEntry> entries;
}
