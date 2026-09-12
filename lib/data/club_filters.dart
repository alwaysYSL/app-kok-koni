import 'models.dart';

List<SportPerson> clubPeople(KokSnapshot data, String id, [String? role]) =>
    data.people
        .where((p) => p.clubId == id && (role == null || p.role == role))
        .toList();

enum ClubSortOption { nameAsc, nameDesc, athletesDesc, statusActiveFirst }

List<Club> filterClubs(
  List<Club> clubs, {
  String query = '',
  String? sport,
  String? status,
  String? village,
  ClubSortOption sortOption = ClubSortOption.nameAsc,
  bool? ascending,
  List<SportPerson>? people,
  KokSnapshot? snapshot,
}) {
  final result = clubs
      .where(
        (c) =>
            c.name.toLowerCase().contains(query.trim().toLowerCase()) &&
            (sport == null || c.sport == sport) &&
            (village == null || c.village == village) &&
            (status == null || c.active == (status == 'Aktif')),
      )
      .toList();

  final effectiveSort =
      (ascending != null && sortOption == ClubSortOption.nameAsc)
      ? (ascending ? ClubSortOption.nameAsc : ClubSortOption.nameDesc)
      : sortOption;

  switch (effectiveSort) {
    case ClubSortOption.nameAsc:
      result.sort((a, b) => a.name.compareTo(b.name));
    case ClubSortOption.nameDesc:
      result.sort((a, b) => b.name.compareTo(a.name));
    case ClubSortOption.athletesDesc:
      final personList = snapshot?.people ?? people;
      final countMap = <String, int>{};
      if (personList != null) {
        for (final p in personList) {
          if (p.role == 'Atlet') {
            countMap[p.clubId] = (countMap[p.clubId] ?? 0) + 1;
          }
        }
      }
      result.sort((a, b) {
        final countA = countMap[a.id] ?? 0;
        final countB = countMap[b.id] ?? 0;
        final comp = countB.compareTo(countA);
        return comp != 0 ? comp : a.name.compareTo(b.name);
      });
    case ClubSortOption.statusActiveFirst:
      result.sort((a, b) {
        if (a.active != b.active) {
          return a.active ? -1 : 1;
        }
        return a.name.compareTo(b.name);
      });
  }

  return result;
}
