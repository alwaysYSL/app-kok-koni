import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/auth/domain/auth_state.dart';
import '../core/auth/presentation/auth_controller.dart';
import 'models.dart';

final class SessionRequiredException implements Exception {
  final String message;
  const SessionRequiredException([
    this.message =
        'Sesi terautentikasi aktif dibutuhkan untuk mengakses data keolahragaan.',
  ]);

  @override
  String toString() => message;
}

class CancelToken {
  bool _isCancelled = false;
  String? _reason;

  bool get isCancelled => _isCancelled;
  String? get reason => _reason;

  void cancel([String? reason]) {
    _isCancelled = true;
    _reason = reason;
  }
}

/// Replace this implementation when the SICABOR contract is available.
/// There are deliberately no guessed HTTP endpoints or fabricated access tokens.
abstract interface class KokRepository {
  Future<KokSnapshot> fetch();
  Future<KokSnapshot> fetchDistrict(
    String districtId, {
    CancelToken? cancelToken,
  });
}

typedef DistrictSnapshot = KokSnapshot;

extension KokSnapshotDistrictExt on KokSnapshot {
  String get districtName {
    if (clubs.any((c) => c.id.startsWith('club-tk-'))) {
      return 'Kecamatan Tarogong Kidul';
    }
    return 'Kecamatan Garut Kota';
  }

  List<String> get sports => clubs.map((c) => c.sport).toSet().toList();
}

class SessionScope {
  final String userId;
  final String districtId;
  final int generation;

  const SessionScope({
    required this.userId,
    required this.districtId,
    required this.generation,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SessionScope &&
          userId == other.userId &&
          districtId == other.districtId &&
          generation == other.generation;

  @override
  int get hashCode =>
      userId.hashCode ^ districtId.hashCode ^ generation.hashCode;
}

final sessionScopeProvider = Provider<SessionScope?>((ref) {
  final authState = ref.watch(authControllerProvider);
  if (authState is AuthSignedIn) {
    return SessionScope(
      userId: authState.user.id,
      districtId: authState.user.scope.id,
      generation: authState.generation,
    );
  }
  return null;
});

final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: const String.fromEnvironment('SICABOR_BASE_URL'),
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 20),
      headers: {'Accept': 'application/json'},
    ),
  );
  ref.onDispose(() => dio.close());
  return dio;
});

final repositoryProvider = Provider<KokRepository>(
  (ref) => DemoKokRepository(),
);

final snapshotProvider = FutureProvider<KokSnapshot>(
  (ref) async {
    final scope = ref.watch(sessionScopeProvider);
    if (scope == null) {
      throw const SessionRequiredException();
    }

    final repository = ref.watch(repositoryProvider);
    final cancelToken = CancelToken();
    ref.onDispose(() => cancelToken.cancel('Session changed or disposed'));

    return repository.fetchDistrict(scope.districtId, cancelToken: cancelToken);
  },
  retry: (retryCount, error) {
    if (error is SessionRequiredException) return null;
    return ProviderContainer.defaultRetry(retryCount, error);
  },
);

class DemoKokRepository implements KokRepository {
  @override
  Future<KokSnapshot> fetch() => fetchDistrict('garut_kota');

  @override
  Future<KokSnapshot> fetchDistrict(
    String districtId, {
    CancelToken? cancelToken,
  }) async {
    if (cancelToken?.isCancelled ?? false) {
      throw Exception('Permintaan data dibatalkan: ${cancelToken?.reason}');
    }
    await Future<void>.delayed(const Duration(milliseconds: 400));
    if (cancelToken?.isCancelled ?? false) {
      throw Exception('Permintaan data dibatalkan: ${cancelToken?.reason}');
    }
    if (districtId == 'tarogong_kidul') {
      const tkClubs = [
        Club(
          id: 'club-tk-1',
          name: 'Tarogong Kidul Utama FC',
          sport: 'Sepak Bola',
          village: 'Sukagalih',
          brandPrimaryHex: '#1E3A8A',
          brandSecondaryHex: '#172554',
        ),
        Club(
          id: 'club-tk-2',
          name: 'PB Surya Tarogong',
          sport: 'Bulu Tangkis',
          village: 'Haurpanggung',
          brandPrimaryHex: '#047857',
          brandSecondaryHex: '#064E3B',
        ),
        Club(
          id: 'club-tk-3',
          name: 'Putra Tarogong Silat',
          sport: 'Pencak Silat',
          village: 'Jayawaras',
          brandPrimaryHex: '#B45309',
          brandSecondaryHex: '#78350F',
        ),
        Club(
          id: 'club-tk-4',
          name: 'Voli Gemilang Tarogong',
          sport: 'Bola Voli',
          village: 'Patarruman',
          brandPrimaryHex: '#7C3AED',
          brandSecondaryHex: '#4C1D95',
        ),
      ];

      final tkPeople = <SportPerson>[];
      final tkAthleteCounts = [26, 22, 24, 16];
      for (var c = 0; c < tkClubs.length; c++) {
        for (var i = 0; i < tkAthleteCounts[c]; i++) {
          tkPeople.add(
            SportPerson(
              id: '${tkClubs[c].id}-atlet-$i',
              name:
                  'Atlet ${i + 1} · ${tkClubs[c].name.replaceFirst('Klub ', '')}',
              clubId: tkClubs[c].id,
              role: 'Atlet',
              group: i.isEven ? 'U-18' : 'U-16',
              gender: i.isEven ? 'L' : 'P',
              age: 15 + (i % 4),
              verified: true,
              missingDocuments: const [],
            ),
          );
        }
        for (var i = 0; i < 2; i++) {
          tkPeople.add(
            SportPerson(
              id: '${tkClubs[c].id}-pelatih-$i',
              name: 'Pelatih ${i + 1} · ${tkClubs[c].name}',
              clubId: tkClubs[c].id,
              role: 'Pelatih',
              group: 'Lisensi C',
              expiredLicense: false,
            ),
          );
        }
        tkPeople.add(
          SportPerson(
            id: '${tkClubs[c].id}-official',
            name: 'Official · ${tkClubs[c].name}',
            clubId: tkClubs[c].id,
            role: 'Official',
            group: 'Manajer tim',
          ),
        );
      }

      return KokSnapshot(
        clubs: tkClubs,
        people: tkPeople,
        loadedAt: DateTime.now(),
        committee: const [
          CommitteeMember(
            id: 'ketua-tk',
            name: 'Cecep (contoh)',
            position: 'Ketua KOK',
            division: 'Pengurus inti',
          ),
          CommitteeMember(
            id: 'sekretaris-tk',
            name: 'Dewi (contoh)',
            position: 'Sekretaris',
            division: 'Pengurus inti',
          ),
        ],
      );
    }

    const clubs = [
      Club(
        id: 'garuda',
        name: 'Klub Garuda Muda',
        sport: 'Sepak Bola',
        village: 'Pakuwon',
        brandPrimaryHex: '#5B566E',
        brandSecondaryHex: '#11294B',
      ),
      Club(
        id: 'pb',
        name: 'PB Citra Garut',
        sport: 'Bulu Tangkis',
        village: 'Paminggir',
        brandPrimaryHex: '#A51D2A',
        brandSecondaryHex: '#670A13',
      ),
      Club(
        id: 'silat',
        name: 'Silat Panglipur',
        sport: 'Pencak Silat',
        village: 'Regol',
      ),
      Club(
        id: 'voli',
        name: 'Voli Bina Muda',
        sport: 'Voli',
        village: 'Pakuwon',
        brandPrimaryHex: '#F3B51B',
        brandSecondaryHex: '#8F6100',
      ),
      Club(
        id: 'tirta',
        name: 'Tirta Kencana',
        sport: 'Renang',
        village: 'Paminggir',
        active: false,
      ),
    ];
    final people = <SportPerson>[];
    final athleteCounts = [34, 21, 44, 18, 8];
    for (var c = 0; c < clubs.length; c++) {
      for (var i = 0; i < athleteCounts[c]; i++) {
        people.add(
          SportPerson(
            id: '${clubs[c].id}-atlet-$i',
            name: 'Atlet ${i + 1} · ${clubs[c].name.replaceFirst('Klub ', '')}',
            clubId: clubs[c].id,
            role: 'Atlet',
            group: i.isEven ? 'U-18' : 'U-16',
            gender: i.isEven ? 'L' : 'P',
            age: 15 + (i % 4),
            verified: !(c == 0 && i < 8),
            missingDocuments: c == 0 && i < 8
                ? ['Kartu Keluarga', 'Akta kelahiran']
                : [],
          ),
        );
      }
      for (var i = 0; i < 2; i++) {
        people.add(
          SportPerson(
            id: '${clubs[c].id}-pelatih-$i',
            name: 'Pelatih ${i + 1} · ${clubs[c].name}',
            clubId: clubs[c].id,
            role: 'Pelatih',
            group: 'Lisensi C',
            expiredLicense: i == 0,
          ),
        );
      }
      people.add(
        SportPerson(
          id: '${clubs[c].id}-official',
          name: 'Official · ${clubs[c].name}',
          clubId: clubs[c].id,
          role: 'Official',
          group: 'Manajer tim',
        ),
      );
    }
    return KokSnapshot(
      clubs: clubs,
      people: people,
      loadedAt: DateTime.now(),
      committee: const [
        CommitteeMember(
          id: 'ketua',
          name: 'Asep (contoh)',
          position: 'Ketua KOK',
          division: 'Pengurus inti',
        ),
        CommitteeMember(
          id: 'wakil',
          name: 'Dedi (contoh)',
          position: 'Wakil Ketua',
          division: 'Pengurus inti',
        ),
        CommitteeMember(
          id: 'sekretaris',
          name: 'Rina (contoh)',
          position: 'Sekretaris',
          division: 'Pengurus inti',
        ),
        CommitteeMember(
          id: 'bendahara',
          name: 'Siti (contoh)',
          position: 'Bendahara',
          division: 'Pengurus inti',
        ),
        CommitteeMember(
          id: 'pembinaan',
          name: 'Hendra (contoh)',
          position: 'Koordinator Pembinaan',
          division: 'Pembinaan prestasi',
        ),
      ],
    );
  }
}

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
