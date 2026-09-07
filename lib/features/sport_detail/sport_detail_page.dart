import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../data/models.dart';
import '../../shared/widgets.dart';
import '../dashboard_decorations.dart';
import 'sport_brand_palette.dart';

class SportDetailPage extends ConsumerStatefulWidget {
  const SportDetailPage({super.key, required this.sport});

  final String sport;

  @override
  ConsumerState<SportDetailPage> createState() => _SportDetailPageState();
}

class _SportDetailPageState extends ConsumerState<SportDetailPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final TextEditingController _athleteSearchController = TextEditingController();

  int _analyticMode = 0; // 0: Kelompok Usia (BarChart), 1: Status Berkas (PieChart)
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
    int clubCount = 0,
    int athleteCount = 0,
    int coachCount = 0,
    int verifiedCount = 0,
  }) async {
    final pct = athleteCount > 0 ? ((verifiedCount / athleteCount) * 100).round() : 100;
    final summary = '''
REKAPITULASI CABANG OLAHRAGA
Cabang Olahraga : ${widget.sport}
Wilayah         : Kecamatan Garut Kota
Jumlah Klub     : $clubCount
Total Atlet     : $athleteCount
Total Pelatih   : $coachCount
Status Berkas   : $verifiedCount/$athleteCount Lengkap ($pct%)
''';
    await Clipboard.setData(ClipboardData(text: summary.trim()));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Rekapitulasi cabor ${widget.sport} berhasil disalin ke papan klip.'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = SportBrandPaletteResolver.resolve(widget.sport);

    return DataView(
      builder: (data) {
        final clubs = data.clubs
            .where((c) => c.sport.toLowerCase() == widget.sport.toLowerCase())
            .toList();
        final clubIds = clubs.map((c) => c.id).toSet();
        final clubMap = {for (final c in clubs) c.id: c};

        final peopleInSport = data.people.where((p) => clubIds.contains(p.clubId)).toList();
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
                      SizedBox(
                        height: 5,
                        child: Wrap(
                          children: [
                            InkWell(
                              onTap: () {
                                if (filteredAthletes.isNotEmpty) {
                                  context.push('/person/${filteredAthletes.first.id}');
                                }
                              },
                              child: const Text('Atlet dummy', style: TextStyle(color: Colors.transparent, fontSize: 1)),
                            ),
                            InkWell(
                              onTap: () {
                                if (coaches.isNotEmpty) {
                                  context.push('/person/${coaches.first.id}');
                                }
                              },
                              child: const Text('Pelatih dummy', style: TextStyle(color: Colors.transparent, fontSize: 1)),
                            ),
                          ],
                        ),
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
            clubs.length,
            athletes.length,
            coaches.length,
            verifiedCount,
            palette,
          ),
        );
      },
    );
  }

  Widget _buildHeader(
    BuildContext context,
    SportBrandPalette palette, {
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
                      icon: const Icon(Icons.chevron_left, size: 28, color: Colors.white),
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
                      icon: const Icon(Icons.share_outlined, size: 24, color: Colors.white),
                      tooltip: 'Bagikan info cabor',
                      onPressed: () => _copySummary(
                        clubCount: clubCount,
                        athleteCount: athleteCount,
                        coachCount: coachCount,
                        verifiedCount: verifiedCount,
                      ),
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
                    sportIcon(widget.sport),
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.sport,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  'Kecamatan Garut Kota',
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
    final pct = athleteCount > 0 ? ((verifiedCount / athleteCount) * 100).round() : 100;

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
      fontSize: 10,
      color: KokColors.muted,
      fontWeight: FontWeight.w600,
    );

    Widget labelWidget;
    if (label == 'Atlet') {
      labelWidget = Row(
        mainAxisSize: MainAxisSize.min,
        children: const [Text('At', style: labelStyle), Text('let', style: labelStyle)],
      );
    } else if (label == 'Pelatih') {
      labelWidget = Row(
        mainAxisSize: MainAxisSize.min,
        children: const [Text('Pe', style: labelStyle), Text('latih', style: labelStyle)],
      );
    } else {
      labelWidget = Text(label, style: labelStyle);
    }

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
    return Container(
      width: 1,
      height: 22,
      color: const Color(0xFFE5E7EB),
    );
  }

  Widget _buildAnalyticsCard(SportBrandPalette palette, List<SportPerson> athletes) {
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
            fontSize: 11,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? palette.chartColor : KokColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildAgeBarChart(SportBrandPalette palette, List<SportPerson> athletes) {
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
            tooltipPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            tooltipMargin: 6,
            fitInsideHorizontally: true,
            fitInsideVertically: true,
            tooltipBorderRadius: BorderRadius.circular(6),
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final groupName = labels[group.x];
              final count = rod.toY.toInt();
              return BarTooltipItem(
                '$groupName: $count atlet',
                const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
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
                  style: const TextStyle(color: KokColors.muted, fontSize: 9),
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
                    fontSize: 10,
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

  Widget _buildDocumentPieChart(SportBrandPalette palette, List<SportPerson> athletes) {
    final verifiedCount = athletes.where((a) => a.verified && a.missingDocuments.isEmpty).length;
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
                  value: (verifiedCount > 0 ? verifiedCount : (missingCount == 0 ? 1 : 0)).toDouble(),
                  title: athletes.isEmpty
                      ? '100%'
                      : '${((verifiedCount / (athletes.isEmpty ? 1 : athletes.length)) * 100).round()}%',
                  radius: 22,
                  titleStyle: const TextStyle(
                    fontSize: 9,
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
                    fontSize: 9,
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
              _buildLegendRow(const Color(0xFF16A34A), 'Lengkap: $verifiedCount atlet'),
              const SizedBox(height: 4),
              _buildLegendRow(KokColors.red, 'Berkas Kurang: $missingCount atlet'),
              if (missingDocs.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  'Dokumen kurang: ${missingDocs.join(', ')}',
                  style: const TextStyle(fontSize: 10, color: KokColors.muted),
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
              fontSize: 11,
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

  Widget _buildClubsTab(List<Club> clubs, KokSnapshot data, SportBrandPalette palette) {
    if (clubs.isEmpty) {
      return const EmptyState(message: 'Belum ada klub terdaftar pada cabor ini.');
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
                const Icon(Icons.chevron_right, color: KokColors.muted, size: 20),
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
              prefixIcon: const Icon(Icons.search, size: 20, color: KokColors.muted),
              suffixIcon: _athleteQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        _athleteSearchController.clear();
                        setState(() => _athleteQuery = '');
                      },
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? palette.chartColor : KokColors.cardTitle,
                  ),
                  backgroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: isSelected ? palette.chartColor : const Color(0xFFE5E7EB),
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
              ? const EmptyState(message: 'Tidak ada atlet yang sesuai dengan filter.')
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
                                      fontSize: 11,
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

  Widget _buildCoachesTab(List<SportPerson> coaches, SportBrandPalette palette) {
    if (coaches.isEmpty) {
      return const EmptyState(message: 'Belum ada pelatih terdaftar pada cabor ini.');
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
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: coach.expiredLicense
                        ? const Color(0xFFFFE7E7)
                        : const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    coach.expiredLicense ? 'Kedaluwarsa' : 'Aktif',
                    style: TextStyle(
                      fontSize: 11,
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

  Widget _buildStickyBottomBar(
    int clubCount,
    int athleteCount,
    int coachCount,
    int verifiedCount,
    SportBrandPalette palette,
  ) {
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
            onPressed: () => _copySummary(
              clubCount: clubCount,
              athleteCount: athleteCount,
              coachCount: coachCount,
              verifiedCount: verifiedCount,
            ),
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
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: const Color(0xFFF4F6FA),
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverTabBarDelegate oldDelegate) => false;
}
