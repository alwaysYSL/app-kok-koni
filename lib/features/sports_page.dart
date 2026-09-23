import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/auth/presentation/auth_controller.dart';
import '../core/theme.dart';
import '../data/models/cabor.dart';
import '../data/providers/cabor_providers.dart';
import '../data/providers/profile_providers.dart';
import '../data/providers/snapshot_provider.dart';
import '../shared/widgets.dart';
import 'sport_detail/sport_brand_palette.dart';

class SportsPage extends ConsumerStatefulWidget {
  const SportsPage({super.key});

  @override
  ConsumerState<SportsPage> createState() => _SportsPageState();
}

class _SportsPageState extends ConsumerState<SportsPage> {
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(caborPaginationProvider.notifier).loadFirstPage(),
    );
  }

  String _displaySportName(String sport) {
    final lower = sport.toLowerCase().trim();
    if (lower == 'voli') return 'Bola Voli';
    return lower
        .split(' ')
        .map((word) {
          if (word.isEmpty) return '';
          return word[0].toUpperCase() + word.substring(1);
        })
        .join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final caborState = ref.watch(caborPaginationProvider);
    final summaryAsync = ref.watch(profileSummaryProvider);
    final summary = summaryAsync.asData?.value;
    final user = ref.watch(currentUserProvider);
    final contextScope = ref.watch(dataRequestContextProvider)?.scope;

    final scopeName =
        summary?.scope.subdistrictName ??
        user?.scope.name ??
        contextScope?.name ??
        'KONI Garut';

    final totalSports = caborState.total > 0
        ? caborState.total
        : (summary?.totalCabor ?? caborState.items.length);

    final totalAthletes =
        summary?.totalAthlete ??
        caborState.items.fold<int>(0, (sum, c) => sum + c.totalAthlete);

    final sortedCabors = List<Cabor>.from(caborState.items)
      ..sort((a, b) {
        final cmp = b.totalAthlete.compareTo(a.totalAthlete);
        if (cmp != 0) return cmp;
        return a.name.compareTo(b.name);
      });

    final maxCount = caborState.items.fold<int>(1, (max, c) {
      return c.totalAthlete > max ? c.totalAthlete : max;
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cabang Olahraga'),
        shape: const Border(
          bottom: BorderSide(color: Color(0xFFE5E7EB), width: 1),
        ),
      ),
      body: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification.metrics.pixels >=
                  notification.metrics.maxScrollExtent - 200 &&
              caborState.hasMore &&
              !caborState.isLoading &&
              !caborState.isLoadingMore) {
            ref.read(caborPaginationProvider.notifier).loadMore();
          }
          return false;
        },
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(profileSummaryProvider);
            await ref.read(caborPaginationProvider.notifier).refresh();
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Header Ringkas
                _buildCompactHeader(
                  totalSports: totalSports,
                  totalAthletes: totalAthletes,
                  scopeName: scopeName,
                ),
                const SizedBox(height: 14),

                // 2. Kartu Sebaran Atlet Horizontal
                if (caborState.items.isNotEmpty) ...[
                  _buildHorizontalDistributionCard(
                    context,
                    sortedCabors,
                    maxCount,
                    loadedCount: caborState.items.length,
                    totalCount: caborState.total > 0
                        ? caborState.total
                        : (summary?.totalCabor ?? caborState.items.length),
                  ),
                  const SizedBox(height: 16),
                ],

                // 3. Direktori Cabor
                const Text(
                  'Direktori cabor',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: KokColors.cardTitle,
                  ),
                ),
                const SizedBox(height: 10),

                if (caborState.isLoading && caborState.items.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (caborState.error != null && caborState.items.isEmpty)
                  () {
                    final presentation = describeRemoteError(caborState.error!);
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.cloud_off_outlined,
                              size: 40,
                              color: KokColors.muted,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              presentation.message,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: KokColors.muted),
                            ),
                            if (presentation.canRetry) ...[
                              const SizedBox(height: 8),
                              FilledButton(
                                onPressed: () => ref
                                    .read(caborPaginationProvider.notifier)
                                    .loadFirstPage(),
                                child: const Text('Coba lagi'),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  }()
                else if (caborState.items.isEmpty)
                  const EmptyState(
                    message: 'Belum ada cabang olahraga terdaftar.',
                  )
                else ...[
                  ...caborState.items.map((cabor) {
                    final displayName = _displaySportName(cabor.name);
                    return Surface(
                      padding: const EdgeInsets.all(14),
                      onTap: () => context.push('/sport/${cabor.id}'),
                      child: Row(
                        children: [
                          _buildCaborAvatar(cabor),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  displayName,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: KokColors.cardTitle,
                                  ),
                                ),
                                if (cabor.groupName != null &&
                                    cabor.groupName!.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    cabor.groupName!,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: KokColors.bluePrimary,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 4,
                                  children: [
                                    _buildMetricChip('${cabor.totalClub} Klub'),
                                    _buildMetricChip(
                                      '${cabor.totalAthlete} Atlet',
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(
                            Icons.chevron_right,
                            size: 20,
                            color: KokColors.bluePrimary,
                          ),
                        ],
                      ),
                    );
                  }),
                  if (caborState.isLoadingMore)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  if (caborState.loadMoreError != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Center(
                        child: OutlinedButton.icon(
                          onPressed: () => ref
                              .read(caborPaginationProvider.notifier)
                              .loadMore(),
                          icon: const Icon(Icons.refresh, size: 16),
                          label: const Text('Gagal memuat lagi. Coba lagi'),
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCaborAvatar(Cabor cabor) {
    if (cabor.logoUrl != null && cabor.logoUrl!.trim().isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          cabor.logoUrl!,
          width: 44,
          height: 44,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => SportAvatar(cabor.name),
        ),
      );
    }
    return SportAvatar(cabor.name);
  }

  Widget _buildCompactHeader({
    required int totalSports,
    required int totalAthletes,
    required String scopeName,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Cabang Olahraga',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: KokColors.cardTitle,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  scopeName,
                  style: const TextStyle(
                    fontSize: 13,
                    color: KokColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: KokColors.pale,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$totalSports Cabor · $totalAthletes Atlet',
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: KokColors.bluePrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHorizontalDistributionCard(
    BuildContext context,
    List<Cabor> sortedCabors,
    int maxCount, {
    required int loadedCount,
    required int totalCount,
  }) {
    final displayedCabors = _isExpanded
        ? sortedCabors
        : sortedCabors.take(5).toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'SEBARAN ATLET PER CABANG OLAHRAGA',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: KokColors.textSecondary,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Berdasarkan cabor yang sudah dimuat ($loadedCount dari $totalCount)',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: KokColors.textSecondary,
            ),
          ),
          const SizedBox(height: 14),
          ...displayedCabors.map((cabor) {
            final count = cabor.totalAthlete;
            final palette = SportBrandPaletteResolver.resolve(cabor.name);
            final ratio = maxCount > 0
                ? (count / maxCount).clamp(0.0, 1.0)
                : 0.0;

            return InkWell(
              onTap: () => context.push('/sport/${cabor.id}'),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    SizedBox(
                      width: 92,
                      child: Text(
                        _displaySportName(cabor.name),
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: KokColors.cardTitle,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Stack(
                        children: [
                          Container(
                            height: 12,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF3F4F6),
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          FractionallySizedBox(
                            widthFactor: ratio < 0.04 && count > 0
                                ? 0.04
                                : ratio,
                            child: Container(
                              height: 12,
                              decoration: BoxDecoration(
                                color: palette.chartColor,
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 60,
                      child: Text(
                        '$count atlet',
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: KokColors.cardTitle,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
          if (sortedCabors.length > 5) ...[
            const SizedBox(height: 8),
            InkWell(
              onTap: () => setState(() => _isExpanded = !_isExpanded),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Center(
                  child: Text(
                    _isExpanded
                        ? 'Sembunyikan ▴'
                        : 'Tampilkan ${sortedCabors.length - 5} cabor lainnya ▾',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: KokColors.bluePrimary,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMetricChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: KokColors.textSecondary,
        ),
      ),
    );
  }
}
