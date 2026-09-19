import 'package:flutter/foundation.dart';

@immutable
final class SicaborScope {
  const SicaborScope({
    required this.subdistrictId,
    required this.subdistrictName,
    required this.districtId,
    required this.districtName,
  });

  final int subdistrictId;
  final String subdistrictName;
  final int districtId;
  final String districtName;

  factory SicaborScope.fromJson(Map<String, dynamic> json) {
    return SicaborScope(
      subdistrictId: _asInt(json['subdistrict_id']),
      subdistrictName: json['subdistrict_name']?.toString() ?? '',
      districtId: _asInt(json['district_id']),
      districtName: json['district_name']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'subdistrict_id': subdistrictId,
    'subdistrict_name': subdistrictName,
    'district_id': districtId,
    'district_name': districtName,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SicaborScope &&
          runtimeType == other.runtimeType &&
          subdistrictId == other.subdistrictId &&
          subdistrictName == other.subdistrictName &&
          districtId == other.districtId &&
          districtName == other.districtName;

  @override
  int get hashCode =>
      Object.hash(subdistrictId, subdistrictName, districtId, districtName);
}

@immutable
final class SicaborMember {
  const SicaborMember({
    required this.id,
    required this.username,
    required this.name,
    this.email,
    required this.type,
    required this.status,
    required this.statusLabel,
  });

  final int id;
  final String username;
  final String name;
  final String? email;
  final String type;
  final int status;
  final String statusLabel;

  factory SicaborMember.fromJson(Map<String, dynamic> json) {
    return SicaborMember(
      id: _asInt(json['id']),
      username: json['username']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      email: json['email'] as String?,
      type: json['type']?.toString() ?? '',
      status: _asInt(json['status']),
      statusLabel: json['status_label']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'username': username,
    'name': name,
    'email': email,
    'type': type,
    'status': status,
    'status_label': statusLabel,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SicaborMember &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          username == other.username &&
          name == other.name &&
          email == other.email &&
          type == other.type &&
          status == other.status &&
          statusLabel == other.statusLabel;

  @override
  int get hashCode =>
      Object.hash(id, username, name, email, type, status, statusLabel);
}

@immutable
final class SicaborKontingen {
  const SicaborKontingen({
    required this.id,
    required this.code,
    required this.name,
  });

  final int id;
  final String code;
  final String name;

  factory SicaborKontingen.fromJson(Map<String, dynamic> json) {
    return SicaborKontingen(
      id: _asInt(json['id']),
      code: json['code']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {'id': id, 'code': code, 'name': name};

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SicaborKontingen &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          code == other.code &&
          name == other.name;

  @override
  int get hashCode => Object.hash(id, code, name);
}

@immutable
final class SicaborSummary {
  const SicaborSummary({
    required this.totalCabor,
    required this.totalCaborFromClub,
    required this.totalCaborFromAthlete,
    required this.totalClub,
    required this.totalAthlete,
    required this.totalAthleteWithoutClub,
  });

  final int totalCabor;
  final int totalCaborFromClub;
  final int totalCaborFromAthlete;
  final int totalClub;
  final int totalAthlete;
  final int totalAthleteWithoutClub;

  factory SicaborSummary.fromJson(Map<String, dynamic> json) {
    return SicaborSummary(
      totalCabor: _asInt(json['total_cabor']),
      totalCaborFromClub: _asInt(json['total_cabor_from_club']),
      totalCaborFromAthlete: _asInt(json['total_cabor_from_athlete']),
      totalClub: _asInt(json['total_club']),
      totalAthlete: _asInt(json['total_athlete']),
      totalAthleteWithoutClub: _asInt(json['total_athlete_without_club']),
    );
  }

  Map<String, dynamic> toJson() => {
    'total_cabor': totalCabor,
    'total_cabor_from_club': totalCaborFromClub,
    'total_cabor_from_athlete': totalCaborFromAthlete,
    'total_club': totalClub,
    'total_athlete': totalAthlete,
    'total_athlete_without_club': totalAthleteWithoutClub,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SicaborSummary &&
          runtimeType == other.runtimeType &&
          totalCabor == other.totalCabor &&
          totalCaborFromClub == other.totalCaborFromClub &&
          totalCaborFromAthlete == other.totalCaborFromAthlete &&
          totalClub == other.totalClub &&
          totalAthlete == other.totalAthlete &&
          totalAthleteWithoutClub == other.totalAthleteWithoutClub;

  @override
  int get hashCode => Object.hash(
    totalCabor,
    totalCaborFromClub,
    totalCaborFromAthlete,
    totalClub,
    totalAthlete,
    totalAthleteWithoutClub,
  );
}

@immutable
final class SicaborProfileData {
  const SicaborProfileData({
    required this.member,
    this.kontingen,
    required this.summary,
    this.dataNotes = const [],
  });

  final SicaborMember member;
  final SicaborKontingen? kontingen;
  final SicaborSummary summary;
  final List<String> dataNotes;

  factory SicaborProfileData.fromJson(Map<String, dynamic> json) {
    final rawKontingen = json['kontingen'];
    final rawNotes = json['data_notes'];
    return SicaborProfileData(
      member: SicaborMember.fromJson(
        (json['member'] as Map<String, dynamic>?) ?? const {},
      ),
      kontingen: rawKontingen is Map<String, dynamic>
          ? SicaborKontingen.fromJson(rawKontingen)
          : null,
      summary: SicaborSummary.fromJson(
        (json['summary'] as Map<String, dynamic>?) ?? const {},
      ),
      dataNotes: rawNotes is List
          ? rawNotes.map((e) => e.toString()).toList()
          : const [],
    );
  }

  Map<String, dynamic> toJson() => {
    'member': member.toJson(),
    'kontingen': kontingen?.toJson(),
    'summary': summary.toJson(),
    'data_notes': dataNotes,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SicaborProfileData &&
          runtimeType == other.runtimeType &&
          member == other.member &&
          kontingen == other.kontingen &&
          summary == other.summary &&
          listEquals(dataNotes, other.dataNotes);

  @override
  int get hashCode =>
      Object.hash(member, kontingen, summary, Object.hashAll(dataNotes));
}

@immutable
final class SicaborProfileResponse {
  const SicaborProfileResponse({
    required this.success,
    required this.message,
    required this.scope,
    required this.data,
  });

  final bool success;
  final String message;
  final SicaborScope scope;
  final SicaborProfileData data;

  factory SicaborProfileResponse.fromJson(Map<String, dynamic> json) {
    return SicaborProfileResponse(
      success: json['success'] as bool? ?? false,
      message: json['message']?.toString() ?? '',
      scope: SicaborScope.fromJson(
        (json['scope'] as Map<String, dynamic>?) ?? const {},
      ),
      data: SicaborProfileData.fromJson(
        (json['data'] as Map<String, dynamic>?) ?? const {},
      ),
    );
  }

  Map<String, dynamic> toJson() => {
    'success': success,
    'message': message,
    'scope': scope.toJson(),
    'data': data.toJson(),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SicaborProfileResponse &&
          runtimeType == other.runtimeType &&
          success == other.success &&
          message == other.message &&
          scope == other.scope &&
          data == other.data;

  @override
  int get hashCode => Object.hash(success, message, scope, data);
}

int _asInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}
