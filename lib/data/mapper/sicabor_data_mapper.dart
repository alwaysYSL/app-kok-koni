import '../../core/auth/data/dto/sicabor_profile_response.dart';
import '../dto/sicabor_athlete_detail_item.dart';
import '../dto/sicabor_athlete_item.dart';
import '../dto/sicabor_cabor_item.dart';
import '../models/athlete.dart';
import '../models/athlete_detail.dart';
import '../models/cabor.dart';
import '../models/profile_summary.dart';

class SicaborDataMapper {
  const SicaborDataMapper();

  Cabor mapCabor(SicaborCaborItem item) {
    return Cabor(
      id: item.id,
      code: item.code,
      name: item.name,
      groupName: item.groupName,
      logoUrl: item.logo,
      status: item.status,
      statusLabel: item.statusLabel,
      totalClub: item.totalClub,
      totalAthlete: item.totalAthlete,
    );
  }

  ProfileSummary mapProfileSummary(SicaborProfileResponse response) {
    return ProfileSummary(
      scope: response.scope,
      member: response.data.member,
      kontingen: response.data.kontingen,
      totalCabor: response.data.summary.totalCabor,
      totalCaborFromClub: response.data.summary.totalCaborFromClub,
      totalCaborFromAthlete: response.data.summary.totalCaborFromAthlete,
      totalClub: response.data.summary.totalClub,
      totalAthlete: response.data.summary.totalAthlete,
      totalAthleteWithoutClub: response.data.summary.totalAthleteWithoutClub,
      dataNotes: response.data.dataNotes,
    );
  }

  Athlete mapAthlete(SicaborAthleteItem item) {
    return Athlete(
      id: item.id,
      code: item.code,
      name: item.name,
      sex: item.sex,
      sexLabel: item.sexLabel,
      pob: item.pob,
      dob: item.dob,
      age: item.age,
      photoUrl: item.photo,
      status: item.status,
      statusLabel: item.statusLabel,
      cabor: _mapAthleteCabor(item.cabor),
      club: item.club == null ? null : _mapAthleteClub(item.club!),
      domicile: _mapAthleteDomicile(item.domicile),
    );
  }

  AthleteDetail mapAthleteDetail(SicaborAthleteDetailItem item) {
    return AthleteDetail(
      id: item.id,
      code: item.code,
      name: item.name,
      sex: item.sex,
      sexLabel: item.sexLabel,
      pob: item.pob,
      dob: item.dob,
      age: item.age,
      photoUrl: item.photo,
      status: item.status,
      statusLabel: item.statusLabel,
      cabor: _mapAthleteCabor(item.cabor),
      club: item.club == null ? null : _mapAthleteClub(item.club!),
      domicile: _mapAthleteDomicile(item.domicile),
      phone: item.phone,
      email: item.email,
      height: item.height,
      weight: item.weight,
      bloodType: item.bloodType,
      address: item.address,
    );
  }
}

AthleteCabor _mapAthleteCabor(Map<String, dynamic> json) {
  return AthleteCabor(
    id: _asInt(json['id']),
    code: json['code']?.toString() ?? '',
    name: json['name']?.toString() ?? '',
  );
}

AthleteClub _mapAthleteClub(Map<String, dynamic> json) {
  return AthleteClub(
    id: _asInt(json['id']),
    code: json['code']?.toString() ?? '',
    name: json['name']?.toString() ?? '',
  );
}

AthleteDomicile _mapAthleteDomicile(Map<String, dynamic> json) {
  return AthleteDomicile(
    subdistrictId: _asInt(json['subdistrict_id']),
    subdistrictName: json['subdistrict_name']?.toString() ?? '',
    districtId: _asInt(json['district_id']),
    districtName: json['district_name']?.toString() ?? '',
    village: json['village']?.toString(),
  );
}

int _asInt(dynamic value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? fallback;
  return fallback;
}
