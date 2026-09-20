import 'package:flutter/foundation.dart';

@immutable
final class SicaborCaborItem {
  const SicaborCaborItem({
    required this.id,
    required this.code,
    required this.name,
    this.groupName,
    this.logo,
    required this.status,
    required this.statusLabel,
    required this.totalClub,
    required this.totalAthlete,
  });

  final int id;
  final String code;
  final String name;
  final String? groupName;
  final String? logo;
  final int status;
  final String statusLabel;
  final int totalClub;
  final int totalAthlete;

  factory SicaborCaborItem.fromJson(Map<String, dynamic> json) {
    return SicaborCaborItem(
      id: _asInt(json['id']),
      code: json['code']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      groupName: json['group_name']?.toString(),
      logo: json['logo']?.toString(),
      status: _asInt(json['status']),
      statusLabel: json['status_label']?.toString() ?? '',
      totalClub: _asInt(json['total_club']),
      totalAthlete: _asInt(json['total_athlete']),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'code': code,
    'name': name,
    'group_name': groupName,
    'logo': logo,
    'status': status,
    'status_label': statusLabel,
    'total_club': totalClub,
    'total_athlete': totalAthlete,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SicaborCaborItem &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          code == other.code &&
          name == other.name &&
          groupName == other.groupName &&
          logo == other.logo &&
          status == other.status &&
          statusLabel == other.statusLabel &&
          totalClub == other.totalClub &&
          totalAthlete == other.totalAthlete;

  @override
  int get hashCode => Object.hash(
    id,
    code,
    name,
    groupName,
    logo,
    status,
    statusLabel,
    totalClub,
    totalAthlete,
  );
}

int _asInt(dynamic value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? fallback;
  return fallback;
}
