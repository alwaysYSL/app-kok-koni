import 'package:flutter/foundation.dart';

@immutable
final class SicaborClubItem {
  const SicaborClubItem({
    required this.id,
    required this.code,
    required this.name,
    this.logo,
    required this.cabor,
    this.headName,
    this.phone,
    this.email,
    this.since,
    this.noSk,
    required this.status,
    required this.statusLabel,
    required this.secretariat,
    required this.totalAthleteInClub,
  });

  final int id;
  final String code;
  final String name;
  final String? logo;
  final Map<String, dynamic> cabor;
  final String? headName;
  final String? phone;
  final String? email;
  final String? since;
  final String? noSk;
  final int status;
  final String statusLabel;
  final Map<String, dynamic> secretariat;
  final int totalAthleteInClub;

  factory SicaborClubItem.fromJson(Map<String, dynamic> json) {
    return SicaborClubItem(
      id: _asInt(json['id']),
      code: json['code']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      logo: json['logo']?.toString(),
      cabor: _asMap(json['cabor']),
      headName: json['head_name']?.toString(),
      phone: json['phone']?.toString(),
      email: json['email']?.toString(),
      since: json['since']?.toString(),
      noSk: json['no_sk']?.toString(),
      status: _asInt(json['status']),
      statusLabel: json['status_label']?.toString() ?? '',
      secretariat: _asMap(json['secretariat']),
      totalAthleteInClub: _asInt(json['total_athlete_in_club']),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'code': code,
    'name': name,
    'logo': logo,
    'cabor': cabor,
    'head_name': headName,
    'phone': phone,
    'email': email,
    'since': since,
    'no_sk': noSk,
    'status': status,
    'status_label': statusLabel,
    'secretariat': secretariat,
    'total_athlete_in_club': totalAthleteInClub,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SicaborClubItem &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          code == other.code &&
          name == other.name &&
          logo == other.logo &&
          mapEquals(cabor, other.cabor) &&
          headName == other.headName &&
          phone == other.phone &&
          email == other.email &&
          since == other.since &&
          noSk == other.noSk &&
          status == other.status &&
          statusLabel == other.statusLabel &&
          mapEquals(secretariat, other.secretariat) &&
          totalAthleteInClub == other.totalAthleteInClub;

  @override
  int get hashCode => Object.hash(
    id,
    code,
    name,
    logo,
    _mapHashCode(cabor),
    headName,
    phone,
    email,
    since,
    noSk,
    status,
    statusLabel,
    _mapHashCode(secretariat),
    totalAthleteInClub,
  );
}

int _asInt(dynamic value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? fallback;
  return fallback;
}

Map<String, dynamic> _asMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return const <String, dynamic>{};
}

int _mapHashCode(Map<String, dynamic> map) {
  return Object.hashAll(map.entries.map((e) => Object.hash(e.key, e.value)));
}
