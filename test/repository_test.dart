import 'package:flutter_test/flutter_test.dart';
import 'package:kok_app/core/auth/domain/user_principal.dart';
import 'package:kok_app/data/models.dart';
import 'package:kok_app/data/repository.dart';

void main() {
  const garutKotaScope = AccessScope(
    type: AccessScopeType.district,
    id: 'garut_kota',
    name: 'Kecamatan Garut Kota',
  );

  const tarogongKidulScope = AccessScope(
    type: AccessScopeType.district,
    id: 'tarogong_kidul',
    name: 'Kecamatan Tarogong Kidul',
  );

  const countyScope = AccessScope(
    type: AccessScopeType.county,
    id: 'koni_kab',
    name: 'KONI Kabupaten Garut',
  );

  group('DemoKokRepository fetchScope & Scoped Datasets', () {
    late DemoKokRepository repo;

    setUp(() {
      repo = DemoKokRepository(simulateLatency: false);
    });

    test(
      'fetchScope Garut Kota menghasilkan 5 cabor, 5 klub, 125 atlet, 10 pelatih',
      () async {
        final snapshot = await repo.fetchScope(garutKotaScope);
        final athletes = snapshot.people
            .where((p) => p.role == 'Atlet')
            .toList();
        final coaches = snapshot.people
            .where((p) => p.role == 'Pelatih')
            .toList();
        final sports = snapshot.clubs.map((c) => c.sport).toSet();

        expect(snapshot.scope, equals(garutKotaScope));
        expect(snapshot.clubs.length, 5);
        expect(sports.length, 5);
        expect(
          sports,
          containsAll([
            'Sepak Bola',
            'Bulu Tangkis',
            'Pencak Silat',
            'Bola Voli',
            'Renang',
          ]),
        );
        expect(athletes.length, 125);
        expect(coaches.length, 10);
      },
    );

    test(
      'fetchScope Tarogong Kidul menghasilkan 4 cabor, 4 klub, 88 atlet, 8 pelatih',
      () async {
        final snapshot = await repo.fetchScope(tarogongKidulScope);
        final athletes = snapshot.people
            .where((p) => p.role == 'Atlet')
            .toList();
        final coaches = snapshot.people
            .where((p) => p.role == 'Pelatih')
            .toList();
        final sports = snapshot.clubs.map((c) => c.sport).toSet();

        expect(snapshot.scope, equals(tarogongKidulScope));
        expect(snapshot.clubs.length, 4);
        expect(sports.length, 4);
        expect(
          sports,
          containsAll([
            'Sepak Bola',
            'Bulu Tangkis',
            'Pencak Silat',
            'Bola Voli',
          ]),
        );
        expect(athletes.length, 88);
        expect(coaches.length, 8);
      },
    );

    test(
      'fetchScope KONI Kabupaten Garut menghasilkan 5 cabor unik, 9 klub, 213 atlet, 18 pelatih',
      () async {
        final snapshot = await repo.fetchScope(countyScope);
        final athletes = snapshot.people
            .where((p) => p.role == 'Atlet')
            .toList();
        final coaches = snapshot.people
            .where((p) => p.role == 'Pelatih')
            .toList();
        final sports = snapshot.clubs.map((c) => c.sport).toSet();

        expect(snapshot.scope, equals(countyScope));
        expect(snapshot.clubs.length, 9);
        expect(sports.length, 5);
        expect(
          sports,
          containsAll([
            'Sepak Bola',
            'Bulu Tangkis',
            'Pencak Silat',
            'Bola Voli',
            'Renang',
          ]),
        );
        expect(athletes.length, 213);
        expect(coaches.length, 18);
      },
    );

    test(
      'fetchScope dengan scope tidak dikenal melempar UnsupportedScopeException',
      () async {
        const unknownScope = AccessScope(
          type: AccessScopeType.district,
          id: 'unknown_district_xyz',
          name: 'Kecamatan Antah Berantah',
        );

        expect(
          () => repo.fetchScope(unknownScope),
          throwsA(
            isA<UnsupportedScopeException>().having(
              (e) => e.scope,
              'scope',
              equals(unknownScope),
            ),
          ),
        );
      },
    );

    test(
      'JSON serialization round-trip pada KokSnapshot mempertahankan scope',
      () async {
        final countySnapshot = await repo.fetchScope(countyScope);
        final json = countySnapshot.toJson();
        final roundTrip = KokSnapshot.fromJson(json);

        expect(roundTrip.scope, equals(countyScope));
        expect(roundTrip.scope.type, equals(AccessScopeType.county));
        expect(roundTrip.scope.id, equals('koni_kab'));
        expect(roundTrip.scope.name, equals('KONI Kabupaten Garut'));
        expect(roundTrip, equals(countySnapshot));
      },
    );
  });

  group('RequestCancellation Contract', () {
    test('cancellation flag dan reason dapat dipicu via controller', () async {
      final controller = RequestCancellationController();
      final token = controller.token;

      expect(token.isCancelled, isFalse);
      expect(token.reason, isNull);

      controller.cancel('Operasi dibatalkan oleh pengguna');

      expect(token.isCancelled, isTrue);
      expect(token.reason, 'Operasi dibatalkan oleh pengguna');
      expect(await token.whenCancelled, 'Operasi dibatalkan oleh pengguna');

      expect(
        () => token.throwIfCancelled(),
        throwsA(
          isA<RequestCancelledException>().having(
            (e) => e.reason,
            'reason',
            'Operasi dibatalkan oleh pengguna',
          ),
        ),
      );
    });

    test('DemoKokRepository menghormati token yang sudah dibatalkan', () async {
      final repo = DemoKokRepository(simulateLatency: false);
      final controller = RequestCancellationController();
      controller.cancel('Dibatalkan sebelum request');

      expect(
        () => repo.fetchScope(garutKotaScope, cancellation: controller.token),
        throwsA(isA<RequestCancelledException>()),
      );
    });
  });

  test('Combined filters, sort and empty results', () async {
    final data = await DemoKokRepository(
      simulateLatency: false,
    ).fetchScope(garutKotaScope);
    expect(
      filterClubs(
        data.clubs,
        query: ' GARUDA ',
        sport: 'Sepak Bola',
        status: 'Aktif',
        village: 'Pakuwon',
      ).single.id,
      'garuda',
    );
    expect(filterClubs(data.clubs, sport: 'Renang', status: 'Aktif'), isEmpty);
    expect(filterClubs(data.clubs, status: 'Pasif').single.id, 'tirta');
    expect(
      filterClubs(data.clubs, ascending: false).first,
      filterClubs(data.clubs).last,
    );
  });

  test(
    'demo repository exposes distinct club branding without network logos',
    () async {
      final data = await DemoKokRepository(
        simulateLatency: false,
      ).fetchScope(garutKotaScope);
      final clubs = {for (final club in data.clubs) club.id: club};
      expect(clubs['garuda']!.brandPrimaryHex, isNotNull);
      expect(
        clubs['pb']!.brandPrimaryHex,
        isNot(clubs['garuda']!.brandPrimaryHex),
      );
      expect(
        clubs['voli']!.brandPrimaryHex,
        isNot(clubs['pb']!.brandPrimaryHex),
      );
      expect(clubs['garuda']!.logoUrl, isNull);
    },
  );

  test('filterClubs with ClubSortOption supports all 4 sort options', () async {
    final data = await DemoKokRepository(
      simulateLatency: false,
    ).fetchScope(garutKotaScope);

    // 1. nameAsc (default)
    final nameAsc = filterClubs(data.clubs, sortOption: ClubSortOption.nameAsc);
    expect(nameAsc.map((c) => c.name).toList(), [
      'Klub Garuda Muda',
      'PB Citra Garut',
      'Silat Panglipur',
      'Tirta Kencana',
      'Voli Bina Muda',
    ]);

    // 2. nameDesc
    final nameDesc = filterClubs(
      data.clubs,
      sortOption: ClubSortOption.nameDesc,
    );
    expect(nameDesc.map((c) => c.name).toList(), [
      'Voli Bina Muda',
      'Tirta Kencana',
      'Silat Panglipur',
      'PB Citra Garut',
      'Klub Garuda Muda',
    ]);

    // 3. athletesDesc (with snapshot or people)
    final athletesDescSnapshot = filterClubs(
      data.clubs,
      sortOption: ClubSortOption.athletesDesc,
      snapshot: data,
    );
    expect(athletesDescSnapshot.map((c) => c.id).toList(), [
      'silat',
      'garuda',
      'pb',
      'voli',
      'tirta',
    ]);

    final athletesDescPeople = filterClubs(
      data.clubs,
      sortOption: ClubSortOption.athletesDesc,
      people: data.people,
    );
    expect(athletesDescPeople.map((c) => c.id).toList(), [
      'silat',
      'garuda',
      'pb',
      'voli',
      'tirta',
    ]);

    // 4. statusActiveFirst with demo data
    final statusActiveFirst = filterClubs(
      data.clubs,
      sortOption: ClubSortOption.statusActiveFirst,
    );
    expect(statusActiveFirst.map((c) => c.id).toList(), [
      'garuda',
      'pb',
      'silat',
      'voli',
      'tirta',
    ]);
    expect(statusActiveFirst.last.active, isFalse);
    expect(statusActiveFirst.take(4).every((c) => c.active), isTrue);

    // Additional edge-cases: active status ordering and tiebreakers
    const dummyClubs = [
      Club(
        id: 'c1',
        name: 'Z Inactive',
        sport: 'Sport',
        village: 'V',
        active: false,
      ),
      Club(
        id: 'c2',
        name: 'A Inactive',
        sport: 'Sport',
        village: 'V',
        active: false,
      ),
      Club(
        id: 'c3',
        name: 'Z Active',
        sport: 'Sport',
        village: 'V',
        active: true,
      ),
      Club(
        id: 'c4',
        name: 'A Active',
        sport: 'Sport',
        village: 'V',
        active: true,
      ),
    ];
    final dummySorted = filterClubs(
      dummyClubs,
      sortOption: ClubSortOption.statusActiveFirst,
    );
    expect(dummySorted.map((c) => c.id).toList(), ['c4', 'c3', 'c2', 'c1']);

    // athletesDesc with only athlete role counted
    const dummyPeople = [
      SportPerson(
        id: 'p1',
        name: 'P1',
        clubId: 'c1',
        role: 'Atlet',
        group: 'G',
      ),
      SportPerson(
        id: 'p2',
        name: 'P2',
        clubId: 'c2',
        role: 'Pelatih',
        group: 'G',
      ),
    ];
    final dummyAthleteSorted = filterClubs(
      dummyClubs,
      sortOption: ClubSortOption.athletesDesc,
      people: dummyPeople,
    );
    expect(dummyAthleteSorted.first.id, 'c1');
  });

  test('JSON round-trip and all people reference a known club', () async {
    final data = await DemoKokRepository(
      simulateLatency: false,
    ).fetchScope(garutKotaScope);
    // Exercise nested JSON models and timestamps.
    final result = KokSnapshot.fromJson(data.toJson());
    expect(result, data);
    expect(
      data.people.every((p) => data.clubs.any((c) => c.id == p.clubId)),
      isTrue,
    );
    expect(data.people.where((p) => p.missingDocuments.isNotEmpty).length, 8);
    expect(data.people.where((p) => p.expiredLicense).length, 5);
  });
}
