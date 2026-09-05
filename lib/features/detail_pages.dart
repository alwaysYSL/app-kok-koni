import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/theme.dart';
import '../data/models.dart';
import '../data/repository.dart';
import '../shared/widgets.dart';

class ClubDetailPage extends StatelessWidget {
  const ClubDetailPage({super.key, required this.id});
  final String id;
  @override
  Widget build(BuildContext context) => DataView(
    builder: (data) {
      final matches = data.clubs.where((c) => c.id == id);
      if (matches.isEmpty) return const MissingPage();
      final club = matches.first;
      return DefaultTabController(
        length: 4,
        child: Scaffold(
          appBar: AppBar(title: const Text('Detail Klub')),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Surface(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          SportAvatar(club.sport),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              club.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 20,
                                color: KokColors.ink,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '${club.sport} · Kel. ${club.village}',
                        style: const TextStyle(color: KokColors.muted),
                      ),
                      const SizedBox(height: 10),
                      StatusBadge(club.active ? 'Aktif' : 'Pasif'),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 20,
                        runSpacing: 8,
                        children: ['Atlet', 'Pelatih', 'Official']
                            .map(
                              (role) => Text(
                                '${clubPeople(data, id, role).length} $role',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: KokColors.ink,
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ],
                  ),
                ),
              ),
              const TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.center,
                tabs: [
                  Tab(text: 'Atlet'),
                  Tab(text: 'Pelatih'),
                  Tab(text: 'Official'),
                  Tab(text: 'Dokumen'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    ...['Atlet', 'Pelatih', 'Official'].map(
                      (role) => _PeopleList(people: clubPeople(data, id, role)),
                    ),
                    ListView(
                      padding: const EdgeInsets.all(16),
                      children: const [
                        Surface(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Dokumen klub',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              SizedBox(height: 12),
                              DetailRow('SK Klub', 'Belum tersedia'),
                              DetailRow('Kepengurusan', 'Belum tersedia'),
                              Text(
                                'Dokumen dan izin akses menunggu integrasi SICABOR. Tidak ada berkas asli dalam versi demo.',
                                style: TextStyle(color: KokColors.muted),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _PeopleList extends StatefulWidget {
  const _PeopleList({required this.people});
  final List<SportPerson> people;
  @override
  State<_PeopleList> createState() => _PeopleListState();
}

class _PeopleListState extends State<_PeopleList> {
  String query = '';
  @override
  Widget build(BuildContext context) {
    final people = widget.people
        .where((p) => p.name.toLowerCase().contains(query.trim().toLowerCase()))
        .toList();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          onChanged: (v) => setState(() => query = v),
          decoration: const InputDecoration(
            hintText: 'Cari nama...',
            prefixIcon: Icon(Icons.search),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          '${people.length} orang',
          style: const TextStyle(color: KokColors.muted),
        ),
        const SizedBox(height: 12),
        if (people.isEmpty) const EmptyState(),
        ...people.map((p) => PersonTile(person: p)),
        const DemoNote(),
      ],
    );
  }
}

class PersonTile extends StatelessWidget {
  const PersonTile({super.key, required this.person});
  final SportPerson person;
  @override
  Widget build(BuildContext context) => Surface(
    onTap: () => context.push('/person/${person.id}'),
    child: Row(
      children: [
        CircleAvatar(
          backgroundColor: KokColors.pale,
          foregroundColor: KokColors.ink,
          child: Icon(
            person.role == 'Atlet'
                ? Icons.directions_run
                : Icons.person_outline,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                person.name,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${person.role} · ${person.group}',
                style: const TextStyle(fontSize: 12, color: KokColors.muted),
              ),
            ],
          ),
        ),
        const SizedBox(width: 6),
        if (person.missingDocuments.isNotEmpty || person.expiredLicense)
          const Icon(
            Icons.error_outline,
            color: KokColors.red,
            semanticLabel: 'Perlu perhatian',
          )
        else
          const Icon(
            Icons.check_circle_outline,
            color: KokColors.blue,
            semanticLabel: 'Terverifikasi',
          ),
      ],
    ),
  );
}

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
