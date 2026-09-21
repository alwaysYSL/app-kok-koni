import 'package:flutter/foundation.dart';

@immutable
final class ClubCabor {
  const ClubCabor({required this.id, required this.code, required this.name});

  final int id;
  final String code;
  final String name;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ClubCabor &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          code == other.code &&
          name == other.name;

  @override
  int get hashCode => Object.hash(id, code, name);
}

@immutable
final class ClubAddress {
  const ClubAddress({
    this.address,
    required this.subdistrictId,
    required this.subdistrictName,
    required this.districtId,
    required this.districtName,
  });

  final String? address;
  final int subdistrictId;
  final String subdistrictName;
  final int districtId;
  final String districtName;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ClubAddress &&
          runtimeType == other.runtimeType &&
          address == other.address &&
          subdistrictId == other.subdistrictId &&
          subdistrictName == other.subdistrictName &&
          districtId == other.districtId &&
          districtName == other.districtName;

  @override
  int get hashCode => Object.hash(
    address,
    subdistrictId,
    subdistrictName,
    districtId,
    districtName,
  );
}

@immutable
final class Club {
  const Club({
    required this.id,
    required this.code,
    required this.name,
    this.logoUrl,
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
  final String? logoUrl;
  final ClubCabor cabor;
  final String? headName;
  final String? phone;
  final String? email;
  final String? since;
  final String? noSk;
  final int status;
  final String statusLabel;
  final ClubAddress secretariat;
  final int totalAthleteInClub;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Club &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          code == other.code &&
          name == other.name &&
          logoUrl == other.logoUrl &&
          cabor == other.cabor &&
          headName == other.headName &&
          phone == other.phone &&
          email == other.email &&
          since == other.since &&
          noSk == other.noSk &&
          status == other.status &&
          statusLabel == other.statusLabel &&
          secretariat == other.secretariat &&
          totalAthleteInClub == other.totalAthleteInClub;

  @override
  int get hashCode => Object.hash(
    id,
    code,
    name,
    logoUrl,
    cabor,
    headName,
    phone,
    email,
    since,
    noSk,
    status,
    statusLabel,
    secretariat,
    totalAthleteInClub,
  );
}
