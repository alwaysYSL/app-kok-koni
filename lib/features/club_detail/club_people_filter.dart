import '../../data/models.dart';

enum ClubPeopleStatusFilter { all, complete, needsAttention }

bool personNeedsAttention(SportPerson person) =>
    person.missingDocuments.isNotEmpty ||
    person.expiredLicense ||
    !person.verified;

List<SportPerson> filterClubPeople(
  List<SportPerson> people, {
  String query = '',
  String? group,
  ClubPeopleStatusFilter status = ClubPeopleStatusFilter.all,
}) {
  final normalizedQuery = query.trim().toLowerCase();
  return people
      .where((person) {
        final matchesQuery =
            normalizedQuery.isEmpty ||
            person.name.toLowerCase().contains(normalizedQuery);
        final matchesGroup = group == null || person.group == group;
        final needsAttention = personNeedsAttention(person);
        final matchesStatus = switch (status) {
          ClubPeopleStatusFilter.all => true,
          ClubPeopleStatusFilter.complete => !needsAttention,
          ClubPeopleStatusFilter.needsAttention => needsAttention,
        };
        return matchesQuery && matchesGroup && matchesStatus;
      })
      .toList(growable: false);
}
