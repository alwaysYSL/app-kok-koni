import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/theme.dart';
import '../data/models.dart';
import '../shared/widgets.dart';
import 'sport_detail/sport_brand_palette.dart';

class SportsPage extends StatefulWidget {
  const SportsPage({super.key});

  @override
  State<SportsPage> createState() => _SportsPageState();
}

class _SportsPageState extends State<SportsPage> {
  bool _isExpanded = false;

  String _displaySportName(String sport) {
    if (sport.toLowerCase() == 'voli') return 'Bola Voli';
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
        final allSports = data.clubs.map((c) => c.sport).toSet().toList()
          ..sort();

        final athletesPerSport = <String, List<SportPerson>>{};
        final coachesPerSport = <String, int>{};
        final clubsPerSport = <String, List<Club>>{};

        final sportByClubId = {for (final c in data.clubs) c.id: c.sport};

        for (final c in data.clubs) {
          clubsPerSport.putIfAbsent(c.sport, () => []).add(c);
        }

        for (final p in data.people) {
          final sport = sportByClubId[p.clubId];
          if (sport == null) continue;
          if (p.role == 'Atlet') {
            athletesPerSport.putIfAbsent(sport, () => []).add(p);
          } else if (p.role == 'Pelatih') {
            coachesPerSport[sport] = (coachesPerSport[sport] ?? 0) + 1;
          }
        }

        final totalAthletes = allSports.fold<int>(
          0,
          (sum, s) => sum + (athletesPerSport[s]?.length ?? 0),
        );

        final maxCount = allSports.fold<int>(1, (max, s) {
          final count = athletesPerSport[s]?.length ?? 0;
          return count > max ? count : max;
        });

        final sortedSports = List<String>.from(allSports)
          ..sort((a, b) {
            final countA = athletesPerSport[a]?.length ?? 0;
            final countB = athletesPerSport[b]?.length ?? 0;
            final cmp = countB.compareTo(countA);
            if (cmp != 0) return cmp;
            return a.compareTo(b);
          });

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Header Ringkas (Model 1)
              _buildCompactHeader(allSports.length, totalAthletes),
              const SizedBox(height: 14),

              // 2. Kartu Sebaran Atlet Horizontal (Format A)
              _buildHorizontalDistributionCard(
                context,
                sortedSports,
                athletesPerSport,
                maxCount,
              ),
              const SizedBox(height: 16),

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
              if (allSports.isEmpty)
                const EmptyState(
                  message: 'Belum ada cabang olahraga terdaftar.',
                ),
              ...allSports.map((sport) {
                final displayName = _displaySportName(sport);
                final clubs = clubsPerSport[sport] ?? [];
                final athletes = athletesPerSport[sport] ?? [];
                final coaches = coachesPerSport[sport] ?? 0;
                final missingAthletes = athletes
                    .where((a) => a.missingDocuments.isNotEmpty)
                    .length;

                return Surface(
                  padding: const EdgeInsets.all(14),
                  onTap: () =>
                      context.push('/sport/${Uri.encodeComponent(sport)}'),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          SportAvatar(sport),
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
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 4,
                                  children: [
                                    _buildMetricChip('${clubs.length} Klub'),
                                    _buildMetricChip(
                                      '${athletes.length} Atlet',
                                    ),
                                    _buildMetricChip('$coaches Pelatih'),
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
                      if (missingAthletes > 0) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.warning_amber_rounded,
                                size: 14,
                                color: Color(0xFFDC2626),
                              ),
                              const SizedBox(width: 5),
                              Flexible(
                                child: Text(
                                  '$missingAthletes atlet berkas kurang',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFFDC2626),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              }),
            ],
          ),
        );
      },
    ),
  );

  Widget _buildCompactHeader(int totalSports, int totalAthletes) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Cabang Olahraga Aktif',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: KokColors.cardTitle,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Kecamatan Garut Kota',
                  style: TextStyle(
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
    List<String> sortedSports,
    Map<String, List<SportPerson>> athletesPerSport,
    int maxCount,
  ) {
    final displayedSports = _isExpanded
        ? sortedSports
        : sortedSports.take(5).toList();

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
          const SizedBox(height: 14),
          ...displayedSports.map((sport) {
            final count = athletesPerSport[sport]?.length ?? 0;
            final palette = SportBrandPaletteResolver.resolve(sport);
            final ratio = maxCount > 0
                ? (count / maxCount).clamp(0.0, 1.0)
                : 0.0;

            return InkWell(
              onTap: () => context.push('/sport/${Uri.encodeComponent(sport)}'),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    SizedBox(
                      width: 92,
                      child: Text(
                        _displaySportName(sport),
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
          if (sortedSports.length > 5) ...[
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
                        : 'Tampilkan ${sortedSports.length - 5} cabor lainnya ▾',
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
