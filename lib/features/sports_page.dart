import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/theme.dart';
import '../data/models.dart';
import '../shared/widgets.dart';
import 'dashboard_decorations.dart';
import 'sport_detail/sport_brand_palette.dart';

class SportsPage extends StatefulWidget {
  const SportsPage({super.key});

  @override
  State<SportsPage> createState() => _SportsPageState();
}

class _SportsPageState extends State<SportsPage> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _shortSportLabel(String sport) {
    final lower = sport.toLowerCase();
    if (lower.contains('silat')) return 'Pencak Silat';
    if (lower.contains('sepak') || (lower.contains('bola') && !lower.contains('voli'))) {
      return 'Sepak Bola';
    }
    if (lower.contains('tangkis') || lower.contains('badminton')) {
      return 'B. Tangkis';
    }
    if (lower.contains('voli')) return 'Voli';
    if (lower.contains('renang')) return 'Renang';
    return sport;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Cabang Olahraga'),
      shape: const Border(
        bottom: BorderSide(color: Color(0xFFE5E7EB), width: 1),
      ),
    ),
    body: DataView(
      builder: (data) {
        final allSports = data.clubs.map((c) => c.sport).toSet().toList()..sort();
        final queryTrimmed = _query.trim().toLowerCase();
        final filteredSports = allSports.where(
          (s) => s.toLowerCase().contains(queryTrimmed),
        ).toList();

        final athletesPerSport = <String, List<SportPerson>>{};
        final coachesPerSport = <String, int>{};
        final clubsPerSport = <String, List<Club>>{};

        for (final sport in allSports) {
          final clubs = data.clubs.where((c) => c.sport == sport).toList();
          clubsPerSport[sport] = clubs;
          final clubIds = clubs.map((c) => c.id).toSet();
          final people = data.people.where((p) => clubIds.contains(p.clubId)).toList();
          athletesPerSport[sport] = people.where((p) => p.role == 'Atlet').toList();
          coachesPerSport[sport] = people.where((p) => p.role == 'Pelatih').length;
        }

        final totalAthletes = allSports.fold<int>(
          0,
          (sum, s) => sum + (athletesPerSport[s]?.length ?? 0),
        );

        final maxCount = allSports.fold<int>(
          1,
          (max, s) {
            final count = athletesPerSport[s]?.length ?? 0;
            return count > max ? count : max;
          },
        );

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // 1. Header Eksekutif
            _buildExecutiveHeader(allSports.length),

            // 2. Kartu Analitik Sebaran Atlet (hanya jika query kosong)
            if (queryTrimmed.isEmpty) ...[
              _buildAnalyticsCard(
                context,
                allSports,
                athletesPerSport,
                totalAthletes,
                maxCount,
              ),
            ],

            // 3. Kolom Pencarian
            TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: 'Cari cabang olahraga...',
                prefixIcon: const Icon(Icons.search, color: KokColors.muted),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 20, color: KokColors.muted),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFD4D8E0)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFD4D8E0)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: KokColors.blue, width: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 4. Daftar Cabor
            const SectionHead('Direktori cabor'),
            if (filteredSports.isEmpty)
              const EmptyState(message: 'Tidak ada cabang olahraga yang sesuai.'),
            ...filteredSports.map((sport) {
              final clubs = clubsPerSport[sport] ?? [];
              final athletes = athletesPerSport[sport] ?? [];
              final coaches = coachesPerSport[sport] ?? 0;
              final verifiedCount = athletes
                  .where((a) => a.verified && a.missingDocuments.isEmpty)
                  .length;
              final docRatio = athletes.isEmpty ? 1.0 : verifiedCount / athletes.length;
              final docPercent = (docRatio * 100).toInt();

              return Surface(
                onTap: () => context.push(
                  '/sport/${Uri.encodeComponent(sport)}',
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        SportAvatar(sport),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                sport,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: KokColors.cardTitle,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                '${clubs.length} klub · ${athletes.length} atlet · $coaches pelatih',
                                style: const TextStyle(
                                  color: KokColors.muted,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right, color: KokColors.bluePrimary),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: docRatio,
                              minHeight: 5,
                              backgroundColor: const Color(0xFFE5E7EB),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                docRatio >= 1.0
                                    ? const Color(0xFF16A34A)
                                    : (docRatio >= 0.7
                                        ? KokColors.blue
                                        : KokColors.yellow),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '$docPercent% Berkas',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: docRatio >= 1.0
                                ? const Color(0xFF16A34A)
                                : KokColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
            const DemoNote(),
          ],
        );
      },
    ),
  );

  Widget _buildExecutiveHeader(int count) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            KokColors.deepNavy,
            KokColors.navy,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: KokColors.navy.withValues(alpha: 0.16),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: CustomPaint(
          painter: const BrandHeaderPatternPainter(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'DIREKTORI CABANG OLAHRAGA',
                    style: TextStyle(
                      color: Colors.white,
                      letterSpacing: 1.1,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '$count Cabang Olahraga Aktif',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Pemetaan potensi pembinaan atlet & klub se-Kecamatan Garut Kota',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAnalyticsCard(
    BuildContext context,
    List<String> allSports,
    Map<String, List<SportPerson>> athletesPerSport,
    int totalAthletes,
    int maxCount,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
        border: Border.all(color: const Color(0xFFF1F3F7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  'SEBARAN ATLET PER CABANG OLAHRAGA',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: KokColors.muted,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: KokColors.pale,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '$totalAthletes Atlet',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: KokColors.blue,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 140,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: (maxCount * 1.25).ceilToDouble(),
                barTouchData: BarTouchData(
                  enabled: true,
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => KokColors.navy,
                    tooltipPadding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    tooltipMargin: 8,
                    fitInsideHorizontally: true,
                    fitInsideVertically: true,
                    tooltipBorderRadius: BorderRadius.circular(8),
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final sport = allSports[group.x];
                      final count = rod.toY.toInt();
                      final percent = totalAthletes > 0
                          ? ((count / totalAthletes) * 100).toStringAsFixed(1)
                          : '0';
                      return BarTooltipItem(
                        '$sport\n',
                        const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                        children: [
                          TextSpan(
                            text: '$count atlet ($percent%)',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                              fontWeight: FontWeight.normal,
                            ),
                          ),
                        ],
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
                      reservedSize: 22,
                      interval: 10,
                      getTitlesWidget: (value, meta) {
                        if (value == 0 || value > maxCount * 1.15) {
                          return const SizedBox.shrink();
                        }
                        return Text(
                          value.toInt().toString(),
                          style: const TextStyle(
                            color: KokColors.muted,
                            fontSize: 9,
                            fontWeight: FontWeight.w500,
                          ),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index < 0 || index >= allSports.length) {
                          return const SizedBox.shrink();
                        }
                        final sport = allSports[index];
                        final shortLabel = _shortSportLabel(sport);
                        return SideTitleWidget(
                          meta: meta,
                          space: 4,
                          child: GestureDetector(
                            onTap: () => context.push(
                              '/sport/${Uri.encodeComponent(sport)}',
                            ),
                            child: Text(
                              shortLabel,
                              style: const TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w600,
                                color: KokColors.cardTitle,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                gridData: const FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 10,
                ),
                borderData: FlBorderData(show: false),
                barGroups: List.generate(allSports.length, (index) {
                  final sport = allSports[index];
                  final count = athletesPerSport[sport]?.length ?? 0;
                  final palette = SportBrandPaletteResolver.resolve(sport);
                  return BarChartGroupData(
                    x: index,
                    barRods: [
                      BarChartRodData(
                        toY: count.toDouble(),
                        color: palette.chartColor,
                        width: 16,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(4),
                        ),
                        backDrawRodData: BackgroundBarChartRodData(
                          show: true,
                          toY: (maxCount * 1.25).ceilToDouble(),
                          color: const Color(0xFFF8FAFC),
                        ),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),
          const SizedBox(height: 10),
          _buildTopSportsSummary(context, allSports, athletesPerSport),
        ],
      ),
    );
  }

  Widget _buildTopSportsSummary(
    BuildContext context,
    List<String> allSports,
    Map<String, List<SportPerson>> athletesPerSport,
  ) {
    final sorted = List<String>.from(allSports)
      ..sort((a, b) {
        final countA = athletesPerSport[a]?.length ?? 0;
        final countB = athletesPerSport[b]?.length ?? 0;
        return countB.compareTo(countA);
      });

    final topTwo = sorted.take(2).toList();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'CABOR DENGAN ATLET TERBANYAK:',
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              color: KokColors.muted,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: topTwo.map((sport) {
              final count = athletesPerSport[sport]?.length ?? 0;
              final palette = SportBrandPaletteResolver.resolve(sport);
              return Expanded(
                child: GestureDetector(
                  onTap: () => context.push(
                    '/sport/${Uri.encodeComponent(sport)}',
                  ),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: palette.softAccent),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: palette.chartColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            sport,
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: KokColors.cardTitle,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$count',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: palette.chartColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
