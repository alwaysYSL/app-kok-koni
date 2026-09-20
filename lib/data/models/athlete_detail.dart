import 'package:flutter/foundation.dart';

import 'athlete.dart';

@immutable
final class AthleteDetail {
  const AthleteDetail({
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
    this.phone,
    this.email,
    this.height,
    this.weight,
    this.bloodType,
    this.address,
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
  final String? phone;
  final String? email;
  final int? height;
  final int? weight;
  final String? bloodType;
  final String? address;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AthleteDetail &&
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
          domicile == other.domicile &&
          phone == other.phone &&
          email == other.email &&
          height == other.height &&
          weight == other.weight &&
          bloodType == other.bloodType &&
          address == other.address;

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
    phone,
    email,
    height,
    weight,
    bloodType,
    address,
  );
}
