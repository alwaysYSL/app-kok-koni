import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/composition/app_composition.dart';
import '../../core/config/deployment_profile.dart';
import '../demo_kok_repository.dart';
import '../models/cabor.dart';
import '../models/paginated_result.dart';
import '../providers/snapshot_provider.dart';
import '../request_cancellation.dart';
import '../services/cabor_service.dart';
import '../services/demo/demo_cabor_service.dart';

final caborServiceProvider = Provider<CaborService>((ref) {
  final composition = ref.watch(appCompositionProvider);
  final context = ref.watch(dataRequestContextProvider);
  if (composition.profile.dataMode == DataMode.demo &&
      context != null &&
      composition.kokRepository is DemoKokRepository) {
    return DemoCaborService(
      demoRepo: composition.kokRepository as DemoKokRepository,
      currentScopeProvider: () => context.scope,
    );
  }
  return composition.caborService;
});

typedef CaborListParams = ({int offset, int limit, String source, String sort});

final caborListProvider =
    FutureProvider.family<PaginatedResult<Cabor>, CaborListParams>((
      ref,
      params,
    ) async {
      final initialContext = ref.watch(dataRequestContextProvider);
      if (initialContext == null) {
        throw const RequestCancelledException(
          'Sesi tidak aktif atau telah berakhir.',
        );
      }

      final service = ref.watch(caborServiceProvider);
      final cancellationController = RequestCancellationController();
      ref.onDispose(() => cancellationController.cancel('Provider disposed'));

      final result = await service.fetchCaborList(
        limit: params.limit,
        offset: params.offset,
        source: params.source,
        sort: params.sort,
        cancellation: cancellationController.token,
      );

      cancellationController.token.throwIfCancelled();

      final currentContext = ref.read(dataRequestContextProvider);
      if (!ref.mounted || currentContext != initialContext) {
        throw const RequestCancelledException(
          'Konteks sesi berubah saat memuat daftar cabor.',
        );
      }

      return result;
    }, retry: (retryCount, error) => null);

/// Resolve direct links through the paginated contract, within the active session.
final caborByIdProvider = FutureProvider.family<Cabor?, int>((ref, id) async {
  if (id <= 0) return null;
  final initialContext = ref.watch(dataRequestContextProvider);
  if (initialContext == null) {
    throw const RequestCancelledException(
      'Sesi tidak aktif atau telah berakhir.',
    );
  }
  var offset = 0;
  while (true) {
    final page = await ref.watch(
      caborListProvider((
        offset: offset,
        limit: 100,
        source: 'all',
        sort: 'name',
      )).future,
    );
    if (!ref.mounted ||
        ref.read(dataRequestContextProvider) != initialContext) {
      throw const RequestCancelledException(
        'Konteks sesi berubah saat memuat cabor.',
      );
    }
    for (final item in page.items) {
      if (item.id == id) return item;
    }
    if (!page.hasMore || page.items.isEmpty) return null;
    offset += page.items.length;
  }
}, retry: (retryCount, error) => null);

final class CaborPaginationState {
  const CaborPaginationState({
    this.items = const [],
    this.total = 0,
    this.hasMore = false,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.error,
    this.loadMoreError,
    this.source = 'all',
    this.sort = 'name',
  });

  final List<Cabor> items;
  final int total;
  final bool hasMore;
  final bool isLoading;
  final bool isLoadingMore;
  final Object? error;
  final Object? loadMoreError;
  final String source;
  final String sort;

  bool get canLoadMore => !isLoading && !isLoadingMore && hasMore;

  CaborPaginationState copyWith({
    List<Cabor>? items,
    int? total,
    bool? hasMore,
    bool? isLoading,
    bool? isLoadingMore,
    Object? error,
    Object? loadMoreError,
    String? source,
    String? sort,
  }) {
    return CaborPaginationState(
      items: items ?? this.items,
      total: total ?? this.total,
      hasMore: hasMore ?? this.hasMore,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      error: error,
      loadMoreError: loadMoreError,
      source: source ?? this.source,
      sort: sort ?? this.sort,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CaborPaginationState &&
          runtimeType == other.runtimeType &&
          listEquals(items, other.items) &&
          total == other.total &&
          hasMore == other.hasMore &&
          isLoading == other.isLoading &&
          isLoadingMore == other.isLoadingMore &&
          error == other.error &&
          loadMoreError == other.loadMoreError &&
          source == other.source &&
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
    source,
    sort,
  );
}

class CaborPaginationController extends Notifier<CaborPaginationState> {
  static const int pageSize = 25;

  int _generation = 0;

  @override
  CaborPaginationState build() {
    ref.watch(dataRequestContextProvider);
    return const CaborPaginationState();
  }

  Future<void> loadFirstPage({
    String source = 'all',
    String sort = 'name',
  }) async {
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
      source: source,
      sort: sort,
    );
    try {
      final result = await ref.refresh(
        caborListProvider((
          offset: 0,
          limit: pageSize,
          source: source,
          sort: sort,
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
        caborListProvider((
          offset: state.items.length,
          limit: pageSize,
          source: state.source,
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

  Future<void> refresh() =>
      loadFirstPage(source: state.source, sort: state.sort);
}

final caborPaginationProvider =
    NotifierProvider<CaborPaginationController, CaborPaginationState>(
      CaborPaginationController.new,
    );
