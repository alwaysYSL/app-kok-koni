import 'package:flutter_test/flutter_test.dart';
import 'package:kok_app/core/auth/domain/user_principal.dart';
import 'package:kok_app/data/demo_kok_repository.dart';
import 'package:kok_app/data/models/cabor.dart';
import 'package:kok_app/data/models/paginated_result.dart';
import 'package:kok_app/data/models/profile_summary.dart';
import 'package:kok_app/data/request_cancellation.dart';
import 'package:kok_app/data/services/cabor_service.dart';
import 'package:kok_app/data/services/demo/demo_cabor_service.dart';
import 'package:kok_app/data/services/demo/demo_profile_service.dart';
import 'package:kok_app/data/services/profile_service.dart';

void main() {
  group('Demo Services Tests', () {
    late DemoKokRepository demoRepo;
    const scope = AccessScope(
      type: AccessScopeType.district,
      id: '1728',
      name: 'Garut Kota',
    );

    setUp(() {
      demoRepo = DemoKokRepository(simulateLatency: false);
    });

    group('DemoProfileService', () {
      test('implements ProfileService interface', () {
        final service = DemoProfileService(
          demoRepo: demoRepo,
          currentScopeProvider: () => scope,
        );
        expect(service, isA<ProfileService>());
      });

      test('adapts snapshot into ProfileSummary for Garut Kota', () async {
        final service = DemoProfileService(
          demoRepo: demoRepo,
          currentScopeProvider: () => scope,
        );

        final summary = await service.fetchProfileSummary();

        expect(summary, isA<ProfileSummary>());
        expect(summary.scope.subdistrictId, equals(1728));
        expect(summary.scope.subdistrictName, equals('Garut Kota'));
        expect(summary.scope.districtId, equals(126));
        expect(summary.scope.districtName, equals('Kabupaten Garut'));

        expect(summary.member.id, equals(578));
        expect(summary.member.username, equals('kt.garutkota'));
        expect(summary.member.name, equals('ADMIN KONTINGEN GARUT KOTA'));
        expect(summary.member.type, equals('admin_kok'));
        expect(summary.member.status, equals(1));
        expect(summary.member.statusLabel, equals('Aktif'));

        expect(summary.kontingen?.id, equals(1));
        expect(summary.kontingen?.code, equals('KGPK-0001'));
        expect(summary.kontingen?.name, equals('Garut Kota'));

        expect(summary.totalCabor, equals(5));
        expect(summary.totalCaborFromClub, equals(5));
        expect(summary.totalCaborFromAthlete, equals(5));
        expect(summary.totalClub, equals(5));
        expect(summary.totalAthlete, equals(125));
        expect(summary.totalAthleteWithoutClub, equals(0));
        expect(
          summary.dataNotes,
          equals(const ['Mode Demo: Menampilkan dataset simulasi lokal KOK.']),
        );
      });

      test('adapts snapshot into ProfileSummary for different scope', () async {
        const tkScope = AccessScope(
          type: AccessScopeType.district,
          id: '1729',
          name: 'Tarogong Kidul',
        );

        final service = DemoProfileService(
          demoRepo: demoRepo,
          currentScopeProvider: () => tkScope,
        );

        final summary = await service.fetchProfileSummary();

        expect(summary.scope.subdistrictId, equals(1729));
        expect(summary.scope.subdistrictName, equals('Tarogong Kidul'));
        expect(summary.kontingen?.name, equals('Tarogong Kidul'));
        expect(summary.totalCabor, equals(4));
        expect(summary.totalClub, equals(4));
        expect(summary.totalAthlete, equals(88)); // 26 + 22 + 24 + 16
      });

      test('respects RequestCancellation when cancelled', () async {
        final cancellationController = RequestCancellationController()
          ..cancel('User cancelled');

        final service = DemoProfileService(
          demoRepo: demoRepo,
          currentScopeProvider: () => scope,
        );

        expect(
          () => service.fetchProfileSummary(
            cancellation: cancellationController.token,
          ),
          throwsA(isA<RequestCancelledException>()),
        );
      });
    });

    group('DemoCaborService', () {
      test('implements CaborService interface', () {
        final service = DemoCaborService(
          demoRepo: demoRepo,
          currentScopeProvider: () => scope,
        );
        expect(service, isA<CaborService>());
      });

      test(
        'adapts snapshot into PaginatedResult<Cabor> with default pagination',
        () async {
          final service = DemoCaborService(
            demoRepo: demoRepo,
            currentScopeProvider: () => scope,
          );

          final result = await service.fetchCaborList();

          expect(result, isA<PaginatedResult<Cabor>>());
          expect(result.total, equals(5));
          expect(result.limit, equals(25));
          expect(result.offset, equals(0));
          expect(result.items.length, equals(5));
          expect(result.hasMore, isFalse);

          // Sports in Garut Kota alphabetically: Bola Voli, Bulu Tangkis, Pencak Silat, Renang, Sepak Bola
          expect(result.items[0].id, equals(1));
          expect(result.items[0].code, equals('DEMO-CB-001'));
          expect(result.items[0].name, equals('BOLA VOLI'));
          expect(result.items[0].status, equals(1));
          expect(result.items[0].statusLabel, equals('Aktif'));
          expect(result.items[0].totalClub, equals(1));
          expect(result.items[0].totalAthlete, equals(18));

          expect(result.items[1].id, equals(2));
          expect(result.items[1].code, equals('DEMO-CB-002'));
          expect(result.items[1].name, equals('BULU TANGKIS'));
          expect(result.items[1].totalClub, equals(1));
          expect(result.items[1].totalAthlete, equals(21));

          expect(result.items[2].id, equals(3));
          expect(result.items[2].code, equals('DEMO-CB-003'));
          expect(result.items[2].name, equals('PENCAK SILAT'));
          expect(result.items[2].totalClub, equals(1));
          expect(result.items[2].totalAthlete, equals(44));

          expect(result.items[3].id, equals(4));
          expect(result.items[3].code, equals('DEMO-CB-004'));
          expect(result.items[3].name, equals('RENANG'));
          expect(result.items[3].totalClub, equals(1));
          expect(result.items[3].totalAthlete, equals(8));

          expect(result.items[4].id, equals(5));
          expect(result.items[4].code, equals('DEMO-CB-005'));
          expect(result.items[4].name, equals('SEPAK BOLA'));
          expect(result.items[4].totalClub, equals(1));
          expect(result.items[4].totalAthlete, equals(34));
        },
      );

      test('supports pagination with limit and offset', () async {
        final service = DemoCaborService(
          demoRepo: demoRepo,
          currentScopeProvider: () => scope,
        );

        // Page 1: limit 2, offset 0
        final page1 = await service.fetchCaborList(limit: 2, offset: 0);
        expect(page1.total, equals(5));
        expect(page1.items.length, equals(2));
        expect(page1.items[0].name, equals('BOLA VOLI'));
        expect(page1.items[1].name, equals('BULU TANGKIS'));
        expect(page1.hasMore, isTrue);
        expect(page1.nextOffset, equals(2));

        // Page 2: limit 2, offset 2
        final page2 = await service.fetchCaborList(limit: 2, offset: 2);
        expect(page2.total, equals(5));
        expect(page2.items.length, equals(2));
        expect(page2.items[0].name, equals('PENCAK SILAT'));
        expect(page2.items[1].name, equals('RENANG'));
        expect(page2.hasMore, isTrue);
        expect(page2.nextOffset, equals(4));

        // Page 3: limit 2, offset 4
        final page3 = await service.fetchCaborList(limit: 2, offset: 4);
        expect(page3.total, equals(5));
        expect(page3.items.length, equals(1));
        expect(page3.items[0].name, equals('SEPAK BOLA'));
        expect(page3.hasMore, isFalse);
        expect(page3.nextOffset, equals(5));

        // Page 4: out of bounds offset
        final page4 = await service.fetchCaborList(limit: 2, offset: 10);
        expect(page4.total, equals(5));
        expect(page4.items.isEmpty, isTrue);
        expect(page4.hasMore, isFalse);
      });

      test('sorts demo cabors by athlete count before pagination', () async {
        final service = DemoCaborService(
          demoRepo: demoRepo,
          currentScopeProvider: () => scope,
        );

        final result = await service.fetchCaborList(sort: 'athlete', limit: 2);

        expect(result.total, 5);
        expect(result.items.map((cabor) => cabor.name), [
          'PENCAK SILAT',
          'SEPAK BOLA',
        ]);
      });

      test('respects RequestCancellation when cancelled', () async {
        final cancellationController = RequestCancellationController()
          ..cancel('User cancelled');

        final service = DemoCaborService(
          demoRepo: demoRepo,
          currentScopeProvider: () => scope,
        );

        expect(
          () => service.fetchCaborList(
            cancellation: cancellationController.token,
          ),
          throwsA(isA<RequestCancelledException>()),
        );
      });
    });
  });
}
