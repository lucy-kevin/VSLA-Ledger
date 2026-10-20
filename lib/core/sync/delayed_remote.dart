import 'package:vsla_ledger/core/models/group.dart';
import 'package:vsla_ledger/core/models/outbox_item.dart';
import 'package:vsla_ledger/core/sync/ledger_remote.dart';

/// Makes any server feel like it is on a slow network, by waiting before
/// every request.
///
/// For the talk: a real slow network is hard to control on stage, a fixed
/// delay is the same every time. Switched on with
/// `--dart-define=DEMO_DELAY_MS=3000`.
class DelayedRemote implements LedgerRemote {
  DelayedRemote(this._inner, this.delay);

  final LedgerRemote _inner;
  final Duration delay;

  @override
  Future<Set<int>> push(List<OutboxItem> items) async {
    await Future<void>.delayed(delay);
    return _inner.push(items);
  }

  @override
  Future<PullResult> pullSince(String groupId, DateTime? since) async {
    await Future<void>.delayed(delay);
    return _inner.pullSince(groupId, since);
  }

  @override
  Future<Group?> findGroupByJoinCode(String joinCode) async {
    await Future<void>.delayed(delay);
    return _inner.findGroupByJoinCode(joinCode);
  }
}
