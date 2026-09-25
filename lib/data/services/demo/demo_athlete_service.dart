import '../../../core/auth/domain/user_principal.dart';
import '../../../core/network/api_exceptions.dart';
import '../../demo_kok_repository.dart';
import '../../models.dart';
import '../../models/athlete.dart';
import '../../models/athlete_detail.dart';
import '../../models/paginated_result.dart';
import '../../request_cancellation.dart';
import '../athlete_service.dart';

final class DemoAthleteService implements AthleteService {
  DemoAthleteService({
    required this.demoRepo,
    required this.currentScopeProvider,
  });

  final DemoKokRepository demoRepo;
  final AccessScope Function() currentScopeProvider;

  @override
  Future<PaginatedResult<Athlete>> fetchAthleteList({
    int limit = 25,
    int offset = 0,
    int? idCabor,
    int? idClub,
    String? sex,
    int? status,
    String? search,
    String sort = 'name',
    RequestCancellation? cancellation,
  }) async {
    cancellation?.throwIfCancelled();
    final scope = currentScopeProvider();
    final snapshot = await demoRepo.fetchScope(
      scope,
      cancellation: cancellation,
    );
    cancellation?.throwIfCancelled();

    final sports = snapshot.clubs.map((c) => c.sport).toSet().toList()..sort();
    var athletes = snapshot.people.where((p) => p.role == 'Atlet').toList();

    // 1. Filter by idCabor
    if (idCabor != null) {
      if (idCabor >= 1 && idCabor <= sports.length) {
        final targetSport = sports[idCabor - 1];
        athletes = athletes.where((p) {
          final club = _findClub(snapshot.clubs, p.clubId);
          return club != null && club.sport == targetSport;
        }).toList();
      } else {
        athletes = [];
      }
    }

    // 2. Filter by idClub
    if (idClub != null) {
      athletes = athletes.where((p) {
        final club = _findClub(snapshot.clubs, p.clubId);
        if (club == null) return false;
        final clubId =
            int.tryParse(club.id) ?? (snapshot.clubs.indexOf(club) + 1);
        return clubId == idClub;
      }).toList();
    }

    // 3. Filter by search
    if (search != null && search.trim().isNotEmpty) {
      final query = search.trim().toLowerCase();
      athletes = athletes
          .where((p) => p.name.toLowerCase().contains(query))
          .toList();
    }

    // 4. Filter by sex
    if (sex != null && sex.trim().isNotEmpty) {
      final normalizedSex = sex.trim().toLowerCase();
      athletes = athletes
          .where((p) => p.gender?.toLowerCase() == normalizedSex)
          .toList();
    }

    // 5. Filter by status
    if (status != null) {
      athletes = athletes.where((p) {
        final pStatus = p.verified ? 1 : 0;
        return pStatus == status;
      }).toList();
    }

    // 6. Sort
    athletes.sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );

    // 7. Map to Athlete domain model
    final mapped = athletes
        .map((p) => _mapToAthlete(p, snapshot, sports))
        .toList();

    // 8. Pagination
    final pageItems = mapped.skip(offset).take(limit).toList();

    return PaginatedResult<Athlete>(
      items: pageItems,
      limit: limit,
      offset: offset,
      total: mapped.length,
    );
  }

  @override
  Future<AthleteDetail> fetchAthleteDetail(
    int id, {
    RequestCancellation? cancellation,
  }) async {
    cancellation?.throwIfCancelled();
    final scope = currentScopeProvider();
    final snapshot = await demoRepo.fetchScope(
      scope,
      cancellation: cancellation,
    );
    cancellation?.throwIfCancelled();

    final sports = snapshot.clubs.map((c) => c.sport).toSet().toList()..sort();

    // Check in current scope's snapshot
    for (final person in snapshot.people) {
      if (resolvePersonId(person) == id || person.id == id.toString()) {
        return _mapToAthleteDetail(person, snapshot, sports);
      }
    }

    throw const NotFoundException('Data atlet tidak ditemukan.');
  }

  static Club? _findClub(List<Club> clubs, String clubId) {
    for (final club in clubs) {
      if (club.id == clubId) return club;
    }
    return null;
  }

  static int resolvePersonId(SportPerson person) {
    final parsed = int.tryParse(person.id);
    if (parsed != null) return parsed;
    if (person.id.startsWith('ATL-')) {
      final parsedAtl = int.tryParse(person.id.substring(4));
      if (parsedAtl != null) return parsedAtl;
    }
    return person.id.hashCode & 0x7fffffff;
  }

  static Athlete _mapToAthlete(
    SportPerson person,
    KokSnapshot snapshot,
    List<String> sports,
  ) {
    final personId = resolvePersonId(person);
    final club = _findClub(snapshot.clubs, person.clubId);

    final AthleteCabor athleteCabor;
    if (club != null) {
      final sportIndex = sports.indexOf(club.sport);
      final caborId = sportIndex >= 0 ? sportIndex + 1 : 1;
      athleteCabor = AthleteCabor(
        id: caborId,
        code: 'DEMO-CB-${caborId.toString().padLeft(3, '0')}',
        name: club.sport.toUpperCase(),
      );
    } else {
      athleteCabor = const AthleteCabor(
        id: 0,
        code: 'DEMO-CB-000',
        name: 'UMUM',
      );
    }

    final AthleteClub? athleteClub;
    if (club != null) {
      final clubIndex = snapshot.clubs.indexOf(club);
      final clubId = int.tryParse(club.id) ?? (clubIndex + 1);
      athleteClub = AthleteClub(
        id: clubId,
        code: 'KLUB-${clubId.toString().padLeft(4, '0')}',
        name: club.name,
      );
    } else {
      athleteClub = null;
    }

    final isMale =
        person.gender == null || person.gender!.toLowerCase().startsWith('l');
    final sex = isMale ? 'l' : 'p';
    final sexLabel = isMale ? 'Laki-Laki' : 'Perempuan';

    final dob = person.birthDate != null
        ? '${person.birthDate!.year.toString().padLeft(4, '0')}-${person.birthDate!.month.toString().padLeft(2, '0')}-${person.birthDate!.day.toString().padLeft(2, '0')}'
        : null;

    final photo = (person.photoUrl != null && person.photoUrl!.isNotEmpty)
        ? person.photoUrl!
        : 'https://sicabor.test/photos/default.png';

    final subdistrictId = int.tryParse(snapshot.scope.id) ?? 1728;
    final subdistrictName = snapshot.scope.name.replaceFirst('Kecamatan ', '');

    final domicile = AthleteDomicile(
      subdistrictId: subdistrictId,
      subdistrictName: subdistrictName,
      districtId: 126,
      districtName: 'Kabupaten Garut',
      village: club?.village,
    );

    return Athlete(
      id: personId,
      code: 'DEMO-AT-${personId.toString().padLeft(6, '0')}',
      name: person.name,
      sex: sex,
      sexLabel: sexLabel,
      pob: person.birthPlace,
      dob: dob,
      age: person.age,
      photoUrl: photo,
      status: person.verified ? 1 : 0,
      statusLabel: person.verified ? 'Aktif' : 'Belum Aktif',
      cabor: athleteCabor,
      club: athleteClub,
      domicile: domicile,
    );
  }

  static AthleteDetail _mapToAthleteDetail(
    SportPerson person,
    KokSnapshot snapshot,
    List<String> sports,
  ) {
    final athlete = _mapToAthlete(person, snapshot, sports);
    final club = _findClub(snapshot.clubs, person.clubId);

    return AthleteDetail(
      id: athlete.id,
      code: athlete.code,
      name: athlete.name,
      sex: athlete.sex,
      sexLabel: athlete.sexLabel,
      pob: athlete.pob,
      dob: athlete.dob,
      age: athlete.age,
      photoUrl: athlete.photoUrl,
      status: athlete.status,
      statusLabel: athlete.statusLabel,
      cabor: athlete.cabor,
      club: athlete.club,
      domicile: athlete.domicile,
      phone: club?.phone,
      email: club?.email,
      address: person.address ?? club?.address,
    );
  }
}
