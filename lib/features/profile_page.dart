import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/session.dart';
import '../core/theme.dart';
import '../data/repository.dart';
import '../shared/widgets.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: AppBar(title: const Text('Profil')),
    body: DataView(
      builder: (data) => ListView(
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
            child: const Row(
              children: [
                CircleAvatar(
                  radius: 25,
                  backgroundColor: Color(0xFF4D74B0),
                  child: Text(
                    'PA',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 20,
                    ),
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pak Asep',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 23,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 5),
                      Text(
                        'Koordinator · Kec. Garut Kota',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                      SizedBox(height: 10),
                      Text(
                        'AKUN DEMO · AKSES LIHAT',
                        style: TextStyle(
                          color: KokColors.yellow,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: .8,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SectionHead('Sinkronisasi SICABOR'),
          Surface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Belum terhubung',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Muat ulang data demo',
                      onPressed: () => ref.invalidate(snapshotProvider),
                      icon: const Icon(Icons.sync, color: KokColors.blue),
                    ),
                  ],
                ),
                const Text(
                  'Versi ini menggunakan data ilustrasi lokal.',
                  style: TextStyle(color: KokColors.muted),
                ),
                const Divider(height: 24),
                Text(
                  'Demo dimuat ${data.loadedAt.hour.toString().padLeft(2, '0')}:${data.loadedAt.minute.toString().padLeft(2, '0')} · ${data.people.length} atlet/pelatih/official',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
          const SectionHead('Umum'),
          _Menu(
            icon: Icons.help_outline,
            title: 'Bantuan & kontak',
            note: 'Panduan penggunaan aplikasi',
            onTap: () => _show(context, 'Bantuan & kontak', const [
              Text(
                'Gunakan tab Cabor untuk menjelajahi cabang olahraga, lalu pilih klub untuk melihat atlet, pelatih, dan official.',
              ),
              SizedBox(height: 16),
              Text(
                'Tab Anggota berisi kepengurusan KOK. Data olahraga dan kepengurusan ditampilkan sebagai data contoh.',
              ),
              SizedBox(height: 16),
              Text('Kontak resmi admin KONI Garut belum dikonfigurasi.'),
            ]),
          ),
          _Menu(
            icon: Icons.settings_outlined,
            title: 'Pengaturan',
            note: 'Preferensi login',
            onTap: () => showModalBottomSheet<void>(
              context: context,
              showDragHandle: true,
              builder: (_) => const _SettingsSheet(),
            ),
          ),
          _Menu(
            icon: Icons.info_outline,
            title: 'Tentang aplikasi',
            note: 'KOK Garut · versi 0.1.0',
            onTap: () => _show(context, 'Tentang aplikasi', const [
              Text(
                'KOK — Koordinator Organisasi Kecamatan',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              SizedBox(height: 12),
              Text(
                'Frontend proyek kerja praktik di KONI Garut. Versi 0.1.0, prototipe interaktif Flutter.',
              ),
              SizedBox(height: 12),
              Text(
                'Data belum tersambung SICABOR. Nomor SK yang diingat disimpan di perangkat; kata sandi tidak disimpan.',
              ),
            ]),
          ),
          const SizedBox(height: 4),
          OutlinedButton.icon(
            onPressed: () => ref.read(sessionProvider.notifier).signOut(),
            icon: const Icon(Icons.logout),
            label: const Text('Keluar'),
          ),
          const DemoNote(),
        ],
      ),
    ),
  );

  void _show(BuildContext context, String title, List<Widget> children) =>
      showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (_) => SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 20),
                ...children,
              ],
            ),
          ),
        ),
      );
}

class _Menu extends StatelessWidget {
  const _Menu({
    required this.icon,
    required this.title,
    required this.note,
    required this.onTap,
  });
  final IconData icon;
  final String title, note;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Surface(
    onTap: onTap,
    child: Row(
      children: [
        CircleAvatar(
          backgroundColor: const Color(0xFFECE9FF),
          child: Icon(icon, color: KokColors.ink),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(
                note,
                style: const TextStyle(fontSize: 12, color: KokColors.muted),
              ),
            ],
          ),
        ),
        const Icon(Icons.chevron_right),
      ],
    ),
  );
}

class _SettingsSheet extends ConsumerStatefulWidget {
  const _SettingsSheet();
  @override
  ConsumerState<_SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends ConsumerState<_SettingsSheet> {
  @override
  Widget build(BuildContext context) {
    final prefs = ref.read(preferencesProvider);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Pengaturan', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            Text(
              prefs.containsKey('remembered_sk')
                  ? 'Nomor SK diingat di perangkat ini.'
                  : 'Tidak ada nomor SK tersimpan.',
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: prefs.containsKey('remembered_sk')
                  ? () async {
                      await prefs.remove('remembered_sk');
                      if (mounted) setState(() {});
                    }
                  : null,
              child: const Text('Hapus nomor SK tersimpan'),
            ),
          ],
        ),
      ),
    );
  }
}
