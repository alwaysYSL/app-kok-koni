import 'package:flutter/material.dart';
import 'package:kok_app/features/dashboard_decorations.dart';

import '../../data/models.dart';
import '../../shared/widgets.dart';
import 'club_brand_palette.dart';

class ClubDetailHeader extends StatelessWidget {
  const ClubDetailHeader({
    super.key,
    required this.club,
    required this.palette,
    required this.athleteCount,
    required this.coachCount,
    required this.officialCount,
    required this.missingFileCount,
    required this.onBack,
    required this.onShare,
    this.excludeClubNameSemantics = false,
  });

  final Club club;
  final ClubBrandPalette palette;
  final int athleteCount;
  final int coachCount;
  final int officialCount;
  final int missingFileCount;
  final VoidCallback onBack;
  final VoidCallback onShare;
  final bool excludeClubNameSemantics;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [palette.headerStart, palette.headerEnd],
      ),
    ),
    child: CustomPaint(
      painter: const BrandHeaderPatternPainter(),
      child: SafeArea(
        bottom: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: SizedBox(
                height: 48,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      onPressed: onBack,
                      tooltip: 'Kembali',
                      color: palette.foreground,
                      icon: const Icon(
                        Icons.chevron_left,
                        size: 28,
                      ),
                    ),
                    IconButton(
                      onPressed: onShare,
                      tooltip: 'Bagikan info klub',
                      color: palette.foreground,
                      icon: const Icon(Icons.share_outlined, size: 24),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(height: 88, child: Center(child: _buildLogo())),
            const SizedBox(height: 8),
            ExcludeSemantics(
              excluding: excludeClubNameSemantics,
              child: Semantics(
                container: true,
                label: club.name,
                child: ExcludeSemantics(
                  child: Text(
                    club.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: palette.foreground,
                      fontSize: 22,
                      height: 1.15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${club.sport} · ${club.foundedYear == null ? 'tahun berdiri belum tersedia' : 'berdiri ${club.foundedYear}'}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: palette.foreground,
                fontSize: 12,
                height: 1.3,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              '${club.registrationNumber ?? 'SK belum tersedia'} · Kel. ${club.village}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: palette.foreground,
                fontSize: 12,
                height: 1.3,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.center,
              runAlignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                _HeaderBadge(
                  label: club.active ? 'AKTIF' : 'TIDAK AKTIF',
                  background: club.active
                      ? const Color(0xFFDDF6E6)
                      : const Color(0xFFE9ECF2),
                  foreground: club.active
                      ? const Color(0xFF176B38)
                      : const Color(0xFF4B5563),
                ),
                if (missingFileCount > 0)
                  _HeaderBadge(
                    label: '$missingFileCount berkas kurang',
                    background: const Color(0xFFFFE7E7),
                    foreground: const Color(0xFFB42318),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            SizedBox(
              height: 48,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _StatColumn(
                      value: athleteCount,
                      label: 'ATLET',
                      foreground: palette.foreground,
                    ),
                  ),
                  _StatDivider(color: palette.foreground),
                  Expanded(
                    child: _StatColumn(
                      value: coachCount,
                      label: 'PELATIH',
                      foreground: palette.foreground,
                    ),
                  ),
                  _StatDivider(color: palette.foreground),
                  Expanded(
                    child: _StatColumn(
                      value: officialCount,
                      label: 'OFFICIAL',
                      foreground: palette.foreground,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ],
  ),
),
),
);

  Widget _buildLogo() {
    final logoUrl = club.logoUrl?.trim();
    if (logoUrl == null || logoUrl.isEmpty) return _fallbackLogo();

    return Semantics(
      label: 'Logo ${club.name}',
      image: true,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Image.network(
          logoUrl,
          width: 88,
          height: 88,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) => _fallbackLogo(),
        ),
      ),
    );
  }

  Widget _fallbackLogo() => Semantics(
    label: 'Logo fallback ${club.name}',
    image: true,
    child: ExcludeSemantics(
      child: Container(
        width: 88,
        height: 88,
        decoration: BoxDecoration(
          color: palette.fallbackAvatar,
          shape: BoxShape.circle,
          border: Border.all(color: palette.foreground.withValues(alpha: 0.28)),
        ),
        child: Icon(sportIcon(club.sport), size: 44, color: palette.foreground),
      ),
    ),
  );
}

class _HeaderBadge extends StatelessWidget {
  const _HeaderBadge({
    required this.label,
    required this.background,
    required this.foreground,
  });

  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      label,
      style: TextStyle(
        color: foreground,
        fontSize: 11,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}

class _StatColumn extends StatelessWidget {
  const _StatColumn({
    required this.value,
    required this.label,
    required this.foreground,
  });

  final int value;
  final String label;
  final Color foreground;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Text(
        '$value',
        style: TextStyle(
          color: foreground,
          fontSize: 21,
          height: 1,
          fontWeight: FontWeight.w800,
        ),
      ),
      const SizedBox(height: 5),
      Text(
        label,
        maxLines: 1,
        style: TextStyle(
          color: foreground,
          fontSize: 10,
          height: 1,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
    ],
  );
}

class _StatDivider extends StatelessWidget {
  const _StatDivider({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => Center(
    child: Container(width: 1, height: 34, color: color.withValues(alpha: 0.3)),
  );
}
