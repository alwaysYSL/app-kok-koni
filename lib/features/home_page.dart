import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/theme.dart';
import '../data/repository.dart';
import '../shared/widgets.dart';
import 'clubs_page.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    body: DataView(
      builder: (data) {
        final athletes = data.people.where((p) => p.role == 'Atlet').toList();
        final verified = athletes.where((p) => p.verified).length;
        final missing = data.people
            .where((p) => p.missingDocuments.isNotEmpty)
            .length;
        final expired = data.people.where((p) => p.expiredLicense).length;
        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(snapshotProvider);
            await ref.read(snapshotProvider.future);
          },
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 30),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [KokColors.blue, KokColors.navy],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: Image.asset(
                        'assets/branding/logo-koni.png',
                        width: 42,
                        height: 42,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'KOORDINATOR ORGANISASI KECAMATAN',
                            style: TextStyle(
                              fontSize: 9,
                              letterSpacing: .8,
                              color: Colors.white70,
                            ),
                          ),
                          SizedBox(height: 6),
                          Text(
                            'Kec. Garut Kota',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            'Pak Asep · Koordinator',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Buka profil',
                      onPressed: () => context.go('/profile'),
                      icon: const CircleAvatar(
                        radius: 20,
                        backgroundColor: Color(0xFF436BAF),
                        child: Text(
                          'PA',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Surface(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.circle,
                                size: 9,
                                color: KokColors.yellow,
                              ),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text(
                                  'Data demo · SICABOR belum terhubung',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: KokColors.muted,
                                  ),
                                ),
                              ),
                              IconButton(
                                tooltip: 'Muat ulang data demo',
                                onPressed: () =>
                                    ref.invalidate(snapshotProvider),
                                icon: const Icon(
                                  Icons.sync,
                                  color: KokColors.blue,
                                  size: 22,
                                ),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${athletes.length}',
                                      style: const TextStyle(
                                        fontSize: 48,
                                        fontWeight: FontWeight.w800,
                                        color: KokColors.ink,
                                        height: 1.1,
                                      ),
                                    ),
                                    const Text(
                                      'ATLET TERDATA',
                                      style: TextStyle(
                                        color: KokColors.muted,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: .8,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    StatusBadge(
                                      '$verified terverifikasi · ${athletes.isEmpty ? 0 : (verified / athletes.length * 100).round()}%',
                                    ),
                                  ],
                                ),
                              ),
                              Image.asset(
                                'assets/branding/mascot.png',
                                width: 82,
                                height: 108,
                              ),
                            ],
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 18),
                            child: Divider(height: 1),
                          ),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: _Stat(
                                  '${data.people.where((p) => p.role == 'Pelatih').length}',
                                  'PELATIH',
                                  'Pembina atlet',
                                ),
                              ),
                              Expanded(
                                child: _Stat(
                                  '${data.clubs.length}',
                                  'KLUB',
                                  '${data.clubs.where((c) => c.active).length} aktif · ${data.clubs.where((c) => !c.active).length} pasif',
                                ),
                              ),
                              Expanded(
                                child: _Stat(
                                  '${data.people.where((p) => p.role == 'Official').length}',
                                  'OFFICIAL',
                                  '${data.clubs.map((c) => c.sport).toSet().length} cabor',
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    SectionHead(
                      'Perlu Perhatian',
                      onTap: () => context.push('/attention'),
                    ),
                    AttentionTile(
                      count: missing,
                      title: 'Atlet berkas kurang',
                      subtitle: 'Lihat kelengkapan dokumen',
                      onTap: () => context.push('/attention?type=documents'),
                    ),
                    AttentionTile(
                      count: expired,
                      title: 'Lisensi pelatih kedaluwarsa',
                      subtitle: 'Koordinasikan dengan pengurus klub',
                      onTap: () => context.push('/attention?type=license'),
                    ),
                    SectionHead(
                      'Klub di kecamatan',
                      onTap: () => context.go('/clubs'),
                    ),
                    ...data.clubs
                        .take(3)
                        .map(
                          (c) => ClubTile(club: c, data: data, compact: true),
                        ),
                    const DemoNote(),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}

class _Stat extends StatelessWidget {
  const _Stat(this.number, this.label, this.note);
  final String number, label, note;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        number,
        style: const TextStyle(
          fontSize: 29,
          color: KokColors.ink,
          fontWeight: FontWeight.w800,
        ),
      ),
      Text(
        label,
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 11,
          color: KokColors.muted,
        ),
      ),
      const SizedBox(height: 3),
      Text(note, style: const TextStyle(fontSize: 10, color: KokColors.muted)),
    ],
  );
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
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(color: KokColors.muted, fontSize: 12),
              ),
            ],
          ),
        ),
        const Icon(Icons.chevron_right, color: KokColors.muted),
      ],
    ),
  );
}
