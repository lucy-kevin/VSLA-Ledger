import 'package:uuid/uuid.dart';
import 'package:vsla_ledger/core/database/daos/sync_state_dao.dart';

const _deviceIdKey = 'deviceId';

/// This phone's id, stamped on every entry it records.
///
/// Made once, the first time the app needs it, and kept in the database so
/// it stays the same after the app restarts.
Future<String> loadDeviceId(
  SyncStateDao syncState, {
  String Function()? newId,
}) async {
  final saved = await syncState.read(_deviceIdKey);
  if (saved != null) return saved;

  final created = (newId ?? const Uuid().v4)();
  await syncState.write(_deviceIdKey, created);
  return created;
}
