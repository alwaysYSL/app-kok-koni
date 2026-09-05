import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/theme.dart';
import '../shared/widgets.dart';

class PersonDetailPage extends StatelessWidget {
  const PersonDetailPage({super.key, required this.id});
  final String id;
  @override
  Widget build(BuildContext context) => DataView(
    builder: (data) {
      final matches = data.people.where((p) => p.id == id);
      if (matches.isEmpty) return const MissingPage();
      final p = matches.first;
      final club = data.clubs.firstWhere((c) => c.id == p.clubId);
      return Scaffold(
        appBar: AppBar(title: Text('Detail ${p.role}')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Surface(
              child: Column(
                children: [
                  const CircleAvatar(
                    radius: 34,
                    backgroundColor: KokColors.pale,
                    child: Icon(
                      Icons.person_outline,
                      size: 36,
                      color: KokColors.ink,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    p.name,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'ID DEMO · ${p.id}',
                    style: const TextStyle(
                      color: KokColors.muted,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 12),
                  StatusBadge(
                    p.missingDocuments.isNotEmpty
                        ? 'Berkas kurang'
                        : p.expiredLicense
                        ? 'Lisensi kedaluwarsa'
                        : 'Terverifikasi',
                    warning: p.missingDocuments.isNotEmpty || p.expiredLicense,
                  ),
                ],
              ),
            ),
            Surface(
              child: Column(
                children: [
                  DetailRow('Klub', club.name),
                  DetailRow('Cabor', club.sport),
                  DetailRow('Kelompok', p.group),
                  DetailRow('Kelurahan', club.village),
                  const DetailRow('Kecamatan', 'Garut Kota'),
                ],
              ),
            ),
            const SectionHead('Kelengkapan berkas'),
            Surface(
              child: Column(
                children: [
                  for (final doc in [
                    'KTP / KIA',
                    'Kartu Keluarga',
                    'Akta kelahiran',
                    'Surat sehat',
                  ])
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Row(
                        children: [
                          Expanded(child: Text(doc)),
                          StatusBadge(
                            p.missingDocuments.contains(doc)
                                ? 'Belum ada'
                                : 'Ada',
                            warning: p.missingDocuments.contains(doc),
                          ),
                        ],
                      ),
                    ),
                  if (p.role == 'Pelatih')
                    DetailRow(
                      'Lisensi',
                      p.expiredLicense
                          ? 'Kedaluwarsa (contoh)'
                          : 'Aktif (contoh)',
                    ),
                ],
              ),
            ),
            const Text(
              'Status dokumen di atas adalah ilustrasi. Berkas pribadi tidak disimpan dalam aplikasi demo.',
              style: TextStyle(color: KokColors.muted, fontSize: 12),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => context.push('/club/${club.id}'),
              icon: const Icon(Icons.groups_outlined),
              label: const Text('Lihat klub terkait'),
            ),
            const DemoNote(),
          ],
        ),
      );
    },
  );
}

class MissingPage extends StatelessWidget {
  const MissingPage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Data tidak ditemukan')),
    body: Center(
      child: FilledButton(
        onPressed: () => context.go('/home'),
        child: const Text('Kembali ke beranda'),
      ),
    ),
  );
}
