import 'package:flutter_test/flutter_test.dart';
import 'package:kok_app/core/auth/domain/user_principal.dart';
import 'package:kok_app/core/network/api_exceptions.dart';
import 'package:kok_app/data/demo_kok_repository.dart';
import 'package:kok_app/data/models/athlete.dart';
import 'package:kok_app/data/models/athlete_detail.dart';
import 'package:kok_app/data/models/paginated_result.dart';
import 'package:kok_app/data/request_cancellation.dart';
import 'package:kok_app/data/services/athlete_service.dart';
import 'package:kok_app/data/services/demo/demo_athlete_service.dart';

void main() {
  group('DemoAthleteService Tests', () {
    late DemoKokRepository demoRepo;
    const scope = AccessScope(
      type: AccessScopeType.district,
      id: '1728',
      name: 'Garut Kota',
    );

    setUp(() {
      demoRepo = DemoKokRepository(simulateLatency: false);
    });

    test('implements AthleteService interface', () {
      final service = DemoAthleteService(
        demoRepo: demoRepo,
        currentScopeProvider: () => scope,
      );
      expect(service, isA<AthleteService>());
    });

    group('fetchAthleteList', () {
      test(
        'returns paginated athletes with default parameters for Garut Kota',
        () async {
          final service = DemoAthleteService(
            demoRepo: demoRepo,
            currentScopeProvider: () => scope,
          );

          final result = await service.fetchAthleteList();

          expect(result, isA<PaginatedResult<Athlete>>());
          // Garut Kota has 34 + 21 + 44 + 18 + 8 = 125 athletes
          expect(result.total, equals(125));
          expect(result.limit, equals(25));
          expect(result.offset, equals(0));
          expect(result.items.length, equals(25));
          expect(result.hasMore, isTrue);
          expect(result.nextOffset, equals(25));
          expect(result.hasFilterWarning, isFalse);

          final first = result.items.first;
          expect(first.id, isPositive);
          expect(first.code, isNotEmpty);
          expect(first.name, isNotEmpty);
          expect(first.sex, isIn(['l', 'p']));
          expect(first.sexLabel, isIn(['Laki-Laki', 'Perempuan']));
          expect(first.status, isIn([0, 1]));
          expect(first.statusLabel, isIn(['Aktif', 'Belum Aktif']));
          expect(first.cabor, isNotNull);
          expect(first.cabor.id, isPositive);
          expect(first.cabor.name, isNotEmpty);
          expect(first.domicile.subdistrictId, equals(1728));
          expect(first.domicile.subdistrictName, equals('Garut Kota'));
          expect(first.domicile.districtName, equals('Kabupaten Garut'));

          // Check athletes are sorted alphabetically by name
          for (var i = 0; i < result.items.length - 1; i++) {
            final current = result.items[i].name.toLowerCase();
            final next = result.items[i + 1].name.toLowerCase();
            expect(current.compareTo(next) <= 0, isTrue);
          }
        },
      );

      test('supports pagination with custom limit and offset', () async {
        final service = DemoAthleteService(
          demoRepo: demoRepo,
          currentScopeProvider: () => scope,
        );

        // Page 1
        final page1 = await service.fetchAthleteList(limit: 10, offset: 0);
        expect(page1.total, equals(125));
        expect(page1.items.length, equals(10));
        expect(page1.hasMore, isTrue);
        expect(page1.nextOffset, equals(10));

        // Page 2
        final page2 = await service.fetchAthleteList(limit: 10, offset: 10);
        expect(page2.total, equals(125));
        expect(page2.items.length, equals(10));
        expect(page2.hasMore, isTrue);
        expect(page2.nextOffset, equals(20));
        expect(page2.items.first.id, isNot(equals(page1.items.first.id)));

        // Out of bounds
        final outOfBounds = await service.fetchAthleteList(
          limit: 10,
          offset: 200,
        );
        expect(outOfBounds.total, equals(125));
        expect(outOfBounds.items, isEmpty);
        expect(outOfBounds.hasMore, isFalse);
      });

      test('filters athletes by idCabor', () async {
        final service = DemoAthleteService(
          demoRepo: demoRepo,
          currentScopeProvider: () => scope,
        );

        // Garut Kota sports sorted alphabetically:
        // 1: Bola Voli (18 athletes)
        // 2: Bulu Tangkis (21 athletes)
        // 3: Pencak Silat (44 athletes)
        // 4: Renang (8 athletes)
        // 5: Sepak Bola (34 athletes)

        final voliResult = await service.fetchAthleteList(
          idCabor: 1,
          limit: 50,
        );
        expect(voliResult.total, equals(18));
        expect(voliResult.items.length, equals(18));
        for (final athlete in voliResult.items) {
          expect(athlete.cabor.id, equals(1));
          expect(athlete.cabor.name, equals('BOLA VOLI'));
        }

        final silatResult = await service.fetchAthleteList(
          idCabor: 3,
          limit: 50,
        );
        expect(silatResult.total, equals(44));
        expect(silatResult.items.length, equals(44));
        for (final athlete in silatResult.items) {
          expect(athlete.cabor.id, equals(3));
          expect(athlete.cabor.name, equals('PENCAK SILAT'));
        }

        final nonExistentCabor = await service.fetchAthleteList(idCabor: 99);
        expect(nonExistentCabor.total, equals(0));
        expect(nonExistentCabor.items, isEmpty);
      });

      test('filters athletes by search query', () async {
        final service = DemoAthleteService(
          demoRepo: demoRepo,
          currentScopeProvider: () => scope,
        );

        final searchResult = await service.fetchAthleteList(
          search: 'Garuda',
          limit: 50,
        );
        expect(searchResult.total, equals(34));
        for (final athlete in searchResult.items) {
          expect(athlete.name.toLowerCase(), contains('garuda'));
        }

        final noMatchResult = await service.fetchAthleteList(
          search: 'xyznonexistent',
        );
        expect(noMatchResult.total, equals(0));
        expect(noMatchResult.items, isEmpty);
      });

      test('filters athletes by sex', () async {
        final service = DemoAthleteService(
          demoRepo: demoRepo,
          currentScopeProvider: () => scope,
        );

        final maleResult = await service.fetchAthleteList(sex: 'l', limit: 100);
        expect(maleResult.total, isPositive);
        for (final athlete in maleResult.items) {
          expect(athlete.sex, equals('l'));
          expect(athlete.sexLabel, equals('Laki-Laki'));
        }

        final femaleResult = await service.fetchAthleteList(
          sex: 'p',
          limit: 100,
        );
        expect(femaleResult.total, isPositive);
        for (final athlete in femaleResult.items) {
          expect(athlete.sex, equals('p'));
          expect(athlete.sexLabel, equals('Perempuan'));
        }

        expect(maleResult.total + femaleResult.total, equals(125));
      });

      test('filters athletes by idClub', () async {
        final service = DemoAthleteService(
          demoRepo: demoRepo,
          currentScopeProvider: () => scope,
        );

        // Club 1 is Garuda Muda (34 athletes)
        final club1Result = await service.fetchAthleteList(
          idClub: 1,
          limit: 50,
        );
        expect(club1Result.total, equals(34));
        for (final athlete in club1Result.items) {
          expect(athlete.club?.id, equals(1));
          expect(athlete.club?.name, equals('Klub Garuda Muda'));
        }
      });

      test('filters athletes by status', () async {
        final service = DemoAthleteService(
          demoRepo: demoRepo,
          currentScopeProvider: () => scope,
        );

        final activeResult = await service.fetchAthleteList(
          status: 1,
          limit: 200,
        );
        final inactiveResult = await service.fetchAthleteList(
          status: 0,
          limit: 200,
        );

        // In Garut Kota demo data, first 8 athletes of Garuda are unverified (missingDocuments)
        expect(inactiveResult.total, equals(8));
        expect(activeResult.total, equals(125 - 8));
        expect(activeResult.total + inactiveResult.total, equals(125));
      });

      test('respects RequestCancellation when cancelled', () async {
        final cancellationController = RequestCancellationController()
          ..cancel('User cancelled athlete list');

        final service = DemoAthleteService(
          demoRepo: demoRepo,
          currentScopeProvider: () => scope,
        );

        expect(
          () => service.fetchAthleteList(
            cancellation: cancellationController.token,
          ),
          throwsA(isA<RequestCancelledException>()),
        );
      });
    });

    group('fetchAthleteDetail', () {
      test('fetches full athlete detail by integer ID', () async {
        final service = DemoAthleteService(
          demoRepo: demoRepo,
          currentScopeProvider: () => scope,
        );

        final list = await service.fetchAthleteList(limit: 5);
        final firstAthlete = list.items.first;

        final detail = await service.fetchAthleteDetail(firstAthlete.id);

        expect(detail, isA<AthleteDetail>());
        expect(detail.id, equals(firstAthlete.id));
        expect(detail.code, equals(firstAthlete.code));
        expect(detail.name, equals(firstAthlete.name));
        expect(detail.sex, equals(firstAthlete.sex));
        expect(detail.sexLabel, equals(firstAthlete.sexLabel));
        expect(detail.status, equals(firstAthlete.status));
        expect(detail.statusLabel, equals(firstAthlete.statusLabel));
        expect(detail.cabor, equals(firstAthlete.cabor));
        expect(detail.club, equals(firstAthlete.club));
        expect(detail.domicile, equals(firstAthlete.domicile));
      });

      test(
        'fetches athlete detail for specific known demo person (Garuda atlet 0)',
        () async {
          final service = DemoAthleteService(
            demoRepo: demoRepo,
            currentScopeProvider: () => scope,
          );

          // Fetch garuda atlet 0 via list
          final list = await service.fetchAthleteList(
            search: 'Atlet 1 · Garuda',
            limit: 1,
          );
          expect(list.items, isNotEmpty);
          final garuda0 = list.items.first;

          final detail = await service.fetchAthleteDetail(garuda0.id);

          expect(detail.name, equals('Atlet 1 · Garuda Muda'));
          expect(detail.pob, equals('Garut'));
          expect(detail.dob, equals('2008-05-01'));
          expect(detail.address, equals('Jl. Cikuray No. 5, Garut'));
          expect(detail.phone, equals('081234567890'));
          expect(detail.email, equals('garuda@example.test'));
        },
      );

      test('throws NotFoundException when athlete id is not found', () async {
        final service = DemoAthleteService(
          demoRepo: demoRepo,
          currentScopeProvider: () => scope,
        );

        expect(
          () => service.fetchAthleteDetail(999999),
          throwsA(isA<NotFoundException>()),
        );
      });

      test('respects RequestCancellation when cancelled', () async {
        final cancellationController = RequestCancellationController()
          ..cancel('User cancelled athlete detail');

        final service = DemoAthleteService(
          demoRepo: demoRepo,
          currentScopeProvider: () => scope,
        );

        expect(
          () => service.fetchAthleteDetail(
            123,
            cancellation: cancellationController.token,
          ),
          throwsA(isA<RequestCancelledException>()),
        );
      });
    });
  });
}
