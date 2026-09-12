import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/auth/presentation/auth_controller.dart';
import '../core/theme.dart';
import '../data/models.dart';
import '../data/providers/snapshot_provider.dart';
import '../shared/widgets.dart';
import 'clubs_page.dart';
import 'dashboard_decorations.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      body: DataView(
        builder: (data) {
          final athletes = data.people.where((p) => p.role == 'Atlet').toList();
          final verified = athletes.where((p) => p.verified).length;
          final missing = data.people
              .where((p) => p.missingDocuments.isNotEmpty)
              .length;
          final expired = data.people.where((p) => p.expiredLicense).length;

          // Cari klub dan cabor yang membutuhkan perhatian
          final missingPeople = data.people
              .where((p) => p.missingDocuments.isNotEmpty)
              .toList();
          final missingClubIds = missingPeople.map((p) => p.clubId).toSet();
          final missingClubs = data.clubs
              .where((c) => missingClubIds.contains(c.id))
              .toList();
          final missingSubtitle = missingClubs.isNotEmpty
              ? '${missingClubs.first.name.replaceFirst('Klub ', '')} · ${missingClubs.first.sport}'
              : (missing > 0
                    ? 'Garuda Muda · Sepak Bola'
                    : 'Semua berkas lengkap');

          final expiredCoaches = data.people
              .where((p) => p.role == 'Pelatih' && p.expiredLicense)
              .toList();
          final expiredClubIds = expiredCoaches.map((p) => p.clubId).toSet();
          final expiredClubs = data.clubs
              .where((c) => expiredClubIds.contains(c.id))
              .toList();
          final expiredSportsCount = expiredClubs
              .map((c) => c.sport)
              .toSet()
              .length;
          final expiredSubtitle = expired > 0
              ? '${expiredClubs.length} klub · $expiredSportsCount cabor'
              : 'Semua lisensi aktif';

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(snapshotProvider);
              await ref.read(snapshotProvider.future);
            },
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                // 1. Header Biru dengan DashboardHeaderDecoration
                DashboardHeaderDecoration(
                  padding: EdgeInsets.fromLTRB(
                    20,
                    MediaQuery.paddingOf(context).top + 16,
                    20,
                    48,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: Image.asset(
                              'assets/branding/logo-koni.png',
                              fit: BoxFit.contain,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    'KOORDINATOR ORGANISASI KECAMATAN',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.8,
                                      color: Colors.white70,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  user?.scope.name ??
                                      (data.scope.name == 'Kecamatan Garut Kota'
                                          ? 'Kec. Garut Kota'
                                          : data.scope.name),
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  user != null
                                      ? '${user.fullName} · ${user.roleTitle}'
                                      : 'Pak Asep · Koordinator',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.white70,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Tooltip(
                            message: 'Buka profil',
                            child: InkWell(
                              onTap: () => context.go('/profile'),
                              borderRadius: BorderRadius.circular(22),
                              child: Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: const Color(
                                    0xFF1E3A8A,
                                  ).withValues(alpha: 0.5),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.3),
                                    width: 1.2,
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  user != null
                                      ? user.fullName
                                            .split(' ')
                                            .where((s) => s.isNotEmpty)
                                            .map((s) => s[0])
                                            .take(2)
                                            .join()
                                            .toUpperCase()
                                      : 'PA',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      _HomeSearchBar(onTap: () => context.push('/search')),
                    ],
                  ),
                ),

                // 2. Konten Mengambang (Floating Stats Card & Seksi-seksi)
                Transform.translate(
                  offset: const Offset(0, -32),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _FloatingStatsCard(
                          data: data,
                          athletes: athletes,
                          verified: verified,
                          onRefresh: () => ref.invalidate(snapshotProvider),
                        ),
                        const SizedBox(height: 8),
                        _SectionHeader(
                          title: 'Perlu Perhatian',
                          onTap: () => context.push('/attention'),
                        ),
                        AttentionTile(
                          count: missing,
                          title: 'Atlet berkas kurang',
                          subtitle: missingSubtitle,
                          onTap: () =>
                              context.push('/attention?type=documents'),
                        ),
                        AttentionTile(
                          count: expired,
                          title: 'Lisensi pelatih kedaluwarsa',
                          subtitle: expiredSubtitle,
                          onTap: () => context.push('/attention?type=license'),
                        ),
                        const SizedBox(height: 8),
                        _SectionHeader(
                          title: 'Klub di kecamatan',
                          onTap: () => context.go('/clubs'),
                        ),
                        ...data.clubs
                            .take(3)
                            .map(
                              (c) =>
                                  ClubTile(club: c, data: data, compact: true),
                            ),
                        const SizedBox(height: 8),
                        const DemoNote(),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Kartu statistik mengambang dengan bayangan lembut, badge persentase verifikasi,
/// siluet atlet lari dinamis, dan 3 kolom metrik ringkas.
class _FloatingStatsCard extends StatelessWidget {
  const _FloatingStatsCard({
    required this.data,
    required this.athletes,
    required this.verified,
    required this.onRefresh,
  });

  final KokSnapshot data;
  final List<SportPerson> athletes;
  final int verified;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final coaches = data.people.where((p) => p.role == 'Pelatih').toList();
    final licensedCoaches = coaches
        .where((p) => p.group.contains('Lisensi'))
        .length;
    final activeClubs = data.clubs.where((c) => c.active).length;
    final inactiveClubs = data.clubs.where((c) => !c.active).length;
    final officials = data.people.where((p) => p.role == 'Official').length;
    final sportsCount = data.clubs.map((c) => c.sport).toSet().length;
    final timeStr =
        '${data.loadedAt.hour.toString().padLeft(2, '0')}:${data.loadedAt.minute.toString().padLeft(2, '0')}';
    final percentage = athletes.isEmpty
        ? 0
        : (verified / athletes.length * 100).round();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Baris status sinkronisasi
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Color(0xFF94A3B8),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Terakhir Dimuat: $timeStr WIB',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF64748B),
                  ),
                ),
              ),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onRefresh,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.sync,
                      size: 16,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Highlight Utama Atlet & Siluet Atlet
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            '${athletes.length}',
                            style: const TextStyle(
                              fontSize: 38,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0C2464),
                              height: 1.0,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'ATLET',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0C2464),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F0FE),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '$verified terverifikasi $percentage%',
                          style: const TextStyle(
                            color: Color(0xFF1B4F9E),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const AthletesSilhouetteGraphic(width: 125, height: 85),
            ],
          ),

          // Divider pemisah tipis
          const Divider(color: Color(0xFFEEEEEE), height: 28, thickness: 1),

          // 3 Kolom Metrik Bawah
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _MetricColumn(
                  count: '${coaches.length}',
                  label: 'PELATIH',
                  subtext: '$licensedCoaches berlisensi',
                ),
              ),
              Expanded(
                child: _MetricColumn(
                  count: '${data.clubs.length}',
                  label: 'KLUB',
                  subtext: '$activeClubs aktif · $inactiveClubs pasif',
                ),
              ),
              Expanded(
                child: _MetricColumn(
                  count: '$officials',
                  label: 'OFFICIAL',
                  subtext: '$sportsCount cabor',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricColumn extends StatelessWidget {
  const _MetricColumn({
    required this.count,
    required this.label,
    required this.subtext,
  });

  final String count;
  final String label;
  final String subtext;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          count,
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: Color(0xFF0C2464),
            height: 1.1,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 12,
            letterSpacing: 0.5,
            color: Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            subtext,
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.onTap});

  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: KokColors.ink,
              ),
            ),
          ),
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(6),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Text(
                'lihat semua >',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: KokColors.blue,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AttentionTile extends StatelessWidget {
  const AttentionTile({
    super.key,
    required this.count,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final int count;
  final String title, subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Surface(
    border: const Color(0xFFFFBCBC),
    onTap: onTap,
    child: Row(
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: KokColors.red,
          child: Text(
            '$count',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: KokColors.cardTitle,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: const TextStyle(color: KokColors.muted, fontSize: 12),
              ),
            ],
          ),
        ),
        const Icon(Icons.chevron_right, color: KokColors.muted, size: 22),
      ],
    ),
  );
}

class _HomeSearchBar extends StatelessWidget {
  const _HomeSearchBar({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'Cari nama atlet, klub, atau cabor',
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        height: 46,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            const Icon(Icons.search, color: KokColors.muted, size: 20),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Cari nama atlet, klub, cabor...',
                style: TextStyle(color: KokColors.muted, fontSize: 13.5),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: KokColors.pale,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Cari',
                style: TextStyle(
                  color: KokColors.bluePrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
