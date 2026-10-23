import 'package:freezed_annotation/freezed_annotation.dart';

part 'group.freezed.dart';
part 'group.g.dart';

/// A savings group: the 15 to 30 people who save and lend together.
@freezed
class Group with _$Group {
  const factory Group({
    /// UUID v4 made on the phone, so creating a group never needs a server.
    required String id,
    required String name,

    /// Short code another treasurer types to join this group on their phone.
    required String joinCode,
    required DateTime createdAt,

    /// Used for last-write-wins when two phones edit the group's name.
    required DateTime updatedAt,

    /// Service charge on loans, in percent per month of what is still owed.
    /// 0 means loans carry no charge. Set when the group is made; each loan
    /// copies it, so a later change could never alter an old loan.
    @Default(0) int monthlyChargePercent,

    /// What one share costs, in whole shillings. Null means the group saves
    /// free amounts instead of buying shares.
    int? sharePriceUgx,
  }) = _Group;

  factory Group.fromJson(Map<String, dynamic> json) => _$GroupFromJson(json);
}
