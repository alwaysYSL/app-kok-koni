import 'package:flutter/foundation.dart';

@immutable
final class Cabor {
  const Cabor({
    required this.id,
    required this.code,
    required this.name,
    this.groupName,
    this.logoUrl,
    required this.status,
    required this.statusLabel,
    required this.totalClub,
    required this.totalAthlete,
  });

  final int id;
  final String code;
  final String name;
  final String? groupName;
  final String? logoUrl;
  final int status;
  final String statusLabel;
  final int totalClub;
  final int totalAthlete;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Cabor &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          code == other.code &&
          name == other.name &&
          groupName == other.groupName &&
          logoUrl == other.logoUrl &&
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
    logoUrl,
    status,
    statusLabel,
    totalClub,
    totalAthlete,
  );
}
