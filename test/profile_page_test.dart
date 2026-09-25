import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kok_app/core/auth/data/dto/sicabor_profile_response.dart';
import 'package:kok_app/core/auth/domain/auth_state.dart';
import 'package:kok_app/core/auth/domain/user_principal.dart';
import 'package:kok_app/core/auth/presentation/auth_controller.dart';
import 'package:kok_app/core/composition/app_composition.dart';
import 'package:kok_app/core/config/deployment_profile.dart';
import 'package:kok_app/core/network/api_exceptions.dart';
import 'package:kok_app/core/preferences.dart';
import 'package:kok_app/data/models.dart';
import 'package:kok_app/data/models/profile_summary.dart';
import 'package:kok_app/data/demo_kok_repository.dart';
import 'package:kok_app/data/providers/profile_providers.dart';
import 'package:kok_app/data/request_cancellation.dart';
import 'package:kok_app/data/providers/snapshot_provider.dart';
import 'package:kok_app/features/profile_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'test_composition.dart';

class _FakeProfileAuthController extends AuthController {
  final UserPrincipal user;
  _FakeProfileAuthController(this.user);

  @override
  AuthState build() => AuthSignedIn(user: user, generation: 1);

  @override
  Future<LogoutResult> logout({
    Duration revocationTimeout = const Duration(seconds: 5),
    String? errorMessage,
  }) async {
    state = AuthSignedOut(errorMessage: errorMessage);
    return const LogoutResult(
      localSessionClosed: true,
      credentialCleared: true,
      metadataClean: true,
      remoteRevocationStatus: RemoteRevocationStatus.revoked,
    );
  }
}

class _SwitchableProfileAuthController extends AuthController {
  final UserPrincipal initialUser;

  _SwitchableProfileAuthController(this.initialUser);

  @override
  AuthState build() => AuthSignedIn(user: initialUser, generation: 1);

  void setUser(UserPrincipal? user) {
    state = user == null
        ? const AuthSignedOut()
        : AuthSignedIn(user: user, generation: 2);
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
    String? errorMessage,
  }) async {
    final res = await completer.future;
    state = AuthSignedOut(errorMessage: errorMessage);
    return res;
  }
}

final testUser = UserPrincipal(
  id: 'usr_garut_kota',
  username: 'DEMO-001',
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
  username: 'DEMO-002',
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
  username: 'DEMO-002',
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
  username: 'DEMO-003',
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

final testProfileSummary = ProfileSummary(
  scope: const SicaborScope(
    districtId: 1728,
    districtName: 'Garut Kota',
    subdistrictId: 172801,
    subdistrictName: 'Garut Kota',
  ),
  member: const SicaborMember(
    id: 1,
    username: 'asep_kok',
    name: 'Pak Asep',
    type: 'KOK',
    status: 1,
    statusLabel: 'Koordinator Kecamatan',
  ),
  kontingen: const SicaborKontingen(
    id: 1,
    code: 'KGPK-0001',
    name: 'Kontingen Garut Kota',
  ),
  totalCabor: 5,
  totalCaborFromClub: 4,
  totalCaborFromAthlete: 5,
  totalClub: 12,
  totalAthlete: 48,
  totalAthleteWithoutClub: 3,
  dataNotes: ['Data atlet dalam proses verifikasi'],
);

AppComposition buildRemoteTestComposition({AppComposition? base}) {
  final baseComp = base ?? buildTestAppComposition();
  return AppComposition(
    profile: const DeploymentProfile(
      environment: AppEnv.staging,
      authMode: AuthMode.remote,
      dataMode: DataMode.remote,
      apiBaseUrl: 'https://staging-api.example.test',
    ),
    authTokenStorage: baseComp.authTokenStorage,
    sessionMetadataStore: baseComp.sessionMetadataStore,
    rememberedUsernameStore: baseComp.rememberedUsernameStore,
    authRepository: baseComp.authRepository,
    kokRepository: baseComp.kokRepository,
    profileService: baseComp.profileService,
    caborService: baseComp.caborService,
    athleteService: baseComp.athleteService,
    clubService: baseComp.clubService,
    credentialIdGenerator: baseComp.credentialIdGenerator,
  );
}

Widget buildTestableProfileWidget({
  required Widget child,
  KokSnapshot? snapshot,
  ProfileSummary? profileSummary,
  Future<ProfileSummary> Function(Ref)? profileSummaryOverride,
  SharedPreferences? preferences,
  GoRouter? router,
  UserPrincipal? user,
  AuthController? authController,
  AppComposition? composition,
}) {
  final currentUser = user ?? testUser;
  final controller = authController ?? _FakeProfileAuthController(currentUser);
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
        helpdesk: const HelpdeskContact(
          whatsapp: '080011112222',
          phone: '(0262) 000-111',
          email: 'helpdesk@example.test',
          address: 'Sekretariat KONI Kabupaten Garut',
          operationalHours: 'Senin–Jumat 08:00–16:00 WIB',
        ),
      );

  final appRouter =
      router ??
      GoRouter(
        initialLocation: '/profile',
        routes: [GoRoute(path: '/profile', builder: (_, _) => child)],
      );

  return ProviderScope(
    overrides: [
      if (composition != null)
        appCompositionProvider.overrideWithValue(composition),
      authControllerProvider.overrideWith(() => controller),
      snapshotProvider.overrideWith((_) async => snap),
      if (profileSummaryOverride != null)
        profileSummaryProvider.overrideWith(profileSummaryOverride)
      else if (profileSummary != null)
        profileSummaryProvider.overrideWith((_) async => profileSummary),
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
  ProfileSummary? profileSummary,
  Future<ProfileSummary> Function(Ref)? profileSummaryOverride,
  SharedPreferences? preferences,
  GoRouter? router,
  UserPrincipal? user,
  AuthController? authController,
  AppComposition? composition,
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
      profileSummary: profileSummary,
      profileSummaryOverride: profileSummaryOverride,
      preferences: preferences,
      router: appRouter,
      user: user,
      authController: authController,
      composition: composition,
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

      await tester.scrollUntilVisible(
        find.text('Keluar dari Akun'),
        100,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.drag(find.byType(ListView), const Offset(0, -48));
      await tester.pump();
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
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          (call) async => null,
        );
        addTearDown(() {
          tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            SystemChannels.platform,
            null,
          );
        });
        await pumpProfilePage(tester, preferences: prefs);

        expect(find.text('DATA & UTILITAS'), findsOneWidget);
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
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          (call) async => null,
        );
        addTearDown(() {
          tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            SystemChannels.platform,
            null,
          );
        });
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
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          (call) async => null,
        );
        addTearDown(() {
          tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            SystemChannels.platform,
            null,
          );
        });
        await pumpProfilePage(tester, preferences: prefs);

        expect(find.text('DATA & UTILITAS'), findsOneWidget);
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
      'tapping Helpdesk KONI Kabupaten opens bottom sheet with model contacts',
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

        // Check contacts supplied by KokSnapshot.helpdesk.
        expect(find.text('Helpdesk & Sekretariat KONI'), findsOneWidget);
        expect(find.text('WhatsApp Helpdesk'), findsOneWidget);
        expect(find.text('080011112222'), findsOneWidget);
        expect(find.text('(0262) 000-111'), findsOneWidget);
        expect(find.text('helpdesk@example.test'), findsOneWidget);
        expect(find.text('Sekretariat KONI Kabupaten Garut'), findsOneWidget);
        expect(
          find.textContaining('Senin–Jumat 08:00–16:00 WIB'),
          findsOneWidget,
        );

        // Close sheet
        expect(find.text('Tutup'), findsOneWidget);
        await tester.tap(find.text('Tutup'));
        await tester.pumpAndSettle();

        expect(find.text('Helpdesk & Sekretariat KONI'), findsNothing);
      },
    );

    testWidgets('helpdesk empty state does not invent contact values', (
      tester,
    ) async {
      final prefs = await SharedPreferences.getInstance();
      final snapshot = KokSnapshot(
        scope: testUser.scope,
        clubs: const [],
        people: const [],
        committee: const [],
        loadedAt: DateTime(2026, 9, 12),
      );

      await pumpProfilePage(tester, preferences: prefs, snapshot: snapshot);
      await tester.tap(find.text('Helpdesk KONI Kabupaten'));
      await tester.pumpAndSettle();

      expect(find.text('Data helpdesk belum tersedia.'), findsOneWidget);
      expect(find.textContaining('0812'), findsNothing);
      expect(find.textContaining('@konigarut.or.id'), findsNothing);
    });

    testWidgets(
      'renders Pengaturan & Aplikasi section and handles settings & about sheets',
      (tester) async {
        final prefs = await SharedPreferences.getInstance();
        await pumpProfilePage(tester, preferences: prefs);

        expect(find.text('APLIKASI'), findsOneWidget);
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
        await tester.drag(find.byType(ListView), const Offset(0, -120));
        await tester.pumpAndSettle();
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
        expect(find.text('DATA & UTILITAS'), findsOneWidget);
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
      expect(find.text('DATA & UTILITAS'), findsOneWidget);
      expect(find.textContaining('entri data'), findsOneWidget);
    });

    testWidgets(
      'Rekapitulasi menampilkan nama wilayah Tarogong Kidul dan menunggu clipboard sebelum konfirmasi',
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
        final clipboardWrite = Completer<void>();
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          (call) async {
            if (call.method == 'Clipboard.setData') {
              copiedText =
                  (call.arguments as Map<Object?, Object?>)['text'] as String?;
              await clipboardWrite.future;
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
        await tester.pump();

        expect(
          find.text('Teks rekapitulasi berhasil disalin ke clipboard'),
          findsNothing,
        );
        expect(copiedText, isNotNull);

        clipboardWrite.complete();
        await tester.pumpAndSettle();

        expect(
          find.text('Teks rekapitulasi berhasil disalin ke clipboard'),
          findsOneWidget,
        );

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

    testWidgets(
      'clipboard failure shows an error without claiming successful copy',
      (tester) async {
        final prefs = await SharedPreferences.getInstance();
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          (call) async {
            if (call.method == 'Clipboard.setData') {
              throw PlatformException(code: 'clipboard-unavailable');
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

        await pumpProfilePage(tester, preferences: prefs);
        await tester.tap(find.text('Rekap Data Kecamatan'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Salin Teks Rekapitulasi'));
        await tester.pumpAndSettle();

        expect(
          find.text('Teks rekapitulasi berhasil disalin ke clipboard'),
          findsNothing,
        );
        expect(
          find.text('Teks rekapitulasi gagal disalin ke clipboard'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'copy re-checks active permission after the account changes while the sheet is open',
      (tester) async {
        final prefs = await SharedPreferences.getInstance();
        var clipboardCalled = false;
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          (call) async {
            if (call.method == 'Clipboard.setData') {
              clipboardCalled = true;
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

        final authController = _SwitchableProfileAuthController(testUser);
        await pumpProfilePage(
          tester,
          preferences: prefs,
          authController: authController,
        );
        await tester.tap(find.text('Rekap Data Kecamatan'));
        await tester.pumpAndSettle();

        authController.setUser(cecepUser);
        await tester.pump();

        await tester.tap(find.text('Salin Teks Rekapitulasi'));
        await tester.pumpAndSettle();

        expect(clipboardCalled, isFalse);
        expect(
          find.text('Teks rekapitulasi berhasil disalin ke clipboard'),
          findsNothing,
        );
      },
    );

    testWidgets(
      'renders demo labels and status when composition dataMode is demo',
      (tester) async {
        final prefs = await SharedPreferences.getInstance();
        final demoComposition = buildTestAppComposition();

        await pumpProfilePage(
          tester,
          preferences: prefs,
          composition: demoComposition,
        );

        // Demo badge on sync card
        expect(
          find.text('Terakhir dimuat: 14:30 · 3 entri data (Mode Demo)'),
          findsOneWidget,
        );

        // Demo connection status
        expect(
          find.text(
            'Status koneksi: Data demo lokal—belum terhubung dengan SICABOR.',
          ),
          findsOneWidget,
        );

        // Demo footer note
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
      },
    );
  });

  group('ProfilePage Remote Mode Tests', () {
    testWidgets('remote account omits contingent when profile has none', (
      tester,
    ) async {
      final prefs = await SharedPreferences.getInstance();
      await pumpProfilePage(
        tester,
        preferences: prefs,
        composition: buildRemoteTestComposition(),
        profileSummary: ProfileSummary(
          scope: testProfileSummary.scope,
          member: testProfileSummary.member,
          totalCabor: 5,
          totalCaborFromClub: 4,
          totalCaborFromAthlete: 5,
          totalClub: 12,
          totalAthlete: 48,
          totalAthleteWithoutClub: 3,
        ),
      );

      expect(find.text('Kontingen Garut Kota'), findsNothing);
      expect(find.text('Pak Asep'), findsOneWidget);
    });

    testWidgets('expired remote session never displays a sample identity', (
      tester,
    ) async {
      final prefs = await SharedPreferences.getInstance();
      final authController = _SwitchableProfileAuthController(testUser);
      await pumpProfilePage(
        tester,
        preferences: prefs,
        composition: buildRemoteTestComposition(),
        authController: authController,
        profileSummaryOverride: (_) => Future.error(
          const RequestCancelledException(
            'Sesi tidak aktif atau telah berakhir.',
          ),
        ),
      );
      authController.setUser(null);
      await tester.pumpAndSettle();

      expect(find.text('Pak Asep'), findsNothing);
      expect(find.text('Kecamatan Garut Kota'), findsNothing);
      expect(find.text('Sesi tidak aktif'), findsOneWidget);
      expect(find.text('Rekap Data Kecamatan'), findsNothing);
    });

    testWidgets(
      'renders executive profile card with user info and kontingen name from profileSummaryProvider',
      (tester) async {
        final prefs = await SharedPreferences.getInstance();
        final remoteComposition = buildRemoteTestComposition();

        await pumpProfilePage(
          tester,
          preferences: prefs,
          composition: remoteComposition,
          profileSummary: testProfileSummary,
        );

        expect(find.text('PA'), findsOneWidget);
        expect(find.text('Pak Asep'), findsOneWidget);
        expect(
          find.text('Koordinator Kecamatan · Kec. Garut Kota'),
          findsOneWidget,
        );
        expect(find.text('AKSES READ-ONLY'), findsOneWidget);
        expect(find.text('Kontingen Garut Kota'), findsOneWidget);
      },
    );

    testWidgets(
      'remote account shows identity status without duplicate dashboard totals or invented sync time',
      (tester) async {
        final prefs = await SharedPreferences.getInstance();
        final remoteComposition = buildRemoteTestComposition();

        await pumpProfilePage(
          tester,
          preferences: prefs,
          composition: remoteComposition,
          profileSummary: testProfileSummary,
        );

        expect(find.text('DATA & UTILITAS'), findsOneWidget);
        expect(find.text('Data Terhubung SICABOR'), findsOneWidget);
        expect(find.text('Koordinator Kecamatan'), findsOneWidget);
        expect(find.text('Total Cabor'), findsNothing);
        expect(find.text('Total Klub'), findsNothing);
        expect(find.text('Total Atlet'), findsNothing);
        expect(find.textContaining('Terakhir sinkron'), findsNothing);
      },
    );

    testWidgets('hides helpdesk and sync status card in remote mode', (
      tester,
    ) async {
      final prefs = await SharedPreferences.getInstance();
      final remoteComposition = buildRemoteTestComposition();

      await pumpProfilePage(
        tester,
        preferences: prefs,
        composition: remoteComposition,
        profileSummary: testProfileSummary,
      );

      // Helpdesk must be hidden
      expect(find.text('Helpdesk KONI Kabupaten'), findsNothing);
      expect(
        find.text('Kontak koordinasi data dan administrasi KOK'),
        findsNothing,
      );

      // Sync card must be hidden
      expect(find.textContaining('entri data'), findsNothing);
      expect(find.textContaining('(Mode Demo)'), findsNothing);

      // Remote footer note without demo claim
      await tester.scrollUntilVisible(
        find.text('Hubungi admin kabupaten untuk koordinasi akun.'),
        200,
      );
      expect(
        find.text('Hubungi admin kabupaten untuk koordinasi akun.'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Data demo lokal—belum terhubung dengan SICABOR.'),
        findsNothing,
      );
    });

    testWidgets(
      'opens remote rekap sheet and copies rekapitulasi text to clipboard for user with reports:export',
      (tester) async {
        final prefs = await SharedPreferences.getInstance();
        final remoteComposition = buildRemoteTestComposition();

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
          preferences: prefs,
          composition: remoteComposition,
          profileSummary: testProfileSummary,
        );

        expect(find.text('DATA & UTILITAS'), findsOneWidget);
        expect(find.text('Rekap Data Kecamatan'), findsOneWidget);

        // Tap Rekap Data Kecamatan
        await tester.tap(find.text('Rekap Data Kecamatan'));
        await tester.pumpAndSettle();

        // Modal should be displayed
        expect(find.text('Rekapitulasi Data KOK Garut Kota'), findsOneWidget);
        expect(
          find.text(
            'Ringkasan data keolahragaan wilayah Kecamatan Garut Kota.',
          ),
          findsOneWidget,
        );
        expect(find.text('5 Cabor'), findsOneWidget);
        expect(find.text('12 Klub'), findsOneWidget);
        expect(find.text('48 Atlet'), findsOneWidget);
        expect(find.text('3 Atlet'), findsOneWidget);

        // Copy button in modal
        expect(find.text('Salin Teks Rekapitulasi'), findsOneWidget);
        await tester.tap(find.text('Salin Teks Rekapitulasi'));
        await tester.pumpAndSettle();

        expect(
          find.text('Teks rekapitulasi berhasil disalin ke clipboard'),
          findsOneWidget,
        );
        expect(copiedText, isNotNull);
        expect(copiedText, contains('REKAPITULASI DATA KECAMATAN GARUT KOTA'));
        expect(copiedText, contains('Total Cabang Olahraga: 5'));
        expect(copiedText, contains('Total Klub: 12'));
        expect(copiedText, contains('Total Atlet: 48'));
        expect(copiedText, contains('Total Atlet Belum Ada Klub: 3'));
        expect(
          copiedText,
          contains(
            'Status: Terdaftar pada Sistem SICABOR Kecamatan Garut Kota',
          ),
        );
      },
    );

    testWidgets('remote account hides rekap when reports:export is absent', (
      tester,
    ) async {
      final prefs = await SharedPreferences.getInstance();
      final remoteComposition = buildRemoteTestComposition();

      await pumpProfilePage(
        tester,
        user: cecepUser,
        preferences: prefs,
        composition: remoteComposition,
        profileSummary: testProfileSummary,
      );

      expect(find.text('Rekap Data Kecamatan'), findsNothing);
      expect(find.text('DATA & UTILITAS'), findsOneWidget);
      expect(find.text('Rekapitulasi Data KOK Garut Kota'), findsNothing);
      expect(find.text('Salin Teks Rekapitulasi'), findsNothing);
    });

    testWidgets('settings modal and logout dialog work in remote mode', (
      tester,
    ) async {
      final prefs = await SharedPreferences.getInstance();
      final remoteComposition = buildRemoteTestComposition();

      await pumpProfilePage(
        tester,
        preferences: prefs,
        composition: remoteComposition,
        profileSummary: testProfileSummary,
      );

      // Test settings sheet
      expect(find.text('Pengaturan Aplikasi'), findsOneWidget);
      await tester.tap(find.text('Pengaturan Aplikasi'));
      await tester.pumpAndSettle();

      expect(find.text('Pengaturan Aplikasi'), findsWidgets);
      expect(find.textContaining('Nomor SK diingat'), findsOneWidget);
      expect(find.text('Hapus nomor SK tersimpan'), findsOneWidget);

      await tester.tap(find.text('Hapus nomor SK tersimpan'));
      await tester.pumpAndSettle();
      expect(prefs.containsKey('remembered_sk'), isFalse);

      // Dismiss settings sheet
      await tester.tapAt(const Offset(20, 20));
      await tester.pumpAndSettle();

      // Test sign out dialog
      await tester.scrollUntilVisible(find.text('Keluar dari Akun'), 200);
      await tester.tap(find.text('Keluar dari Akun'));
      await tester.pumpAndSettle();

      expect(find.text('Keluar dari Akun?'), findsOneWidget);
      await tester.tap(find.text('Batal'));
      await tester.pumpAndSettle();
      expect(find.text('Keluar dari Akun?'), findsNothing);
    });

    testWidgets('remote mode handles loading state', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final remoteComposition = buildRemoteTestComposition();
      final completer = Completer<ProfileSummary>();

      await tester.pumpWidget(
        buildTestableProfileWidget(
          child: const ProfilePage(),
          preferences: prefs,
          composition: remoteComposition,
          profileSummaryOverride: (_) => completer.future,
        ),
      );
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('remote mode handles error state with retry', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final remoteComposition = buildRemoteTestComposition();

      await tester.pumpWidget(
        buildTestableProfileWidget(
          child: const ProfilePage(),
          preferences: prefs,
          composition: remoteComposition,
          profileSummaryOverride: (_) =>
              Future.error(Exception('Network error')),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Gagal memuat data.'), findsOneWidget);
      expect(find.text('Coba Lagi'), findsOneWidget);
    });

    testWidgets(
      'remote mode handles NO_SUBDISTRICT error without retry button',
      (tester) async {
        final prefs = await SharedPreferences.getInstance();
        final remoteComposition = buildRemoteTestComposition();

        await tester.pumpWidget(
          buildTestableProfileWidget(
            child: const ProfilePage(),
            preferences: prefs,
            composition: remoteComposition,
            profileSummaryOverride: (_) => Future.error(
              const ForbiddenException(
                'Akses ditolak',
                'NO_SUBDISTRICT',
                'Akun belum terikat pada kecamatan.',
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump();

        expect(
          find.text(
            'Akun belum terikat pada kecamatan. Hubungi admin kabupaten.',
          ),
          findsOneWidget,
        );
        expect(find.text('Coba Lagi'), findsNothing);
      },
    );
  });
}
