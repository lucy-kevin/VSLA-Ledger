import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:vsla_ledger/core/models/entry_type.dart';
import 'package:vsla_ledger/core/models/whole_shillings_converter.dart';

part 'ledger_entry.freezed.dart';
part 'ledger_entry.g.dart';

/// One line in the group's ledger.
///
/// Entries are append-only: once written they are never changed or deleted.
/// A mistake is fixed by adding a new [EntryType.correction] entry that
/// points at the wrong one, just like crossing out a line in a paper ledger.
/// This is what lets two offline phones merge their records safely.
@freezed
class LedgerEntry with _$LedgerEntry {
  const factory LedgerEntry({
    /// UUID v4 made on the phone. The server upserts by this id, so sending
    /// the same entry twice is harmless.
    required String id,
    required String groupId,
    required String memberId,
    required EntryType type,

    /// Whole Uganda shillings. An int, never a double: doubles cannot hold
    /// money exactly and the rounding errors add up.
    @WholeShillingsConverter() required int amountUgx,

    /// When the treasurer recorded it, by the phone's clock.
    required DateTime createdAt,

    /// Which phone recorded it. Helps trace a record back to its source.
    required String deviceId,

    /// When the server first saw this entry. Null until it has synced.
    DateTime? serverReceivedAt,

    /// For a correction: the id of the entry being corrected.
    String? correctsEntryId,

    /// Links a repayment to the loan it pays back.
    String? loanId,
  }) = _LedgerEntry;

  factory LedgerEntry.fromJson(Map<String, dynamic> json) =>
      _$LedgerEntryFromJson(json);
}
