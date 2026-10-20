import 'dart:convert';

import 'package:vsla_ledger/core/clock.dart';
import 'package:vsla_ledger/core/models/group.dart';
import 'package:vsla_ledger/core/models/ledger_entry.dart';
import 'package:vsla_ledger/core/models/member.dart';
import 'package:vsla_ledger/core/models/outbox_item.dart';
import 'package:vsla_ledger/core/sync/ledger_remote.dart';

/// Thrown by [FakeLedgerRemote] while it pretends to be offline.
class FakeServerOffline implements Exception {
  @override
  String toString() => 'No connection to the server';
}

/// A pretend server that lives in memory.
///
/// It lets anyone run and test the whole app with no server and no
/// internet. Set [offline] to true to act like airplane mode.
class FakeLedgerRemote implements LedgerRemote {
  FakeLedgerRemote({DateTime Function()? now}) : _now = now ?? nowUtc;

  final DateTime Function() _now;

  /// While true, every call fails as if there were no network.
  bool offline = false;

  /// How many items each push carried. Lets tests check batching.
  final List<int> pushedBatchSizes = [];

  final _groups = <String, _Stored<Group>>{};
  final _members = <String, _Stored<Member>>{};
  final _entries = <String, _Stored<LedgerEntry>>{};

  List<LedgerEntry> get entries =>
      _entries.values.map((stored) => stored.record).toList();

  @override
  Future<Set<int>> push(List<OutboxItem> items) async {
    if (offline) throw FakeServerOffline();
    pushedBatchSizes.add(items.length);

    final receivedAt = _now();
    for (final item in items) {
      final json = jsonDecode(item.payloadJson) as Map<String, dynamic>;
      switch (item.entityType) {
        case OutboxEntityType.group:
          // Groups and members can be edited, so the newest copy wins.
          _groups[item.entityId] = _Stored(Group.fromJson(json), receivedAt);
        case OutboxEntityType.member:
          _members[item.entityId] = _Stored(Member.fromJson(json), receivedAt);
        case OutboxEntityType.ledgerEntry:
          // Ledger entries never change: keep the first copy we received.
          _entries.putIfAbsent(item.entityId, () {
            final entry = LedgerEntry.fromJson(json);
            return _Stored(
              entry.copyWith(serverReceivedAt: receivedAt),
              receivedAt,
            );
          });
      }
    }
    return {for (final item in items) item.id};
  }

  @override
  Future<Group?> findGroupByJoinCode(String joinCode) async {
    if (offline) throw FakeServerOffline();
    for (final stored in _groups.values) {
      if (stored.record.joinCode == joinCode) return stored.record;
    }
    return null;
  }

  @override
  Future<PullResult> pullSince(String groupId, DateTime? since) async {
    if (offline) throw FakeServerOffline();
    final serverTime = _now();

    // "At or after" since, not just "after": a record that arrived in the
    // same millisecond as the last pull must not be missed. Getting a record
    // twice is harmless, because the phone skips ids it already has.
    bool isNew(_Stored<Object> stored) =>
        since == null || !stored.receivedAt.isBefore(since);

    return PullResult(
      serverTime: serverTime,
      groups: [
        for (final stored in _groups.values)
          if (stored.record.id == groupId && isNew(stored)) stored.record,
      ],
      members: [
        for (final stored in _members.values)
          if (stored.record.groupId == groupId && isNew(stored)) stored.record,
      ],
      entries: [
        for (final stored in _entries.values)
          if (stored.record.groupId == groupId && isNew(stored)) stored.record,
      ],
    );
  }
}

class _Stored<T> {
  _Stored(this.record, this.receivedAt);

  final T record;
  final DateTime receivedAt;
}
