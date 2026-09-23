import '../../../core/auth/domain/user_principal.dart';
import '../../../core/network/api_exceptions.dart';
import '../../demo_kok_repository.dart';
import '../../models.dart' as demo;
import '../../models/club.dart';
import '../../models/club_detail.dart';
import '../../models/paginated_result.dart';
import '../../request_cancellation.dart';
import '../club_service.dart';

final class DemoClubService implements ClubService {
  DemoClubService({required this.demoRepo, required this.currentScopeProvider});

  final DemoKokRepository demoRepo;
  final AccessScope Function() currentScopeProvider;

  @override
  Future<PaginatedResult<Club>> fetchClubList({
    int limit = 25,
    int offset = 0,
    int? idCabor,
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
    var clubs = snapshot.clubs.toList();

    // 1. Filter by idCabor
    if (idCabor != null) {
      if (idCabor >= 1 && idCabor <= sports.length) {
        final targetSport = sports[idCabor - 1];
        clubs = clubs
            .where((c) => c.sport.toLowerCase() == targetSport.toLowerCase())
            .toList();
      } else {
        clubs = [];
      }
    }

    // 2. Filter by status
    if (status != null) {
      clubs = clubs.where((c) {
        final clubStatus = c.active ? 1 : 0;
        return clubStatus == status;
      }).toList();
    }

    // 3. Filter by search
    if (search != null && search.trim().isNotEmpty) {
      final query = search.trim().toLowerCase();
      clubs = clubs.where((c) {
        final nameMatch = c.name.toLowerCase().contains(query);
        final sportMatch = c.sport.toLowerCase().contains(query);
        final villageMatch = c.village.toLowerCase().contains(query);
        return nameMatch || sportMatch || villageMatch;
      }).toList();
    }

    // 4. Sort
    if (sort == 'name_desc') {
      clubs.sort(
        (a, b) => b.name.toLowerCase().compareTo(a.name.toLowerCase()),
      );
    } else {
      clubs.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );
    }

    // 5. Map to Club domain model
    final mapped = clubs.map((c) => _mapToClub(c, snapshot, sports)).toList();

    // 6. Pagination
    final pageItems = mapped.skip(offset).take(limit).toList();

    return PaginatedResult<Club>(
      items: pageItems,
      limit: limit,
      offset: offset,
      total: mapped.length,
    );
  }

  @override
  Future<ClubDetail> fetchClubDetail(
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
    for (final club in snapshot.clubs) {
      if (_resolveClubId(club, snapshot) == id || club.id == id.toString()) {
        return _mapToClubDetail(club, snapshot, sports);
      }
    }

    throw const NotFoundException('Data club tidak ditemukan.');
  }

  static int _resolveClubId(demo.Club club, demo.KokSnapshot snapshot) {
    final parsed = int.tryParse(club.id);
    if (parsed != null) return parsed;
    final index = snapshot.clubs.indexOf(club);
    if (index >= 0) return index + 1;
    return club.id.hashCode & 0x7fffffff;
  }

  static Club _mapToClub(
    demo.Club demoClub,
    demo.KokSnapshot snapshot,
    List<String> sports,
  ) {
    final clubId = _resolveClubId(demoClub, snapshot);

    final sportIndex = sports.indexOf(demoClub.sport);
    final caborId = sportIndex >= 0 ? sportIndex + 1 : 1;
    final cabor = ClubCabor(
      id: caborId,
      code: 'DEMO-CB-${caborId.toString().padLeft(3, '0')}',
      name: demoClub.sport.toUpperCase(),
    );

    final athleteCount = snapshot.people
        .where((p) => p.clubId == demoClub.id && p.role == 'Atlet')
        .length;

    final subdistrictId = int.tryParse(snapshot.scope.id) ?? 1728;
    final subdistrictName = snapshot.scope.name.replaceFirst('Kecamatan ', '');

    final secretariat = ClubAddress(
      address: demoClub.address,
      subdistrictId: subdistrictId,
      subdistrictName: subdistrictName,
      districtId: 126,
      districtName: 'Kabupaten Garut',
    );

    final skDoc = demoClub.documents
        .where((d) => d.fileUrl != null && d.fileUrl!.isNotEmpty)
        .firstOrNull;
    final noSk =
        demoClub.registrationNumber ??
        (skDoc != null ? 'SK-${demoClub.id.toUpperCase()}' : null);

    return Club(
      id: clubId,
      code: 'KLUB-${clubId.toString().padLeft(4, '0')}',
      name: demoClub.name,
      logoUrl: demoClub.logoUrl,
      cabor: cabor,
      headName: null,
      phone: demoClub.phone,
      email: demoClub.email,
      since: demoClub.foundedYear?.toString(),
      noSk: noSk,
      status: demoClub.active ? 1 : 0,
      statusLabel: demoClub.active ? 'Aktif' : 'Belum Aktif',
      secretariat: secretariat,
      totalAthleteInClub: athleteCount,
    );
  }

  static ClubDetail _mapToClubDetail(
    demo.Club demoClub,
    demo.KokSnapshot snapshot,
    List<String> sports,
  ) {
    final base = _mapToClub(demoClub, snapshot, sports);

    final clubPeople = snapshot.people
        .where((p) => p.clubId == demoClub.id)
        .toList();
    final demoCoaches = clubPeople.where((p) => p.role == 'Pelatih').toList();
    final demoOfficials = clubPeople
        .where((p) => p.role == 'Official')
        .toList();
    final demoManagement = clubPeople
        .where((p) => p.role == 'Pengurus' || p.role == 'Ketua')
        .toList();

    final coachItems = demoCoaches.map((p) {
      final personId = int.tryParse(p.id);
      return ClubPersonnelItem(
        id: personId,
        name: p.name,
        role: p.group.isNotEmpty ? p.group : p.role,
        photoUrl: p.photoUrl,
        source: 'demo.people',
      );
    }).toList();

    final officialItems = demoOfficials.map((p) {
      final personId = int.tryParse(p.id);
      return ClubPersonnelItem(
        id: personId,
        name: p.name,
        role: p.group.isNotEmpty ? p.group : p.role,
        photoUrl: p.photoUrl,
        source: 'demo.people',
      );
    }).toList();

    final managementItems = demoManagement.map((p) {
      final personId = int.tryParse(p.id);
      return ClubPersonnelItem(
        id: personId,
        name: p.name,
        role: p.group.isNotEmpty ? p.group : p.role,
        photoUrl: p.photoUrl,
        source: 'demo.people',
      );
    }).toList();

    final coachesBlock = ClubPersonnelBlock(
      dataAvailable: coachItems.isNotEmpty,
      reason: coachItems.isEmpty ? 'NOT_RECORDED_IN_SYSTEM' : null,
      items: coachItems,
    );

    final officialsBlock = ClubPersonnelBlock(
      dataAvailable: officialItems.isNotEmpty,
      reason: officialItems.isEmpty ? 'NOT_RECORDED_IN_SYSTEM' : null,
      items: officialItems,
    );

    final ClubManagementBlock managementBlock;
    if (managementItems.isNotEmpty) {
      managementBlock = ClubManagementBlock(
        dataAvailable: true,
        partial: false,
        source: 'demo.people',
        items: managementItems,
      );
    } else if (base.headName != null) {
      managementBlock = ClubManagementBlock(
        dataAvailable: true,
        partial: true,
        source: 'club.head_name',
        items: [
          ClubPersonnelItem(
            id: null,
            name: base.headName!,
            role: 'Ketua',
            phone: base.phone,
            email: base.email,
            source: 'club.head_name',
          ),
        ],
      );
    } else {
      managementBlock = const ClubManagementBlock(
        dataAvailable: false,
        partial: false,
        items: [],
      );
    }

    final skDoc = demoClub.documents
        .where((d) => d.fileUrl != null && d.fileUrl!.isNotEmpty)
        .firstOrNull;

    return ClubDetail(
      id: base.id,
      code: base.code,
      name: base.name,
      logoUrl: base.logoUrl,
      cabor: base.cabor,
      headName: base.headName,
      phone: base.phone,
      email: base.email,
      since: base.since,
      noSk: base.noSk,
      status: base.status,
      statusLabel: base.statusLabel,
      secretariat: base.secretariat,
      totalAthleteInClub: base.totalAthleteInClub,
      training: null,
      fileSkUrl: skDoc?.fileUrl,
      officials: officialsBlock,
      coaches: coachesBlock,
      management: managementBlock,
    );
  }
}
