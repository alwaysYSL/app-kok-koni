import '../../../core/auth/domain/user_principal.dart';
import '../../demo_kok_repository.dart';
import '../../models/cabor.dart';
import '../../models/paginated_result.dart';
import '../../request_cancellation.dart';
import '../cabor_service.dart';

final class DemoCaborService implements CaborService {
  DemoCaborService({
    required this.demoRepo,
    required this.currentScopeProvider,
  });

  final DemoKokRepository demoRepo;
  final AccessScope Function() currentScopeProvider;

  @override
  Future<PaginatedResult<Cabor>> fetchCaborList({
    int limit = 25,
    int offset = 0,
    String source = 'all',
    String sort = 'name',
    RequestCancellation? cancellation,
  }) async {
    final scope = currentScopeProvider();
    final snapshot = await demoRepo.fetchScope(
      scope,
      cancellation: cancellation,
    );
    final sports = snapshot.clubs.map((c) => c.sport).toSet().toList()..sort();

    final caborList = <Cabor>[];
    for (var i = 0; i < sports.length; i++) {
      final sportName = sports[i];
      final clubsWithSport =
          snapshot.clubs.where((c) => c.sport == sportName).toList();
      final athletesCount = snapshot.people
          .where(
            (p) =>
                p.role == 'Atlet' &&
                snapshot.clubs.any(
                  (c) => c.id == p.clubId && c.sport == sportName,
                ),
          )
          .length;

      caborList.add(
        Cabor(
          id: i + 1,
          code: 'DEMO-CB-${(i + 1).toString().padLeft(3, '0')}',
          name: sportName.toUpperCase(),
          status: 1,
          statusLabel: 'Aktif',
          totalClub: clubsWithSport.length,
          totalAthlete: athletesCount,
        ),
      );
    }

    final pageItems = caborList.skip(offset).take(limit).toList();
    return PaginatedResult<Cabor>(
      items: pageItems,
      limit: limit,
      offset: offset,
      total: caborList.length,
    );
  }
}
