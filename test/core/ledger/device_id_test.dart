import 'package:flutter_test/flutter_test.dart';
import 'package:vsla_ledger/core/database/app_database.dart';
import 'package:vsla_ledger/core/ledger/device_id.dart';

import '../../helpers/test_database.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = newTestDatabase());
  tearDown(() => db.close());

  test('the device id is made once and then kept', () async {
    final first = await loadDeviceId(db.syncStateDao, newId: () => 'phone-a');
    final second = await loadDeviceId(db.syncStateDao, newId: () => 'phone-b');

    expect(first, 'phone-a');
    expect(second, 'phone-a');
  });
}
