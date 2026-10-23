import 'package:flutter_test/flutter_test.dart';
import 'package:vsla_ledger/core/models/entry_type.dart';
import 'package:vsla_ledger/core/models/ledger_entry.dart';

void main() {
  final contribution = LedgerEntry(
    id: 'b2c3d4e5-f6a7-4b8c-9d0e-1f2a3b4c5d6e',
    groupId: '3f0c1d9e-5a3b-4c7e-9f21-0a1b2c3d4e5f',
    memberId: '7a1e2b3c-4d5e-4f60-8a9b-0c1d2e3f4a5b',
    type: EntryType.contribution,
    amountUgx: 10000,
    createdAt: DateTime.utc(2026, 10, 13, 9),
    deviceId: 'phone-a',
  );

  test('a new entry has not reached the server yet', () {
    expect(contribution.serverReceivedAt, isNull);
    expect(contribution.correctsEntryId, isNull);
    expect(contribution.loanId, isNull);
  });

  test('uses the agreed JSON field names', () {
    expect(contribution.toJson(), {
      'id': 'b2c3d4e5-f6a7-4b8c-9d0e-1f2a3b4c5d6e',
      'groupId': '3f0c1d9e-5a3b-4c7e-9f21-0a1b2c3d4e5f',
      'memberId': '7a1e2b3c-4d5e-4f60-8a9b-0c1d2e3f4a5b',
      'type': 'contribution',
      'amountUgx': 10000,
      'createdAt': '2026-10-13T09:00:00.000Z',
      'deviceId': 'phone-a',
      'serverReceivedAt': null,
      'correctsEntryId': null,
      'loanId': null,
      'meetingDate': null,
      'shares': null,
      'monthlyChargePercent': null,
    });
  });

  test('the amount stays a whole number through JSON', () {
    final decoded = LedgerEntry.fromJson(contribution.toJson());

    expect(decoded.amountUgx, isA<int>());
    expect(decoded.amountUgx, 10000);
  });

  test('every entry type survives a trip to JSON and back', () {
    for (final type in EntryType.values) {
      final entry = contribution.copyWith(type: type);

      expect(LedgerEntry.fromJson(entry.toJson()), entry);
    }
  });

  test('a correction keeps its link to the entry it corrects', () {
    final correction = contribution.copyWith(
      id: 'c3d4e5f6-a7b8-4c9d-8e0f-2a3b4c5d6e7f',
      type: EntryType.correction,
      correctsEntryId: contribution.id,
      serverReceivedAt: DateTime.utc(2026, 10, 13, 10),
    );

    final decoded = LedgerEntry.fromJson(correction.toJson());

    expect(decoded, correction);
    expect(decoded.correctsEntryId, contribution.id);
  });

  test('a fractional amount is rejected, not rounded', () {
    final json = contribution.toJson()..['amountUgx'] = 10000.5;

    expect(() => LedgerEntry.fromJson(json), throwsFormatException);
  });
}
