import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/theme.dart';
import '../shared/widgets.dart';

class SportsPage extends StatefulWidget {
  const SportsPage({super.key});
  @override
  State<SportsPage> createState() => _SportsPageState();
}

class _SportsPageState extends State<SportsPage> {
  String query = '';
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Cabang Olahraga')),
    body: DataView(
      builder: (data) {
        final allSports = data.clubs.map((c) => c.sport).toSet().toList()
          ..sort();
        final sports = allSports.where(
          (s) => s.toLowerCase().contains(query.trim().toLowerCase()),
        );
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [KokColors.blue, KokColors.ink],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'OLAHRAGA DI KECAMATAN',
                    style: TextStyle(
                      color: Colors.white70,
                      letterSpacing: 1.1,
                      fontSize: 10,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '${allSports.length} cabang olahraga',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 25,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Temukan klub dan potensi atlet Kecamatan Garut Kota.',
                    style: TextStyle(color: Colors.white70, height: 1.5),
                  ),
                ],
              ),
            ),
            TextField(
              onChanged: (v) => setState(() => query = v),
              decoration: const InputDecoration(
                hintText: 'Cari cabang olahraga...',
                prefixIcon: Icon(Icons.search),
              ),
            ),
            const SizedBox(height: 20),
            const SectionHead('Direktori cabor'),
            if (sports.isEmpty) const EmptyState(),
            ...sports.map((sport) {
              final clubs = data.clubs.where((c) => c.sport == sport).toList();
              final ids = clubs.map((c) => c.id).toSet();
              final athletes = data.people
                  .where((p) => ids.contains(p.clubId) && p.role == 'Atlet')
                  .length;
              return Surface(
                onTap: () =>
                    context.push('/sport/${Uri.encodeComponent(sport)}'),
                child: Row(
                  children: [
                    SportAvatar(sport),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            sport,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            '${clubs.length} klub · $athletes atlet',
                            style: const TextStyle(
                              color: KokColors.muted,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: KokColors.blue),
                  ],
                ),
              );
            }),
            const DemoNote(),
          ],
        );
      },
    ),
  );
}
