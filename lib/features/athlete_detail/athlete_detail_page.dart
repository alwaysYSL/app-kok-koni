import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../data/models.dart';
import '../../shared/widgets.dart';
import '../club_detail/club_brand_palette.dart';
import '../detail_pages.dart';

typedef PersonDetailPage = AthleteDetailPage;

class AthleteDetailPage extends StatelessWidget {
  const AthleteDetailPage({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context) {
    return DataView(
      builder: (data) {
        final matches = data.people.where((p) => p.id == id);
        if (matches.isEmpty) return const MissingPage();

        final person = matches.first;
        final club = data.clubs.firstWhere(
          (c) => c.id == person.clubId,
          orElse: () => Club(
            id: person.clubId,
            name: 'Klub ${person.clubId}',
            sport: 'Olahraga',
            village: 'Garut Kota',
          ),
        );

        final coachMatches = data.people.where(
          (p) => p.clubId == club.id && p.role == 'Pelatih',
        );
        final coachName = coachMatches.isNotEmpty
            ? coachMatches.first.name
            : 'Pelatih ${club.name}';

        final palette = ClubBrandPaletteResolver.resolve(club);

        return Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          body: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _HeaderAndCardSection(
                  person: person,
                  club: club,
                  palette: palette,
                  coachName: coachName,
                ),
                const SizedBox(height: 16),
                _DocumentChecklistSection(person: person, palette: palette),
                const SizedBox(height: 16),
                _HistoryTimelineSection(
                  person: person,
                  club: club,
                  palette: palette,
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
          bottomNavigationBar: _StickyBottomBar(
            club: club,
            palette: palette,
          ),
        );
      },
    );
  }
}

class _HeaderAndCardSection extends StatelessWidget {
  const _HeaderAndCardSection({
    required this.person,
    required this.club,
    required this.palette,
    required this.coachName,
  });

  final SportPerson person;
  final Club club;
  final ClubBrandPalette palette;
  final String coachName;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: 170,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [palette.headerStart, palette.headerEnd],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 126, 16, 0),
          child: _ProfileCard(
            person: person,
            club: club,
            palette: palette,
            coachName: coachName,
          ),
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.chevron_left,
                      color: palette.foreground,
                      size: 28,
                    ),
                    onPressed: () {
                      if (context.canPop()) {
                        context.pop();
                      } else {
                        context.go('/home');
                      }
                    },
                  ),
                  Text(
                    'Detail ${person.role}',
                    style: TextStyle(
                      color: palette.foreground,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.share_outlined,
                      color: palette.foreground,
                      size: 24,
                    ),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Tautan profil ${person.name} disalin ke clipboard.',
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.person,
    required this.club,
    required this.palette,
    required this.coachName,
  });

  final SportPerson person;
  final Club club;
  final ClubBrandPalette palette;
  final String coachName;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.topCenter,
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
            border: Border.all(color: const Color(0xFFF1F5F9)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 52, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                person.name,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF0C2464),
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'ID SICABOR · ATL-${person.id}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF6B7280),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 10),
              Center(child: _buildStatusBadge(person)),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 14),
                child: DashedDivider(color: Color(0xFFE5E7EB)),
              ),
              _buildDetailRow(
                icon: Icons.groups_outlined,
                label: 'Klub',
                value: club.name,
                palette: palette,
              ),
              _buildDetailRow(
                icon: Icons.emoji_events_outlined,
                label: 'Cabor',
                value: club.sport,
                palette: palette,
              ),
              _buildDetailRow(
                icon: Icons.badge_outlined,
                label: 'Kelompok',
                value: person.group,
                palette: palette,
              ),
              _buildDetailRow(
                icon: Icons.cake_outlined,
                label: 'Lahir / Usia',
                value: person.age != null ? '${person.age} tahun' : '16 tahun',
                palette: palette,
              ),
              _buildDetailRow(
                icon: Icons.place_outlined,
                label: 'Alamat',
                value: '${club.village}, Kec. Garut Kota',
                palette: palette,
              ),
              _buildDetailRow(
                icon: Icons.sports_outlined,
                label: 'Pelatih',
                value: coachName,
                palette: palette,
              ),
            ],
          ),
        ),
        Positioned(
          top: -44,
          child: _AvatarCircle(person: person, palette: palette),
        ),
      ],
    );
  }

  Widget _buildStatusBadge(SportPerson person) {
    final String statusText;
    final Color statusBg;
    final Color statusFg;

    if (person.missingDocuments.isNotEmpty) {
      statusText = 'berkas kurang';
      statusBg = const Color(0xFFFEE2E2);
      statusFg = const Color(0xFFDC2626);
    } else if (person.expiredLicense) {
      statusText = 'lisensi kedaluwarsa';
      statusBg = const Color(0xFFFEE2E2);
      statusFg = const Color(0xFFDC2626);
    } else {
      statusText = 'terverifikasi';
      statusBg = const Color(0xFFD1FAE5);
      statusFg = const Color(0xFF059669);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: statusBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        statusText,
        style: TextStyle(
          color: statusFg,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
    required ClubBrandPalette palette,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: palette.softAccent,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 16, color: palette.headerStart),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF6B7280),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Container(
            width: 1,
            height: 14,
            color: const Color(0xFFE5E7EB),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Color(0xFF0C2464),
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AvatarCircle extends StatelessWidget {
  const _AvatarCircle({required this.person, required this.palette});

  final SportPerson person;
  final ClubBrandPalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 88,
      height: 88,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipOval(
        child: person.photoUrl != null && person.photoUrl!.isNotEmpty
            ? Image.network(
                person.photoUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _fallbackAvatar(),
              )
            : _fallbackAvatar(),
      ),
    );
  }

  Widget _fallbackAvatar() {
    final words = person.name.trim().split(RegExp(r'\s+'));
    final initials = words
        .where((w) => w.isNotEmpty)
        .take(2)
        .map((w) => w[0].toUpperCase())
        .join();

    return Container(
      color: palette.fallbackAvatar,
      alignment: Alignment.center,
      child: Text(
        initials.isNotEmpty ? initials : '?',
        style: const TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w800,
          color: Color(0xFF0C2464),
        ),
      ),
    );
  }
}

class _DocumentChecklistSection extends StatelessWidget {
  const _DocumentChecklistSection({
    required this.person,
    required this.palette,
  });

  final SportPerson person;
  final ClubBrandPalette palette;

  static const _standardDocs = [
    'KTP / KIA',
    'Kartu Keluarga',
    'Akta kelahiran',
    'Surat sehat',
  ];

  @override
  Widget build(BuildContext context) {
    final completeCount = _standardDocs
        .where((d) => !person.missingDocuments.contains(d))
        .length;
    final progress = completeCount / _standardDocs.length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              'KELENGKAPAN BERKAS',
              style: TextStyle(
                color: Color(0xFF0C2464),
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
              border: Border.all(color: const Color(0xFFF1F5F9)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Kelengkapan dokumen',
                      style: TextStyle(
                        color: Color(0xFF0C2464),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '$completeCount dari ${_standardDocs.length}',
                      style: const TextStyle(
                        color: Color(0xFF0C2464),
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 6,
                    backgroundColor: const Color(0xFFE5E7EB),
                    valueColor:
                        AlwaysStoppedAnimation<Color>(palette.headerStart),
                  ),
                ),
                const SizedBox(height: 14),
                for (var i = 0; i < _standardDocs.length; i++) ...[
                  if (i > 0)
                    const Divider(
                      height: 16,
                      thickness: 0.8,
                      color: Color(0xFFF1F5F9),
                    ),
                  _buildDocRow(
                    doc: _standardDocs[i],
                    isMissing: person.missingDocuments.contains(_standardDocs[i]),
                  ),
                ],
                if (person.role == 'Pelatih') ...[
                  const Divider(
                    height: 16,
                    thickness: 0.8,
                    color: Color(0xFFF1F5F9),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Lisensi',
                        style: TextStyle(
                          color: Color(0xFF1F2937),
                          fontSize: 13.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: person.expiredLicense
                              ? const Color(0xFFFEE2E2)
                              : const Color(0xFFD1FAE5),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          person.expiredLicense ? 'Kedaluwarsa' : 'Aktif',
                          style: TextStyle(
                            color: person.expiredLicense
                                ? const Color(0xFFDC2626)
                                : const Color(0xFF059669),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocRow({required String doc, required bool isMissing}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            doc,
            style: const TextStyle(
              color: Color(0xFF1F2937),
              fontSize: 13.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: isMissing
                ? const Color(0xFFFEF3C7)
                : const Color(0xFFE8F0FE),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            isMissing ? 'belum' : '✓ ada',
            style: TextStyle(
              color: isMissing
                  ? const Color(0xFFD97706)
                  : const Color(0xFF1B4F9E),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _HistoryTimelineSection extends StatelessWidget {
  const _HistoryTimelineSection({
    required this.person,
    required this.club,
    required this.palette,
  });

  final SportPerson person;
  final Club club;
  final ClubBrandPalette palette;

  @override
  Widget build(BuildContext context) {
    final milestones = [
      ('2026', 'Porkot Garut, ${person.group}'),
      ('2025', 'Kejuaraan Antar Klub'),
      ('2024', 'Masuk ${club.name}'),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              'RIWAYAT',
              style: TextStyle(
                color: Color(0xFF0C2464),
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
              border: Border.all(color: const Color(0xFFF1F5F9)),
            ),
            child: Column(
              children: [
                for (var i = 0; i < milestones.length; i++) ...[
                  if (i > 0)
                    const Divider(
                      height: 18,
                      thickness: 0.8,
                      color: Color(0xFFF1F5F9),
                    ),
                  Row(
                    children: [
                      Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: palette.softAccent,
                          border: Border.all(
                            color: palette.headerStart.withValues(alpha: 0.3),
                            width: 1,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: palette.headerStart,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        milestones[i].$1,
                        style: const TextStyle(
                          color: Color(0xFF0C2464),
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          milestones[i].$2,
                          style: const TextStyle(
                            color: Color(0xFF374151),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StickyBottomBar extends StatelessWidget {
  const _StickyBottomBar({required this.club, required this.palette});

  final Club club;
  final ClubBrandPalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
      ),
      child: SafeArea(
        top: false,
        child: FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: palette.headerStart,
            foregroundColor: palette.foreground,
            minimumSize: const Size.fromHeight(50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 0,
          ),
          onPressed: () => _showClubContactModal(context, club, palette),
          icon: Icon(
            Icons.chat_bubble_outline,
            color: palette.foreground,
            size: 20,
          ),
          label: Text(
            'Hubungi pengurus klub',
            style: TextStyle(
              color: palette.foreground,
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
        ),
      ),
    );
  }

  static void _showClubContactModal(
    BuildContext context,
    Club club,
    ClubBrandPalette palette,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE5E7EB),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Sekretariat Klub',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0C2464),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  club.name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF374151),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.place_outlined,
                            size: 20,
                            color: Color(0xFF6B7280),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              '${club.village}, Kec. Garut Kota',
                              style: const TextStyle(
                                fontSize: 13.5,
                                color: Color(0xFF1F2937),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 16, color: Color(0xFFE5E7EB)),
                      const Row(
                        children: [
                          Icon(
                            Icons.phone_outlined,
                            size: 20,
                            color: Color(0xFF6B7280),
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              '0812-3456-7890',
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1F2937),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: palette.headerStart,
                    foregroundColor: palette.foreground,
                    minimumSize: const Size.fromHeight(46),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () => Navigator.of(sheetContext).pop(),
                  icon: Icon(Icons.close, color: palette.foreground, size: 18),
                  label: Text(
                    'Tutup',
                    style: TextStyle(
                      color: palette.foreground,
                      fontWeight: FontWeight.w600,
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
}
