import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
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
          routerConfig:
              router ??
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

    testWidgets(
      'renders compact header with cabor count badge and no hero banner',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(360, 1000));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(buildSubject());
        await tester.pumpAndSettle();

        expect(find.text('Cabang Olahraga Aktif'), findsOneWidget);
        expect(find.text('Kecamatan Garut Kota'), findsOneWidget);
        expect(find.textContaining('5 Cabor'), findsOneWidget);
        expect(find.text('DIREKTORI CABANG OLAHRAGA'), findsNothing);
      },
    );

    testWidgets(
      'renders horizontal athlete distribution bars with full names and no search bar',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(360, 1000));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(buildSubject());
        await tester.pumpAndSettle();

        // Verify no search field exists
        expect(find.byType(TextField), findsNothing);

        // Verify distribution chart header
        expect(find.text('SEBARAN ATLET PER CABANG OLAHRAGA'), findsOneWidget);

        // Verify full sport names are rendered in the distribution card
        expect(find.text('Pencak Silat'), findsWidgets);
        expect(find.text('Sepak Bola'), findsWidgets);
        expect(find.text('Bulu Tangkis'), findsWidgets);
        expect(find.text('Bola Voli'), findsWidgets);
        expect(find.text('Renang'), findsWidgets);

        // Verify athlete count labels
        expect(find.text('44 atlet'), findsOneWidget);
        expect(find.text('34 atlet'), findsOneWidget);
      },
    );

    testWidgets(
      'displays sport cards with metric chips and warning badge only on missing documents',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(360, 1000));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(buildSubject());
        await tester.pumpAndSettle();

        // Verify metric chips
        expect(find.textContaining('Klub'), findsWidgets);
        expect(find.textContaining('Atlet'), findsWidgets);
        expect(find.textContaining('Pelatih'), findsWidgets);

        // Verify warning only on Sepak Bola (cabor with 8 missing documents)
        expect(find.text('8 atlet berkas kurang'), findsOneWidget);
        expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);

        // Verify progress bar is removed
        expect(find.byType(LinearProgressIndicator), findsNothing);
      },
    );

    testWidgets(
      'tapping sport card or horizontal bar navigates to /sport/:name',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(360, 1000));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(buildSubject());
        await tester.pumpAndSettle();

        await tester.tap(find.text('Bulu Tangkis').first);
        await tester.pumpAndSettle();

        expect(find.text('Detail: Bulu Tangkis'), findsOneWidget);
      },
    );
  });
}
