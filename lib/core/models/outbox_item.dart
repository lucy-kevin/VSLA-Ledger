import 'package:freezed_annotation/freezed_annotation.dart';

part 'outbox_item.freezed.dart';
part 'outbox_item.g.dart';

/// Which table an outbox item's record lives in.
///
/// The names are stored in the database, so renaming a value is a schema
/// change.
enum OutboxEntityType { group, member, ledgerEntry }

/// A change that is saved on the phone but not yet sent to the server.
///
/// Every user write adds one of these in the same database transaction as
/// the record itself, so a record can never be saved without being queued.
/// The sync service deletes the item once the server accepts it.
@freezed
class OutboxItem with _$OutboxItem {
  const factory OutboxItem({
    /// Auto-incremented by the database, so items are pushed in the order
    /// they were written.
    required int id,
    required OutboxEntityType entityType,

    /// The id of the group, member or ledger entry to push.
    required String entityId,

    /// The record as JSON, exactly as it will be sent.
    required String payloadJson,
    required DateTime createdAt,

    /// How many pushes have failed so far.
    @Default(0) int attempts,

    /// The most recent failure, kept so the treasurer can be told why.
    String? lastError,
  }) = _OutboxItem;

  factory OutboxItem.fromJson(Map<String, dynamic> json) =>
      _$OutboxItemFromJson(json);
}
