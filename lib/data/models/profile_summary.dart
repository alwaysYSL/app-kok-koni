import 'package:flutter/foundation.dart';

import '../../core/auth/data/dto/sicabor_profile_response.dart';

@immutable
final class ProfileSummary {
  const ProfileSummary({
    required this.scope,
    required this.member,
    this.kontingen,
    required this.totalCabor,
    required this.totalCaborFromClub,
    required this.totalCaborFromAthlete,
    required this.totalClub,
    required this.totalAthlete,
    required this.totalAthleteWithoutClub,
    this.dataNotes = const [],
  });

  final SicaborScope scope;
  final SicaborMember member;
  final SicaborKontingen? kontingen;
  final int totalCabor;
  final int totalCaborFromClub;
  final int totalCaborFromAthlete;
  final int totalClub;
  final int totalAthlete;
  final int totalAthleteWithoutClub;
  final List<String> dataNotes;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProfileSummary &&
          runtimeType == other.runtimeType &&
          scope == other.scope &&
          member == other.member &&
          kontingen == other.kontingen &&
          totalCabor == other.totalCabor &&
          totalCaborFromClub == other.totalCaborFromClub &&
          totalCaborFromAthlete == other.totalCaborFromAthlete &&
          totalClub == other.totalClub &&
          totalAthlete == other.totalAthlete &&
          totalAthleteWithoutClub == other.totalAthleteWithoutClub &&
          listEquals(dataNotes, other.dataNotes);

  @override
  int get hashCode => Object.hash(
        scope,
        member,
        kontingen,
        totalCabor,
        totalCaborFromClub,
        totalCaborFromAthlete,
        totalClub,
        totalAthlete,
        totalAthleteWithoutClub,
        Object.hashAll(dataNotes),
      );
}
