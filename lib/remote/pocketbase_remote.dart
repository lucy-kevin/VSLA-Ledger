import 'dart:convert';

import 'package:pocketbase/pocketbase.dart';
import 'package:vsla_ledger/core/models/group.dart';
import 'package:vsla_ledger/core/models/ledger_entry.dart';
import 'package:vsla_ledger/core/models/member.dart';
import 'package:vsla_ledger/core/models/outbox_item.dart';
import 'package:vsla_ledger/core/sync/ledger_remote.dart';

/// Syncs with a self-hosted PocketBase server.
///
/// This file is the only place in the app that knows about PocketBase.
/// Everything else talks to [LedgerRemote], so swapping PocketBase for
/// another server never touches the rest of the code.
///
/// The server side lives in `server/pocketbase/`.
class PocketBaseRemote implements LedgerRemote {
  PocketBaseRemote(this._pb);

  /// [url] is the server address, for example `http://10.0.2.2:8090`.
  PocketBaseRemote.connect(String url) : this(PocketBase(url));

  final PocketBase _pb;

  static const Map<OutboxEntityType, String> _collections = {
    OutboxEntityType.group: 'groups',
    OutboxEntityType.member: 'members',
    OutboxEntityType.ledgerEntry: 'ledger_entries',
  };

  @override
  Future<Set<int>> push(List<OutboxItem> items) async {
    if (items.isEmpty) return {};
    try {
      await _sendBatch(items);
      return {for (final item in items) item.id};
    } on ClientException catch (error) {
      if (!_serverRefusedSomething(error)) rethrow;
      // A batch is all or nothing: one refused record fails the whole batch.
      // Send them one at a time, so one bad record cannot hold up the others.
      return _pushOneByOne(items);
    }
  }

  Future<Set<int>> _pushOneByOne(List<OutboxItem> items) async {
    final accepted = <int>{};
    for (final item in items) {
      try {
        await _sendBatch([item]);
        accepted.add(item.id);
      } on ClientException catch (error) {
        if (!_serverRefusedSomething(error)) rethrow;
        // Left out of `accepted`: the sync service marks it as failed.
      }
    }
    return accepted;
  }

  Future<void> _sendBatch(List<OutboxItem> items) async {
    final batch = _pb.createBatch();
    for (final item in items) {
      batch
          .collection(_collections[item.entityType]!)
          .upsert(body: _toServer(item));
    }
    await batch.send();
  }

  /// A 4xx answer means the server looked at the records and refused one.
  /// Anything else (no connection, timeout, server error) means "try the
  /// whole thing again later".
  bool _serverRefusedSomething(ClientException error) =>
      error.statusCode >= 400 && error.statusCode < 500;

  Map<String, dynamic> _toServer(OutboxItem item) {
    final json = jsonDecode(item.payloadJson) as Map<String, dynamic>;
    // The server keeps its own "first received" time (`created`).
    return json..remove('serverReceivedAt');
  }

  @override
  Future<PullResult> pullSince(String groupId, DateTime? since) async {
    final updatedSince = since == null ? '' : ' && updated >= {:since}';
    // `?since` leaves the key out entirely when since is null.
    final params = {'groupId': groupId, 'since': ?since};

    final groups = await _fetch(
      'groups',
      'id = {:groupId}$updatedSince',
      params,
    );
    final members = await _fetch(
      'members',
      'groupId = {:groupId}$updatedSince',
      params,
    );
    final entries = await _fetch(
      'ledger_entries',
      'groupId = {:groupId}$updatedSince',
      params,
    );

    return PullResult(
      serverTime: _newestUpdate([...groups, ...members, ...entries], since),
      groups: [
        for (final record in groups) Group.fromJson(_fromServer(record)),
      ],
      members: [
        for (final record in members) Member.fromJson(_fromServer(record)),
      ],
      entries: [
        for (final record in entries)
          LedgerEntry.fromJson(_ledgerEntry(record)),
      ],
    );
  }

  Future<List<RecordModel>> _fetch(
    String collection,
    String filter,
    Map<String, dynamic> params,
  ) => _pb
      .collection(collection)
      .getFullList(filter: _pb.filter(filter, params), sort: 'updated');

  // PocketBase answers with no clock of its own, so the next pull starts
  // from the newest `updated` time it sent us: still the server's clock,
  // never the phone's. "At or after" means that last record comes again
  // next time, which is harmless: the phone skips ids it already has.
  DateTime _newestUpdate(List<RecordModel> records, DateTime? since) {
    var newest = since ?? DateTime.utc(1970);
    for (final record in records) {
      final updated = DateTime.parse(record.get<String>('updated'));
      if (updated.isAfter(newest)) newest = updated;
    }
    return newest;
  }

  Map<String, dynamic> _ledgerEntry(RecordModel record) =>
      _fromServer(record)..['serverReceivedAt'] = record.get<String>('created');

  // PocketBase sends an empty string for an empty text field; the app uses
  // null.
  Map<String, dynamic> _fromServer(RecordModel record) => {
    for (final MapEntry(:key, :value) in record.toJson().entries)
      key: value == '' ? null : value,
  };
}
