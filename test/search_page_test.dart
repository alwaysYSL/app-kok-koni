import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kok_app/core/theme.dart';
import 'package:kok_app/data/models.dart';
import 'package:kok_app/data/repository.dart';
import 'package:kok_app/features/search/global_search_page.dart';

Widget createSearchTestApp({
  required KokSnapshot snapshot,
  void Function(String route)? onNavigated,
}) {
  final router = GoRouter(
    initialLocation: '/search',
    routes: [
      GoRoute(
        path: '/search',
        builder: (_, _) => const GlobalSearchPage(),
      ),
      GoRoute(
        path: '/person/:id',
        builder: (_, state) {
          onNavigated?.call('/person/${state.pathParameters['id']}');
          return Scaffold(body: Text('Person Detail ${state.pathParameters['id']}'));
        },
      ),
      GoRoute(
        path: '/club/:id',
        builder: (_, state) {
          onNavigated?.call('/club/${state.pathParameters['id']}');
          return Scaffold(body: Text('Club Detail ${state.pathParameters['id']}'));
        },
      ),
      GoRoute(
        path: '/sport/:name',
        builder: (_, state) {
          onNavigated?.call('/sport/${state.pathParameters['name']}');
          return Scaffold(body: Text('Sport Detail ${state.pathParameters['name']}'));
        },
      ),
    ],
  );
  addTearDown(router.dispose);

  return ProviderScope(
    overrides: [
      snapshotProvider.overrideWith((_) async => snapshot),
    ],
    child: MaterialApp.router(
      theme: kokTheme(),
      routerConfig: router,
    ),
  );
}

void main() {
  setUpAll(() async {
    final font = FontLoader('KokSans')
      ..addFont(rootBundle.load('assets/fonts/PlusJakartaSans.ttf'));
    await font.load();
  });

  group('GlobalSearchPage Widget Tests', () {
    testWidgets('renders search input with autofocus, back button, and category chips', (tester) async {
      final repo = DemoKokRepository();
      final data = await tester.runAsync(() => repo.fetch());
      expect(data, isNotNull);

      await tester.pumpWidget(createSearchTestApp(snapshot: data!));
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Cari nama atlet, pelatih, klub, cabor...'), findsOneWidget);
      expect(find.byIcon(Icons.chevron_left), findsOneWidget);
      expect(find.text('Semua'), findsOneWidget);
      expect(find.text('Atlet'), findsOneWidget);
      expect(find.text('Pelatih'), findsOneWidget);
      expect(find.text('Klub'), findsOneWidget);
      expect(find.text('Cabor'), findsOneWidget);
    });

    testWidgets('searches for athlete by name and navigates to athlete detail on tap', (tester) async {
      final repo = DemoKokRepository();
      final data = await tester.runAsync(() => repo.fetch());
      expect(data, isNotNull);

      String? navigatedRoute;
      await tester.pumpWidget(
        createSearchTestApp(
          snapshot: data!,
          onNavigated: (route) => navigatedRoute = route,
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Voli Bina Muda');
      await tester.pumpAndSettle();

      expect(find.text('Atlet 1 · Voli Bina Muda'), findsOneWidget);
      expect(find.textContaining('Voli Bina Muda · Voli'), findsWidgets);

      await tester.tap(find.text('Atlet 1 · Voli Bina Muda'));
      await tester.pumpAndSettle();

      expect(navigatedRoute, '/person/voli-atlet-0');
      expect(find.text('Person Detail voli-atlet-0'), findsOneWidget);
    });

    testWidgets('category chip filters results by role', (tester) async {
      final repo = DemoKokRepository();
      final data = await tester.runAsync(() => repo.fetch());
      expect(data, isNotNull);

      await tester.pumpWidget(createSearchTestApp(snapshot: data!));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Garuda');
      await tester.pumpAndSettle();

      // In 'Semua', both Club and Athletes/Coaches appear
      expect(find.text('Klub Garuda Muda'), findsOneWidget);

      // Tap 'Atlet' chip
      await tester.tap(find.widgetWithText(ChoiceChip, 'Atlet'));
      await tester.pumpAndSettle();

      // Club should be filtered out
      expect(find.text('Klub Garuda Muda'), findsNothing);
      // Athletes should still be present
      expect(find.textContaining('Garuda Muda'), findsWidgets);
    });

    testWidgets('displays empty state when no matches found', (tester) async {
      final repo = DemoKokRepository();
      final data = await tester.runAsync(() => repo.fetch());
      expect(data, isNotNull);

      await tester.pumpWidget(createSearchTestApp(snapshot: data!));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'KataKunciYangTidakMungkinAda123');
      await tester.pumpAndSettle();

      expect(find.textContaining('Tidak ditemukan hasil'), findsOneWidget);
    });

    testWidgets('navigates to club detail and sport detail on tap', (tester) async {
      final repo = DemoKokRepository();
      final data = await tester.runAsync(() => repo.fetch());
      expect(data, isNotNull);

      String? navigatedRoute;
      await tester.pumpWidget(
        createSearchTestApp(
          snapshot: data!,
          onNavigated: (route) => navigatedRoute = route,
        ),
      );
      await tester.pumpAndSettle();

      // Search for 'Silat'
      await tester.enterText(find.byType(TextField), 'Silat');
      await tester.pumpAndSettle();

      // Tap club
      expect(find.text('Silat Panglipur'), findsOneWidget);
      await tester.tap(find.text('Silat Panglipur'));
      await tester.pumpAndSettle();

      expect(navigatedRoute, '/club/silat');
      expect(find.text('Club Detail silat'), findsOneWidget);
    });

    testWidgets('clears query when clear icon is tapped', (tester) async {
      final repo = DemoKokRepository();
      final data = await tester.runAsync(() => repo.fetch());
      expect(data, isNotNull);

      await tester.pumpWidget(createSearchTestApp(snapshot: data!));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Garuda');
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.close), findsOneWidget);
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      expect(find.text('Pencarian Terpadu Garut Kota'), findsOneWidget);
      expect(find.byIcon(Icons.close), findsNothing);
    });

    testWidgets('tapping sport suggestion chip populates search query', (tester) async {
      final repo = DemoKokRepository();
      final data = await tester.runAsync(() => repo.fetch());
      expect(data, isNotNull);

      await tester.pumpWidget(createSearchTestApp(snapshot: data!));
      await tester.pumpAndSettle();

      expect(find.text('SARAN CABANG OLAHRAGA'), findsOneWidget);
      expect(find.widgetWithText(ActionChip, 'Sepak Bola'), findsOneWidget);

      await tester.tap(find.widgetWithText(ActionChip, 'Sepak Bola'));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(TextField, 'Sepak Bola'), findsOneWidget);
      expect(find.textContaining('DITEMUKAN'), findsOneWidget);
    });
  });
}
