import 'package:flutter_test/flutter_test.dart';
import 'package:kok_app/data/repository.dart';
import 'package:kok_app/data/models.dart';

void main() {
  test('Combined filters, sort and empty results', () async {
    final data = await DemoKokRepository().fetch();
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
      final data = await DemoKokRepository().fetch();
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
    final data = await DemoKokRepository().fetch();

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
    final data = await DemoKokRepository().fetch();
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
