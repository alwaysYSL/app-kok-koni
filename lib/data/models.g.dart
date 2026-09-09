// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

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
    };

_CommitteeMember _$CommitteeMemberFromJson(Map<String, dynamic> json) =>
    _CommitteeMember(
      id: json['id'] as String,
      name: json['name'] as String,
      position: json['position'] as String,
      division: json['division'] as String,
      period: json['period'] as String? ?? '2025–2029',
    );

Map<String, dynamic> _$CommitteeMemberToJson(_CommitteeMember instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'position': instance.position,
      'division': instance.division,
      'period': instance.period,
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
);

Map<String, dynamic> _$KokSnapshotToJson(_KokSnapshot instance) =>
    <String, dynamic>{
      'scope': instance.scope.toJson(),
      'clubs': instance.clubs.map((e) => e.toJson()).toList(),
      'people': instance.people.map((e) => e.toJson()).toList(),
      'committee': instance.committee.map((e) => e.toJson()).toList(),
      'loadedAt': instance.loadedAt.toIso8601String(),
    };
