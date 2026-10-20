import 'package:flutter_test/flutter_test.dart';
import 'package:vsla_ledger/core/clock.dart';

void main() {
  test('the time is in UTC and whole milliseconds', () {
    for (var i = 0; i < 20; i++) {
      final now = nowUtc();
      expect(now.isUtc, isTrue);
      expect(now.microsecond, 0);
    }
  });
}
