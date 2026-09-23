import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/composition/app_composition.dart';
import '../../core/config/deployment_profile.dart';
import '../../core/network/api_exceptions.dart';
import '../../core/theme.dart';
import '../../data/club_filters.dart';
import '../../data/kok_repository.dart';
import '../../data/models.dart';
import '../../data/models/athlete.dart';
import '../../data/models/club_detail.dart' as domain_detail;
import '../../data/providers/athlete_providers.dart';
import '../../data/providers/club_providers.dart';
import '../../shared/widgets.dart';
import '../dashboard_decorations.dart';
import '../detail_pages.dart';
import 'club_brand_palette.dart';
import 'club_detail_header.dart';
import 'club_detail_tabs.dart';
import 'club_document_tab.dart';
import 'club_people_filter.dart';
import 'club_people_tab.dart';

bool _isRemoteMode(WidgetRef ref) {
  try {
    return ref.watch(appCompositionProvider).profile.dataMode ==
        DataMode.remote;
  } catch (_) {
    return false;
  }
}

class ClubDetailPage extends ConsumerWidget {
  const ClubDetailPage({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (_isRemoteMode(ref)) {
      final clubId = int.tryParse(id);
      if (clubId == null) {
        return const MissingPage(message: 'Data klub tidak ditemukan.');
      }

      final asyncDetail = ref.watch(clubDetailProvider(clubId));
      return asyncDetail.when(
        data: (detail) => _RemoteClubDetailContent(detail: detail),
        loading: () => const Scaffold(
          backgroundColor: Color(0xFFF4F6FA),
          body: Center(child: CircularProgressIndicator.adaptive()),
        ),
        error: (e, _) {
          if (e is NotFoundException ||
              e is KokResourceNotFoundException ||
              e.toString().toLowerCase().contains('404') ||
              e.toString().toLowerCase().contains('not found') ||
              e.toString().toLowerCase().contains('tidak ditemukan')) {
            return const MissingPage(message: 'Data klub tidak ditemukan.');
          }
          final presentation = describeRemoteError(e);
          return Scaffold(
            backgroundColor: const Color(0xFFF4F6FA),
            appBar: AppBar(
              title: const Text('Detail Klub'),
              leading: IconButton(
                icon: const Icon(Icons.chevron_left, size: 28),
                onPressed: () => _goBack(context),
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
                      'Gagal memuat detail klub',
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
                      style: const TextStyle(
                        fontSize: 13,
                        color: KokColors.muted,
                      ),
                    ),
                    if (presentation.canRetry) ...[
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () =>
                            ref.refresh(clubDetailProvider(clubId)),
                        icon: const Icon(Icons.refresh, size: 18),
                        label: const Text('Coba Lagi'),
                      ),
                    ],
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
        final matches = data.clubs.where((club) => club.id == id);
        if (matches.isEmpty) return const MissingPage();
        final club = matches.first;
        final allPeople = clubPeople(data, id);
        final athletes = allPeople.where((p) => p.role == 'Atlet').toList();
        final coaches = allPeople.where((p) => p.role == 'Pelatih').toList();
        final officials = allPeople.where((p) => p.role == 'Official').toList();
        final missingCount = allPeople.where(personNeedsAttention).length;
        final palette = ClubBrandPaletteResolver.resolve(club);

        return DefaultTabController(
          length: 4,
          child: Scaffold(
            backgroundColor: const Color(0xFFF4F6FA),
            body: NestedScrollView(
              headerSliverBuilder: (context, innerBoxIsScrolled) => [
                SliverOverlapAbsorber(
                  handle: NestedScrollView.sliverOverlapAbsorberHandleFor(
                    context,
                  ),
                  sliver: SliverAppBar(
                    automaticallyImplyLeading: false,
                    pinned: true,
                    expandedHeight: 420,
                    toolbarHeight: 64,
                    backgroundColor: palette.headerEnd,
                    flexibleSpace: LayoutBuilder(
                      builder: (context, constraints) {
                        final titleOpacity =
                            ((420 - constraints.biggest.height) / 200).clamp(
                              0.0,
                              1.0,
                            );
                        return Stack(
                          fit: StackFit.expand,
                          children: [
                            FlexibleSpaceBar(
                              collapseMode: CollapseMode.parallax,
                              background: OverflowBox(
                                alignment: Alignment.topCenter,
                                maxHeight: double.infinity,
                                child: ClubDetailHeader(
                                  club: club,
                                  palette: palette,
                                  athleteCount: athletes.length,
                                  coachCount: coaches.length,
                                  officialCount: officials.length,
                                  missingFileCount: missingCount,
                                  onBack: () => _goBack(context),
                                  onShare: () => _shareClub(context, club),
                                  excludeClubNameSemantics: titleOpacity > 0,
                                ),
                              ),
                            ),
                            if (titleOpacity > 0)
                              IgnorePointer(
                                child: Opacity(
                                  opacity: titleOpacity,
                                  child: Align(
                                    alignment: Alignment.topCenter,
                                    child: Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                        64,
                                        20,
                                        64,
                                        0,
                                      ),
                                      child: Semantics(
                                        container: true,
                                        label: club.name,
                                        child: ExcludeSemantics(
                                          child: Text(
                                            club.name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: palette.foreground,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            if (titleOpacity == 1)
                              Positioned(
                                top: 0,
                                left: 0,
                                right: 0,
                                child: SafeArea(
                                  bottom: false,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    child: SizedBox(
                                      height: 48,
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          IconButton(
                                            onPressed: () => _goBack(context),
                                            tooltip: 'Kembali',
                                            color: palette.foreground,
                                            icon: const Icon(
                                              Icons.chevron_left,
                                              size: 28,
                                            ),
                                          ),
                                          IconButton(
                                            onPressed: () =>
                                                _shareClub(context, club),
                                            tooltip: 'Bagikan info klub',
                                            color: palette.foreground,
                                            icon: const Icon(
                                              Icons.share_outlined,
                                              size: 24,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                    bottom: PreferredSize(
                      preferredSize: const Size.fromHeight(88),
                      child: DecoratedBox(
                        decoration: const BoxDecoration(
                          color: Color(0xFFF4F6FA),
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(28),
                          ),
                        ),
                        child: ClubDetailTabBar(palette: palette),
                      ),
                    ),
                  ),
                ),
              ],
              body: Padding(
                padding: const EdgeInsets.only(top: 64 + 88),
                child: TabBarView(
                  children: [
                    ClubPeopleTab(
                      role: 'Atlet',
                      people: athletes,
                      palette: palette,
                      onPersonTap: (person) =>
                          context.push('/person/${person.id}'),
                    ),
                    ClubPeopleTab(
                      role: 'Pelatih',
                      people: coaches,
                      palette: palette,
                      onPersonTap: (person) =>
                          context.push('/person/${person.id}'),
                    ),
                    ClubPeopleTab(
                      role: 'Official',
                      people: officials,
                      palette: palette,
                      onPersonTap: (person) =>
                          context.push('/person/${person.id}'),
                    ),
                    ClubDocumentTab(club: club),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  static void _shareClub(BuildContext context, Club club) {
    Clipboard.setData(
      ClipboardData(
        text: '${club.name} · ${club.sport} · Kel. ${club.village}',
      ),
    );
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Info klub disalin')));
  }

  static void _shareRemoteClub(
    BuildContext context,
    domain_detail.ClubDetail detail,
  ) {
    Clipboard.setData(
      ClipboardData(
        text:
            '${detail.name} · ${detail.cabor.name} · ${detail.secretariat.districtName}',
      ),
    );
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Info klub disalin')));
  }

  static void _goBack(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/clubs');
    }
  }
}

class _RemoteClubDetailContent extends StatelessWidget {
  const _RemoteClubDetailContent({required this.detail});

  final domain_detail.ClubDetail detail;

  @override
  Widget build(BuildContext context) {
    final palette = ClubBrandPaletteResolver.resolveFromSport(
      detail.cabor.name,
    );

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F6FA),
        body: NestedScrollView(
          headerSliverBuilder: (sliverContext, innerBoxIsScrolled) {
            return [
              SliverToBoxAdapter(
                child: _RemoteClubDetailHeader(
                  detail: detail,
                  palette: palette,
                ),
              ),
              SliverPersistentHeader(
                pinned: true,
                delegate: _SliverTabBarDelegate(
                  ClubDetailRemoteTabBar(palette: palette),
                ),
              ),
            ];
          },
          body: TabBarView(
            children: [
              _RemoteClubInfoTab(detail: detail, palette: palette),
              _RemoteClubPengurusTab(detail: detail, palette: palette),
              _RemoteClubAthletesTab(club: detail, palette: palette),
            ],
          ),
        ),
      ),
    );
  }
}

class _RemoteClubDetailHeader extends StatelessWidget {
  const _RemoteClubDetailHeader({required this.detail, required this.palette});

  final domain_detail.ClubDetail detail;
  final ClubBrandPalette palette;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
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
                        onPressed: () => ClubDetailPage._goBack(context),
                        tooltip: 'Kembali',
                        color: palette.foreground,
                        icon: const Icon(Icons.chevron_left, size: 28),
                      ),
                      IconButton(
                        onPressed: () =>
                            ClubDetailPage._shareRemoteClub(context, detail),
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
                    Semantics(
                      container: true,
                      label: detail.name,
                      child: Text(
                        detail.name,
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
                    const SizedBox(height: 8),
                    Wrap(
                      alignment: WrapAlignment.center,
                      runAlignment: WrapAlignment.center,
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _RemoteHeaderBadge(
                          label: detail.code,
                          background: palette.foreground.withValues(
                            alpha: 0.18,
                          ),
                          foreground: palette.foreground,
                        ),
                        _RemoteHeaderBadge(
                          label: detail.cabor.name,
                          background: palette.foreground.withValues(
                            alpha: 0.18,
                          ),
                          foreground: palette.foreground,
                        ),
                        _RemoteHeaderBadge(
                          label: detail.statusLabel.toUpperCase(),
                          background: detail.status == 1
                              ? const Color(0xFFDDF6E6)
                              : const Color(0xFFE9ECF2),
                          foreground: detail.status == 1
                              ? const Color(0xFF176B38)
                              : const Color(0xFF4B5563),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: palette.foreground.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                '${detail.totalAthleteInClub}',
                                style: TextStyle(
                                  color: palette.foreground,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'TOTAL ANGGOTA',
                                style: TextStyle(
                                  color: palette.foreground.withValues(
                                    alpha: 0.9,
                                  ),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Termasuk atlet dari kecamatan lain',
                            style: TextStyle(
                              color: palette.foreground.withValues(alpha: 0.75),
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
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
  }

  Widget _buildLogo() {
    final logoUrl = detail.logoUrl?.trim();
    if (logoUrl == null || logoUrl.isEmpty) return _fallbackLogo();

    return Semantics(
      label: 'Logo ${detail.name}',
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
    label: 'Logo fallback ${detail.name}',
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
        child: Icon(
          sportIcon(detail.cabor.name),
          size: 44,
          color: palette.foreground,
        ),
      ),
    ),
  );
}

class _RemoteHeaderBadge extends StatelessWidget {
  const _RemoteHeaderBadge({
    required this.label,
    required this.background,
    required this.foreground,
  });

  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      label,
      style: TextStyle(
        color: foreground,
        fontSize: 11,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

typedef UrlLauncherFn = Future<bool> Function(Uri uri, {LaunchMode mode});

final urlLauncherProvider = Provider<UrlLauncherFn>((ref) => launchUrl);

Future<void> launchDocumentUrl(
  BuildContext context,
  String? rawUrl, {
  UrlLauncherFn launcher = launchUrl,
}) async {
  if (rawUrl == null || rawUrl.trim().isEmpty) return;
  final trimmed = rawUrl.trim();
  final uri = Uri.tryParse(trimmed);
  final isValid =
      uri != null &&
      (uri.scheme == 'http' || uri.scheme == 'https') &&
      uri.host.isNotEmpty;

  var launched = false;
  if (isValid) {
    try {
      launched = await launcher(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      launched = false;
    }
  }

  if (!launched && context.mounted) {
    unawaited(Clipboard.setData(ClipboardData(text: trimmed)));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Tautan berkas SK disalin ke papan klip')),
    );
  }
}

class _RemoteClubInfoTab extends ConsumerWidget {
  const _RemoteClubInfoTab({required this.detail, required this.palette});

  final domain_detail.ClubDetail detail;
  final ClubBrandPalette palette;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildCard(
            title: 'Identitas Klub',
            icon: Icons.badge_outlined,
            children: [
              _InfoRow(label: 'Nama Klub', value: detail.name),
              _InfoRow(label: 'Kode Klub', value: detail.code),
              _InfoRow(
                label: 'Cabang Olahraga',
                value: '${detail.cabor.name} (${detail.cabor.code})',
              ),
              _InfoRow(
                label: 'Ketua / Pimpinan',
                value: detail.headName ?? '-',
              ),
              _InfoRow(
                label: 'Tahun Berdiri',
                value: detail.since != null && detail.since!.isNotEmpty
                    ? detail.since!
                    : '-',
              ),
              _InfoRow(label: 'Status', value: detail.statusLabel),
            ],
          ),
          const SizedBox(height: 12),
          _buildCard(
            title: 'Surat Keputusan (SK)',
            icon: Icons.description_outlined,
            children: [
              _InfoRow(
                label: 'Nomor SK',
                value: detail.noSk != null && detail.noSk!.isNotEmpty
                    ? detail.noSk!
                    : 'SK belum tersedia',
              ),
              _InfoRow(
                label: 'Berkas SK',
                value: detail.fileSkUrl != null && detail.fileSkUrl!.isNotEmpty
                    ? 'Berkas tersedia'
                    : 'Berkas belum tersedia',
                trailing:
                    detail.fileSkUrl != null && detail.fileSkUrl!.isNotEmpty
                    ? IconButton(
                        icon: const Icon(
                          Icons.open_in_new,
                          size: 18,
                          color: KokColors.blue,
                        ),
                        tooltip: 'Salin / Buka tautan berkas SK',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () => launchDocumentUrl(
                          context,
                          detail.fileSkUrl,
                          launcher: ref.read(urlLauncherProvider),
                        ),
                      )
                    : null,
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildCard(
            title: 'Kontak',
            icon: Icons.contact_phone_outlined,
            children: [
              _InfoRow(
                label: 'Telepon / WhatsApp',
                value: detail.phone != null && detail.phone!.isNotEmpty
                    ? detail.phone!
                    : '-',
              ),
              _InfoRow(
                label: 'Email',
                value: detail.email != null && detail.email!.isNotEmpty
                    ? detail.email!
                    : '-',
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildCard(
            title: 'Alamat & Lokasi',
            icon: Icons.location_on_outlined,
            children: [
              const Text(
                'Sekretariat',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: KokColors.cardTitle,
                ),
              ),
              const SizedBox(height: 4),
              _InfoRow(
                label: 'Alamat',
                value:
                    detail.secretariat.address != null &&
                        detail.secretariat.address!.isNotEmpty
                    ? detail.secretariat.address!
                    : '-',
              ),
              _InfoRow(
                label: 'Kecamatan',
                value: detail.secretariat.subdistrictName,
              ),
              _InfoRow(
                label: 'Kabupaten / Kota',
                value: detail.secretariat.districtName,
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Divider(height: 1, color: Color(0xFFE5E7EB)),
              ),
              const Text(
                'Tempat Latihan',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: KokColors.cardTitle,
                ),
              ),
              const SizedBox(height: 4),
              if (detail.training != null) ...[
                _InfoRow(
                  label: 'Alamat',
                  value:
                      detail.training!.address != null &&
                          detail.training!.address!.isNotEmpty
                      ? detail.training!.address!
                      : '-',
                ),
                _InfoRow(
                  label: 'Kecamatan',
                  value: detail.training!.subdistrictName,
                ),
                _InfoRow(
                  label: 'Kabupaten / Kota',
                  value: detail.training!.districtName,
                ),
              ] else
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    'Belum ada data tempat latihan',
                    style: TextStyle(
                      fontSize: 13,
                      color: KokColors.muted,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          _buildCard(
            title: 'Total Anggota',
            icon: Icons.groups_outlined,
            children: [
              Text(
                '${detail.totalAthleteInClub} Atlet',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: KokColors.cardTitle,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Termasuk atlet dari kecamatan lain',
                style: TextStyle(fontSize: 12, color: KokColors.muted),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: KokColors.ink),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: KokColors.cardTitle,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value, this.trailing});

  final String label;
  final String value;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: KokColors.muted,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                color: KokColors.cardTitle,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 8), trailing!],
        ],
      ),
    );
  }
}

class _RemoteClubPengurusTab extends StatelessWidget {
  const _RemoteClubPengurusTab({required this.detail, required this.palette});

  final domain_detail.ClubDetail detail;
  final ClubBrandPalette palette;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildManagementSection(context),
          const SizedBox(height: 16),
          _buildOfficialsSection(context),
          const SizedBox(height: 16),
          _buildCoachesSection(context),
        ],
      ),
    );
  }

  Widget _buildManagementSection(BuildContext context) {
    final mgmt = detail.management;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.corporate_fare_outlined,
                size: 18,
                color: KokColors.ink,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Struktur Kepengurusan',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: KokColors.cardTitle,
                  ),
                ),
              ),
              if (mgmt.dataAvailable && mgmt.partial)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: const Text(
                    'Data Parsial',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF92400E),
                    ),
                  ),
                ),
            ],
          ),
          if (mgmt.dataAvailable && mgmt.partial) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: Color(0xFFB45309)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Data kepengurusan ini bersifat parsial atau terbatas dari SICABOR.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF92400E),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          if (!mgmt.dataAvailable)
            const _UnavailableNotice(message: 'Belum tercatat di sistem')
          else if (mgmt.items.isEmpty)
            const Text(
              'Belum ada data kepengurusan.',
              style: TextStyle(
                fontSize: 13,
                color: KokColors.muted,
                fontStyle: FontStyle.italic,
              ),
            )
          else
            ...mgmt.items.map(
              (item) => _PersonnelItemTile(item: item, palette: palette),
            ),
        ],
      ),
    );
  }

  static String _mapReasonToMessage(String? reason, String fallback) {
    return switch (reason) {
      'NOT_RECORDED_IN_SYSTEM' => 'Belum tercatat di sistem',
      'NOT_AVAILABLE' => 'Data belum tersedia',
      _ => fallback,
    };
  }

  Widget _buildOfficialsSection(BuildContext context) {
    final officials = detail.officials;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.assignment_ind_outlined,
                size: 18,
                color: KokColors.ink,
              ),
              SizedBox(width: 8),
              Text(
                'Official',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: KokColors.cardTitle,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (!officials.dataAvailable)
            _UnavailableNotice(
              message: _mapReasonToMessage(
                officials.reason,
                'Data official belum tersedia atau tidak dipublikasikan.',
              ),
            )
          else if (officials.items.isEmpty)
            const Text(
              'Belum ada data official.',
              style: TextStyle(
                fontSize: 13,
                color: KokColors.muted,
                fontStyle: FontStyle.italic,
              ),
            )
          else
            ...officials.items.map(
              (item) => _PersonnelItemTile(item: item, palette: palette),
            ),
        ],
      ),
    );
  }

  Widget _buildCoachesSection(BuildContext context) {
    final coaches = detail.coaches;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.sports_outlined, size: 18, color: KokColors.ink),
              SizedBox(width: 8),
              Text(
                'Pelatih',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: KokColors.cardTitle,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (!coaches.dataAvailable)
            _UnavailableNotice(
              message: _mapReasonToMessage(
                coaches.reason,
                'Data pelatih belum tersedia atau tidak dipublikasikan.',
              ),
            )
          else if (coaches.items.isEmpty)
            const Text(
              'Belum ada data pelatih.',
              style: TextStyle(
                fontSize: 13,
                color: KokColors.muted,
                fontStyle: FontStyle.italic,
              ),
            )
          else
            ...coaches.items.map(
              (item) => _PersonnelItemTile(item: item, palette: palette),
            ),
        ],
      ),
    );
  }
}

class _UnavailableNotice extends StatelessWidget {
  const _UnavailableNotice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, size: 16, color: KokColors.muted),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 13,
                color: KokColors.muted,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PersonnelItemTile extends StatelessWidget {
  const _PersonnelItemTile({required this.item, required this.palette});

  final domain_detail.ClubPersonnelItem item;
  final ClubBrandPalette palette;

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: palette.softAccent,
            backgroundImage: item.photoUrl != null && item.photoUrl!.isNotEmpty
                ? NetworkImage(item.photoUrl!)
                : null,
            child: item.photoUrl == null || item.photoUrl!.isEmpty
                ? Text(
                    item.name.isNotEmpty ? item.name[0].toUpperCase() : '?',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: palette.selectedTab,
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
                  item.name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: KokColors.cardTitle,
                  ),
                ),
                if (item.role != null && item.role!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    item.role!,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: KokColors.muted,
                    ),
                  ),
                ],
                if (item.phone != null && item.phone!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    item.phone!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: KokColors.muted,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (item.id != null)
            const Icon(Icons.chevron_right, size: 20, color: KokColors.muted),
        ],
      ),
    );

    if (item.id != null) {
      return InkWell(
        onTap: () => context.push('/person/${item.id}'),
        borderRadius: BorderRadius.circular(8),
        child: content,
      );
    }

    return content;
  }
}

class _RemoteClubAthletesTab extends ConsumerStatefulWidget {
  const _RemoteClubAthletesTab({required this.club, required this.palette});

  final domain_detail.ClubDetail club;
  final ClubBrandPalette palette;

  @override
  ConsumerState<_RemoteClubAthletesTab> createState() =>
      _RemoteClubAthletesTabState();
}

class _RemoteClubAthletesTabState
    extends ConsumerState<_RemoteClubAthletesTab> {
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
                idCabor: null,
                idClub: widget.club.id,
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
              idCabor: null,
              idClub: widget.club.id,
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
                idCabor: null,
                idClub: widget.club.id,
              )).notifier,
            )
            .updateSearch(query);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(
      athletePaginationProvider((idCabor: null, idClub: widget.club.id)),
    );
    final controller = ref.read(
      athletePaginationProvider((
        idCabor: null,
        idClub: widget.club.id,
      )).notifier,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
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
                        ? widget.palette.selectedTab
                        : KokColors.cardTitle,
                  ),
                  backgroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: isSelected
                          ? widget.palette.selectedTab
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

        // Subtitle / info header explaining counts
        if (!state.isLoading)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(
              'Hasil filter wilayah ini: ${state.total} atlet (Total atlet terdaftar di klub: ${widget.club.totalAthleteInClub})',
              style: const TextStyle(
                fontSize: 12,
                color: KokColors.muted,
                fontStyle: FontStyle.italic,
              ),
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
          message:
              'Tidak ada atlet dari kecamatan ini yang tercatat di klub ini.',
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
                      athlete.name.isNotEmpty
                          ? athlete.name[0].toUpperCase()
                          : 'A',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: widget.palette.selectedTab,
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
                  Row(
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
                          athlete.cabor.name,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: widget.palette.selectedTab,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
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
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 20, color: KokColors.muted),
          ],
        ),
      ),
    );
  }
}

class _SliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverTabBarDelegate(this.widget);

  final PreferredSizeWidget widget;

  @override
  double get minExtent => widget.preferredSize.height;
  @override
  double get maxExtent => widget.preferredSize.height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(color: const Color(0xFFF4F6FA), child: widget);
  }

  @override
  bool shouldRebuild(_SliverTabBarDelegate oldDelegate) =>
      widget != oldDelegate.widget;
}
