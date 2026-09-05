import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../shared/widgets.dart';

class CommitteePage extends StatefulWidget {
  const CommitteePage({super.key});
  @override
  State<CommitteePage> createState() => _CommitteePageState();
}

class _CommitteePageState extends State<CommitteePage> {
  String _query = '';
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Anggota KOK')),
    body: DataView(
      builder: (data) {
        final members = data.committee
            .where(
              (m) => '${m.name} ${m.position} ${m.division}'
                  .toLowerCase()
                  .contains(_query.trim().toLowerCase()),
            )
            .toList();
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Surface(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const StatusBadge('KEPENGURUSAN KOK'),
                  const SizedBox(height: 12),
                  const Text(
                    'Kecamatan Garut Kota',
                    style: TextStyle(
                      fontSize: 21,
                      color: KokColors.ink,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '${data.committee.length} pengurus · Periode contoh 2025–2029',
                    style: const TextStyle(
                      color: KokColors.muted,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            TextField(
              onChanged: (v) => setState(() => _query = v),
              decoration: const InputDecoration(
                hintText: 'Cari nama atau jabatan...',
                prefixIcon: Icon(Icons.search),
              ),
            ),
            const SizedBox(height: 20),
            const SectionHead('Struktur kepengurusan'),
            if (members.isEmpty) const EmptyState(),
            ...members.map(
              (m) => Surface(
                onTap: () => showModalBottomSheet<void>(
                  context: context,
                  showDragHandle: true,
                  isScrollControlled: true,
                  builder: (context) => SafeArea(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            m.name,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 12),
                          DetailRow('Jabatan', m.position),
                          DetailRow('Bidang', m.division),
                          DetailRow('Periode', m.period),
                          const DetailRow('Kecamatan', 'Garut Kota'),
                          const DemoNote(),
                        ],
                      ),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: KokColors.pale,
                      foregroundColor: KokColors.ink,
                      child: Text(
                        m.name.substring(0, 1),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            m.name,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            m.position,
                            style: const TextStyle(
                              color: KokColors.blue,
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            m.division,
                            style: const TextStyle(
                              color: KokColors.muted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: KokColors.muted),
                  ],
                ),
              ),
            ),
            const DemoNote(),
          ],
        );
      },
    ),
  );
}
