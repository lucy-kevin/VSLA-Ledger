import 'dart:convert';
import 'dart:math';

import 'package:uuid/uuid.dart';
import 'package:vsla_ledger/core/clock.dart';
import 'package:vsla_ledger/core/database/app_database.dart';
import 'package:vsla_ledger/core/models/group.dart';
import 'package:vsla_ledger/core/models/member.dart';
import 'package:vsla_ledger/core/models/outbox_item.dart';

/// Letters and digits that are hard to mix up when read aloud or copied by
/// hand: no 0/O, 1/I/L.
const joinCodeAlphabet = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
const joinCodeLength = 6;

/// Creates groups and adds members.
///
/// Like the ledger, every write saves the record and its outbox item in one
/// transaction, so nothing is on the phone without being queued for sync.
class GroupRepository {
  GroupRepository({
    required AppDatabase db,
    DateTime Function()? now,
    String Function()? newId,
    Random? random,
  }) : _db = db,
       _now = now ?? nowUtc,
       _newId = newId ?? const Uuid().v4,
       _random = random ?? Random.secure();

  final AppDatabase _db;
  final DateTime Function() _now;
  final String Function() _newId;
  final Random _random;

  /// Makes a group on this phone.
  ///
  /// [monthlyChargePercent] is the service charge on loans (0 to 100 percent
  /// a month of what is still owed). [sharePriceUgx] is what one share costs;
  /// leave it out for a group that saves free amounts. Both are fixed when
  /// the group is made.
  Future<Group> createGroup(
    String name, {
    int monthlyChargePercent = 0,
    int? sharePriceUgx,
  }) async {
    if (monthlyChargePercent < 0 || monthlyChargePercent > 100) {
      throw ArgumentError.value(
        monthlyChargePercent,
        'monthlyChargePercent',
        'must be 0 to 100',
      );
    }
    if (sharePriceUgx != null && sharePriceUgx < 1) {
      throw ArgumentError.value(sharePriceUgx, 'sharePriceUgx', 'must be 1+');
    }
    final now = _now();
    final group = Group(
      id: _newId(),
      name: _required(name, 'name'),
      joinCode: makeJoinCode(_random),
      createdAt: now,
      updatedAt: now,
      monthlyChargePercent: monthlyChargePercent,
      sharePriceUgx: sharePriceUgx,
    );

    await _db.transaction(() async {
      await _db.groupDao.insertGroup(group);
      await _db.outboxDao.enqueue(
        entityType: OutboxEntityType.group,
        entityId: group.id,
        payloadJson: jsonEncode(group.toJson()),
        createdAt: now,
      );
    });
    return group;
  }

  Future<Member> addMember({
    required String groupId,
    required String name,
    String? phone,
  }) async {
    final now = _now();
    final trimmedPhone = phone?.trim();
    final member = Member(
      id: _newId(),
      groupId: groupId,
      name: _required(name, 'name'),
      phone: (trimmedPhone == null || trimmedPhone.isEmpty)
          ? null
          : trimmedPhone,
      joinedAt: now,
      updatedAt: now,
    );

    await _db.transaction(() async {
      await _db.memberDao.insertMember(member);
      await _db.outboxDao.enqueue(
        entityType: OutboxEntityType.member,
        entityId: member.id,
        payloadJson: jsonEncode(member.toJson()),
        createdAt: now,
      );
    });
    return member;
  }

  // The screens check this first and show a friendly message; this is the
  // last line of defence against a blank name reaching the database.
  String _required(String value, String field) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) throw ArgumentError.value(value, field, 'is empty');
    return trimmed;
  }
}

/// Cleans up a code as a person typed it: ignores case, spaces and dashes,
/// so "tkw 482" and "TKW-482" both become "TKW482".
String normalizeJoinCode(String typed) =>
    typed.toUpperCase().replaceAll(RegExp(r'[\s-]'), '');

/// Whether [code] (already normalized) could be a join code at all.
bool isValidJoinCode(String code) =>
    code.length == joinCodeLength &&
    code.split('').every(joinCodeAlphabet.contains);

String makeJoinCode(Random random) => String.fromCharCodes([
  for (var i = 0; i < joinCodeLength; i++)
    joinCodeAlphabet.codeUnitAt(random.nextInt(joinCodeAlphabet.length)),
]);
