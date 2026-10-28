import 'package:flutter_test/flutter_test.dart';
import 'package:vsla_ledger/core/models/entry_type.dart';

void main() {
  test(
    'entry type names stay the same, because they are stored and synced',
    () {
      expect(
        EntryType.values.map((type) => type.name),
        [
          'contribution',
          'loan',
          'repayment',
          'correction',
          'socialFund',
          'fine',
        ],
      );
    },
  );
}
