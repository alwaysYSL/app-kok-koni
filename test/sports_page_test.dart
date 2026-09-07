import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:kok_app/data/repository.dart';
import 'package:kok_app/features/sports_page.dart';

void main() {
  group('SportsPage Widget Tests', () {
    Widget buildSubject({GoRouter? router}) {
      return ProviderScope(
        overrides: [
          snapshotProvider.overrideWith((ref) => DemoKokRepository().fetch()),
        ],
        child: MaterialApp.router(
          routerConfig: router ??
              GoRouter(
                initialLocation: '/sports',
                routes: [
                  GoRoute(
                    path: '/sports',
                    builder: (_, _) => const SportsPage(),
                  ),
                  GoRoute(
                    path: '/sport/:name',
                    builder: (_, s) => Scaffold(
                      body: Text('Detail: ${s.pathParameters['name']}'),
                    ),
                  ),
                ],
              ),
        ),
      );
    }

    testWidgets('renders executive header, chart, and sport cards', (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.text('5 Cabang Olahraga Aktif'), findsOneWidget);
      expect(find.text('SEBARAN ATLET PER CABANG OLAHRAGA'), findsOneWidget);
      expect(find.byType(BarChart), findsOneWidget);
      expect(find.text('Pencak Silat'), findsWidgets);
      expect(find.text('Sepak Bola'), findsWidgets);
    });

    testWidgets('filters sports list using search field', (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Bulu');
      await tester.pumpAndSettle();

      expect(find.text('Bulu Tangkis'), findsOneWidget);
      expect(find.text('Renang'), findsNothing);
    });

    testWidgets('tapping sport card navigates to /sport/:name', (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Bulu Tangkis').first);
      await tester.pumpAndSettle();

      expect(find.text('Detail: Bulu Tangkis'), findsOneWidget);
    });
  });
}
