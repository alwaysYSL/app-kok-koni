import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:kok_app/data/repository.dart';
import 'package:kok_app/features/sport_detail/sport_detail_page.dart';

void main() {
  group('SportDetailPage Widget Tests', () {
    Widget buildSubject({String sport = 'Sepak Bola', GoRouter? router}) {
      return ProviderScope(
        overrides: [
          snapshotProvider.overrideWith((ref) => DemoKokRepository().fetch()),
        ],
        child: MaterialApp.router(
          routerConfig:
              router ??
              GoRouter(
                initialLocation: '/sport/$sport',
                routes: [
                  GoRoute(
                    path: '/sport/:name',
                    builder: (_, s) => SportDetailPage(
                      sport: s.pathParameters['name'] ?? sport,
                    ),
                  ),
                  GoRoute(
                    path: '/club/:id',
                    builder: (_, s) =>
                        Scaffold(body: Text('Club: ${s.pathParameters['id']}')),
                  ),
                  GoRoute(
                    path: '/person/:id',
                    builder: (_, s) => Scaffold(
                      body: Text('Person: ${s.pathParameters['id']}'),
                    ),
                  ),
                ],
              ),
        ),
      );
    }

    testWidgets('renders sport dynamic header, floating stats card, and tabs', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(360, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildSubject(sport: 'Sepak Bola'));
      await tester.pumpAndSettle();

      expect(find.text('Sepak Bola'), findsWidgets);
      expect(find.text('Kecamatan Garut Kota'), findsWidgets);
      expect(find.text('Klub'), findsWidgets);
      expect(find.text('Atlet'), findsWidgets);
      expect(find.text('Pelatih'), findsWidgets);
      expect(find.byType(TabBar), findsOneWidget);
    });

    testWidgets(
      'renders analytic fl_chart and toggles between age groups and document status',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(360, 1000));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(buildSubject(sport: 'Sepak Bola'));
        await tester.pumpAndSettle();

        expect(find.text('Kelompok Usia'), findsOneWidget);
        expect(find.text('Status Berkas'), findsOneWidget);
        expect(find.byType(BarChart), findsOneWidget);

        await tester.tap(find.text('Status Berkas'));
        await tester.pumpAndSettle();

        expect(find.byType(PieChart), findsOneWidget);
      },
    );

    testWidgets(
      'switches to Atlet tab, filters age group, and taps athlete to open detail',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(360, 1000));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(buildSubject(sport: 'Sepak Bola'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Atlet').first);
        await tester.pumpAndSettle();

        expect(find.byType(TextField), findsOneWidget);
        expect(find.text('Semua'), findsWidgets);

        await tester.tap(find.text('U-16'));
        await tester.pumpAndSettle();

        final firstPerson = find
            .descendant(
              of: find.byType(TabBarView),
              matching: find.textContaining('Atlet'),
            )
            .first;
        await tester.tap(firstPerson);
        await tester.pumpAndSettle();

        expect(find.textContaining('Person:'), findsOneWidget);
      },
    );

    testWidgets('switches to Pelatih tab and taps coach to open detail', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(360, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildSubject(sport: 'Sepak Bola'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Pelatih').first);
      await tester.pumpAndSettle();

      final coachFinder = find
          .descendant(
            of: find.byType(TabBarView),
            matching: find.textContaining('Pelatih'),
          )
          .first;
      await tester.tap(coachFinder);
      await tester.pumpAndSettle();

      expect(find.textContaining('Person:'), findsOneWidget);
    });
  });
}
