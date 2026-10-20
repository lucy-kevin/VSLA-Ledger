import 'package:vsla_ledger/core/models/outbox_item.dart';

/// Sends [items] to a server in one batch, and returns the ids the server
/// accepted.
///
/// Servers save a batch all or nothing: if they refuse one record, the whole
/// batch fails. Then this sends the items one at a time, so one bad record
/// cannot hold up all the others. A refused item is left out of the result
/// and the sync service marks it as failed.
///
/// [send] sends one batch. [isRefusal] says whether an error means "the
/// server looked at the records and refused one" (worth retrying one by
/// one), as opposed to "the server could not be reached" (rethrown, so the
/// whole batch is tried again later).
Future<Set<int>> pushWithFallback(
  List<OutboxItem> items, {
  required Future<void> Function(List<OutboxItem> batch) send,
  required bool Function(Object error) isRefusal,
}) async {
  if (items.isEmpty) return {};
  try {
    await send(items);
    return {for (final item in items) item.id};
  } on Object catch (error) {
    if (!isRefusal(error)) rethrow;
  }

  final accepted = <int>{};
  for (final item in items) {
    try {
      await send([item]);
      accepted.add(item.id);
    } on Object catch (error) {
      if (!isRefusal(error)) rethrow;
    }
  }
  return accepted;
}
