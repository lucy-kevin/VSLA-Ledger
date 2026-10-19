import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:vsla_ledger/core/models/ledger_entry.dart';

part 'entry_line.freezed.dart';

/// One line of a member's history, as the screen shows it.
@freezed
class EntryLine with _$EntryLine {
  const factory EntryLine({
    required LedgerEntry entry,

    /// A correction points at this entry, so it no longer counts.
    required bool isCancelled,

    /// Still in the outbox: shown as "Saved on phone" instead of "Synced".
    required bool isWaitingToSync,
  }) = _EntryLine;
}
