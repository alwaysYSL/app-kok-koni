import 'package:freezed_annotation/freezed_annotation.dart';
import '../core/auth/domain/user_principal.dart';

part 'models.freezed.dart';
part 'models.g.dart';

@freezed
abstract class ClubDocument with _$ClubDocument {
  const factory ClubDocument({
    required String id,
    required String name,
    required String status,
    String? fileUrl,
    DateTime? uploadedAt,
    DateTime? verifiedAt,
  }) = _ClubDocument;
  factory ClubDocument.fromJson(Map<String, dynamic> json) =>
      _$ClubDocumentFromJson(json);
}

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
    String? phone,
    String? email,
    String? address,
    @Default(<ClubDocument>[]) List<ClubDocument> documents,
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
    String? nik,
    String? birthPlace,
    DateTime? birthDate,
    String? address,
    @Default(<Milestone>[]) List<Milestone> milestones,
    @Default(<String>[]) List<String> requiredDocuments,
    @Default(<String>[]) List<String> completedDocuments,
  }) = _SportPerson;
  factory SportPerson.fromJson(Map<String, dynamic> json) =>
      _$SportPersonFromJson(json);
}

@freezed
abstract class Milestone with _$Milestone {
  const factory Milestone({
    required String year,
    required String title,
    String? description,
  }) = _Milestone;
  factory Milestone.fromJson(Map<String, dynamic> json) =>
      _$MilestoneFromJson(json);
}

@freezed
abstract class CommitteeMember with _$CommitteeMember {
  const factory CommitteeMember({
    required String id,
    required String name,
    required String position,
    required String division,
    @Default('2025–2029') String period,
    String? phone,
    String? email,
    String? photoUrl,
  }) = _CommitteeMember;
  factory CommitteeMember.fromJson(Map<String, dynamic> json) =>
      _$CommitteeMemberFromJson(json);
}

@freezed
abstract class HelpdeskContact with _$HelpdeskContact {
  const factory HelpdeskContact({
    String? whatsapp,
    String? phone,
    String? email,
    String? address,
    String? operationalHours,
  }) = _HelpdeskContact;
  factory HelpdeskContact.fromJson(Map<String, dynamic> json) =>
      _$HelpdeskContactFromJson(json);
}

@freezed
abstract class KokSnapshot with _$KokSnapshot {
  const factory KokSnapshot({
    required AccessScope scope,
    required List<Club> clubs,
    required List<SportPerson> people,
    required List<CommitteeMember> committee,
    required DateTime loadedAt,
    HelpdeskContact? helpdesk,
  }) = _KokSnapshot;
  factory KokSnapshot.fromJson(Map<String, dynamic> json) =>
      _$KokSnapshotFromJson(json);
}

extension KokSnapshotExt on KokSnapshot {
  List<String> get sports => clubs.map((c) => c.sport).toSet().toList();
}
