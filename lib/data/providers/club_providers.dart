import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/composition/app_composition.dart';
import '../../core/config/deployment_profile.dart';
import '../demo_kok_repository.dart';
import '../kok_repository.dart';
import '../models.dart' hide Club;
import '../models/club.dart';
import '../models/club_detail.dart';
import '../models/paginated_result.dart';
import '../request_cancellation.dart';
import '../services/club_service.dart';
import '../services/demo/demo_club_service.dart';
import '../services/remote/remote_club_service.dart';
import 'snapshot_provider.dart';

final clubServiceProvider = Provider<ClubService>((ref) {
  final composition = ref.watch(appCompositionProvider);
  final context = ref.watch(dataRequestContextProvider);
  if (composition.profile.dataMode == DataMode.demo &&
      context != null &&
      composition.kokRepository is DemoKokRepository) {
    return DemoClubService(
      demoRepo: composition.kokRepository as DemoKokRepository,
      currentScopeProvider: () => context.scope,
    );
  }
  final service = composition.clubService;
  if (service != null) return service;
  if (composition.apiClient != null) {
    return RemoteClubService(client: composition.apiClient!);
  }
  throw StateError('ClubService is not available in current composition.');
});

typedef ClubListParams = ({
  int offset,
  int limit,
  int? idCabor,
  int? status,
  String? search,
  String sort,
});

final clubListProvider =
    FutureProvider.family<PaginatedResult<Club>, ClubListParams>((
      ref,
      params,
    ) async {
      final initialContext = ref.watch(dataRequestContextProvider);
      if (initialContext == null) {
        throw const RequestCancelledException(
          'Sesi tidak aktif atau telah berakhir.',
        );
      }

      final service = ref.watch(clubServiceProvider);
      final cancellationController = RequestCancellationController();
      ref.onDispose(() => cancellationController.cancel('Provider disposed'));

      final result = await service.fetchClubList(
        limit: params.limit,
        offset: params.offset,
        idCabor: params.idCabor,
        status: params.status,
        search: params.search,
        sort: params.sort,
        cancellation: cancellationController.token,
      );

      cancellationController.token.throwIfCancelled();

      final currentContext = ref.read(dataRequestContextProvider);
      if (!ref.mounted || currentContext != initialContext) {
        throw const RequestCancelledException(
          'Konteks sesi berubah saat memuat daftar klub.',
        );
      }

      return result;
    }, retry: (retryCount, error) => null);

final class ClubPaginationState {
  const ClubPaginationState({
    this.items = const [],
    this.total = 0,
    this.hasMore = false,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.error,
    this.loadMoreError,
    this.filterWarning,
    this.search,
    this.status,
    this.sort = 'name',
  });

  final List<Club> items;
  final int total;
  final bool hasMore;
  final bool isLoading;
  final bool isLoadingMore;
  final Object? error;
  final Object? loadMoreError;
  final Map<String, dynamic>? filterWarning;
  final String? search;
  final int? status;
  final String sort;

  bool get canLoadMore => !isLoading && !isLoadingMore && hasMore;
  bool get hasFilterWarning => filterWarning != null;
  String? get filterWarningMessage => filterWarning?['message'] as String?;

  ClubPaginationState copyWith({
    List<Club>? items,
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
    int? status,
    bool clearStatus = false,
    String? sort,
  }) {
    return ClubPaginationState(
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
      status: clearStatus ? null : (status ?? this.status),
      sort: sort ?? this.sort,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ClubPaginationState &&
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
    status,
    sort,
  );
}

class ClubPaginationController extends Notifier<ClubPaginationState> {
  ClubPaginationController(this.idCabor);

  static const int pageSize = 25;

  final int? idCabor;

  @override
  ClubPaginationState build() {
    return const ClubPaginationState();
  }

  Future<void> loadFirstPage() async {
    state = state.copyWith(
      isLoading: true,
      error: null,
      clearFilterWarning: true,
    );
    try {
      final result = await ref.refresh(
        clubListProvider((
          offset: 0,
          limit: pageSize,
          idCabor: idCabor,
          status: state.status,
          search: state.search,
          sort: state.sort,
        )).future,
      );
      state = state.copyWith(
        items: result.items,
        total: result.total,
        hasMore: result.hasMore,
        filterWarning: result.filterWarning,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e);
    }
  }

  Future<void> loadMore() async {
    if (!state.canLoadMore) return;
    state = state.copyWith(isLoadingMore: true, loadMoreError: null);
    try {
      final result = await ref.refresh(
        clubListProvider((
          offset: state.items.length,
          limit: pageSize,
          idCabor: idCabor,
          status: state.status,
          search: state.search,
          sort: state.sort,
        )).future,
      );
      state = state.copyWith(
        items: [...state.items, ...result.items],
        total: result.total,
        hasMore: result.hasMore,
        filterWarning: result.filterWarning,
        isLoadingMore: false,
      );
    } catch (e) {
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

  void updateStatusFilter(int? status) {
    if (state.status == status) return;
    state = status == null
        ? state.copyWith(clearStatus: true)
        : state.copyWith(status: status);
    loadFirstPage();
  }

  void updateSort(String sort) {
    if (state.sort == sort) return;
    state = state.copyWith(sort: sort);
    loadFirstPage();
  }

  Future<void> refresh() => loadFirstPage();
}

final clubPaginationProvider =
    NotifierProvider.family<
      ClubPaginationController,
      ClubPaginationState,
      int?
    >(ClubPaginationController.new);

final clubDetailProvider = FutureProvider.family<ClubDetail, int>((
  ref,
  clubId,
) async {
  final initialContext = ref.watch(dataRequestContextProvider);
  if (initialContext == null) {
    throw const RequestCancelledException(
      'Sesi tidak aktif atau telah berakhir.',
    );
  }

  final service = ref.watch(clubServiceProvider);
  final cancellationController = RequestCancellationController();
  ref.onDispose(() => cancellationController.cancel('Provider disposed'));

  final detail = await service.fetchClubDetail(
    clubId,
    cancellation: cancellationController.token,
  );

  cancellationController.token.throwIfCancelled();

  final currentContext = ref.read(dataRequestContextProvider);
  if (!ref.mounted || currentContext != initialContext) {
    throw const RequestCancelledException(
      'Konteks sesi berubah saat memuat detail klub.',
    );
  }

  return detail;
}, retry: (retryCount, error) => null);

// Legacy helpers and granular providers retained for backwards compatibility
@visibleForTesting
Future<T> runGranularRequest<T>(
  Ref ref,
  Future<T> Function(
    RequestCancellation cancellation,
    DataRequestContext context,
  )
  request,
) async {
  final context = ref.watch(dataRequestContextProvider);
  if (context == null) {
    throw const SessionRequiredException();
  }

  final cancellationController = RequestCancellationController();
  ref.onDispose(() => cancellationController.cancel('Provider disposed'));

  final result = await request(cancellationController.token, context);
  cancellationController.token.throwIfCancelled();

  if (!ref.mounted || ref.read(dataRequestContextProvider) != context) {
    throw const RequestCancelledException('Stale granular response rejected');
  }

  return result;
}

@visibleForTesting
Duration? granularRetry(int retryCount, Object error) {
  if (error is SessionRequiredException ||
      error is RequestCancelledException ||
      error is UnsupportedScopeException ||
      error is KokResourceNotFoundException) {
    return null;
  }
  return ProviderContainer.defaultRetry(retryCount, error);
}

final clubMembersProvider =
    FutureProvider.family<List<SportPerson>, ({String clubId, String? role})>((
      ref,
      params,
    ) {
      return runGranularRequest(
        ref,
        (cancellation, _) => ref
            .read(repositoryProvider)
            .fetchClubMembers(
              params.clubId,
              role: params.role,
              cancellation: cancellation,
            ),
      );
    }, retry: granularRetry);

final personDetailProvider = FutureProvider.family<SportPerson, String>((
  ref,
  personId,
) {
  return runGranularRequest(
    ref,
    (cancellation, _) => ref
        .read(repositoryProvider)
        .fetchPersonDetail(personId, cancellation: cancellation),
  );
}, retry: granularRetry);

final committeeProvider = FutureProvider<List<CommitteeMember>>((ref) {
  return runGranularRequest(
    ref,
    (cancellation, context) => ref
        .read(repositoryProvider)
        .fetchCommittee(context.scope, cancellation: cancellation),
  );
}, retry: granularRetry);

final helpdeskProvider = FutureProvider<HelpdeskContact?>((ref) {
  return runGranularRequest(
    ref,
    (cancellation, _) =>
        ref.read(repositoryProvider).fetchHelpdesk(cancellation: cancellation),
  );
}, retry: granularRetry);
