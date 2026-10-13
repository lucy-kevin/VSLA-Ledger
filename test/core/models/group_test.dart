import 'package:flutter_test/flutter_test.dart';
import 'package:vsla_ledger/core/models/group.dart';

void main() {
  final group = Group(
    id: '3f0c1d9e-5a3b-4c7e-9f21-0a1b2c3d4e5f',
    name: 'Tukolere Wamu',
    joinCode: 'TKW482',
    createdAt: DateTime.utc(2026, 10, 13, 9),
    updatedAt: DateTime.utc(2026, 10, 14, 9),
  );

  test('survives a trip to JSON and back', () {
    expect(Group.fromJson(group.toJson()), group);
  });

  test('uses the agreed JSON field names', () {
    expect(group.toJson(), {
      'id': '3f0c1d9e-5a3b-4c7e-9f21-0a1b2c3d4e5f',
      'name': 'Tukolere Wamu',
      'joinCode': 'TKW482',
      'createdAt': '2026-10-13T09:00:00.000Z',
      'updatedAt': '2026-10-14T09:00:00.000Z',
    });
  });
}
