import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kok_app/features/dashboard_decorations.dart';

import '../../core/composition/app_composition.dart';
import '../../core/config/deployment_profile.dart';
import '../../core/network/api_exceptions.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../data/models/athlete.dart';
import '../../data/models/athlete_detail.dart';
import '../../data/providers/athlete_providers.dart';
import '../../shared/widgets.dart';
import '../club_detail/club_brand_palette.dart';
import '../detail_pages.dart';
import '../sport_detail/sport_brand_palette.dart';

typedef PersonDetailPage = AthleteDetailPage;

bool _isRemoteMode(WidgetRef ref) {
  try {
    return ref.watch(appCompositionProvider).profile.dataMode ==
        DataMode.remote;
  } catch (_) {
    return false;
  }
}

class AthleteDetailPage extends ConsumerWidget {
  const AthleteDetailPage({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (_isRemoteMode(ref)) {
      final athleteId = int.tryParse(id);
      if (athleteId == null) {
        return const MissingPage(message: 'Data atlet tidak ditemukan.');
      }

      final asyncDetail = ref.watch(athleteDetailProvider(athleteId));
      return asyncDetail.when(
        data: (detail) => _RemoteAthleteDetailContent(detail: detail),
        loading: () => const Scaffold(
          backgroundColor: Color(0xFFF8FAFC),
          body: Center(child: CircularProgressIndicator.adaptive()),
        ),
        error: (e, _) {
          if (e is NotFoundException) {
            return const MissingPage(message: 'Data atlet tidak ditemukan.');
          }
          return Scaffold(
            backgroundColor: const Color(0xFFF8FAFC),
            appBar: AppBar(
              title: const Text('Detail Atlet'),
              leading: IconButton(
                icon: const Icon(Icons.chevron_left, size: 28),
                onPressed: () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go('/sports');
                  }
                },
              ),
            ),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 48,
                      color: KokColors.red,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Gagal memuat detail atlet',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: KokColors.cardTitle,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '$e',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 13,
                        color: KokColors.muted,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () =>
                          ref.refresh(athleteDetailProvider(athleteId)),
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Coba Lagi'),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    }

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
            sport: '-',
            village: '-',
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
                _HistoryTimelineSection(person: person, palette: palette),
                const SizedBox(height: 24),
              ],
            ),
          ),
          bottomNavigationBar: _StickyBottomBar(club: club, palette: palette),
        );
      },
    );
  }
}

class _RemoteAthleteDetailContent extends StatelessWidget {
  const _RemoteAthleteDetailContent({required this.detail});

  final AthleteDetail detail;

  @override
  Widget build(BuildContext context) {
    final palette = SportBrandPaletteResolver.resolve(detail.cabor.name);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _RemoteHeaderAndCardSection(detail: detail, palette: palette),
            const SizedBox(height: 16),
            _RemotePhysicalDataSection(detail: detail, palette: palette),
            const SizedBox(height: 16),
            _RemoteContactAddressSection(detail: detail, palette: palette),
            const SizedBox(height: 24),
          ],
        ),
      ),
      bottomNavigationBar: detail.club != null
          ? _RemoteStickyBottomBar(club: detail.club!, palette: palette)
          : null,
    );
  }
}

class _RemoteHeaderAndCardSection extends StatelessWidget {
  const _RemoteHeaderAndCardSection({
    required this.detail,
    required this.palette,
  });

  final AthleteDetail detail;
  final SportBrandPalette palette;

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
            child: const CustomPaint(painter: BrandHeaderPatternPainter()),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 126, 16, 0),
          child: _RemoteProfileCard(detail: detail, palette: palette),
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
                    icon: const Icon(
                      Icons.chevron_left,
                      color: Colors.white,
                      size: 28,
                    ),
                    onPressed: () {
                      if (context.canPop()) {
                        context.pop();
                      } else {
                        context.go('/sports');
                      }
                    },
                  ),
                  const Expanded(
                    child: Text(
                      'Detail Atlet',
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.share_outlined,
                      color: Colors.white,
                      size: 24,
                    ),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Tautan profil ${detail.name} disalin ke clipboard.',
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

class _RemoteProfileCard extends StatelessWidget {
  const _RemoteProfileCard({required this.detail, required this.palette});

  final AthleteDetail detail;
  final SportBrandPalette palette;

  String _birthLabel(AthleteDetail detail) {
    final parts = <String>[];
    if (detail.pob != null && detail.pob!.trim().isNotEmpty) {
      parts.add(detail.pob!.trim());
    }
    if (detail.dob != null && detail.dob!.trim().isNotEmpty) {
      parts.add(detail.dob!.trim());
    }
    if (parts.isNotEmpty) {
      final base = parts.join(' · ');
      return detail.age != null ? '$base (${detail.age} thn)' : base;
    }
    return detail.age != null ? '${detail.age} tahun' : '-';
  }

  String _domicileLabel(AthleteDomicile domicile) {
    final village = domicile.village?.trim();
    if (village != null && village.isNotEmpty) {
      return '$village, ${domicile.subdistrictName}';
    }
    return '${domicile.subdistrictName}, ${domicile.districtName}';
  }

  @override
  Widget build(BuildContext context) {
    final bool isActive = detail.status == 1;

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
                detail.name,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: KokColors.cardTitle,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'ID · ${detail.code}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF6B7280),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 10),
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isActive
                        ? const Color(0xFFD1FAE5)
                        : const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    detail.statusLabel.toLowerCase(),
                    style: TextStyle(
                      color: isActive
                          ? const Color(0xFF059669)
                          : const Color(0xFFDC2626),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 14),
                child: DashedDivider(color: Color(0xFFE5E7EB)),
              ),
              _buildDetailRow(
                icon: Icons.groups_outlined,
                label: 'Klub',
                value: detail.club?.name ?? 'Belum terdaftar di klub',
                palette: palette,
              ),
              _buildDetailRow(
                icon: Icons.emoji_events_outlined,
                label: 'Cabor',
                value: detail.cabor.name,
                palette: palette,
              ),
              _buildDetailRow(
                icon: Icons.person_outline,
                label: 'Jenis Kelamin',
                value: detail.sexLabel,
                palette: palette,
              ),
              _buildDetailRow(
                icon: Icons.cake_outlined,
                label: 'Lahir / Usia',
                value: _birthLabel(detail),
                palette: palette,
              ),
              _buildDetailRow(
                icon: Icons.place_outlined,
                label: 'Domisili',
                value: _domicileLabel(detail.domicile),
                palette: palette,
              ),
            ],
          ),
        ),
        Positioned(
          top: -44,
          child: _RemoteAvatarCircle(
            photoUrl: detail.photoUrl,
            name: detail.name,
            palette: palette,
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
    required SportBrandPalette palette,
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
            width: 90,
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF6B7280),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Container(width: 1, height: 14, color: const Color(0xFFE5E7EB)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: KokColors.cardTitle,
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

class _RemoteAvatarCircle extends StatelessWidget {
  const _RemoteAvatarCircle({
    required this.photoUrl,
    required this.name,
    required this.palette,
  });

  final String photoUrl;
  final String name;
  final SportBrandPalette palette;

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
        child: photoUrl.isNotEmpty
            ? Image.network(
                photoUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _fallbackAvatar(),
              )
            : _fallbackAvatar(),
      ),
    );
  }

  Widget _fallbackAvatar() {
    final words = name.trim().split(RegExp(r'\s+'));
    final initials = words
        .where((w) => w.isNotEmpty)
        .take(2)
        .map((w) => w[0].toUpperCase())
        .join();

    return Container(
      color: palette.softAccent,
      alignment: Alignment.center,
      child: Text(
        initials.isNotEmpty ? initials : '?',
        style: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w800,
          color: palette.headerStart,
        ),
      ),
    );
  }
}

class _RemotePhysicalDataSection extends StatelessWidget {
  const _RemotePhysicalDataSection({
    required this.detail,
    required this.palette,
  });

  final AthleteDetail detail;
  final SportBrandPalette palette;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              'DATA FISIK',
              style: TextStyle(
                color: KokColors.cardTitle,
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
            child: Row(
              children: [
                Expanded(
                  child: _buildStatBox(
                    label: 'Tinggi Badan',
                    value: detail.height != null ? '${detail.height} cm' : '-',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatBox(
                    label: 'Berat Badan',
                    value: detail.weight != null ? '${detail.weight} kg' : '-',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatBox(
                    label: 'Golongan Darah',
                    value:
                        detail.bloodType != null &&
                            detail.bloodType!.trim().isNotEmpty
                        ? detail.bloodType!.trim()
                        : '-',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatBox({required String label, required String value}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Text(
            value,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: KokColors.cardTitle,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: Color(0xFF6B7280),
            ),
          ),
        ],
      ),
    );
  }
}

class _RemoteContactAddressSection extends StatelessWidget {
  const _RemoteContactAddressSection({
    required this.detail,
    required this.palette,
  });

  final AthleteDetail detail;
  final SportBrandPalette palette;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              'KONTAK & ALAMAT',
              style: TextStyle(
                color: KokColors.cardTitle,
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
                _buildRow(
                  icon: Icons.phone_outlined,
                  label: 'Telepon',
                  value: detail.phone != null && detail.phone!.trim().isNotEmpty
                      ? detail.phone!.trim()
                      : '-',
                ),
                const Divider(
                  height: 16,
                  thickness: 0.8,
                  color: Color(0xFFF1F5F9),
                ),
                _buildRow(
                  icon: Icons.email_outlined,
                  label: 'Email',
                  value: detail.email != null && detail.email!.trim().isNotEmpty
                      ? detail.email!.trim()
                      : '-',
                ),
                const Divider(
                  height: 16,
                  thickness: 0.8,
                  color: Color(0xFFF1F5F9),
                ),
                _buildRow(
                  icon: Icons.home_outlined,
                  label: 'Alamat',
                  value:
                      detail.address != null &&
                          detail.address!.trim().isNotEmpty
                      ? detail.address!.trim()
                      : '-',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
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
          width: 70,
          child: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF6B7280),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
        Container(
          width: 1,
          height: 14,
          margin: const EdgeInsets.only(top: 6),
          color: const Color(0xFFE5E7EB),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              value,
              style: const TextStyle(
                color: KokColors.cardTitle,
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _RemoteStickyBottomBar extends StatelessWidget {
  const _RemoteStickyBottomBar({required this.club, required this.palette});

  final AthleteClub club;
  final SportBrandPalette palette;

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
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 0,
          ),
          onPressed: () => _showClubContactModal(context, club, palette),
          icon: const Icon(
            Icons.chat_bubble_outline,
            color: Colors.white,
            size: 20,
          ),
          label: const Text(
            'Hubungi pengurus klub',
            style: TextStyle(
              color: Colors.white,
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
    AthleteClub club,
    SportBrandPalette palette,
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
                    color: KokColors.cardTitle,
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
                const SizedBox(height: 8),
                Text(
                  'Kode Klub: ${club.code}',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: palette.headerStart,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(46),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () => Navigator.of(sheetContext).pop(),
                  icon: const Icon(Icons.close, color: Colors.white, size: 18),
                  label: const Text(
                    'Tutup',
                    style: TextStyle(
                      color: Colors.white,
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
            child: const CustomPaint(painter: BrandHeaderPatternPainter()),
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
                  Expanded(
                    child: Text(
                      'Detail ${person.role}',
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: palette.foreground,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
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

  String _idLabel(SportPerson person) {
    final upperId = person.id.toUpperCase();
    if (upperId.startsWith('ATL-') ||
        upperId.startsWith('PEL-') ||
        upperId.startsWith('OFF-')) {
      return 'ID · ${person.id}';
    }
    switch (person.role.toLowerCase()) {
      case 'pelatih':
        return 'ID · PEL-${person.id}';
      case 'official':
        return 'ID · OFF-${person.id}';
      default:
        return 'ID · ATL-${person.id}';
    }
  }

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
                  color: KokColors.cardTitle,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _idLabel(person),
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
                value: _birthLabel(person),
                palette: palette,
              ),
              _buildDetailRow(
                icon: Icons.place_outlined,
                label: 'Alamat',
                value: person.address ?? club.address ?? '-',
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

  String _birthLabel(SportPerson person) {
    final birthDate = person.birthDate;
    if (birthDate != null) {
      final months = [
        'Januari',
        'Februari',
        'Maret',
        'April',
        'Mei',
        'Juni',
        'Juli',
        'Agustus',
        'September',
        'Oktober',
        'November',
        'Desember',
      ];
      final date =
          '${birthDate.day} ${months[birthDate.month - 1]} ${birthDate.year}';
      final place = person.birthPlace;
      return place == null || place.trim().isEmpty ? date : '$place · $date';
    }
    return person.age == null ? '-' : '${person.age} tahun';
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
          Container(width: 1, height: 14, color: const Color(0xFFE5E7EB)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: KokColors.cardTitle,
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
          color: KokColors.cardTitle,
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
                color: KokColors.cardTitle,
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
                    const Expanded(
                      child: Text(
                        'Kelengkapan dokumen',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: KokColors.cardTitle,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$completeCount dari ${_standardDocs.length}',
                      style: const TextStyle(
                        color: KokColors.cardTitle,
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
                    valueColor: AlwaysStoppedAnimation<Color>(
                      palette.headerStart,
                    ),
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
                    isMissing: person.missingDocuments.contains(
                      _standardDocs[i],
                    ),
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
                      const Expanded(
                        child: Text(
                          'Lisensi',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Color(0xFF1F2937),
                            fontSize: 13.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
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
  const _HistoryTimelineSection({required this.person, required this.palette});

  final SportPerson person;
  final ClubBrandPalette palette;

  @override
  Widget build(BuildContext context) {
    final milestones = person.milestones;

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
                color: KokColors.cardTitle,
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
            child: milestones.isEmpty
                ? const Text(
                    'Riwayat prestasi belum tersedia.',
                    style: TextStyle(color: KokColors.muted, fontSize: 13),
                  )
                : Column(
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
                                  color: palette.headerStart.withValues(
                                    alpha: 0.3,
                                  ),
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
                              milestones[i].year,
                              style: const TextStyle(
                                color: KokColors.cardTitle,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                milestones[i].description == null ||
                                        milestones[i].description!
                                            .trim()
                                            .isEmpty
                                    ? milestones[i].title
                                    : '${milestones[i].title} · ${milestones[i].description}',
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
                    color: KokColors.cardTitle,
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
                              _displayValue(club.address),
                              style: const TextStyle(
                                fontSize: 13.5,
                                color: Color(0xFF1F2937),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 16, color: Color(0xFFE5E7EB)),
                      Row(
                        children: [
                          const Icon(
                            Icons.phone_outlined,
                            size: 20,
                            color: Color(0xFF6B7280),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _displayValue(club.phone),
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1F2937),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 16, color: Color(0xFFE5E7EB)),
                      Row(
                        children: [
                          const Icon(
                            Icons.email_outlined,
                            size: 20,
                            color: Color(0xFF6B7280),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _displayValue(club.email),
                              style: const TextStyle(
                                fontSize: 13.5,
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

  static String _displayValue(String? value) {
    if (value == null || value.trim().isEmpty) return '-';
    return value;
  }
}
