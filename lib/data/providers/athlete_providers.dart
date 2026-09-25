import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/composition/app_composition.dart';
import '../../core/config/deployment_profile.dart';
import '../demo_kok_repository.dart';
import '../models/athlete.dart';
import '../models/athlete_detail.dart';
import '../models/paginated_result.dart';
import '../providers/snapshot_provider.dart';
import '../request_cancellation.dart';
import '../services/athlete_service.dart';
import '../services/demo/demo_athlete_service.dart';

final athleteServiceProvider = Provider<AthleteService>((ref) {
  final composition = ref.watch(appCompositionProvider);
  final context = ref.watch(dataRequestContextProvider);
  if (composition.profile.dataMode == DataMode.demo &&
      context != null &&
      composition.kokRepository is DemoKokRepository) {
    return DemoAthleteService(
      demoRepo: composition.kokRepository as DemoKokRepository,
      currentScopeProvider: () => context.scope,
    );
  }
  return composition.athleteService;
});

typedef AthleteListParams = ({
  int offset,
  int limit,
  int? idCabor,
  int? idClub,
  String? sex,
  int? status,
  String? search,
  String sort,
});

final athleteListProvider =
    FutureProvider.family<PaginatedResult<Athlete>, AthleteListParams>((
      ref,
      params,
    ) async {
      final initialContext = ref.watch(dataRequestContextProvider);
      if (initialContext == null) {
        throw const RequestCancelledException(
          'Sesi tidak aktif atau telah berakhir.',
        );
      }

      final service = ref.watch(athleteServiceProvider);
      final cancellationController = RequestCancellationController();
      ref.onDispose(() => cancellationController.cancel('Provider disposed'));

      final result = await service.fetchAthleteList(
        limit: params.limit,
        offset: params.offset,
        idCabor: params.idCabor,
        idClub: params.idClub,
        sex: params.sex,
        status: params.status,
        search: params.search,
        sort: params.sort,
        cancellation: cancellationController.token,
      );

      cancellationController.token.throwIfCancelled();

      final currentContext = ref.read(dataRequestContextProvider);
      if (!ref.mounted || currentContext != initialContext) {
        throw const RequestCancelledException(
          'Konteks sesi berubah saat memuat daftar atlet.',
        );
      }

      return result;
    }, retry: (retryCount, error) => null);

final class AthletePaginationState {
  const AthletePaginationState({
    this.items = const [],
    this.total = 0,
    this.hasMore = false,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.error,
    this.loadMoreError,
    this.filterWarning,
    this.search,
    this.sex,
    this.status,
    this.sort = 'name',
  });

  final List<Athlete> items;
  final int total;
  final bool hasMore;
  final bool isLoading;
  final bool isLoadingMore;
  final Object? error;
  final Object? loadMoreError;
  final Map<String, dynamic>? filterWarning;
  final String? search;
  final String? sex;
  final int? status;
  final String sort;

  bool get canLoadMore => !isLoading && !isLoadingMore && hasMore;
  bool get hasFilterWarning => filterWarning != null;
  String? get filterWarningMessage => filterWarning?['message'] as String?;

  AthletePaginationState copyWith({
    List<Athlete>? items,
    int? total,
    bool? hasMore,
    bool? isLoading,
    bool? isLoadingMore,
    Object? error,
    Object? loadMoreError,
    Map<String, dynamic>? filterWarning,
    bool clearFilterWarning = false,
    String? search,
    bool clearSearch = false,
    String? sex,
    bool clearSex = false,
    int? status,
    bool clearStatus = false,
    String? sort,
  }) {
    return AthletePaginationState(
      items: items ?? this.items,
      total: total ?? this.total,
      hasMore: hasMore ?? this.hasMore,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      error: error,
      loadMoreError: loadMoreError,
      filterWarning: clearFilterWarning
          ? null
          : (filterWarning ?? this.filterWarning),
      search: clearSearch ? null : (search ?? this.search),
      sex: clearSex ? null : (sex ?? this.sex),
      status: clearStatus ? null : (status ?? this.status),
      sort: sort ?? this.sort,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AthletePaginationState &&
          runtimeType == other.runtimeType &&
          listEquals(items, other.items) &&
          total == other.total &&
          hasMore == other.hasMore &&
          isLoading == other.isLoading &&
          isLoadingMore == other.isLoadingMore &&
          error == other.error &&
          loadMoreError == other.loadMoreError &&
          mapEquals(filterWarning, other.filterWarning) &&
          search == other.search &&
          sex == other.sex &&
          status == other.status &&
          sort == other.sort;

  @override
  int get hashCode => Object.hash(
    Object.hashAll(items),
    total,
    hasMore,
    isLoading,
    isLoadingMore,
    error,
    loadMoreError,
    filterWarning == null ? 0 : Object.hashAll(filterWarning!.entries),
    search,
    sex,
    status,
    sort,
  );
}

typedef AthleteFilterScope = ({int? idCabor, int? idClub});

class AthletePaginationController extends Notifier<AthletePaginationState> {
  AthletePaginationController(this.scope);

  static const int pageSize = 25;

  final AthleteFilterScope scope;

  int _generation = 0;

  @override
  AthletePaginationState build() {
    ref.watch(dataRequestContextProvider);
    return const AthletePaginationState();
  }

  Future<void> loadFirstPage() async {
    final contextAtStart = ref.read(dataRequestContextProvider);
    if (contextAtStart == null) return;
    _generation++;
    final expectedGen = _generation;

    state = state.copyWith(
      items: const [],
      total: 0,
      hasMore: false,
      isLoading: true,
      error: null,
      clearFilterWarning: true,
    );
    try {
      final result = await ref.refresh(
        athleteListProvider((
          offset: 0,
          limit: pageSize,
          idCabor: scope.idCabor,
          idClub: scope.idClub,
          sex: state.sex,
          status: state.status,
          search: state.search,
          sort: state.sort,
        )).future,
      );
      if (!ref.mounted) return;
      final currentContext = ref.read(dataRequestContextProvider);
      if (currentContext != contextAtStart || expectedGen != _generation) {
        return;
      }
      state = state.copyWith(
        items: result.items,
        total: result.total,
        hasMore: result.hasMore,
        filterWarning: result.filterWarning,
        isLoading: false,
      );
    } catch (e) {
      if (!ref.mounted ||
          ref.read(dataRequestContextProvider) != contextAtStart ||
          expectedGen != _generation) {
        return;
      }
      state = state.copyWith(
        isLoading: false,
        error: e,
        items: const [],
        total: 0,
        hasMore: false,
      );
    }
  }

  Future<void> loadMore() async {
    if (!state.canLoadMore) return;
    final contextAtStart = ref.read(dataRequestContextProvider);
    if (contextAtStart == null) return;
    final expectedGen = _generation;

    state = state.copyWith(isLoadingMore: true, loadMoreError: null);
    try {
      final result = await ref.refresh(
        athleteListProvider((
          offset: state.items.length,
          limit: pageSize,
          idCabor: scope.idCabor,
          idClub: scope.idClub,
          sex: state.sex,
          status: state.status,
          search: state.search,
          sort: state.sort,
        )).future,
      );
      if (!ref.mounted) return;
      final currentContext = ref.read(dataRequestContextProvider);
      if (currentContext != contextAtStart || expectedGen != _generation) {
        return;
      }
      state = state.copyWith(
        items: [...state.items, ...result.items],
        total: result.total,
        hasMore: result.hasMore,
        filterWarning: result.filterWarning,
        isLoadingMore: false,
      );
    } catch (e) {
      if (!ref.mounted ||
          ref.read(dataRequestContextProvider) != contextAtStart ||
          expectedGen != _generation) {
        return;
      }
      state = state.copyWith(isLoadingMore: false, loadMoreError: e);
    }
  }

  void updateSearch(String? query) {
    final normalized = (query == null || query.trim().isEmpty)
        ? null
        : query.trim();
    if (state.search == normalized) return;
    state = normalized == null
        ? state.copyWith(clearSearch: true)
        : state.copyWith(search: normalized);
    loadFirstPage();
  }

  void updateSexFilter(String? sex) {
    final normalized = (sex == null || sex.trim().isEmpty) ? null : sex.trim();
    if (state.sex == normalized) return;
    state = normalized == null
        ? state.copyWith(clearSex: true)
        : state.copyWith(sex: normalized);
    loadFirstPage();
  }

  void updateStatusFilter(int? status) {
    if (state.status == status) return;
    state = status == null
        ? state.copyWith(clearStatus: true)
        : state.copyWith(status: status);
    loadFirstPage();
  }

  void updateFilters({String? sex, int? status}) {
    final normalizedSex = (sex == null || sex.trim().isEmpty)
        ? null
        : sex.trim();
    if (state.sex == normalizedSex && state.status == status) return;
    state = state.copyWith(
      sex: normalizedSex,
      clearSex: normalizedSex == null,
      status: status,
      clearStatus: status == null,
    );
    loadFirstPage();
  }

  void updateSort(String sort) {
    if (state.sort == sort) return;
    state = state.copyWith(sort: sort);
    loadFirstPage();
  }

  Future<void> refresh() => loadFirstPage();
}

final athletePaginationProvider =
    NotifierProvider.family<
      AthletePaginationController,
      AthletePaginationState,
      AthleteFilterScope
    >(AthletePaginationController.new);

final athleteDetailProvider = FutureProvider.family<AthleteDetail, int>((
  ref,
  athleteId,
) async {
  final initialContext = ref.watch(dataRequestContextProvider);
  if (initialContext == null) {
    throw const RequestCancelledException(
      'Sesi tidak aktif atau telah berakhir.',
    );
  }

  final service = ref.watch(athleteServiceProvider);
  final cancellationController = RequestCancellationController();
  ref.onDispose(() => cancellationController.cancel('Provider disposed'));

  final detail = await service.fetchAthleteDetail(
    athleteId,
    cancellation: cancellationController.token,
  );

  cancellationController.token.throwIfCancelled();

  final currentContext = ref.read(dataRequestContextProvider);
  if (!ref.mounted || currentContext != initialContext) {
    throw const RequestCancelledException(
      'Konteks sesi berubah saat memuat detail atlet.',
    );
  }

  return detail;
}, retry: (retryCount, error) => null);
