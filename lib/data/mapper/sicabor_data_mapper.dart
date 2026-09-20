import '../../core/auth/data/dto/sicabor_profile_response.dart';
import '../dto/sicabor_cabor_item.dart';
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
}
