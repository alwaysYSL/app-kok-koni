// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ClubDocument _$ClubDocumentFromJson(Map<String, dynamic> json) =>
    _ClubDocument(
      id: json['id'] as String,
      name: json['name'] as String,
      status: json['status'] as String,
      fileUrl: json['fileUrl'] as String?,
      uploadedAt: json['uploadedAt'] == null
          ? null
          : DateTime.parse(json['uploadedAt'] as String),
      verifiedAt: json['verifiedAt'] == null
          ? null
          : DateTime.parse(json['verifiedAt'] as String),
    );

Map<String, dynamic> _$ClubDocumentToJson(_ClubDocument instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'status': instance.status,
      'fileUrl': instance.fileUrl,
      'uploadedAt': instance.uploadedAt?.toIso8601String(),
      'verifiedAt': instance.verifiedAt?.toIso8601String(),
    };

_Club _$ClubFromJson(Map<String, dynamic> json) => _Club(
  id: json['id'] as String,
  name: json['name'] as String,
  sport: json['sport'] as String,
  village: json['village'] as String,
  active: json['active'] as bool? ?? true,
  logoUrl: json['logoUrl'] as String?,
  brandPrimaryHex: json['brandPrimaryHex'] as String?,
  brandSecondaryHex: json['brandSecondaryHex'] as String?,
  foundedYear: (json['foundedYear'] as num?)?.toInt(),
  registrationNumber: json['registrationNumber'] as String?,
  phone: json['phone'] as String?,
  email: json['email'] as String?,
  address: json['address'] as String?,
  documents:
      (json['documents'] as List<dynamic>?)
          ?.map((e) => ClubDocument.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const <ClubDocument>[],
);

Map<String, dynamic> _$ClubToJson(_Club instance) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'sport': instance.sport,
  'village': instance.village,
  'active': instance.active,
  'logoUrl': instance.logoUrl,
  'brandPrimaryHex': instance.brandPrimaryHex,
  'brandSecondaryHex': instance.brandSecondaryHex,
  'foundedYear': instance.foundedYear,
  'registrationNumber': instance.registrationNumber,
  'phone': instance.phone,
  'email': instance.email,
  'address': instance.address,
  'documents': instance.documents.map((e) => e.toJson()).toList(),
};

_SportPerson _$SportPersonFromJson(Map<String, dynamic> json) => _SportPerson(
  id: json['id'] as String,
  name: json['name'] as String,
  clubId: json['clubId'] as String,
  role: json['role'] as String,
  group: json['group'] as String,
  verified: json['verified'] as bool? ?? true,
  expiredLicense: json['expiredLicense'] as bool? ?? false,
  missingDocuments:
      (json['missingDocuments'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      const <String>[],
  photoUrl: json['photoUrl'] as String?,
  gender: json['gender'] as String?,
  age: (json['age'] as num?)?.toInt(),
  nik: json['nik'] as String?,
  birthPlace: json['birthPlace'] as String?,
  birthDate: json['birthDate'] == null
      ? null
      : DateTime.parse(json['birthDate'] as String),
  address: json['address'] as String?,
  milestones:
      (json['milestones'] as List<dynamic>?)
          ?.map((e) => Milestone.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const <Milestone>[],
  requiredDocuments:
      (json['requiredDocuments'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      const <String>[],
  completedDocuments:
      (json['completedDocuments'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      const <String>[],
);

Map<String, dynamic> _$SportPersonToJson(_SportPerson instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'clubId': instance.clubId,
      'role': instance.role,
      'group': instance.group,
      'verified': instance.verified,
      'expiredLicense': instance.expiredLicense,
      'missingDocuments': instance.missingDocuments,
      'photoUrl': instance.photoUrl,
      'gender': instance.gender,
      'age': instance.age,
      'nik': instance.nik,
      'birthPlace': instance.birthPlace,
      'birthDate': instance.birthDate?.toIso8601String(),
      'address': instance.address,
      'milestones': instance.milestones.map((e) => e.toJson()).toList(),
      'requiredDocuments': instance.requiredDocuments,
      'completedDocuments': instance.completedDocuments,
    };

_Milestone _$MilestoneFromJson(Map<String, dynamic> json) => _Milestone(
  year: json['year'] as String,
  title: json['title'] as String,
  description: json['description'] as String?,
);

Map<String, dynamic> _$MilestoneToJson(_Milestone instance) =>
    <String, dynamic>{
      'year': instance.year,
      'title': instance.title,
      'description': instance.description,
    };

_CommitteeMember _$CommitteeMemberFromJson(Map<String, dynamic> json) =>
    _CommitteeMember(
      id: json['id'] as String,
      name: json['name'] as String,
      position: json['position'] as String,
      division: json['division'] as String,
      period: json['period'] as String? ?? '2025–2029',
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      photoUrl: json['photoUrl'] as String?,
    );

Map<String, dynamic> _$CommitteeMemberToJson(_CommitteeMember instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'position': instance.position,
      'division': instance.division,
      'period': instance.period,
      'phone': instance.phone,
      'email': instance.email,
      'photoUrl': instance.photoUrl,
    };

_HelpdeskContact _$HelpdeskContactFromJson(Map<String, dynamic> json) =>
    _HelpdeskContact(
      whatsapp: json['whatsapp'] as String?,
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      address: json['address'] as String?,
      operationalHours: json['operationalHours'] as String?,
    );

Map<String, dynamic> _$HelpdeskContactToJson(_HelpdeskContact instance) =>
    <String, dynamic>{
      'whatsapp': instance.whatsapp,
      'phone': instance.phone,
      'email': instance.email,
      'address': instance.address,
      'operationalHours': instance.operationalHours,
    };

_KokSnapshot _$KokSnapshotFromJson(Map<String, dynamic> json) => _KokSnapshot(
  scope: AccessScope.fromJson(json['scope']),
  clubs: (json['clubs'] as List<dynamic>)
      .map((e) => Club.fromJson(e as Map<String, dynamic>))
      .toList(),
  people: (json['people'] as List<dynamic>)
      .map((e) => SportPerson.fromJson(e as Map<String, dynamic>))
      .toList(),
  committee: (json['committee'] as List<dynamic>)
      .map((e) => CommitteeMember.fromJson(e as Map<String, dynamic>))
      .toList(),
  loadedAt: DateTime.parse(json['loadedAt'] as String),
  helpdesk: json['helpdesk'] == null
      ? null
      : HelpdeskContact.fromJson(json['helpdesk'] as Map<String, dynamic>),
);

Map<String, dynamic> _$KokSnapshotToJson(_KokSnapshot instance) =>
    <String, dynamic>{
      'scope': instance.scope.toJson(),
      'clubs': instance.clubs.map((e) => e.toJson()).toList(),
      'people': instance.people.map((e) => e.toJson()).toList(),
      'committee': instance.committee.map((e) => e.toJson()).toList(),
      'loadedAt': instance.loadedAt.toIso8601String(),
      'helpdesk': instance.helpdesk?.toJson(),
    };
