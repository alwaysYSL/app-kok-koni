import 'package:flutter/foundation.dart';

@immutable
final class SicaborAthleteDetailItem {
  const SicaborAthleteDetailItem({
    required this.id,
    required this.code,
    required this.name,
    required this.sex,
    required this.sexLabel,
    this.pob,
    this.dob,
    this.age,
    required this.photo,
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
  final String photo;
  final int status;
  final String statusLabel;
  final Map<String, dynamic> cabor;
  final Map<String, dynamic>? club;
  final Map<String, dynamic> domicile;
  final String? phone;
  final String? email;
  final int? height;
  final int? weight;
  final String? bloodType;
  final String? address;

  factory SicaborAthleteDetailItem.fromJson(Map<String, dynamic> json) {
    return SicaborAthleteDetailItem(
      id: _asInt(json['id']),
      code: json['code']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      sex: json['sex']?.toString() ?? '',
      sexLabel: json['sex_label']?.toString() ?? '',
      pob: json['pob']?.toString(),
      dob: json['dob']?.toString(),
      age: _asNullableInt(json['age']),
      photo: json['photo']?.toString() ?? '',
      status: _asInt(json['status']),
      statusLabel: json['status_label']?.toString() ?? '',
      cabor: _asMap(json['cabor']),
      club: _asNullableMap(json['club']),
      domicile: _asMap(json['domicile']),
      phone: json['phone']?.toString(),
      email: json['email']?.toString(),
      height: _asNullableInt(json['height']),
      weight: _asNullableInt(json['weight']),
      bloodType: json['blood_type']?.toString(),
      address: json['address']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'code': code,
    'name': name,
    'sex': sex,
    'sex_label': sexLabel,
    'pob': pob,
    'dob': dob,
    'age': age,
    'photo': photo,
    'status': status,
    'status_label': statusLabel,
    'cabor': cabor,
    'club': club,
    'domicile': domicile,
    'phone': phone,
    'email': email,
    'height': height,
    'weight': weight,
    'blood_type': bloodType,
    'address': address,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SicaborAthleteDetailItem &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          code == other.code &&
          name == other.name &&
          sex == other.sex &&
          sexLabel == other.sexLabel &&
          pob == other.pob &&
          dob == other.dob &&
          age == other.age &&
          photo == other.photo &&
          status == other.status &&
          statusLabel == other.statusLabel &&
          mapEquals(cabor, other.cabor) &&
          mapEquals(club, other.club) &&
          mapEquals(domicile, other.domicile) &&
          phone == other.phone &&
          email == other.email &&
          height == other.height &&
          weight == other.weight &&
          bloodType == other.bloodType &&
          address == other.address;

  @override
  int get hashCode => Object.hashAll([
    id,
    code,
    name,
    sex,
    sexLabel,
    pob,
    dob,
    age,
    photo,
    status,
    statusLabel,
    _mapHashCode(cabor),
    club != null ? _mapHashCode(club!) : null,
    _mapHashCode(domicile),
    phone,
    email,
    height,
    weight,
    bloodType,
    address,
  ]);
}

int _asInt(dynamic value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? fallback;
  return fallback;
}

int? _asNullableInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

Map<String, dynamic> _asMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return const <String, dynamic>{};
}

Map<String, dynamic>? _asNullableMap(dynamic value) {
  if (value == null) return null;
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return null;
}

int _mapHashCode(Map<String, dynamic> map) {
  return Object.hashAll(map.entries.map((e) => Object.hash(e.key, e.value)));
}
