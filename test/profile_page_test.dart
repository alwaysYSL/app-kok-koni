import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kok_app/core/auth/domain/auth_state.dart';
import 'package:kok_app/core/auth/domain/user_principal.dart';
import 'package:kok_app/core/auth/presentation/auth_controller.dart';
import 'package:kok_app/core/preferences.dart';
import 'package:kok_app/data/models.dart';
import 'package:kok_app/data/demo_kok_repository.dart';
import 'package:kok_app/data/providers/snapshot_provider.dart';
import 'package:kok_app/features/profile_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeProfileAuthController extends AuthController {
  final UserPrincipal user;
  _FakeProfileAuthController(this.user);

  @override
  AuthState build() => AuthSignedIn(user: user, generation: 1);

  @override
  Future<LogoutResult> logout({
    Duration revocationTimeout = const Duration(seconds: 5),
  }) async {
    state = const AuthSignedOut();
    return const LogoutResult(
      localSessionClosed: true,
      credentialCleared: true,
      metadataClean: true,
      remoteRevocationStatus: RemoteRevocationStatus.revoked,
    );
  }
}

class _CompleterAuthController extends AuthController {
  final UserPrincipal user;
  final Completer<LogoutResult> completer;
  _CompleterAuthController(this.user, this.completer);

  @override
  AuthState build() => AuthSignedIn(user: user, generation: 1);

  @override
  Future<LogoutResult> logout({
    Duration revocationTimeout = const Duration(seconds: 5),
  }) async {
    final res = await completer.future;
    state = const AuthSignedOut();
    return res;
  }
}

final testUser = UserPrincipal(
  id: 'usr_garut_kota',
  skNumber: 'DEMO-001',
  fullName: 'Pak Asep',
  roleTitle: 'Koordinator Kecamatan',
  scope: const AccessScope(
    type: AccessScopeType.district,
    id: 'garut_kota',
    name: 'Kecamatan Garut Kota',
  ),
  permissions: {'sports:read', 'reports:export'},
);

final cecepUser = UserPrincipal(
  id: 'usr_tarogong_kidul',
  skNumber: 'DEMO-002',
  fullName: 'Pak Cecep',
  roleTitle: 'Koordinator Kecamatan',
  scope: const AccessScope(
    type: AccessScopeType.district,
    id: 'tarogong_kidul',
    name: 'Kecamatan Tarogong Kidul',
  ),
  permissions: {'sports:read'},
);

final cecepUserWithExport = UserPrincipal(
  id: 'usr_tarogong_kidul',
  skNumber: 'DEMO-002',
  fullName: 'Pak Cecep',
  roleTitle: 'Koordinator Kecamatan',
  scope: const AccessScope(
    type: AccessScopeType.district,
    id: 'tarogong_kidul',
    name: 'Kecamatan Tarogong Kidul',
  ),
  permissions: {'sports:read', 'reports:export'},
);

final koniKabUser = UserPrincipal(
  id: 'usr_koni_kab',
  skNumber: 'DEMO-003',
  fullName: 'Ibu Rina',
  roleTitle: 'Tim Verifikator',
  scope: const AccessScope(
    type: AccessScopeType.county,
    id: 'koni_kab',
    name: 'KONI Kabupaten Garut',
  ),
  permissions: {
    'sports:read',
    'clubs:read',
    'members:read',
    'documents:verify',
    'reports:export',
  },
);

Widget buildTestableProfileWidget({
  required Widget child,
  KokSnapshot? snapshot,
  SharedPreferences? preferences,
  GoRouter? router,
  UserPrincipal? user,
}) {
  final currentUser = user ?? testUser;
  final snap =
      snapshot ??
      KokSnapshot(
        scope: currentUser.scope,
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

  final appRouter =
      router ??
      GoRouter(
        initialLocation: '/profile',
        routes: [GoRoute(path: '/profile', builder: (_, _) => child)],
      );

  return ProviderScope(
    overrides: [
      authControllerProvider.overrideWith(
        () => _FakeProfileAuthController(currentUser),
      ),
      snapshotProvider.overrideWith((_) async => snap),
      if (preferences != null)
        preferencesProvider.overrideWithValue(preferences),
    ],
    child: MaterialApp.router(routerConfig: appRouter),
  );
}

Future<void> pumpProfilePage(
  WidgetTester tester, {
  Widget child = const ProfilePage(),
  KokSnapshot? snapshot,
  SharedPreferences? preferences,
  GoRouter? router,
  UserPrincipal? user,
}) async {
  tester.view.physicalSize = const Size(390, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final appRouter =
      router ??
      GoRouter(
        initialLocation: '/profile',
        routes: [GoRoute(path: '/profile', builder: (_, _) => child)],
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
      user: user,
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({'remembered_sk': 'DEMO-001'});
  });

  testWidgets(
    'ProfilePage menampilkan profil pengurus dan tombol logout di luar DataView bahkan jika snapshot error',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authControllerProvider.overrideWith(
              () => _FakeProfileAuthController(testUser),
            ),
            snapshotProvider.overrideWith(
              (ref) => throw Exception('Koneksi olahraga gagal'),
            ),
          ],
          child: const MaterialApp(home: ProfilePage()),
        ),
      );

      await tester.pump();

      expect(find.text('Pak Asep'), findsOneWidget);
      expect(
        find.text('Koordinator Kecamatan · Kec. Garut Kota'),
        findsOneWidget,
      );
      expect(find.text('Keluar dari Akun'), findsOneWidget);

      await tester.tap(find.text('Keluar dari Akun'));
      await tester.pumpAndSettle();
      expect(find.text('Keluar dari Akun?'), findsOneWidget);
    },
  );

  group('ProfilePage Widget Tests', () {
    testWidgets('renders AppBar with title Akun and executive profile card', (
      tester,
    ) async {
      final prefs = await SharedPreferences.getInstance();
      await pumpProfilePage(tester, preferences: prefs);

      // Header AppBar title
      expect(find.text('Akun'), findsOneWidget);

      // Executive Profile Card
      expect(find.text('PA'), findsOneWidget);
      expect(find.text('Pak Asep'), findsOneWidget);
      expect(
        find.text('Koordinator Kecamatan · Kec. Garut Kota'),
        findsOneWidget,
      );
      expect(find.text('AKSES READ-ONLY'), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets(
      'renders district user profile with Koordinator Kecamatan and AKSES READ-ONLY badge',
      (tester) async {
        final prefs = await SharedPreferences.getInstance();
        await pumpProfilePage(tester, preferences: prefs, user: testUser);

        expect(find.text('Pak Asep'), findsOneWidget);
        expect(
          find.text('Koordinator Kecamatan · Kec. Garut Kota'),
          findsOneWidget,
        );
        expect(find.text('AKSES READ-ONLY'), findsOneWidget);
      },
    );

    testWidgets(
      'renders county user profile (usr_koni_kab) with Tim Verifikator and AKSES KABUPATEN badge',
      (tester) async {
        final prefs = await SharedPreferences.getInstance();
        await pumpProfilePage(tester, preferences: prefs, user: koniKabUser);

        expect(find.text('IR'), findsOneWidget);
        expect(find.text('Ibu Rina'), findsOneWidget);
        expect(
          find.text('Tim Verifikator · KONI Kabupaten Garut'),
          findsOneWidget,
        );
        expect(find.text('AKSES KABUPATEN'), findsOneWidget);
        expect(find.text('AKSES READ-ONLY'), findsNothing);
      },
    );

    test('AccountProfileCardPainter shouldRepaint returns false', () {
      const painter = AccountProfileCardPainter();
      expect(painter.shouldRepaint(const AccountProfileCardPainter()), isFalse);
    });

    testWidgets(
      'renders Seksi Status Data Keolahragaan with honest demo label and dynamic time/count',
      (tester) async {
        final prefs = await SharedPreferences.getInstance();
        await pumpProfilePage(tester, preferences: prefs);

        expect(find.text('STATUS DATA KEOLAHRAGAAN'), findsOneWidget);
        expect(
          find.text('Terakhir dimuat: 14:30 · 3 entri data (Mode Demo)'),
          findsOneWidget,
        );
        expect(find.byIcon(Icons.sync_rounded), findsOneWidget);
        expect(
          find.text(
            'Status koneksi: Data demo lokal—belum terhubung dengan SICABOR.',
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

        expect(find.text('Data berhasil dimuat ulang'), findsOneWidget);
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'renders Utilitas Koordinator section and opens Rekap Data Kecamatan modal for user with reports:export',
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
      'SC-30: DEMO-002 tanpa permission reports:export tidak dapat mengekspor rekap',
      (tester) async {
        final prefs = await SharedPreferences.getInstance();
        await pumpProfilePage(tester, user: cecepUser, preferences: prefs);

        expect(find.text('Rekap Data Kecamatan'), findsOneWidget);
        expect(
          find.text('Fitur tidak tersedia untuk peran ini'),
          findsOneWidget,
        );

        await tester.tap(find.text('Rekap Data Kecamatan'));
        await tester.pumpAndSettle();

        expect(find.text('Rekapitulasi Data KOK Tarogong Kidul'), findsNothing);
        expect(find.text('Salin Teks Rekapitulasi'), findsNothing);
      },
    );

    testWidgets(
      'tapping Helpdesk KONI Kabupaten opens bottom sheet with contacts and unverified demo note',
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
        expect(
          find.text('WhatsApp Helpdesk (Kontak Demo - Belum Diverifikasi)'),
          findsOneWidget,
        );
        expect(
          find.text(
            'Kontak demo tidak digunakan untuk verifikasi atau pemulihan akun.',
          ),
          findsOneWidget,
        );
        expect(find.textContaining('0812'), findsOneWidget);
        expect(
          find.textContaining('sekretariat@konigarut.or.id'),
          findsOneWidget,
        );
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
        expect(find.text('Preferensi sesi & memori nomor SK'), findsOneWidget);

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
        expect(
          find.text('KOK Garut · Versi 0.1.0 (Prototipe)'),
          findsOneWidget,
        );

        await tester.tap(find.text('Tentang Aplikasi'));
        await tester.pumpAndSettle();

        expect(
          find.text('KOK — Koordinator Organisasi Kecamatan'),
          findsOneWidget,
        );
        expect(
          find.textContaining('KONI Kabupaten Garut & Dispora Garut'),
          findsOneWidget,
        );

        // Close about modal
        expect(find.text('Tutup'), findsOneWidget);
        await tester.tap(find.text('Tutup'));
        await tester.pumpAndSettle();

        expect(
          find.text('KOK — Koordinator Organisasi Kecamatan'),
          findsNothing,
        );
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

    testWidgets('tapping Ya Keluar in confirmation dialog revokes session', (
      tester,
    ) async {
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          preferencesProvider.overrideWithValue(prefs),
          authControllerProvider.overrideWith(
            () => _FakeProfileAuthController(testUser),
          ),
        ],
      );
      addTearDown(container.dispose);

      final appRouter = GoRouter(
        initialLocation: '/profile',
        routes: [
          GoRoute(path: '/profile', builder: (_, _) => const ProfilePage()),
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

      // Session revoked in AuthController
      expect(container.read(authControllerProvider), isA<AuthSignedOut>());
    });

    testWidgets(
      'sign out dialog awaits logout with busy state and disabled buttons',
      (tester) async {
        final prefs = await SharedPreferences.getInstance();
        final completer = Completer<LogoutResult>();
        final fakeController = _CompleterAuthController(testUser, completer);

        final container = ProviderContainer(
          overrides: [
            preferencesProvider.overrideWithValue(prefs),
            authControllerProvider.overrideWith(() => fakeController),
          ],
        );
        addTearDown(container.dispose);

        final appRouter = GoRouter(
          initialLocation: '/profile',
          routes: [
            GoRoute(path: '/profile', builder: (_, _) => const ProfilePage()),
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

        await tester.scrollUntilVisible(find.text('Keluar dari Akun'), 200);
        await tester.tap(find.text('Keluar dari Akun'));
        await tester.pumpAndSettle();

        expect(find.text('Keluar dari Akun?'), findsOneWidget);

        // Tap Ya, Keluar
        await tester.tap(find.text('Ya, Keluar'));
        await tester.pump();

        // While busy logging out: CircularProgressIndicator is shown, buttons disabled
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        final batalButton = tester.widget<TextButton>(
          find.widgetWithText(TextButton, 'Batal'),
        );
        expect(batalButton.onPressed, isNull);
        final keluarButton = tester.widget<ElevatedButton>(
          find.byType(ElevatedButton),
        );
        expect(keluarButton.onPressed, isNull);

        // Complete logout
        completer.complete(
          const LogoutResult(
            localSessionClosed: true,
            credentialCleared: true,
            metadataClean: true,
            remoteRevocationStatus: RemoteRevocationStatus.revoked,
          ),
        );
        await tester.pumpAndSettle();

        // Dialog should be dismissed
        expect(find.text('Keluar dari Akun?'), findsNothing);
      },
    );

    testWidgets('renders footer note about kabupaten data coordination', (
      tester,
    ) async {
      final prefs = await SharedPreferences.getInstance();
      await pumpProfilePage(tester, preferences: prefs);

      await tester.scrollUntilVisible(
        find.text(
          'Data demo lokal—belum terhubung dengan SICABOR. Hubungi admin kabupaten untuk koordinasi akun.',
        ),
        200,
      );
      expect(
        find.text(
          'Data demo lokal—belum terhubung dengan SICABOR. Hubungi admin kabupaten untuk koordinasi akun.',
        ),
        findsOneWidget,
      );
    });

    testWidgets(
      'SC-31: profile page bebas klaim aktif SICABOR dan menampilkan label jujur',
      (tester) async {
        final prefs = await SharedPreferences.getInstance();
        await pumpProfilePage(tester, preferences: prefs);

        // Forbidden claims must NOT exist
        expect(find.text('SINKRONISASI DATA SICABOR'), findsNothing);
        expect(
          find.textContaining('tersinkronisasi dengan SICABOR'),
          findsNothing,
        );
        expect(find.textContaining('data SICABOR aktif'), findsNothing);

        // Honest labels MUST exist
        expect(find.text('STATUS DATA KEOLAHRAGAAN'), findsOneWidget);
        expect(
          find.textContaining('Data demo lokal—belum terhubung dengan SICABOR'),
          findsWidgets,
        );
      },
    );

    testWidgets('works seamlessly with DemoKokRepository snapshot', (
      tester,
    ) async {
      final data = await tester.runAsync(
        () => DemoKokRepository().fetchScope(
          const AccessScope(
            type: AccessScopeType.district,
            id: 'garut_kota',
            name: 'Kecamatan Garut Kota',
          ),
        ),
      );
      final prefs = await SharedPreferences.getInstance();
      await pumpProfilePage(tester, snapshot: data, preferences: prefs);

      expect(find.text('Akun'), findsOneWidget);
      expect(find.text('Pak Asep'), findsOneWidget);
      expect(find.text('STATUS DATA KEOLAHRAGAAN'), findsOneWidget);
      expect(find.textContaining('entri data'), findsOneWidget);
    });

    testWidgets(
      'Rekapitulasi menampilkan nama wilayah Tarogong Kidul secara dinamis saat akun Tarogong Kidul aktif',
      (tester) async {
        final data = await tester.runAsync(
          () => DemoKokRepository().fetchScope(
            const AccessScope(
              type: AccessScopeType.district,
              id: 'tarogong_kidul',
              name: 'Kecamatan Tarogong Kidul',
            ),
          ),
        );
        final prefs = await SharedPreferences.getInstance();

        String? copiedText;
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          (call) async {
            if (call.method == 'Clipboard.setData') {
              copiedText =
                  (call.arguments as Map<Object?, Object?>)['text'] as String?;
            }
            return null;
          },
        );
        addTearDown(() {
          tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            SystemChannels.platform,
            null,
          );
        });

        await pumpProfilePage(
          tester,
          user: cecepUserWithExport,
          snapshot: data,
          preferences: prefs,
        );

        await tester.scrollUntilVisible(find.text('Rekap Data Kecamatan'), 200);
        await tester.tap(find.text('Rekap Data Kecamatan'));
        await tester.pumpAndSettle();

        expect(
          find.text('Rekapitulasi Data KOK Tarogong Kidul'),
          findsOneWidget,
        );
        expect(
          find.text(
            'Ringkasan data keolahragaan wilayah Kecamatan Tarogong Kidul.',
          ),
          findsOneWidget,
        );

        expect(find.text('Salin Teks Rekapitulasi'), findsOneWidget);
        await tester.tap(find.text('Salin Teks Rekapitulasi'));
        await tester.pumpAndSettle();

        expect(
          copiedText,
          contains('REKAPITULASI DATA KECAMATAN TAROGONG KIDUL'),
        );
        expect(
          copiedText,
          contains(
            'Status: Terdaftar pada Sistem KOK Kecamatan Tarogong Kidul',
          ),
        );
      },
    );
  });
}
