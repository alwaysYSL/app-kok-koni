import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kok_app/app.dart';
import 'package:kok_app/core/auth/data/auth_token_storage.dart';
import 'package:kok_app/core/auth/data/demo_auth_repository.dart';
import 'package:kok_app/core/auth/data/remembered_sk_store.dart';
import 'package:kok_app/core/auth/presentation/auth_controller.dart';
import 'package:kok_app/core/auth/domain/auth_state.dart';
import 'package:kok_app/core/auth/presentation/session_unavailable_page.dart';
import 'package:kok_app/core/session.dart';
import 'package:kok_app/data/models.dart';
import 'package:kok_app/features/club_detail/club_document_tab.dart';
import 'package:kok_app/features/clubs_page.dart';
import 'package:kok_app/features/dashboard_decorations.dart';
import 'package:kok_app/features/home_page.dart';
import 'package:kok_app/features/search/global_search_page.dart';
import 'package:kok_app/features/athlete_detail/athlete_detail_page.dart';
import 'package:kok_app/features/sport_detail/sport_detail_page.dart';

class _FakeTokenStorage implements AuthTokenStorage {
  String? _token;
  @override
  Future<String?> readRefreshToken() async => _token;
  @override
  Future<void> saveRefreshToken(String token) async => _token = token;
  @override
  Future<void> clear() async => _token = null;
}

Future<ProviderContainer> start(
  WidgetTester tester, {
  double width = 390,
  double scale = 1,
  String? initialToken,
  List<dynamic> overrides = const [],
}) async {
  tester.view.physicalSize = Size(width, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final tokenStorage = _FakeTokenStorage();
  if (initialToken != null) {
    await tokenStorage.saveRefreshToken(initialToken);
  }
  final skStore = RememberedSkStore(prefs);
  final authRepo = DemoAuthRepository(
    tokenStorage: tokenStorage,
    skStore: skStore,
    simulateLatency: false,
  );
  final container = ProviderContainer(
    overrides: [
      preferencesProvider.overrideWithValue(prefs),
      authTokenStorageProvider.overrideWithValue(tokenStorage),
      rememberedSkStoreProvider.overrideWithValue(skStore),
      authRepositoryProvider.overrideWithValue(authRepo),
      ...overrides,
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const KokApp()),
  );
  await tester.pumpAndSettle();
  return container;
}

Future<void> signInTestUser(
  ProviderContainer container, {
  String sk = 'DEMO-001',
  String password = 'kokgarut123',
}) async {
  await container.read(authControllerProvider.notifier).login(
    skNumber: sk,
    password: password,
    staySignedIn: false,
    rememberSk: false,
  );
  await container.read(sessionProvider.notifier).signIn(sk, password, false);
}

void main() {
  testWidgets(
    'club documents reflect registration availability without actions',
    (tester) async {
      const club = Club(
        id: 'pb',
        name: 'PB Citra Garut',
        sport: 'Bulu Tangkis',
        village: 'Paminggir',
      );
      for (final registration in [null, '', '   ', '  SK/123/2026  ']) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ClubDocumentTab(
                club: club.copyWith(registrationNumber: registration),
              ),
            ),
          ),
        );
        final available = registration == '  SK/123/2026  ';
        expect(find.text('SK Klub'), findsOneWidget);
        expect(find.text('Kepengurusan'), findsOneWidget);
        expect(
          find.text('Tersedia'),
          available ? findsOneWidget : findsNothing,
        );
        expect(find.text('Belum tersedia'), findsNWidgets(available ? 1 : 2));
        if (available) {
          expect(find.text('  SK/123/2026  '), findsOneWidget);
          expect(
            tester.widget<Text>(find.text('Tersedia')).style!.color,
            const Color(0xFF176B38),
          );
        }
        expect(
          tester.widget<Text>(find.text('Belum tersedia').first).style!.color,
          const Color(0xFF4B5563),
        );
        expect(find.textContaining('Data milik SICABOR'), findsOneWidget);
        expect(
          find.byWidgetPredicate(
            (widget) => widget is InkWell && widget.onTap != null,
          ),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets(
    'club detail keeps tabs and collapsed title visible while scrolling',
    (tester) async {
      final container = await start(tester, width: 320);
      await signInTestUser(container);
      await tester.pumpAndSettle();
      container.read(routerProvider).push('/club/garuda');
      await tester.pumpAndSettle();
      await tester.drag(find.byType(TabBarView), const Offset(0, -550));
      await tester.pumpAndSettle();
      final collapsedTitle = find.text('Klub Garuda Muda').last;
      expect(tester.getTopLeft(collapsedTitle).dy, lessThan(64));
      expect(
        tester
            .widget<Opacity>(
              find
                  .ancestor(of: collapsedTitle, matching: find.byType(Opacity))
                  .first,
            )
            .opacity,
        1,
      );
      for (final label in ['Atlet', 'Pelatih', 'Official', 'Dokumen']) {
        expect(find.text(label).hitTestable(), findsOneWidget);
      }
      await tester.tap(find.text('Dokumen'));
      await tester.pumpAndSettle();
      expect(find.text('SK Klub').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'club detail keeps toolbar actions and one title semantic available after collapse',
    (tester) async {
      final semanticsHandle = tester.ensureSemantics();
      final container = await start(tester, width: 320);
      await signInTestUser(container);
      await tester.pumpAndSettle();
      container.read(routerProvider).push('/club/garuda');
      await tester.pumpAndSettle();

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

      await tester.drag(find.byType(TabBarView), const Offset(0, -550));
      await tester.pumpAndSettle();

      expect(find.byTooltip('Kembali').hitTestable(), findsOneWidget);
      expect(find.byTooltip('Bagikan info klub').hitTestable(), findsOneWidget);
      expect(find.semantics.byLabel('Klub Garuda Muda'), findsOne);
      semanticsHandle.dispose();

      await tester.tap(find.byTooltip('Bagikan info klub').hitTestable());
      await tester.pumpAndSettle();
      expect(copiedText, 'Klub Garuda Muda · Sepak Bola · Kel. Pakuwon');
      expect(find.text('Info klub disalin'), findsOneWidget);

      await tester.tap(find.byTooltip('Kembali').hitTestable());
      await tester.pumpAndSettle();
      expect(find.byTooltip('Bagikan info klub'), findsNothing);
      expect(find.text('Beranda'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Club detail renders four polished tabs and share action', (
    tester,
  ) async {
    final container = await start(tester);
    await signInTestUser(container);
    await tester.pumpAndSettle();
    container.read(routerProvider).go('/club/garuda');
    await tester.pumpAndSettle();

    expect(find.text('Klub Garuda Muda'), findsOneWidget);
    for (final label in ['Atlet', 'Pelatih', 'Official', 'Dokumen']) {
      expect(find.text(label), findsOneWidget);
    }
    await tester.tap(find.text('Pelatih'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Pelatih 1'), findsWidgets);
    await tester.tap(find.text('Official'));
    await tester.pumpAndSettle();
    expect(find.text('Official · Klub Garuda Muda'), findsOneWidget);
    await tester.tap(find.text('Dokumen'));
    await tester.pumpAndSettle();
    expect(find.text('SK Klub'), findsOneWidget);
    expect(find.text('Kepengurusan'), findsOneWidget);

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
    await tester.tap(find.byTooltip('Bagikan info klub'));
    await tester.pumpAndSettle();
    expect(copiedText, 'Klub Garuda Muda · Sepak Bola · Kel. Pakuwon');
    expect(find.text('Info klub disalin'), findsOneWidget);

    await tester.tap(find.text('Atlet'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Atlet 1').first);
    await tester.pumpAndSettle();
    expect(find.text('Detail Atlet'), findsOneWidget);
    expect(find.text('KELENGKAPAN BERKAS'), findsOneWidget);
    expect(find.text('Hubungi pengurus klub'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('direct club entry back action returns to the club list', (
    tester,
  ) async {
    final container = await start(tester);
    await signInTestUser(container);
    await tester.pumpAndSettle();
    container.read(routerProvider).go('/club/garuda');
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Kembali'));
    await tester.pumpAndSettle();

    expect(find.byType(ClubsPage), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Login, five tabs, sport/club/person navigation and logout', (
    tester,
  ) async {
    final container = await start(tester);
    expect(find.text('Masuk Akun'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).at(0), 'DEMO-001');
    await tester.enterText(find.byType(TextFormField).at(1), 'kokgarut123');
    await tester.ensureVisible(find.text('Masuk'));
    await tester.tap(find.text('Masuk'));
    await tester.pumpAndSettle();
    expect(find.byType(NavigationDestination), findsNWidgets(5));
    await tester.tap(find.text('Cabor'));
    await tester.pumpAndSettle();
    expect(find.text('Cabang Olahraga'), findsOneWidget);
    await tester.tap(find.text('Bulu Tangkis').first);
    await tester.pumpAndSettle();
    expect(find.byType(SportDetailPage), findsOneWidget);
    expect(find.text('Bulu Tangkis'), findsWidgets);
    expect(find.text('Berkas Lengkap'), findsOneWidget);
    expect(find.byType(TabBar), findsOneWidget);
    await tester.tap(find.widgetWithText(Tab, 'Atlet'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Atlet 1').first);
    await tester.pumpAndSettle();
    expect(find.byType(AthleteDetailPage), findsOneWidget);
    expect(find.text('Detail Atlet'), findsOneWidget);
    expect(find.text('KELENGKAPAN BERKAS'), findsOneWidget);
    expect(find.text('Hubungi pengurus klub'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.chevron_left));
    await tester.pumpAndSettle();
    expect(find.byType(SportDetailPage), findsOneWidget);
    await tester.tap(find.byIcon(Icons.chevron_left));
    await tester.pumpAndSettle();
    expect(find.text('Cabang Olahraga'), findsOneWidget);
    container.read(routerProvider).go('/committee');
    await tester.pumpAndSettle();
    expect(find.textContaining('Anggota KOK'), findsOneWidget);
    expect(find.text('Ketua KOK'), findsOneWidget);
    expect(find.text('Nama Atlet Satu'), findsNothing);
    container.read(routerProvider).go('/profile');
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Keluar dari Akun'), 200);
    await tester.tap(find.text('Keluar dari Akun'));
    await tester.pumpAndSettle();
    expect(find.text('Keluar dari Akun?'), findsOneWidget);
    await tester.tap(find.text('Ya, Keluar'));
    await tester.pumpAndSettle();
    expect(find.text('Masuk Akun'), findsOneWidget);
    container.read(routerProvider).go('/club/garuda');
    await tester.pumpAndSettle();
    expect(find.text('Masuk Akun'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('320px layout, search, missing routes and all major screens', (
    tester,
  ) async {
    final container = await start(tester, width: 320);
    await signInTestUser(container);
    await tester.pumpAndSettle();
    for (final route in [
      '/home',
      '/sports',
      '/clubs',
      '/committee',
      '/profile',
      '/club/garuda',
      '/person/garuda-atlet-0',
      '/attention',
      '/club/missing',
    ]) {
      container.read(routerProvider).go(route);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: route);
      if (route == '/club/garuda') {
        for (final label in ['Atlet', 'Pelatih', 'Official', 'Dokumen']) {
          await tester.tap(find.text(label));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: '$route: $label');
        }
      }
    }
    container.read(routerProvider).go('/clubs');
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'does not exist');
    await tester.pumpAndSettle();
    expect(find.text('Tidak ada hasil yang sesuai.'), findsOneWidget);
    await tester.tap(find.text('Reset filter'));
    await tester.pumpAndSettle();
    expect(find.text('Klub Garuda Muda'), findsOneWidget);
  });

  testWidgets('club detail supports 1.3 text scale without overflow', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final container = await start(tester, width: 320);
    await signInTestUser(container);
    container.read(routerProvider).go('/club/garuda');
    await tester.pumpAndSettle();
    for (final label in ['Atlet', 'Pelatih', 'Official', 'Dokumen']) {
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: label);
    }
  });

  testWidgets('HomePage renders floating card, decorations, stats, and sections', (
    tester,
  ) async {
    final container = await start(tester);
    await signInTestUser(container);
    await tester.pumpAndSettle();

    // Check Header & Decorations
    expect(find.byType(DashboardHeaderDecoration), findsOneWidget);
    expect(find.byType(AthletesSilhouetteGraphic), findsOneWidget);
    expect(find.text('KOORDINATOR ORGANISASI KECAMATAN'), findsOneWidget);
    expect(find.text('Kecamatan Garut Kota'), findsOneWidget);
    expect(find.text('Pak Asep · Koordinator Kecamatan'), findsOneWidget);
    expect(find.text('PA'), findsOneWidget);
    expect(find.text('Cari nama atlet, klub, cabor...'), findsOneWidget);

    // Check Floating Stats Card
    expect(find.textContaining('Terakhir Tersinkron SICABOR'), findsOneWidget);
    expect(find.text('ATLET'), findsOneWidget);
    expect(find.text('PELATIH'), findsOneWidget);
    expect(find.text('KLUB'), findsOneWidget);
    expect(find.text('OFFICIAL'), findsOneWidget);

    // Check Perlu Perhatian & Klub Sections
    expect(find.text('Perlu Perhatian'), findsOneWidget);
    expect(find.text('Klub di kecamatan'), findsOneWidget);
    expect(find.text('Atlet berkas kurang'), findsOneWidget);
    expect(find.text('Lisensi pelatih kedaluwarsa'), findsOneWidget);
    expect(find.text('lihat semua >'), findsNWidgets(2));

    // Tap Profile avatar navigates to profile
    await tester.tap(find.text('PA'));
    await tester.pumpAndSettle();
    expect(find.text('Ketua KOK'), findsNothing);

    // Go back to home and tap 'lihat semua >' on Perlu Perhatian
    container.read(routerProvider).go('/home');
    await tester.pumpAndSettle();
    await tester.tap(find.text('lihat semua >').first);
    await tester.pumpAndSettle();
    expect(find.text('Perlu Perhatian (13)'), findsOneWidget);
    expect(find.text('Semua 13'), findsOneWidget);
    expect(find.text('Berkas Atlet 8'), findsOneWidget);
    expect(find.text('Lisensi 5'), findsOneWidget);
  });

  testWidgets('ClubsPage renders polished UI, sort modal, filter chips and dynamic count', (
    tester,
  ) async {
    final container = await start(tester);
    await signInTestUser(container);
    await tester.pumpAndSettle();

    container.read(routerProvider).go('/clubs');
    await tester.pumpAndSettle();

    // Verify dynamic count in AppBar and subtitle
    expect(find.textContaining('Klub ('), findsOneWidget);
    expect(find.textContaining('klub ·'), findsOneWidget);

    // Verify filter chips
    expect(find.text('Semua'), findsOneWidget);
    expect(find.widgetWithText(FilterChipDropdown, 'Cabor'), findsOneWidget);
    expect(find.widgetWithText(FilterChipDropdown, 'Status'), findsOneWidget);
    expect(find.widgetWithText(FilterChipDropdown, 'Kel.'), findsOneWidget);

    // Verify sort button opens sort modal
    await tester.tap(find.byIcon(Icons.swap_vert));
    await tester.pumpAndSettle();
    expect(find.text('Urutkan Klub'), findsOneWidget);
    expect(find.text('Nama (A → Z)'), findsOneWidget);
    expect(find.text('Jumlah Atlet Terbanyak'), findsOneWidget);

    // Tap sort by athletes
    await tester.tap(find.text('Jumlah Atlet Terbanyak'));
    await tester.pumpAndSettle();

    // Modal should close
    expect(find.text('Urutkan Klub'), findsNothing);
  });

  testWidgets(
    'Search flow: HomePage search bar navigates to /search, finds athlete, opens detail, and navigates back',
    (tester) async {
      final container = await start(tester);
      await signInTestUser(container);
      await tester.pumpAndSettle();

      // 1. Di Beranda, verifikasi keberadaan placeholder 'Cari nama atlet, klub, cabor...'
      expect(find.text('Cari nama atlet, klub, cabor...'), findsOneWidget);

      // 2. Ketuk search bar -> verifikasi pindah ke /search (GlobalSearchPage)
      await tester.tap(find.text('Cari nama atlet, klub, cabor...'));
      await tester.pumpAndSettle();
      expect(find.byType(GlobalSearchPage), findsOneWidget);

      // 3. Cari atlet (masukkan teks 'Voli Bina Muda')
      await tester.enterText(find.byType(TextField), 'Voli Bina Muda');
      await tester.pumpAndSettle();
      expect(find.text('Atlet 1 · Voli Bina Muda'), findsOneWidget);

      // 4. Ketuk kartu atlet -> verifikasi masuk ke Detail Atlet (/person/voli-atlet-0)
      await tester.tap(find.text('Atlet 1 · Voli Bina Muda'));
      await tester.pumpAndSettle();
      expect(find.byType(AthleteDetailPage), findsOneWidget);

      // 5. Ketuk tombol kembali -> kembali ke /search
      await tester.tap(find.byIcon(Icons.chevron_left));
      await tester.pumpAndSettle();
      expect(find.byType(GlobalSearchPage), findsOneWidget);

      // 6. Ketuk kembali lagi -> kembali ke Beranda (/home)
      await tester.tap(find.byIcon(Icons.chevron_left));
      await tester.pumpAndSettle();
      expect(find.byType(HomePage), findsOneWidget);
    },
  );

  group('Authentication & Multi-Account Lifecycle E2E', () {
    testWidgets(
      'Alur 1: Startup -> /session -> /login -> Login Pak Asep -> Logout',
      (tester) async {
        final container = await start(tester);
        expect(find.text('Masuk Akun'), findsOneWidget);

        await tester.enterText(find.byType(TextFormField).at(0), 'DEMO-001');
        await tester.enterText(find.byType(TextFormField).at(1), 'kokgarut123');
        await tester.ensureVisible(find.text('Masuk'));
        await tester.tap(find.text('Masuk'));
        await tester.pumpAndSettle();

        expect(find.byType(HomePage), findsOneWidget);
        expect(find.textContaining('Pak Asep'), findsWidgets);
        expect(find.text('Kecamatan Garut Kota'), findsOneWidget);

        container.read(routerProvider).go('/profile');
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(find.text('Keluar dari Akun'), 200);
        await tester.tap(find.text('Keluar dari Akun'));
        await tester.pumpAndSettle();
        expect(find.text('Keluar dari Akun?'), findsOneWidget);
        await tester.tap(find.text('Ya, Keluar'));
        await tester.pumpAndSettle();

        expect(find.text('Masuk Akun'), findsOneWidget);
      },
    );

    testWidgets(
      'Alur 2: Multi-Akun & Isolasi Cache Tarogong Kidul',
      (tester) async {
        final container = await start(tester);
        expect(find.text('Masuk Akun'), findsOneWidget);

        await tester.enterText(find.byType(TextFormField).at(0), 'DEMO-002');
        await tester.enterText(find.byType(TextFormField).at(1), 'koktarogong123');
        await tester.ensureVisible(find.text('Masuk'));
        await tester.tap(find.text('Masuk'));
        await tester.pumpAndSettle();

        expect(find.byType(HomePage), findsOneWidget);
        expect(find.textContaining('Pak Cecep'), findsWidgets);
        expect(find.text('Kecamatan Tarogong Kidul'), findsOneWidget);

        container.read(routerProvider).go('/sports');
        await tester.pumpAndSettle();
        expect(find.text('Sepak Bola'), findsWidgets);
        expect(find.text('Bulu Tangkis'), findsWidgets);
        expect(find.text('Pencak Silat'), findsWidgets);
        expect(find.text('Bola Voli'), findsWidgets);
        expect(find.text('Renang'), findsNothing);
        expect(find.text('Klub Garuda Muda'), findsNothing);
      },
    );

    testWidgets(
      'Alur 3: Persistensi token auto-restore langsung ke /home',
      (tester) async {
        final container = await start(
          tester,
          initialToken: 'token_usr_garut_kota',
        );

        expect(find.text('Masuk Akun'), findsNothing);
        expect(find.byType(HomePage), findsOneWidget);
        expect(find.textContaining('Pak Asep'), findsWidgets);
        expect(find.text('Kecamatan Garut Kota'), findsOneWidget);
        expect(container.read(currentUserProvider)?.name, 'Pak Asep');
      },
    );

    testWidgets(
      'Alur 4: Simulasi gangguan DEMO-TIMEOUT mengarahkan ke /session-unavailable',
      (tester) async {
        final container = await start(tester);
        expect(find.text('Masuk Akun'), findsOneWidget);

        await tester.enterText(find.byType(TextFormField).at(0), 'DEMO-TIMEOUT');
        await tester.enterText(find.byType(TextFormField).at(1), 'timeout123');
        await tester.ensureVisible(find.text('Masuk'));
        await tester.tap(find.text('Masuk'));
        await tester.pumpAndSettle();

        expect(find.byType(SessionUnavailablePage), findsOneWidget);
        expect(find.text('Koneksi Sesi Terganggu'), findsOneWidget);

        await tester.tap(find.text('Masuk Ulang / Ganti Akun'));
        await tester.pumpAndSettle();

        expect(find.byType(SessionUnavailablePage), findsNothing);
        expect(find.text('Masuk Akun'), findsOneWidget);
        expect(container.read(authControllerProvider), isA<AuthSignedOut>());
      },
    );
  });
}

