import 'package:flutter_test/flutter_test.dart';
import 'package:kok_app/data/models.dart';
import 'package:kok_app/features/club_detail/club_people_filter.dart';

const people = [
  SportPerson(
    id: '1',
    name: 'Alya Putri',
    clubId: 'c',
    role: 'Atlet',
    group: 'U-18',
    gender: 'P',
    age: 17,
  ),
  SportPerson(
    id: '2',
    name: 'Bima Putra',
    clubId: 'c',
    role: 'Atlet',
    group: 'U-16',
    missingDocuments: ['Kartu Keluarga'],
  ),
  SportPerson(
    id: '3',
    name: 'Coach Dedi',
    clubId: 'c',
    role: 'Pelatih',
    group: 'Lisensi C',
    expiredLicense: true,
  ),
];

void main() {
  test('filters case-insensitive query and group together', () {
    final result = filterClubPeople(people, query: 'alya', group: 'U-18');
    expect(result.map((p) => p.id), ['1']);
  });

  test(
    'needsAttention includes missing documents, expired license, and unverified',
    () {
      final result = filterClubPeople(
        people,
        status: ClubPeopleStatusFilter.needsAttention,
      );
      expect(result.map((p) => p.id), ['2', '3']);
    },
  );

  test('complete excludes every attention condition', () {
    final result = filterClubPeople(
      people,
      status: ClubPeopleStatusFilter.complete,
    );
    expect(result.map((p) => p.id), ['1']);
  });
}
