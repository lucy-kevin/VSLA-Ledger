import 'package:freezed_annotation/freezed_annotation.dart';

part 'member.freezed.dart';
part 'member.g.dart';

/// A person in a savings group.
///
/// We keep only a name and an optional phone number. No national ID and no
/// location: these are real people's records and we store as little as we can.
@freezed
class Member with _$Member {
  const factory Member({
    /// UUID v4 made on the phone.
    required String id,
    required String groupId,
    required String name,
    required DateTime joinedAt,

    /// Used for last-write-wins when two phones edit the same member.
    required DateTime updatedAt,

    /// Optional, because many members share a phone or have none.
    String? phone,
  }) = _Member;

  factory Member.fromJson(Map<String, dynamic> json) => _$MemberFromJson(json);
}
