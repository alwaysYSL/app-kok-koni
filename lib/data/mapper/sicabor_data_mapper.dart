import '../../core/auth/data/dto/sicabor_profile_response.dart';
import '../dto/sicabor_athlete_detail_item.dart';
import '../dto/sicabor_athlete_item.dart';
import '../dto/sicabor_cabor_item.dart';
import '../dto/sicabor_club_detail_item.dart';
import '../dto/sicabor_club_item.dart';
import '../models/athlete.dart';
import '../models/athlete_detail.dart';
import '../models/cabor.dart';
import '../models/club.dart';
import '../models/club_detail.dart';
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

  Club mapClub(SicaborClubItem item) {
    return Club(
      id: item.id,
      code: item.code,
      name: item.name,
      logoUrl: item.logo,
      cabor: _mapClubCabor(item.cabor),
      headName: item.headName,
      phone: item.phone,
      email: item.email,
      since: item.since,
      noSk: item.noSk,
      status: item.status,
      statusLabel: item.statusLabel,
      secretariat: _mapClubAddress(item.secretariat),
      totalAthleteInClub: item.totalAthleteInClub,
    );
  }

  ClubDetail mapClubDetail(SicaborClubDetailItem item) {
    return ClubDetail(
      id: item.id,
      code: item.code,
      name: item.name,
      logoUrl: item.logo,
      cabor: _mapClubCabor(item.cabor),
      headName: item.headName,
      phone: item.phone,
      email: item.email,
      since: item.since,
      noSk: item.noSk,
      status: item.status,
      statusLabel: item.statusLabel,
      secretariat: _mapClubAddress(item.secretariat),
      totalAthleteInClub: item.totalAthleteInClub,
      training: item.training == null ? null : _mapClubAddress(item.training!),
      fileSkUrl: item.fileSk,
      officials: _mapPersonnelBlock(item.officials),
      coaches: _mapPersonnelBlock(item.coaches),
      management: _mapManagementBlock(item.management),
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

ClubCabor _mapClubCabor(Map<String, dynamic> json) {
  return ClubCabor(
    id: _asInt(json['id']),
    code: json['code']?.toString() ?? '',
    name: json['name']?.toString() ?? '',
  );
}

ClubAddress _mapClubAddress(Map<String, dynamic> json) {
  return ClubAddress(
    address: json['address']?.toString(),
    subdistrictId: _asInt(json['subdistrict_id']),
    subdistrictName: json['subdistrict_name']?.toString() ?? '',
    districtId: _asInt(json['district_id']),
    districtName: json['district_name']?.toString() ?? '',
  );
}

ClubPersonnelBlock _mapPersonnelBlock(Map<String, dynamic> json) {
  final rawItems = json['items'] ?? json['data'];
  final itemsList = (rawItems is List)
      ? rawItems
            .whereType<Map>()
            .map((e) => _mapPersonnelItem(Map<String, dynamic>.from(e)))
            .toList()
      : const <ClubPersonnelItem>[];
  return ClubPersonnelBlock(
    dataAvailable: _asBool(json['data_available']),
    reason: json['reason']?.toString(),
    items: itemsList,
  );
}

ClubManagementBlock _mapManagementBlock(Map<String, dynamic> json) {
  final rawItems = json['items'] ?? json['data'];
  final itemsList = (rawItems is List)
      ? rawItems
            .whereType<Map>()
            .map((e) => _mapPersonnelItem(Map<String, dynamic>.from(e)))
            .toList()
      : const <ClubPersonnelItem>[];
  return ClubManagementBlock(
    dataAvailable: _asBool(json['data_available']),
    partial: _asBool(json['partial']),
    source: json['source']?.toString(),
    items: itemsList,
  );
}

ClubPersonnelItem _mapPersonnelItem(Map<String, dynamic> json) {
  return ClubPersonnelItem(
    id: json['id'] != null ? _asNullableInt(json['id']) : null,
    name: json['name']?.toString() ?? '',
    role: json['role']?.toString(),
    phone: json['phone']?.toString(),
    email: json['email']?.toString(),
    photoUrl: json['photo_url']?.toString() ?? json['photo']?.toString(),
    source: json['source']?.toString(),
  );
}

bool _asBool(dynamic value, {bool fallback = false}) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    final lower = value.toLowerCase();
    if (lower == 'true' || lower == '1') return true;
    if (lower == 'false' || lower == '0') return false;
  }
  return fallback;
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
