import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/auth/domain/auth_state.dart';
import '../core/auth/domain/user_principal.dart';
import '../core/auth/presentation/auth_controller.dart';
import 'demo_kok_repository.dart';
import 'kok_repository.dart';
import 'models.dart';
import 'request_cancellation.dart';

export 'demo_kok_repository.dart';
export 'kok_repository.dart';
export 'models.dart' show KokSnapshotDistrictExt;
export 'request_cancellation.dart';

final class SessionRequiredException implements Exception {
  final String message;
  const SessionRequiredException([
    this.message =
        'Sesi terautentikasi aktif dibutuhkan untuk mengakses data keolahragaan.',
  ]);

  @override
  String toString() => message;
}

typedef DistrictSnapshot = KokSnapshot;

class SessionScope {
  final String userId;
  final String districtId;
  final int generation;
  final AccessScope? accessScope;

  const SessionScope({
    required this.userId,
    required this.districtId,
    required this.generation,
    this.accessScope,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SessionScope &&
          userId == other.userId &&
          districtId == other.districtId &&
          generation == other.generation &&
          accessScope == other.accessScope;

  @override
  int get hashCode => Object.hash(userId, districtId, generation, accessScope);
}

final sessionScopeProvider = Provider<SessionScope?>((ref) {
  final authState = ref.watch(authControllerProvider);
  if (authState is AuthSignedIn) {
    return SessionScope(
      userId: authState.user.id,
      districtId: authState.user.scope.id,
      generation: authState.generation,
      accessScope: authState.user.scope,
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
    final cancellationController = RequestCancellationController();
    ref.onDispose(
      () => cancellationController.cancel('Session changed or disposed'),
    );

    final targetScope =
        scope.accessScope ??
        AccessScope(
          type: AccessScopeType.district,
          id: scope.districtId,
          name: scope.districtId,
        );

    return repository.fetchScope(
      targetScope,
      cancellation: cancellationController.token,
    );
  },
  retry: (retryCount, error) {
    if (error is SessionRequiredException) return null;
    return ProviderContainer.defaultRetry(retryCount, error);
  },
);

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
