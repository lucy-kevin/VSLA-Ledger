import 'package:flutter_test/flutter_test.dart';
import 'package:vsla_ledger/core/models/member.dart';

void main() {
  final member = Member(
    id: '7a1e2b3c-4d5e-4f60-8a9b-0c1d2e3f4a5b',
    groupId: '3f0c1d9e-5a3b-4c7e-9f21-0a1b2c3d4e5f',
    name: 'Nakato Sarah',
    joinedAt: DateTime.utc(2026, 10, 13, 9),
    updatedAt: DateTime.utc(2026, 10, 13, 9),
  );

  test('survives a trip to JSON and back', () {
    final withPhone = member.copyWith(phone: '0772123456');

    expect(Member.fromJson(withPhone.toJson()), withPhone);
  });

  test('a member can have no phone number', () {
    expect(member.phone, isNull);
    expect(Member.fromJson(member.toJson()), member);
  });
}
