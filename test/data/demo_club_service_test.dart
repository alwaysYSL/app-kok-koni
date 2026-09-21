import 'package:flutter_test/flutter_test.dart';
import 'package:kok_app/core/auth/domain/user_principal.dart';
import 'package:kok_app/core/network/api_exceptions.dart';
import 'package:kok_app/data/demo_kok_repository.dart';
import 'package:kok_app/data/models/club.dart';
import 'package:kok_app/data/models/club_detail.dart';
import 'package:kok_app/data/models/paginated_result.dart';
import 'package:kok_app/data/request_cancellation.dart';
import 'package:kok_app/data/services/club_service.dart';
import 'package:kok_app/data/services/demo/demo_club_service.dart';

void main() {
  group('DemoClubService Tests', () {
    late DemoKokRepository demoRepo;
    const scope = AccessScope(
      type: AccessScopeType.district,
      id: '1728',
      name: 'Garut Kota',
    );

    setUp(() {
      demoRepo = DemoKokRepository(simulateLatency: false);
    });

    test('implements ClubService interface', () {
      final service = DemoClubService(
        demoRepo: demoRepo,
        currentScopeProvider: () => scope,
      );
      expect(service, isA<ClubService>());
    });

    group('fetchClubList', () {
      test(
        'returns paginated clubs with default parameters for Garut Kota',
        () async {
          final service = DemoClubService(
            demoRepo: demoRepo,
            currentScopeProvider: () => scope,
          );

          final result = await service.fetchClubList();

          expect(result, isA<PaginatedResult<Club>>());
          // Garut Kota has 5 clubs (Garuda, PB, Silat, Voli, Tirta)
          expect(result.total, equals(5));
          expect(result.limit, equals(25));
          expect(result.offset, equals(0));
          expect(result.items.length, equals(5));
          expect(result.hasMore, isFalse);

          // Check first club properties
          final first = result.items.first;
          expect(first.id, isPositive);
          expect(first.code, isNotEmpty);
          expect(first.name, isNotEmpty);
          expect(first.status, isIn([0, 1]));
          expect(first.statusLabel, isIn(['Aktif', 'Belum Aktif']));
          expect(first.cabor, isNotNull);
          expect(first.cabor.id, isPositive);
          expect(first.cabor.name, isNotEmpty);
          expect(first.secretariat.subdistrictId, equals(1728));
          expect(first.secretariat.subdistrictName, equals('Garut Kota'));
          expect(first.secretariat.districtName, equals('Kabupaten Garut'));

          // Check clubs are sorted alphabetically by name
          for (var i = 0; i < result.items.length - 1; i++) {
            final current = result.items[i].name.toLowerCase();
            final next = result.items[i + 1].name.toLowerCase();
            expect(current.compareTo(next) <= 0, isTrue);
          }
        },
      );

      test('calculates totalAthleteInClub accurately for each club', () async {
        final service = DemoClubService(
          demoRepo: demoRepo,
          currentScopeProvider: () => scope,
        );

        final result = await service.fetchClubList(limit: 10);
        final garuda = result.items.firstWhere(
          (c) => c.name.contains('Garuda'),
        );
        final pb = result.items.firstWhere((c) => c.name.contains('Citra'));
        final silat = result.items.firstWhere((c) => c.name.contains('Silat'));
        final voli = result.items.firstWhere((c) => c.name.contains('Voli'));
        final tirta = result.items.firstWhere((c) => c.name.contains('Tirta'));

        expect(garuda.totalAthleteInClub, equals(34));
        expect(pb.totalAthleteInClub, equals(21));
        expect(silat.totalAthleteInClub, equals(44));
        expect(voli.totalAthleteInClub, equals(18));
        expect(tirta.totalAthleteInClub, equals(8));
      });

      test('supports pagination with custom limit and offset', () async {
        final service = DemoClubService(
          demoRepo: demoRepo,
          currentScopeProvider: () => scope,
        );

        // Page 1
        final page1 = await service.fetchClubList(limit: 2, offset: 0);
        expect(page1.total, equals(5));
        expect(page1.items.length, equals(2));
        expect(page1.hasMore, isTrue);
        expect(page1.nextOffset, equals(2));

        // Page 2
        final page2 = await service.fetchClubList(limit: 2, offset: 2);
        expect(page2.total, equals(5));
        expect(page2.items.length, equals(2));
        expect(page2.hasMore, isTrue);
        expect(page2.nextOffset, equals(4));
        expect(page2.items.first.id, isNot(equals(page1.items.first.id)));

        // Page 3 (last single item)
        final page3 = await service.fetchClubList(limit: 2, offset: 4);
        expect(page3.total, equals(5));
        expect(page3.items.length, equals(1));
        expect(page3.hasMore, isFalse);

        // Out of bounds
        final outOfBounds = await service.fetchClubList(limit: 10, offset: 100);
        expect(outOfBounds.total, equals(5));
        expect(outOfBounds.items, isEmpty);
        expect(outOfBounds.hasMore, isFalse);
      });

      test('filters clubs by idCabor', () async {
        final service = DemoClubService(
          demoRepo: demoRepo,
          currentScopeProvider: () => scope,
        );

        // Garut Kota sports sorted alphabetically:
        // 1: Bola Voli -> Voli Bina Muda
        // 2: Bulu Tangkis -> PB Citra Garut
        // 3: Pencak Silat -> Silat Panglipur
        // 4: Renang -> Tirta Kencana
        // 5: Sepak Bola -> Klub Garuda Muda

        final sepakBolaResult = await service.fetchClubList(idCabor: 5);
        expect(sepakBolaResult.total, equals(1));
        expect(sepakBolaResult.items.first.name, equals('Klub Garuda Muda'));
        expect(sepakBolaResult.items.first.cabor.id, equals(5));
        expect(sepakBolaResult.items.first.cabor.name, equals('SEPAK BOLA'));

        final silatResult = await service.fetchClubList(idCabor: 3);
        expect(silatResult.total, equals(1));
        expect(silatResult.items.first.name, equals('Silat Panglipur'));
        expect(silatResult.items.first.cabor.id, equals(3));
        expect(silatResult.items.first.cabor.name, equals('PENCAK SILAT'));

        final nonExistentCabor = await service.fetchClubList(idCabor: 99);
        expect(nonExistentCabor.total, equals(0));
        expect(nonExistentCabor.items, isEmpty);
      });

      test('filters clubs by status', () async {
        final service = DemoClubService(
          demoRepo: demoRepo,
          currentScopeProvider: () => scope,
        );

        final activeResult = await service.fetchClubList(status: 1);
        final inactiveResult = await service.fetchClubList(status: 0);

        // Tirta Kencana is inactive (active: false)
        expect(activeResult.total, equals(4));
        expect(inactiveResult.total, equals(1));
        expect(inactiveResult.items.first.name, equals('Tirta Kencana'));
        expect(inactiveResult.items.first.status, equals(0));
        expect(inactiveResult.items.first.statusLabel, equals('Belum Aktif'));
      });

      test('filters clubs by search query', () async {
        final service = DemoClubService(
          demoRepo: demoRepo,
          currentScopeProvider: () => scope,
        );

        final searchResult = await service.fetchClubList(search: 'Garuda');
        expect(searchResult.total, equals(1));
        expect(searchResult.items.first.name, equals('Klub Garuda Muda'));

        final noMatchResult = await service.fetchClubList(
          search: 'xyznonexistent',
        );
        expect(noMatchResult.total, equals(0));
        expect(noMatchResult.items, isEmpty);
      });

      test('respects RequestCancellation when cancelled', () async {
        final cancellationController = RequestCancellationController()
          ..cancel('User cancelled club list');

        final service = DemoClubService(
          demoRepo: demoRepo,
          currentScopeProvider: () => scope,
        );

        expect(
          () =>
              service.fetchClubList(cancellation: cancellationController.token),
          throwsA(isA<RequestCancelledException>()),
        );
      });
    });

    group('fetchClubDetail', () {
      test('fetches full club detail by integer ID', () async {
        final service = DemoClubService(
          demoRepo: demoRepo,
          currentScopeProvider: () => scope,
        );

        final list = await service.fetchClubList(search: 'Garuda');
        final garudaClub = list.items.first;

        final detail = await service.fetchClubDetail(garudaClub.id);

        expect(detail, isA<ClubDetail>());
        expect(detail.id, equals(garudaClub.id));
        expect(detail.code, equals(garudaClub.code));
        expect(detail.name, equals('Klub Garuda Muda'));
        expect(detail.phone, equals('081234567890'));
        expect(detail.email, equals('garuda@example.test'));
        expect(
          detail.secretariat.address,
          equals('Jl. Pakuwon No. 10, Kecamatan Garut Kota'),
        );
        expect(detail.totalAthleteInClub, equals(34));
        expect(
          detail.fileSkUrl,
          equals('https://demo.invalid/documents/garuda-sk-klub.pdf'),
        );

        // Verify personnel blocks
        expect(detail.officials.dataAvailable, isTrue);
        expect(detail.officials.items.length, equals(1));
        expect(
          detail.officials.items.first.name,
          contains('Official · Klub Garuda Muda'),
        );

        expect(detail.coaches.dataAvailable, isTrue);
        expect(detail.coaches.items.length, equals(2));
        expect(
          detail.coaches.items.first.name,
          contains('Pelatih 1 · Klub Garuda Muda'),
        );
      });

      test('throws NotFoundException when club id is not found', () async {
        final service = DemoClubService(
          demoRepo: demoRepo,
          currentScopeProvider: () => scope,
        );

        expect(
          () => service.fetchClubDetail(999999),
          throwsA(isA<NotFoundException>()),
        );
      });

      test('respects RequestCancellation when cancelled', () async {
        final cancellationController = RequestCancellationController()
          ..cancel('User cancelled club detail');

        final service = DemoClubService(
          demoRepo: demoRepo,
          currentScopeProvider: () => scope,
        );

        expect(
          () => service.fetchClubDetail(
            1,
            cancellation: cancellationController.token,
          ),
          throwsA(isA<RequestCancelledException>()),
        );
      });
    });
  });
}
