import '../../../core/auth/data/dto/sicabor_profile_response.dart';
import '../../../core/auth/domain/user_principal.dart';
import '../../demo_kok_repository.dart';
import '../../models/profile_summary.dart';
import '../../request_cancellation.dart';
import '../profile_service.dart';

final class DemoProfileService implements ProfileService {
  DemoProfileService({
    required this.demoRepo,
    required this.currentScopeProvider,
  });

  final DemoKokRepository demoRepo;
  final AccessScope Function() currentScopeProvider;

  @override
  Future<ProfileSummary> fetchProfileSummary({
    RequestCancellation? cancellation,
  }) async {
    final scope = currentScopeProvider();
    final snapshot = await demoRepo.fetchScope(
      scope,
      cancellation: cancellation,
    );
    final athletes = snapshot.people.where((p) => p.role == 'Atlet').toList();
    final sports = snapshot.clubs.map((c) => c.sport).toSet();

    return ProfileSummary(
      scope: SicaborScope(
        subdistrictId: int.tryParse(scope.id) ?? 1728,
        subdistrictName: scope.name.replaceFirst('Kecamatan ', ''),
        districtId: 126,
        districtName: 'Kabupaten Garut',
      ),
      member: const SicaborMember(
        id: 578,
        username: 'kt.garutkota',
        name: 'ADMIN KONTINGEN GARUT KOTA',
        type: 'admin_kok',
        status: 1,
        statusLabel: 'Aktif',
      ),
      kontingen: SicaborKontingen(
        id: 1,
        code: 'KGPK-0001',
        name: scope.name,
      ),
      totalCabor: sports.length,
      totalCaborFromClub: sports.length,
      totalCaborFromAthlete: sports.length,
      totalClub: snapshot.clubs.length,
      totalAthlete: athletes.length,
      totalAthleteWithoutClub: 0,
      dataNotes: const ['Mode Demo: Menampilkan dataset simulasi lokal KOK.'],
    );
  }
}
