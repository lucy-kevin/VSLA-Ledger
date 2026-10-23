import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:vsla_ledger/core/clock.dart';
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

    /// The day of the group meeting this entry belongs to (the time of day is
    /// not used). The treasurer may record Monday's meeting on Tuesday, so
    /// this can differ from [createdAt]. Null on entries made before this
    /// field existed: use [meetingDay] to read it.
    DateTime? meetingDate,

    /// For savings bought as shares: how many. The amount is always
    /// shares x the group's share price.
    int? shares,

    /// For a loan: the group's service charge (percent per month) when the
    /// loan was given. Null or 0 means no charge.
    int? monthlyChargePercent,
  }) = _LedgerEntry;

  const LedgerEntry._();

  factory LedgerEntry.fromJson(Map<String, dynamic> json) =>
      _$LedgerEntryFromJson(json);

  /// The meeting day, whether or not one was chosen: older entries count on
  /// the day they were recorded.
  DateTime get meetingDay => dateOnly(meetingDate ?? createdAt.toLocal());
}
