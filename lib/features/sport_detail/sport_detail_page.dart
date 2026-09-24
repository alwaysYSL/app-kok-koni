import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/presentation/auth_controller.dart';
import '../../core/composition/app_composition.dart';
import '../../core/config/deployment_profile.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../data/models/athlete.dart';
import '../../data/models/club.dart' as domain;
import '../../data/providers/athlete_providers.dart';
import '../../data/providers/cabor_providers.dart';
import '../../data/providers/club_providers.dart';
import '../../data/providers/profile_providers.dart';
import '../../shared/widgets.dart';
import '../../shared/detail_header_lip.dart';
import '../dashboard_decorations.dart';
import 'sport_brand_palette.dart';

bool _isRemoteMode(WidgetRef ref) {
  try {
    return ref.watch(appCompositionProvider).profile.dataMode ==
        DataMode.remote;
  } catch (_) {
    return false;
  }
}

class SportDetailPage extends ConsumerStatefulWidget {
  const SportDetailPage({super.key, required this.sport});

  final String sport;

  @override
  ConsumerState<SportDetailPage> createState() => _SportDetailPageState();
}

class _SportDetailPageState extends ConsumerState<SportDetailPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final TextEditingController _athleteSearchController =
      TextEditingController();

  int _analyticMode =
      0; // 0: Kelompok Usia (BarChart), 1: Status Berkas (PieChart)
  String _selectedAgeGroup = 'Semua';
  String _athleteQuery = '';

  static const _ageGroups = ['Semua', 'U-14', 'U-16', 'U-18', 'Senior'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _athleteSearchController.dispose();
    super.dispose();
  }

  String _getAgeCategory(SportPerson person) {
    final group = person.group.toUpperCase();
    if (group.contains('U-14') || group.contains('U14')) return 'U-14';
    if (group.contains('U-16') || group.contains('U16')) return 'U-16';
    if (group.contains('U-18') || group.contains('U18')) return 'U-18';
    if (group.contains('SENIOR')) return 'Senior';
    if (person.age != null) {
      if (person.age! < 14) return 'U-14';
      if (person.age! <= 16) return 'U-16';
      if (person.age! <= 18) return 'U-18';
      return 'Senior';
    }
    return 'Senior';
  }

  Future<void> _copySummary({
    required String sportName,
    required String scopeName,
    int clubCount = 0,
    int athleteCount = 0,
    int coachCount = 0,
    int verifiedCount = 0,
  }) async {
    final user = ref.read(currentUserProvider);
    if (!(user?.hasPermission('reports:export') ?? false)) return;
    final pct = athleteCount > 0
        ? ((verifiedCount / athleteCount) * 100).round()
        : 100;
    final summary =
        '''
REKAPITULASI CABANG OLAHRAGA
Cabang Olahraga : $sportName
Wilayah         : $scopeName
Jumlah Klub     : $clubCount
Total Atlet     : $athleteCount
Total Pelatih   : $coachCount
Status Berkas   : $verifiedCount/$athleteCount Lengkap ($pct%)
''';
    await Clipboard.setData(ClipboardData(text: summary.trim()));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Rekapitulasi cabor $sportName berhasil disalin ke papan klip.',
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final canExport = user?.hasPermission('reports:export') ?? false;

    if (_isRemoteMode(ref)) {
      final id = int.tryParse(widget.sport) ?? 0;
      final detail = ref.watch(caborByIdProvider(id));
      final summary = ref.watch(profileSummaryProvider).asData?.value;
      final scopeName =
          summary?.scope.subdistrictName ?? user?.scope.name ?? 'KONI Garut';
      return detail.when(
        skipLoadingOnRefresh: false,
        loading: () => Scaffold(
          appBar: AppBar(title: const Text('Cabang Olahraga')),
          body: const Center(child: CircularProgressIndicator()),
        ),
        error: (error, stack) {
          final presentation = describeRemoteError(error);
          return Scaffold(
            appBar: AppBar(title: const Text('Cabang Olahraga')),
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(presentation.message, textAlign: TextAlign.center),
                  if (presentation.canRetry)
                    TextButton(
                      onPressed: () {
                        ref.invalidate(caborListProvider);
                        ref.invalidate(caborByIdProvider(id));
                      },
                      child: const Text('Coba Lagi'),
                    ),
                ],
              ),
            ),
          );
        },
        data: (cabor) {
          if (cabor == null) {
            return Scaffold(
              appBar: AppBar(title: const Text('Cabang Olahraga')),
              body: const Center(
                child: Text('Cabang olahraga tidak ditemukan.'),
              ),
            );
          }
          final palette = SportBrandPaletteResolver.resolve(cabor.name);
          return DefaultTabController(
            key: ValueKey(cabor.id),
            length: 2,
            child: Scaffold(
              backgroundColor: Colors.white,
              body: LayoutBuilder(
                builder: (context, constraints) {
                  // Keep search/filter controls and results usable when the keyboard
                  // or landscape orientation leaves a short viewport.
                  final height = constraints.maxHeight < 600
                      ? 600.0
                      : constraints.maxHeight;
                  return SingleChildScrollView(
                    child: SizedBox(
                      height: height,
                      child: Column(
                        children: [
                          DetailHeaderLip(
                            header: Container(
                              width: double.infinity,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    palette.headerStart,
                                    palette.headerEnd,
                                  ],
                                ),
                              ),
                              child: SafeArea(
                                bottom: false,
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    0,
                                    16,
                                    40,
                                  ),
                                  child: Column(
                                    children: [
                                      Align(
                                        alignment: Alignment.centerLeft,
                                        child: IconButton(
                                          tooltip: 'Kembali',
                                          icon: const Icon(
                                            Icons.chevron_left,
                                            color: Colors.white,
                                          ),
                                          onPressed: () {
                                            if (context.canPop()) {
                                              context.pop();
                                            } else {
                                              context.go('/sports');
                                            }
                                          },
                                        ),
                                      ),
                                      Text(
                                        cabor.name,
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      if (cabor.groupName?.trim().isNotEmpty ??
                                          false)
                                        Text(
                                          cabor.groupName!,
                                          style: const TextStyle(
                                            color: Colors.white,
                                          ),
                                        ),
                                      Text(
                                        scopeName,
                                        style: const TextStyle(
                                          color: Colors.white70,
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceEvenly,
                                        children: [
                                          Expanded(
                                            child: Column(
                                              children: [
                                                Text(
                                                  '${cabor.totalAthlete}',
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 24,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                const Text(
                                                  'Atlet di kecamatan',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.white70,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Expanded(
                                            child: Column(
                                              children: [
                                                Text(
                                                  '${cabor.totalClub}',
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 24,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                const Text(
                                                  'Klub di kecamatan',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.white70,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                            child: Container(
                              decoration: BoxDecoration(
                                color: palette.softAccent,
                                borderRadius: BorderRadius.circular(24),
                              ),
                              child: TabBar(
                                indicatorSize: TabBarIndicatorSize.tab,
                                dividerColor: Colors.transparent,
                                labelColor: palette.chartColor,
                                unselectedLabelColor: KokColors.muted,
                                indicator: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(24),
                                ),
                                tabs: const [
                                  Tab(text: 'Atlet'),
                                  Tab(text: 'Klub'),
                                ],
                              ),
                            ),
                          ),
                          Expanded(
                            child: TabBarView(
                              children: [
                                _RemoteAthletesTab(
                                  caborId: cabor.id,
                                  palette: palette,
                                ),
                                _RemoteClubsTab(
                                  caborId: cabor.id,
                                  palette: palette,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          );
        },
      );
    }

    return DataView(
      builder: (data) {
        final allSports = data.clubs.map((c) => c.sport).toSet().toList()
          ..sort();
        final sportId = int.tryParse(widget.sport);
        final String targetSport;
        if (sportId != null && sportId >= 1 && sportId <= allSports.length) {
          targetSport = allSports[sportId - 1];
        } else {
          final decoded = Uri.decodeComponent(widget.sport);
          targetSport = allSports.firstWhere(
            (s) =>
                s.toLowerCase() == decoded.toLowerCase() ||
                s.toLowerCase() == widget.sport.toLowerCase(),
            orElse: () => decoded,
          );
        }

        final palette = SportBrandPaletteResolver.resolve(targetSport);

        final clubs = data.clubs
            .where((c) => c.sport.toLowerCase() == targetSport.toLowerCase())
            .toList();
        final clubIds = clubs.map((c) => c.id).toSet();
        final clubMap = {for (final c in clubs) c.id: c};

        final peopleInSport = data.people
            .where((p) => clubIds.contains(p.clubId))
            .toList();
        final athletes = peopleInSport.where((p) => p.role == 'Atlet').toList();
        final coaches = peopleInSport
            .where((p) => p.role == 'Pelatih' || p.role == 'Official')
            .toList();

        final verifiedAthletes = athletes
            .where((a) => a.verified && a.missingDocuments.isEmpty)
            .toList();
        final verifiedCount = verifiedAthletes.length;

        final filteredAthletes = athletes.where((a) {
          if (_selectedAgeGroup != 'Semua') {
            final cat = _getAgeCategory(a);
            if (cat != _selectedAgeGroup) return false;
          }
          if (_athleteQuery.isNotEmpty) {
            if (!a.name.toLowerCase().contains(_athleteQuery.toLowerCase())) {
              return false;
            }
          }
          return true;
        }).toList();

        return Scaffold(
          backgroundColor: const Color(0xFFF4F6FA),
          body: NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) {
              return [
                SliverToBoxAdapter(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildHeader(
                        context,
                        palette,
                        sportName: targetSport,
                        scopeName: data.scope.name,
                        canExport: canExport,
                        clubCount: clubs.length,
                        athleteCount: athletes.length,
                        coachCount: coaches.length,
                        verifiedCount: verifiedCount,
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                        child: _buildFloatingStatsCard(
                          clubs.length,
                          athletes.length,
                          coaches.length,
                          verifiedCount,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                        child: _buildAnalyticsCard(palette, athletes),
                      ),
                    ],
                  ),
                ),
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _SliverTabBarDelegate(_buildTabBar(palette)),
                ),
              ];
            },
            body: TabBarView(
              controller: _tabController,
              children: [
                _buildClubsTab(clubs, data, palette),
                _buildAthletesTab(filteredAthletes, clubMap, palette),
                _buildCoachesTab(coaches, palette),
              ],
            ),
          ),
          bottomNavigationBar: _buildStickyBottomBar(
            sportName: targetSport,
            clubCount: clubs.length,
            athleteCount: athletes.length,
            coachCount: coaches.length,
            verifiedCount: verifiedCount,
            palette: palette,
            scopeName: data.scope.name,
            canExport: canExport,
          ),
        );
      },
    );
  }

  Widget _buildHeader(
    BuildContext context,
    SportBrandPalette palette, {
    required String sportName,
    required String scopeName,
    required bool canExport,
    required int clubCount,
    required int athleteCount,
    required int coachCount,
    required int verifiedCount,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [palette.headerStart, palette.headerEnd],
        ),
      ),
      child: CustomPaint(
        painter: const BrandHeaderPatternPainter(),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.chevron_left,
                        size: 28,
                        color: Colors.white,
                      ),
                      tooltip: 'Kembali',
                      onPressed: () {
                        if (context.canPop()) {
                          context.pop();
                        } else {
                          context.go('/sports');
                        }
                      },
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.share_outlined,
                        size: 24,
                        color: canExport ? Colors.white : Colors.white38,
                      ),
                      tooltip: canExport
                          ? 'Bagikan info cabor'
                          : 'Akses ekspor laporan tidak diizinkan',
                      onPressed: canExport
                          ? () => _copySummary(
                              sportName: sportName,
                              scopeName: scopeName,
                              clubCount: clubCount,
                              athleteCount: athleteCount,
                              coachCount: coachCount,
                              verifiedCount: verifiedCount,
                            )
                          : null,
                    ),
                  ],
                ),
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.18),
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: Icon(
                    sportIcon(sportName),
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  sportName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  scopeName,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingStatsCard(
    int clubCount,
    int athleteCount,
    int coachCount,
    int verifiedCount,
  ) {
    final pct = athleteCount > 0
        ? ((verifiedCount / athleteCount) * 100).round()
        : 100;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildStatItem(
              value: '$clubCount',
              label: 'Klub',
              onTap: () => _tabController.animateTo(0),
            ),
          ),
          _buildVerticalDivider(),
          Expanded(
            child: _buildStatItem(
              value: '$athleteCount',
              label: 'Atlet',
              onTap: () => _tabController.animateTo(1),
            ),
          ),
          _buildVerticalDivider(),
          Expanded(
            child: _buildStatItem(
              value: '$coachCount',
              label: 'Pelatih',
              onTap: () => _tabController.animateTo(2),
            ),
          ),
          _buildVerticalDivider(),
          Expanded(
            child: _buildStatItem(
              value: '$pct%',
              label: 'Berkas Lengkap',
              onTap: () => _tabController.animateTo(1),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required String value,
    required String label,
    required VoidCallback onTap,
  }) {
    const labelStyle = TextStyle(
      fontSize: 12,
      color: KokColors.muted,
      fontWeight: FontWeight.w600,
    );

    final labelWidget = Text(label, style: labelStyle);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: KokColors.cardTitle,
            ),
          ),
          const SizedBox(height: 2),
          labelWidget,
        ],
      ),
    );
  }

  Widget _buildVerticalDivider() {
    return Container(width: 1, height: 22, color: const Color(0xFFE5E7EB));
  }

  Widget _buildAnalyticsCard(
    SportBrandPalette palette,
    List<SportPerson> athletes,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _buildToggleChip(
                  label: 'Kelompok Usia',
                  selected: _analyticMode == 0,
                  palette: palette,
                  onTap: () => setState(() => _analyticMode = 0),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildToggleChip(
                  label: 'Status Berkas',
                  selected: _analyticMode == 1,
                  palette: palette,
                  onTap: () => setState(() => _analyticMode = 1),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 95,
            child: _analyticMode == 0
                ? _buildAgeBarChart(palette, athletes)
                : _buildDocumentPieChart(palette, athletes),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleChip({
    required String label,
    required bool selected,
    required SportBrandPalette palette,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? palette.softAccent : const Color(0xFFF4F6FA),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? palette.chartColor : const Color(0xFFE5E7EB),
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? palette.chartColor : KokColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildAgeBarChart(
    SportBrandPalette palette,
    List<SportPerson> athletes,
  ) {
    final u14 = athletes.where((a) => _getAgeCategory(a) == 'U-14').length;
    final u16 = athletes.where((a) => _getAgeCategory(a) == 'U-16').length;
    final u18 = athletes.where((a) => _getAgeCategory(a) == 'U-18').length;
    final senior = athletes.where((a) => _getAgeCategory(a) == 'Senior').length;
    final counts = [u14, u16, u18, senior];
    final maxCount = counts.fold<int>(1, (m, c) => c > m ? c : m);

    const labels = ['U14', 'U16', 'U18', 'Senior'];

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: (maxCount * 1.25).ceilToDouble(),
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => KokColors.navy,
            tooltipPadding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 4,
            ),
            tooltipMargin: 6,
            fitInsideHorizontally: true,
            fitInsideVertically: true,
            tooltipBorderRadius: BorderRadius.circular(6),
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final groupName = labels[group.x];
              final count = rod.toY.toInt();
              return BarTooltipItem(
                '$groupName: $count atlet',
                const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 20,
              interval: maxCount > 6 ? (maxCount / 2).ceilToDouble() : 2,
              getTitlesWidget: (value, meta) {
                if (value == 0 || value > maxCount * 1.15) {
                  return const SizedBox.shrink();
                }
                return Text(
                  value.toInt().toString(),
                  style: const TextStyle(color: KokColors.muted, fontSize: 12),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 18,
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx < 0 || idx >= 4) return const SizedBox.shrink();
                return Text(
                  labels[idx],
                  style: const TextStyle(
                    color: KokColors.cardTitle,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                );
              },
            ),
          ),
        ),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        barGroups: List.generate(4, (i) {
          return BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: counts[i].toDouble(),
                color: palette.chartColor,
                width: 18,
                borderRadius: BorderRadius.circular(4),
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildDocumentPieChart(
    SportBrandPalette palette,
    List<SportPerson> athletes,
  ) {
    final verifiedCount = athletes
        .where((a) => a.verified && a.missingDocuments.isEmpty)
        .length;
    final missingCount = athletes.length - verifiedCount;

    final missingDocs = <String>{};
    for (final a in athletes) {
      missingDocs.addAll(a.missingDocuments);
    }

    return Row(
      children: [
        SizedBox(
          width: 90,
          height: 90,
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 22,
              sections: [
                PieChartSectionData(
                  color: const Color(0xFF16A34A),
                  value:
                      (verifiedCount > 0
                              ? verifiedCount
                              : (missingCount == 0 ? 1 : 0))
                          .toDouble(),
                  title: athletes.isEmpty
                      ? '100%'
                      : '${((verifiedCount / (athletes.isEmpty ? 1 : athletes.length)) * 100).round()}%',
                  radius: 22,
                  titleStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                PieChartSectionData(
                  color: KokColors.red,
                  value: missingCount.toDouble(),
                  title: missingCount > 0 && athletes.isNotEmpty
                      ? '${((missingCount / athletes.length) * 100).round()}%'
                      : '',
                  radius: 22,
                  titleStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegendRow(
                const Color(0xFF16A34A),
                'Lengkap: $verifiedCount atlet',
              ),
              const SizedBox(height: 4),
              _buildLegendRow(
                KokColors.red,
                'Berkas Kurang: $missingCount atlet',
              ),
              if (missingDocs.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  'Dokumen kurang: ${missingDocs.join(', ')}',
                  style: const TextStyle(fontSize: 12, color: KokColors.muted),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLegendRow(Color color, String text) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: KokColors.cardTitle,
            ),
          ),
        ),
      ],
    );
  }

  TabBar _buildTabBar(SportBrandPalette palette) {
    return TabBar(
      controller: _tabController,
      indicatorColor: palette.chartColor,
      labelColor: KokColors.cardTitle,
      unselectedLabelColor: KokColors.muted,
      labelStyle: const TextStyle(
        fontFamily: 'KokSans',
        fontWeight: FontWeight.w700,
        fontSize: 13,
      ),
      tabs: const [
        Tab(text: 'Klub'),
        Tab(text: 'Atlet'),
        Tab(text: 'Pelatih'),
      ],
    );
  }

  Widget _buildClubsTab(
    List<Club> clubs,
    KokSnapshot data,
    SportBrandPalette palette,
  ) {
    if (clubs.isEmpty) {
      return const EmptyState(
        message: 'Belum ada klub terdaftar pada cabor ini.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      itemCount: clubs.length,
      itemBuilder: (context, index) {
        final club = clubs[index];
        final clubAthletes = data.people
            .where((p) => p.clubId == club.id && p.role == 'Atlet')
            .length;

        return InkWell(
          onTap: () => context.push('/club/${club.id}'),
          borderRadius: BorderRadius.circular(14),
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: palette.softAccent,
                  child: Icon(
                    Icons.shield_outlined,
                    color: palette.chartColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        club.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: KokColors.cardTitle,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Kel. ${club.village} · $clubAthletes atlet',
                        style: const TextStyle(
                          fontSize: 12,
                          color: KokColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.chevron_right,
                  color: KokColors.muted,
                  size: 20,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAthletesTab(
    List<SportPerson> athletes,
    Map<String, Club> clubMap,
    SportBrandPalette palette,
  ) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
          child: TextField(
            controller: _athleteSearchController,
            onChanged: (val) => setState(() => _athleteQuery = val),
            decoration: InputDecoration(
              hintText: 'Cari nama atlet...',
              prefixIcon: const Icon(
                Icons.search,
                size: 20,
                color: KokColors.muted,
              ),
              suffixIcon: _athleteQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        _athleteSearchController.clear();
                        setState(() => _athleteQuery = '');
                      },
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFD4D8E0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFD4D8E0)),
              ),
            ),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: _ageGroups.map((group) {
              final isSelected = _selectedAgeGroup == group;
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: FilterChip(
                  label: Text(group),
                  selected: isSelected,
                  onSelected: (_) => setState(() => _selectedAgeGroup = group),
                  selectedColor: palette.softAccent,
                  labelStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected
                        ? palette.chartColor
                        : KokColors.cardTitle,
                  ),
                  backgroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: isSelected
                          ? palette.chartColor
                          : const Color(0xFFE5E7EB),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 6),
        Expanded(
          child: athletes.isEmpty
              ? const EmptyState(
                  message: 'Tidak ada atlet yang sesuai dengan filter.',
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  itemCount: athletes.length,
                  itemBuilder: (context, index) {
                    final athlete = athletes[index];
                    final isComplete =
                        athlete.verified && athlete.missingDocuments.isEmpty;

                    return InkWell(
                      onTap: () => context.push('/person/${athlete.id}'),
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE5E7EB)),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: palette.softAccent,
                              child: Text(
                                athlete.name.isNotEmpty ? athlete.name[0] : 'A',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: palette.chartColor,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    athlete.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                      color: KokColors.cardTitle,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    '${clubMap[athlete.clubId]?.name ?? 'Klub'} · ${athlete.group}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: KokColors.muted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: isComplete
                                    ? const Color(0xFFDCFCE7)
                                    : const Color(0xFFFFE7E7),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    isComplete
                                        ? Icons.check_circle
                                        : Icons.warning_amber_rounded,
                                    size: 12,
                                    color: isComplete
                                        ? const Color(0xFF16A34A)
                                        : KokColors.red,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    isComplete ? 'Lengkap' : 'Kurang',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: isComplete
                                          ? const Color(0xFF16A34A)
                                          : KokColors.red,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildCoachesTab(
    List<SportPerson> coaches,
    SportBrandPalette palette,
  ) {
    if (coaches.isEmpty) {
      return const EmptyState(
        message: 'Belum ada pelatih terdaftar pada cabor ini.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      itemCount: coaches.length,
      itemBuilder: (context, index) {
        final coach = coaches[index];

        return InkWell(
          onTap: () => context.push('/person/${coach.id}'),
          borderRadius: BorderRadius.circular(14),
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: palette.softAccent,
                  child: Icon(
                    Icons.sports,
                    color: palette.chartColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        coach.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: KokColors.cardTitle,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${coach.role} · ${coach.group}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: KokColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: coach.expiredLicense
                        ? const Color(0xFFFFE7E7)
                        : const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    coach.expiredLicense ? 'Kedaluwarsa' : 'Aktif',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: coach.expiredLicense
                          ? KokColors.red
                          : const Color(0xFF16A34A),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStickyBottomBar({
    required String sportName,
    required int clubCount,
    required int athleteCount,
    required int coachCount,
    required int verifiedCount,
    required SportBrandPalette palette,
    required String scopeName,
    required bool canExport,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      child: SafeArea(
        child: SizedBox(
          height: 48,
          child: FilledButton.icon(
            onPressed: canExport
                ? () => _copySummary(
                    sportName: sportName,
                    scopeName: scopeName,
                    clubCount: clubCount,
                    athleteCount: athleteCount,
                    coachCount: coachCount,
                    verifiedCount: verifiedCount,
                  )
                : null,
            icon: const Icon(Icons.copy_rounded, size: 18),
            label: const Text('Salin Rekapitulasi Cabor'),
            style: FilledButton.styleFrom(
              backgroundColor: palette.chartColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverTabBarDelegate(this.tabBar);
  final TabBar tabBar;

  @override
  double get minExtent => tabBar.preferredSize.height;
  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(color: const Color(0xFFF4F6FA), child: tabBar);
  }

  @override
  bool shouldRebuild(_SliverTabBarDelegate oldDelegate) => false;
}

class _RemoteAthletesTab extends ConsumerStatefulWidget {
  const _RemoteAthletesTab({required this.caborId, required this.palette});

  final int? caborId;
  final SportBrandPalette palette;

  @override
  ConsumerState<_RemoteAthletesTab> createState() => _RemoteAthletesTabState();
}

class _RemoteAthletesTabState extends ConsumerState<_RemoteAthletesTab> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _debounceTimer;

  static const _sexFilterOptions = [
    (label: 'Semua', value: null),
    (label: 'Laki-Laki', value: 'l'),
    (label: 'Perempuan', value: 'p'),
  ];

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (mounted) {
        ref
            .read(
              athletePaginationProvider((
                idCabor: widget.caborId,
                idClub: null,
              )).notifier,
            )
            .loadFirstPage();
      }
    });
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.hasClients &&
        _scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200) {
      ref
          .read(
            athletePaginationProvider((
              idCabor: widget.caborId,
              idClub: null,
            )).notifier,
          )
          .loadMore();
    }
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      if (mounted) {
        ref
            .read(
              athletePaginationProvider((
                idCabor: widget.caborId,
                idClub: null,
              )).notifier,
            )
            .updateSearch(query);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(
      athletePaginationProvider((idCabor: widget.caborId, idClub: null)),
    );
    final controller = ref.read(
      athletePaginationProvider((
        idCabor: widget.caborId,
        idClub: null,
      )).notifier,
    );

    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
          child: TextField(
            controller: _searchController,
            onChanged: (val) {
              setState(() {});
              _onSearchChanged(val);
            },
            decoration: InputDecoration(
              hintText: 'Cari nama atlet...',
              prefixIcon: const Icon(
                Icons.search,
                size: 20,
                color: KokColors.muted,
              ),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        _debounceTimer?.cancel();
                        _searchController.clear();
                        controller.updateSearch(null);
                        setState(() {});
                      },
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFD4D8E0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFD4D8E0)),
              ),
            ),
          ),
        ),

        // Filter chips (Jenis Kelamin)
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: _sexFilterOptions.map((opt) {
              final isSelected = state.sex == opt.value;
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: FilterChip(
                  label: Text(opt.label),
                  selected: isSelected,
                  onSelected: (_) => controller.updateSexFilter(opt.value),
                  selectedColor: widget.palette.softAccent,
                  labelStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected
                        ? widget.palette.chartColor
                        : KokColors.cardTitle,
                  ),
                  backgroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: isSelected
                          ? widget.palette.chartColor
                          : const Color(0xFFE5E7EB),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),

        // Filter Warning Banner (if present)
        if (state.hasFilterWarning)
          Container(
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFBFDBFE)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.info_outline,
                  color: Color(0xFF2563EB),
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    state.filterWarningMessage ?? '',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF1E40AF),
                    ),
                  ),
                ),
              ],
            ),
          ),

        const SizedBox(height: 6),

        // Content
        Expanded(child: _buildBody(state, controller)),
      ],
    );
  }

  Widget _buildBody(
    AthletePaginationState state,
    AthletePaginationController controller,
  ) {
    if (state.isLoading && state.items.isEmpty) {
      return const Center(child: CircularProgressIndicator.adaptive());
    }

    if (state.error != null && state.items.isEmpty) {
      final presentation = describeRemoteError(state.error!);
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: KokColors.red),
              const SizedBox(height: 12),
              const Text(
                'Gagal memuat data atlet',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: KokColors.cardTitle,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                presentation.message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: KokColors.muted),
              ),
              if (presentation.canRetry) ...[
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => controller.loadFirstPage(),
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Coba Lagi'),
                ),
              ],
            ],
          ),
        ),
      );
    }

    if (state.items.isEmpty) {
      return const SingleChildScrollView(
        child: EmptyState(
          message: 'Tidak ada atlet yang sesuai dengan filter.',
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => controller.refresh(),
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        itemCount:
            state.items.length +
            (state.isLoadingMore || state.loadMoreError != null ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == state.items.length) {
            if (state.isLoadingMore) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CircularProgressIndicator.adaptive()),
              );
            }
            if (state.loadMoreError != null) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Gagal memuat atlet berikutnya',
                      style: TextStyle(fontSize: 12, color: KokColors.muted),
                    ),
                    TextButton(
                      onPressed: () => controller.loadMore(),
                      child: const Text('Coba lagi'),
                    ),
                  ],
                ),
              );
            }
            return const SizedBox.shrink();
          }

          final athlete = state.items[index];
          return _buildAthleteCard(athlete);
        },
      ),
    );
  }

  Widget _buildAthleteCard(Athlete athlete) {
    return InkWell(
      onTap: () => context.push('/person/${athlete.id}'),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: widget.palette.softAccent,
              backgroundImage: athlete.photoUrl.isNotEmpty
                  ? NetworkImage(athlete.photoUrl)
                  : null,
              child: athlete.photoUrl.isEmpty
                  ? Text(
                      athlete.name.isNotEmpty ? athlete.name[0] : 'A',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: widget.palette.chartColor,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    athlete.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: KokColors.cardTitle,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    athlete.club?.name ?? 'Belum terdaftar di klub',
                    style: const TextStyle(
                      fontSize: 12,
                      color: KokColors.muted,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      if (athlete.code.trim().isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3F4F6),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            athlete.code.trim(),
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              color: KokColors.muted,
                            ),
                          ),
                        ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: widget.palette.softAccent,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          athlete.cabor.name,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: widget.palette.chartColor,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          athlete.sexLabel,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: KokColors.textSecondary,
                          ),
                        ),
                      ),
                      if (athlete.statusLabel.trim().isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: athlete.status == 1
                                ? const Color(0xFFDCFCE7)
                                : const Color(0xFFF3F4F6),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            athlete.statusLabel.trim(),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: athlete.status == 1
                                  ? const Color(0xFF16A34A)
                                  : KokColors.textSecondary,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, color: KokColors.muted, size: 20),
          ],
        ),
      ),
    );
  }
}

class _RemoteClubsTab extends ConsumerStatefulWidget {
  const _RemoteClubsTab({required this.caborId, required this.palette});

  final int? caborId;
  final SportBrandPalette palette;

  @override
  ConsumerState<_RemoteClubsTab> createState() => _RemoteClubsTabState();
}

class _RemoteClubsTabState extends ConsumerState<_RemoteClubsTab> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _debounceTimer;

  static const _statusFilterOptions = [
    (label: 'Semua', value: null),
    (label: 'Aktif', value: 1),
    (label: 'Belum Aktif', value: 0),
  ];

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (mounted) {
        ref
            .read(clubPaginationProvider(widget.caborId).notifier)
            .loadFirstPage();
      }
    });
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.hasClients &&
        _scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200) {
      ref.read(clubPaginationProvider(widget.caborId).notifier).loadMore();
    }
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      if (mounted) {
        ref
            .read(clubPaginationProvider(widget.caborId).notifier)
            .updateSearch(query);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(clubPaginationProvider(widget.caborId));
    final controller = ref.read(
      clubPaginationProvider(widget.caborId).notifier,
    );

    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
          child: TextField(
            controller: _searchController,
            onChanged: (val) {
              setState(() {});
              _onSearchChanged(val);
            },
            decoration: InputDecoration(
              hintText: 'Cari nama klub...',
              prefixIcon: const Icon(
                Icons.search,
                size: 20,
                color: KokColors.muted,
              ),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        _debounceTimer?.cancel();
                        _searchController.clear();
                        controller.updateSearch(null);
                        setState(() {});
                      },
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFD4D8E0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFD4D8E0)),
              ),
            ),
          ),
        ),

        // Filter chips (Status)
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: _statusFilterOptions.map((opt) {
              final isSelected = state.status == opt.value;
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: FilterChip(
                  label: Text(opt.label),
                  selected: isSelected,
                  onSelected: (_) => controller.updateStatusFilter(opt.value),
                  selectedColor: widget.palette.softAccent,
                  labelStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected
                        ? widget.palette.chartColor
                        : KokColors.cardTitle,
                  ),
                  backgroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: isSelected
                          ? widget.palette.chartColor
                          : const Color(0xFFE5E7EB),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),

        // Filter Warning Banner (if present)
        if (state.hasFilterWarning)
          Container(
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFBFDBFE)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.info_outline,
                  color: Color(0xFF2563EB),
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    state.filterWarningMessage ?? '',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF1E40AF),
                    ),
                  ),
                ),
              ],
            ),
          ),

        const SizedBox(height: 6),

        // Content
        Expanded(child: _buildBody(state, controller)),
      ],
    );
  }

  Widget _buildBody(
    ClubPaginationState state,
    ClubPaginationController controller,
  ) {
    if (state.isLoading && state.items.isEmpty) {
      return const Center(child: CircularProgressIndicator.adaptive());
    }

    if (state.error != null && state.items.isEmpty) {
      final presentation = describeRemoteError(state.error!);
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: KokColors.red),
              const SizedBox(height: 12),
              const Text(
                'Gagal memuat data klub',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: KokColors.cardTitle,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                presentation.message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: KokColors.muted),
              ),
              if (presentation.canRetry) ...[
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => controller.loadFirstPage(),
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Coba Lagi'),
                ),
              ],
            ],
          ),
        ),
      );
    }

    if (state.items.isEmpty) {
      return const SingleChildScrollView(
        child: EmptyState(message: 'Tidak ada klub yang sesuai dengan filter.'),
      );
    }

    return RefreshIndicator(
      onRefresh: () => controller.refresh(),
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        itemCount:
            state.items.length +
            (state.isLoadingMore || state.loadMoreError != null ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == state.items.length) {
            if (state.isLoadingMore) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CircularProgressIndicator.adaptive()),
              );
            }
            if (state.loadMoreError != null) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Gagal memuat klub berikutnya',
                      style: TextStyle(fontSize: 12, color: KokColors.muted),
                    ),
                    TextButton(
                      onPressed: () => controller.loadMore(),
                      child: const Text('Coba lagi'),
                    ),
                  ],
                ),
              );
            }
            return const SizedBox.shrink();
          }

          final club = state.items[index];
          return _buildClubCard(club);
        },
      ),
    );
  }

  Widget _buildClubCard(domain.Club club) {
    return InkWell(
      onTap: () => context.push('/club/${club.id}'),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: widget.palette.softAccent,
              backgroundImage:
                  (club.logoUrl != null && club.logoUrl!.isNotEmpty)
                  ? NetworkImage(club.logoUrl!)
                  : null,
              child: (club.logoUrl == null || club.logoUrl!.isEmpty)
                  ? Text(
                      club.name.isNotEmpty ? club.name[0] : 'K',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: widget.palette.chartColor,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    club.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: KokColors.cardTitle,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (club.headName != null && club.headName!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Ketua: ${club.headName}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: KokColors.muted,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  if (club.secretariat.address != null &&
                      club.secretariat.address!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      club.secretariat.address!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: KokColors.muted,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ] else if (club.secretariat.subdistrictName.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Kec. ${club.secretariat.subdistrictName}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: KokColors.muted,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: widget.palette.softAccent,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          club.cabor.name,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: widget.palette.chartColor,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: club.status == 1
                              ? const Color(0xFFDCFCE7)
                              : const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          club.statusLabel,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: club.status == 1
                                ? const Color(0xFF16A34A)
                                : KokColors.textSecondary,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${club.totalAthleteInClub} Atlet',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: KokColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, color: KokColors.muted, size: 20),
          ],
        ),
      ),
    );
  }
}
