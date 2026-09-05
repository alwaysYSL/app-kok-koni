import 'package:freezed_annotation/freezed_annotation.dart';

part 'models.freezed.dart';
part 'models.g.dart';

@freezed
abstract class Club with _$Club {
  const factory Club({
    required String id,
    required String name,
    required String sport,
    required String village,
    @Default(true) bool active,
    String? logoUrl,
    String? brandPrimaryHex,
    String? brandSecondaryHex,
    int? foundedYear,
    String? registrationNumber,
  }) = _Club;
  factory Club.fromJson(Map<String, dynamic> json) => _$ClubFromJson(json);
}

@freezed
abstract class SportPerson with _$SportPerson {
  const factory SportPerson({
    required String id,
    required String name,
    required String clubId,
    required String role,
    required String group,
    @Default(true) bool verified,
    @Default(false) bool expiredLicense,
    @Default(<String>[]) List<String> missingDocuments,
    String? photoUrl,
    String? gender,
    int? age,
  }) = _SportPerson;
  factory SportPerson.fromJson(Map<String, dynamic> json) =>
      _$SportPersonFromJson(json);
}

@freezed
abstract class CommitteeMember with _$CommitteeMember {
  const factory CommitteeMember({
    required String id,
    required String name,
    required String position,
    required String division,
    @Default('2025–2029') String period,
  }) = _CommitteeMember;
  factory CommitteeMember.fromJson(Map<String, dynamic> json) =>
      _$CommitteeMemberFromJson(json);
}

@freezed
abstract class KokSnapshot with _$KokSnapshot {
  const factory KokSnapshot({
    required List<Club> clubs,
    required List<SportPerson> people,
    required List<CommitteeMember> committee,
    required DateTime loadedAt,
  }) = _KokSnapshot;
  factory KokSnapshot.fromJson(Map<String, dynamic> json) =>
      _$KokSnapshotFromJson(json);
}
