import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:vsla_ledger/core/models/group.dart';
import 'package:vsla_ledger/core/models/ledger_entry.dart';
import 'package:vsla_ledger/core/models/member.dart';
import 'package:vsla_ledger/core/models/outbox_item.dart';
import 'package:vsla_ledger/core/sync/ledger_remote.dart';
import 'package:vsla_ledger/core/sync/push_with_fallback.dart';

/// Syncs with Google's Cloud Firestore.
///
/// It is here to compare with PocketBase: same app, same interface, a
/// vendor's cloud instead of your own server. This file is the only place
/// in the app that knows about Firebase.
///
/// Setup (project, rules, indexes) is in `server/firebase/README.md`.
class FirebaseRemote implements LedgerRemote {
  FirebaseRemote(this._db, {this.timeout = const Duration(seconds: 20)});

  /// Starts Firebase from `android/app/google-services.json`.
  static Future<FirebaseRemote> connect() async {
    await Firebase.initializeApp();
    // Firestore can keep its own offline copy and queue writes, which would
    // hide our outbox: the demo would show Firestore's offline mode, not
    // ours. Switched off, Firestore behaves like a plain server.
    final db = FirebaseFirestore.instance
      ..settings = const Settings(persistenceEnabled: false);
    return FirebaseRemote(db);
  }

  final FirebaseFirestore _db;

  /// Without its offline copy, Firestore still waits quietly for the
  /// network instead of failing. This limit turns that wait into an error,
  /// so the sync can record it and try again later. A write that does reach
  /// the server after the limit is harmless: records are saved by id.
  final Duration timeout;

  static const Map<OutboxEntityType, String> _collections = {
    OutboxEntityType.group: 'groups',
    OutboxEntityType.member: 'members',
    OutboxEntityType.ledgerEntry: 'ledger_entries',
  };

  @override
  Future<Set<int>> push(List<OutboxItem> items) => pushWithFallback(
    items,
    send: _commit,
    isRefusal: _serverRefusedSomething,
  );

  Future<void> _commit(List<OutboxItem> items) async {
    final batch = _db.batch();
    for (final item in items) {
      final doc = _db
          .collection(_collections[item.entityType]!)
          .doc(item.entityId);
      batch.set(doc, _toServer(item));
    }
    await batch.commit().timeout(timeout);
  }

  /// The security rules said no (for example, a changed ledger entry).
  /// Anything else, such as no network, means "try again later".
  bool _serverRefusedSomething(Object error) =>
      error is FirebaseException &&
      (error.code == 'permission-denied' || error.code == 'invalid-argument');

  Map<String, dynamic> _toServer(OutboxItem item) {
    final json = jsonDecode(item.payloadJson) as Map<String, dynamic>;
    return json
      ..remove('serverReceivedAt')
      // Set by Firestore's own clock when the write arrives. Pulls ask for
      // "everything with serverUpdatedAt at or after my last pull".
      ..['serverUpdatedAt'] = FieldValue.serverTimestamp();
  }

  @override
  Future<PullResult> pullSince(String groupId, DateTime? since) async {
    final group = await _db
        .collection('groups')
        .doc(groupId)
        .get()
        .timeout(timeout);
    final members = await _query('members', groupId, since);
    final entries = await _query('ledger_entries', groupId, since);

    final groups = [
      if (group.exists && _isNew(group.data()!, since)) group.data()!,
    ];

    return PullResult(
      serverTime: _newestUpdate([...groups, ...members, ...entries], since),
      groups: [for (final data in groups) Group.fromJson(_fromServer(data))],
      members: [for (final data in members) Member.fromJson(_fromServer(data))],
      entries: [
        for (final data in entries) LedgerEntry.fromJson(_ledgerEntry(data)),
      ],
    );
  }

  /// Needs a composite index on (groupId, serverUpdatedAt); see
  /// `server/firebase/firestore.indexes.json`.
  Future<List<Map<String, dynamic>>> _query(
    String collection,
    String groupId,
    DateTime? since,
  ) async {
    var query = _db.collection(collection).where('groupId', isEqualTo: groupId);
    if (since != null) {
      query = query.where(
        'serverUpdatedAt',
        isGreaterThanOrEqualTo: Timestamp.fromDate(since),
      );
    }
    final snapshot = await query
        .orderBy('serverUpdatedAt')
        .get()
        .timeout(timeout);
    return [for (final doc in snapshot.docs) doc.data()];
  }

  bool _isNew(Map<String, dynamic> data, DateTime? since) =>
      since == null || !_updatedAt(data).isBefore(since);

  DateTime _updatedAt(Map<String, dynamic> data) =>
      (data['serverUpdatedAt'] as Timestamp).toDate().toUtc();

  // Like PocketBase, Firestore sends no clock of its own with a query, so
  // the next pull starts from the newest serverUpdatedAt it sent us.
  DateTime _newestUpdate(List<Map<String, dynamic>> records, DateTime? since) {
    var newest = since ?? DateTime.utc(1970);
    for (final data in records) {
      final updated = _updatedAt(data);
      if (updated.isAfter(newest)) newest = updated;
    }
    return newest;
  }

  // Firestore's timestamp type is not JSON, so it is taken out before the
  // record becomes one of our models.
  Map<String, dynamic> _fromServer(Map<String, dynamic> data) =>
      Map.of(data)..remove('serverUpdatedAt');

  Map<String, dynamic> _ledgerEntry(Map<String, dynamic> data) =>
      _fromServer(data)
        ..['serverReceivedAt'] = _updatedAt(data).toIso8601String();
}
