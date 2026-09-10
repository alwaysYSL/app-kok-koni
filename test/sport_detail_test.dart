import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kok_app/core/auth/domain/user_principal.dart';
import 'package:kok_app/core/auth/presentation/auth_controller.dart';
import 'package:kok_app/data/repository.dart';
import 'package:kok_app/features/sport_detail/sport_detail_page.dart';

void main() {
  const garutScope = AccessScope(
    type: AccessScopeType.district,
    id: 'garut_kota',
    name: 'Kecamatan Garut Kota',
  );

  final userWithExport = UserPrincipal(
    id: 'usr_garut_kota',
    skNumber: 'DEMO-001',
    fullName: 'Pak Asep',
    roleTitle: 'Koordinator Kecamatan',
    scope: garutScope,
    permissions: const {'sports:read', 'reports:export'},
  );

  final userWithoutExport = UserPrincipal(
    id: 'usr_tarogong_kidul',
    skNumber: 'DEMO-002',
    fullName: 'Pak Cecep',
    roleTitle: 'Koordinator Kecamatan',
    scope: const AccessScope(
      type: AccessScopeType.district,
      id: 'tarogong_kidul',
      name: 'Kecamatan Tarogong Kidul',
    ),
    permissions: const {'sports:read'},
  );

  group('SportDetailPage Widget Tests', () {
    Widget buildSubject({
      String sport = 'Sepak Bola',
      GoRouter? router,
      AccessScope scope = garutScope,
      UserPrincipal? user,
    }) {
      return ProviderScope(
        overrides: [
          currentUserProvider.overrideWithValue(user),
          snapshotProvider.overrideWith(
            (ref) => DemoKokRepository().fetchScope(scope),
          ),
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

    testWidgets(
      'SC-30: user without reports:export cannot export (share button disabled)',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(360, 1000));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          buildSubject(sport: 'Sepak Bola', user: userWithoutExport),
        );
        await tester.pumpAndSettle();

        final shareBtn = tester.widget<IconButton>(
          find.widgetWithIcon(IconButton, Icons.share_outlined),
        );
        expect(shareBtn.onPressed, isNull);
        expect(shareBtn.tooltip, 'Akses ekspor laporan tidak diizinkan');
        final icon = tester.widget<Icon>(find.byIcon(Icons.share_outlined));
        expect(icon.color, Colors.white38);
      },
    );

    testWidgets(
      'SC-30: user with reports:export can export and summary contains dynamic scope name',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(360, 1000));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        String? copiedText;
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          (call) async {
            if (call.method == 'Clipboard.setData') {
              copiedText = (call.arguments as Map)['text'] as String?;
            }
            return null;
          },
        );

        await tester.pumpWidget(
          buildSubject(sport: 'Sepak Bola', user: userWithExport),
        );
        await tester.pumpAndSettle();

        final shareBtn = tester.widget<IconButton>(
          find.widgetWithIcon(IconButton, Icons.share_outlined),
        );
        expect(shareBtn.onPressed, isNotNull);
        expect(shareBtn.tooltip, 'Bagikan info cabor');
        final icon = tester.widget<Icon>(find.byIcon(Icons.share_outlined));
        expect(icon.color, Colors.white);

        await tester.tap(find.widgetWithIcon(IconButton, Icons.share_outlined));
        await tester.pumpAndSettle();

        expect(copiedText, isNotNull);
        expect(copiedText, contains('REKAPITULASI CABANG OLAHRAGA'));
        expect(copiedText, contains('Cabang Olahraga : Sepak Bola'));
        expect(copiedText, contains('Wilayah         : Kecamatan Garut Kota'));
        expect(
          find.text(
            'Rekapitulasi cabor Sepak Bola berhasil disalin ke papan klip.',
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'renders dynamic territory name from snapshot scope in header',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(360, 1000));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        const tarogongScope = AccessScope(
          type: AccessScopeType.district,
          id: 'tarogong_kidul',
          name: 'Kecamatan Tarogong Kidul',
        );

        await tester.pumpWidget(
          buildSubject(
            sport: 'Sepak Bola',
            scope: tarogongScope,
            user: userWithExport,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Kecamatan Tarogong Kidul'), findsWidgets);
        expect(find.text('Kecamatan Garut Kota'), findsNothing);
      },
    );
  });
}
