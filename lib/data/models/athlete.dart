import 'package:flutter/foundation.dart';

@immutable
final class AthleteCabor {
  const AthleteCabor({
    required this.id,
    required this.code,
    required this.name,
  });

  final int id;
  final String code;
  final String name;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AthleteCabor &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          code == other.code &&
          name == other.name;

  @override
  int get hashCode => Object.hash(id, code, name);
}

@immutable
final class AthleteClub {
  const AthleteClub({required this.id, required this.code, required this.name});

  final int id;
  final String code;
  final String name;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AthleteClub &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          code == other.code &&
          name == other.name;

  @override
  int get hashCode => Object.hash(id, code, name);
}

@immutable
final class AthleteDomicile {
  const AthleteDomicile({
    required this.subdistrictId,
    required this.subdistrictName,
    required this.districtId,
    required this.districtName,
    this.village,
  });

  final int subdistrictId;
  final String subdistrictName;
  final int districtId;
  final String districtName;
  final String? village;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AthleteDomicile &&
          runtimeType == other.runtimeType &&
          subdistrictId == other.subdistrictId &&
          subdistrictName == other.subdistrictName &&
          districtId == other.districtId &&
          districtName == other.districtName &&
          village == other.village;

  @override
  int get hashCode => Object.hash(
    subdistrictId,
    subdistrictName,
    districtId,
    districtName,
    village,
  );
}

@immutable
final class Athlete {
  const Athlete({
    required this.id,
    required this.code,
    required this.name,
    required this.sex,
    required this.sexLabel,
    this.pob,
    this.dob,
    this.age,
    required this.photoUrl,
    required this.status,
    required this.statusLabel,
    required this.cabor,
    this.club,
    required this.domicile,
  });

  final int id;
  final String code;
  final String name;
  final String sex;
  final String sexLabel;
  final String? pob;
  final String? dob;
  final int? age;
  final String photoUrl;
  final int status;
  final String statusLabel;
  final AthleteCabor cabor;
  final AthleteClub? club;
  final AthleteDomicile domicile;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Athlete &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          code == other.code &&
          name == other.name &&
          sex == other.sex &&
          sexLabel == other.sexLabel &&
          pob == other.pob &&
          dob == other.dob &&
          age == other.age &&
          photoUrl == other.photoUrl &&
          status == other.status &&
          statusLabel == other.statusLabel &&
          cabor == other.cabor &&
          club == other.club &&
          domicile == other.domicile;

  @override
  int get hashCode => Object.hash(
    id,
    code,
    name,
    sex,
    sexLabel,
    pob,
    dob,
    age,
    photoUrl,
    status,
    statusLabel,
    cabor,
    club,
    domicile,
  );
}
