import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kok_app/core/session.dart';
import 'package:kok_app/data/models.dart';
import 'package:kok_app/data/repository.dart';
import 'package:kok_app/features/profile_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget buildTestableProfileWidget({
  required Widget child,
  KokSnapshot? snapshot,
  SharedPreferences? preferences,
  GoRouter? router,
}) {
  final snap = snapshot ??
      KokSnapshot(
        clubs: const [
          Club(
            id: 'garuda',
            name: 'Klub Garuda Muda',
            sport: 'Sepak Bola',
            village: 'Pakuwon',
          ),
          Club(
            id: 'pb',
            name: 'PB Citra Garut',
            sport: 'Bulu Tangkis',
            village: 'Paminggir',
          ),
        ],
        people: const [
          SportPerson(
            id: 'garuda-atlet-0',
            name: 'Atlet 1 · Garuda Muda',
            clubId: 'garuda',
            role: 'Atlet',
            group: 'U-16',
            missingDocuments: ['Kartu Keluarga'],
          ),
          SportPerson(
            id: 'pb-atlet-0',
            name: 'Atlet 2 · PB Citra Garut',
            clubId: 'pb',
            role: 'Atlet',
            group: 'U-18',
          ),
          SportPerson(
            id: 'garuda-pelatih-0',
            name: 'Pelatih 1 · Garuda Muda',
            clubId: 'garuda',
            role: 'Pelatih',
            group: 'Lisensi C',
          ),
        ],
        committee: const [],
        loadedAt: DateTime(2026, 9, 7, 14, 30),
      );

  final appRouter = router ??
      GoRouter(
        initialLocation: '/profile',
        routes: [
          GoRoute(path: '/profile', builder: (_, _) => child),
        ],
      );

  return ProviderScope(
    overrides: [
      snapshotProvider.overrideWith((_) async => snap),
      if (preferences != null)
        preferencesProvider.overrideWithValue(preferences),
    ],
    child: MaterialApp.router(
      routerConfig: appRouter,
    ),
  );
}

Future<void> pumpProfilePage(
  WidgetTester tester, {
  Widget child = const ProfilePage(),
  KokSnapshot? snapshot,
  SharedPreferences? preferences,
  GoRouter? router,
}) async {
  tester.view.physicalSize = const Size(390, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final appRouter = router ??
      GoRouter(
        initialLocation: '/profile',
        routes: [
          GoRoute(path: '/profile', builder: (_, _) => child),
        ],
      );
  if (router == null) {
    addTearDown(appRouter.dispose);
  }

  await tester.pumpWidget(
    buildTestableProfileWidget(
      child: child,
      snapshot: snapshot,
      preferences: preferences,
      router: appRouter,
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({'remembered_sk': 'DEMO-001'});
  });

  group('ProfilePage Widget Tests', () {
    testWidgets(
      'renders AppBar with title Akun and executive profile card',
      (tester) async {
        final prefs = await SharedPreferences.getInstance();
        await pumpProfilePage(tester, preferences: prefs);

        // Header AppBar title
        expect(find.text('Akun'), findsOneWidget);

        // Executive Profile Card
        expect(find.text('PA'), findsOneWidget);
        expect(find.text('Pak Asep'), findsOneWidget);
        expect(find.text('Koordinator · Kec. Garut Kota'), findsOneWidget);
        expect(find.text('AKSES READ-ONLY'), findsOneWidget);
        expect(find.byType(CustomPaint), findsWidgets);
      },
    );

    test('AccountProfileCardPainter shouldRepaint returns false', () {
      const painter = AccountProfileCardPainter();
      expect(painter.shouldRepaint(const AccountProfileCardPainter()), isFalse);
    });

    testWidgets(
      'renders Seksi Sinkronisasi Data SICABOR with dynamic time and count',
      (tester) async {
        final prefs = await SharedPreferences.getInstance();
        await pumpProfilePage(tester, preferences: prefs);

        expect(find.text('SINKRONISASI DATA SICABOR'), findsOneWidget);
        expect(
          find.text('Terakhir sinkron: 14:30 · 3 entri data'),
          findsOneWidget,
        );
        expect(find.byIcon(Icons.sync_rounded), findsOneWidget);
        expect(
          find.text(
            'Status koneksi: Data lokal tersinkronisasi dengan SICABOR Kabupaten Garut.',
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'tapping sync button triggers invalidation and shows snackbar',
      (tester) async {
        final prefs = await SharedPreferences.getInstance();
        await pumpProfilePage(tester, preferences: prefs);

        final syncButton = find.byIcon(Icons.sync_rounded);
        expect(syncButton, findsOneWidget);

        await tester.tap(syncButton);
        await tester.pump();

        expect(find.text('Data berhasil disinkronkan ulang'), findsOneWidget);
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'renders Utilitas Koordinator section and opens Rekap Data Kecamatan modal',
      (tester) async {
        final prefs = await SharedPreferences.getInstance();
        await pumpProfilePage(tester, preferences: prefs);

        expect(find.text('UTILITAS KOORDINATOR'), findsOneWidget);
        expect(find.text('Rekap Data Kecamatan'), findsOneWidget);
        expect(
          find.text('Ringkasan cabor, klub, dan atlet untuk laporan'),
          findsOneWidget,
        );

        // Tap Rekap Data Kecamatan
        await tester.tap(find.text('Rekap Data Kecamatan'));
        await tester.pumpAndSettle();

        // Modal should be displayed
        expect(find.text('Rekapitulasi Data KOK Garut Kota'), findsOneWidget);
        expect(find.text('2 Cabor'), findsOneWidget);
        expect(find.text('2 Klub'), findsOneWidget);
        expect(find.text('2 Atlet'), findsOneWidget);
        expect(find.text('1 Pelatih'), findsOneWidget);
        expect(find.text('1 Berkas Kurang'), findsOneWidget);

        // Copy button in modal
        expect(find.text('Salin Teks Rekapitulasi'), findsOneWidget);
        await tester.tap(find.text('Salin Teks Rekapitulasi'));
        await tester.pump();

        expect(
          find.text('Teks rekapitulasi berhasil disalin ke clipboard'),
          findsOneWidget,
        );
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'tapping Helpdesk KONI Kabupaten opens bottom sheet with contacts',
      (tester) async {
        final prefs = await SharedPreferences.getInstance();
        await pumpProfilePage(tester, preferences: prefs);

        expect(find.text('Helpdesk KONI Kabupaten'), findsOneWidget);
        expect(
          find.text('Kontak koordinasi data dan administrasi KOK'),
          findsOneWidget,
        );

        await tester.tap(find.text('Helpdesk KONI Kabupaten'));
        await tester.pumpAndSettle();

        // Check contacts in bottom sheet
        expect(find.text('Helpdesk & Sekretariat KONI'), findsOneWidget);
        expect(find.textContaining('0812'), findsOneWidget);
        expect(find.textContaining('sekretariat@konigarut.or.id'), findsOneWidget);
        expect(find.textContaining('Ciateul'), findsOneWidget);

        // Close sheet
        expect(find.text('Tutup'), findsOneWidget);
        await tester.tap(find.text('Tutup'));
        await tester.pumpAndSettle();

        expect(find.text('Helpdesk & Sekretariat KONI'), findsNothing);
      },
    );

    testWidgets(
      'renders Pengaturan & Aplikasi section and handles settings & about sheets',
      (tester) async {
        final prefs = await SharedPreferences.getInstance();
        await pumpProfilePage(tester, preferences: prefs);

        expect(find.text('PENGATURAN & APLIKASI'), findsOneWidget);
        expect(find.text('Pengaturan Aplikasi'), findsOneWidget);
        expect(
          find.text('Preferensi sesi & memori nomor SK'),
          findsOneWidget,
        );

        // Tap Pengaturan Aplikasi
        await tester.tap(find.text('Pengaturan Aplikasi'));
        await tester.pumpAndSettle();

        expect(find.text('Pengaturan Aplikasi'), findsWidgets);
        expect(find.textContaining('Nomor SK diingat'), findsOneWidget);
        expect(find.text('Hapus nomor SK tersimpan'), findsOneWidget);

        // Tap delete remembered SK
        await tester.tap(find.text('Hapus nomor SK tersimpan'));
        await tester.pumpAndSettle();

        expect(prefs.containsKey('remembered_sk'), isFalse);
        expect(find.text('Tidak ada nomor SK tersimpan.'), findsOneWidget);

        // Dismiss settings sheet
        await tester.tapAt(const Offset(20, 20));
        await tester.pumpAndSettle();

        // Tap Tentang Aplikasi
        expect(find.text('Tentang Aplikasi'), findsOneWidget);
        expect(find.text('KOK Garut · Versi 0.1.0 (Prototipe)'), findsOneWidget);

        await tester.tap(find.text('Tentang Aplikasi'));
        await tester.pumpAndSettle();

        expect(find.text('KOK — Koordinator Organisasi Kecamatan'), findsOneWidget);
        expect(find.textContaining('KONI Kabupaten Garut & Dispora Garut'), findsOneWidget);

        // Close about modal
        expect(find.text('Tutup'), findsOneWidget);
        await tester.tap(find.text('Tutup'));
        await tester.pumpAndSettle();

        expect(find.text('KOK — Koordinator Organisasi Kecamatan'), findsNothing);
      },
    );

    testWidgets(
      'tapping Keluar shows custom confirmation dialog and Batal cancels it',
      (tester) async {
        final prefs = await SharedPreferences.getInstance();
        await pumpProfilePage(tester, preferences: prefs);

        // Scroll to Keluar button
        await tester.scrollUntilVisible(find.text('Keluar dari Akun'), 200);
        expect(find.text('Keluar dari Akun'), findsOneWidget);

        // Tap Keluar dari Akun
        await tester.tap(find.text('Keluar dari Akun'));
        await tester.pumpAndSettle();

        // Custom Confirmation Dialog
        expect(find.text('Keluar dari Akun?'), findsOneWidget);
        expect(
          find.text(
            'Sesi Anda akan berakhir. Anda perlu memasukkan kembali nomor SK KOK untuk masuk ke aplikasi.',
          ),
          findsOneWidget,
        );
        expect(find.text('Batal'), findsOneWidget);
        expect(find.text('Ya, Keluar'), findsOneWidget);

        // Tap Batal
        await tester.tap(find.text('Batal'));
        await tester.pumpAndSettle();

        // Dialog dismissed, still on profile page
        expect(find.text('Keluar dari Akun?'), findsNothing);
        expect(find.text('Akun'), findsOneWidget);
      },
    );

    testWidgets(
      'tapping Ya Keluar in confirmation dialog revokes session',
      (tester) async {
        final prefs = await SharedPreferences.getInstance();
        final container = ProviderContainer(
          overrides: [
            preferencesProvider.overrideWithValue(prefs),
          ],
        );
        addTearDown(container.dispose);

        // Sign in first
        await container
            .read(sessionProvider.notifier)
            .signIn('DEMO-001', 'kokgarut123', false);
        expect(container.read(sessionProvider), isTrue);

        final appRouter = GoRouter(
          initialLocation: '/profile',
          routes: [
            GoRoute(
              path: '/profile',
              builder: (_, _) => const ProfilePage(),
            ),
          ],
        );
        addTearDown(appRouter.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp.router(routerConfig: appRouter),
          ),
        );
        await tester.pumpAndSettle();

        // Scroll and tap Keluar dari Akun
        await tester.scrollUntilVisible(find.text('Keluar dari Akun'), 200);
        await tester.tap(find.text('Keluar dari Akun'));
        await tester.pumpAndSettle();

        // Tap Ya, Keluar
        await tester.tap(find.text('Ya, Keluar'));
        await tester.pumpAndSettle();

        // Session revoked
        expect(container.read(sessionProvider), isFalse);
      },
    );

    testWidgets(
      'renders footer note about kabupaten data coordination',
      (tester) async {
        final prefs = await SharedPreferences.getInstance();
        await pumpProfilePage(tester, preferences: prefs);

        await tester.scrollUntilVisible(
          find.text(
            'Data keanggotaan dikelola SICABOR — hubungi admin kabupaten untuk perubahan data akun.',
          ),
          200,
        );
        expect(
          find.text(
            'Data keanggotaan dikelola SICABOR — hubungi admin kabupaten untuk perubahan data akun.',
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'works seamlessly with DemoKokRepository snapshot',
      (tester) async {
        final data = await tester.runAsync(() => DemoKokRepository().fetch());
        final prefs = await SharedPreferences.getInstance();
        await pumpProfilePage(
          tester,
          snapshot: data,
          preferences: prefs,
        );

        expect(find.text('Akun'), findsOneWidget);
        expect(find.text('Pak Asep'), findsOneWidget);
        expect(find.text('SINKRONISASI DATA SICABOR'), findsOneWidget);
        expect(find.textContaining('entri data'), findsOneWidget);
      },
    );
  });
}
