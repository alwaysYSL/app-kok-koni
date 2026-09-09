import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kok_app/data/models.dart';
import 'package:kok_app/data/repository.dart';
import 'package:kok_app/features/attention_page.dart';
import 'package:kok_app/shared/widgets.dart';

Widget buildTestableWidget({
  required Widget child,
  KokSnapshot? snapshot,
  GoRouter? router,
}) {
  final snap =
      snapshot ??
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
            id: 'p1',
            name: 'Nama Atlet Dua',
            clubId: 'garuda',
            role: 'Atlet',
            group: 'U-16',
            missingDocuments: ['KK', 'Akta Kelahiran'],
          ),
          SportPerson(
            id: 'p2',
            name: 'Nama Atlet Lima',
            clubId: 'pb',
            role: 'Atlet',
            group: 'U-18',
            missingDocuments: ['Surat Sehat'],
          ),
          SportPerson(
            id: 'p3',
            name: 'Pelatih Satu',
            clubId: 'garuda',
            role: 'Pelatih',
            group: 'Lisensi C',
            expiredLicense: true,
          ),
          SportPerson(
            id: 'p4',
            name: 'Atlet Normal',
            clubId: 'garuda',
            role: 'Atlet',
            group: 'U-16',
          ),
        ],
        committee: const [],
        loadedAt: DateTime(2026, 9, 5),
      );

  final appRouter =
      router ??
      GoRouter(
        initialLocation: '/attention',
        routes: [
          GoRoute(path: '/attention', builder: (_, _) => child),
          GoRoute(
            path: '/person/:id',
            builder: (context, state) => Scaffold(
              body: Text('Person Detail: ${state.pathParameters['id']}'),
            ),
          ),
          GoRoute(
            path: '/home',
            builder: (context, state) =>
                const Scaffold(body: Text('Home Page')),
          ),
        ],
      );

  return ProviderScope(
    overrides: [snapshotProvider.overrideWith((ref) async => snap)],
    child: MaterialApp.router(routerConfig: appRouter),
  );
}

Future<void> pumpAttentionPage(
  WidgetTester tester, {
  Widget child = const AttentionPage(),
  KokSnapshot? snapshot,
  GoRouter? router,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final appRouter =
      router ??
      GoRouter(
        initialLocation: '/attention',
        routes: [
          GoRoute(path: '/attention', builder: (_, _) => child),
          GoRoute(
            path: '/person/:id',
            builder: (context, state) => Scaffold(
              body: Text('Person Detail: ${state.pathParameters['id']}'),
            ),
          ),
          GoRoute(
            path: '/home',
            builder: (context, state) =>
                const Scaffold(body: Text('Home Page')),
          ),
        ],
      );
  if (router == null) {
    addTearDown(appRouter.dispose);
  }

  await tester.pumpWidget(
    buildTestableWidget(child: child, snapshot: snapshot, router: appRouter),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'AttentionPage renders dynamic title, info button, chips, and cards',
    (tester) async {
      await pumpAttentionPage(tester);

      // Dynamic title: 2 docs + 1 license = 3 total
      expect(find.text('Perlu Perhatian (3)'), findsOneWidget);

      // Info button
      expect(find.byIcon(Icons.info_outline), findsOneWidget);

      // 3 filter chips with counts
      expect(find.text('Semua 3'), findsOneWidget);
      expect(find.text('Berkas Atlet 2'), findsOneWidget);
      expect(find.text('Lisensi 1'), findsOneWidget);

      // Subheader
      expect(
        find.text('Temuan kualitas data untuk koordinasi'),
        findsOneWidget,
      );

      // Cards count
      expect(find.byType(AttentionCard), findsNWidgets(3));
      expect(find.text('Nama Atlet Dua'), findsOneWidget);
      expect(find.text('Nama Atlet Lima'), findsOneWidget);
      expect(find.text('Pelatih Satu'), findsOneWidget);
      expect(find.text('Atlet Normal'), findsNothing);

      // Dashed dividers on cards
      expect(find.byType(DashedDivider), findsNWidgets(3));

      // Card details
      expect(find.text('KK & Akta Kelahiran kurang'), findsOneWidget);
      expect(find.text('Surat Sehat kurang'), findsOneWidget);
      expect(find.text('Lisensi kedaluwarsa'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsNWidgets(3));

      // Footer note & demo note
      expect(
        find.text(
          'Tindak lanjuti temuan di atas dengan menghubungi ketua pengurus klub bersangkutan.',
        ),
        findsOneWidget,
      );
      expect(find.byType(DemoNote), findsOneWidget);
    },
  );

  testWidgets('Info button opens modal bottom sheet with coordination guide', (
    tester,
  ) async {
    await pumpAttentionPage(tester);

    // Tap info button
    await tester.tap(find.byIcon(Icons.info_outline));
    await tester.pumpAndSettle();

    // Verify modal title and contents
    expect(find.text('Informasi Kualitas Data'), findsOneWidget);
    expect(find.textContaining('Berkas Atlet'), findsWidgets);
    expect(find.textContaining('Lisensi Pelatih'), findsWidgets);

    // Dismiss modal by tapping close button
    await tester.ensureVisible(find.text('Mengerti'));
    await tester.tap(find.text('Mengerti'));
    await tester.pumpAndSettle();
    expect(find.text('Informasi Kualitas Data'), findsNothing);
  });

  testWidgets(
    'Switching filter chips updates active filter, title, and cards',
    (tester) async {
      await pumpAttentionPage(tester);

      // Initial state: Semua 3
      expect(find.text('Perlu Perhatian (3)'), findsOneWidget);
      expect(find.byType(AttentionCard), findsNWidgets(3));

      // Tap 'Berkas Atlet 2'
      await tester.tap(find.text('Berkas Atlet 2'));
      await tester.pumpAndSettle();

      expect(find.text('Perlu Perhatian (2)'), findsOneWidget);
      expect(find.byType(AttentionCard), findsNWidgets(2));
      expect(find.text('Nama Atlet Dua'), findsOneWidget);
      expect(find.text('Nama Atlet Lima'), findsOneWidget);
      expect(find.text('Pelatih Satu'), findsNothing);

      // Tap 'Lisensi 1'
      await tester.ensureVisible(find.text('Lisensi 1'));
      await tester.tap(find.text('Lisensi 1'));
      await tester.pumpAndSettle();

      expect(find.text('Perlu Perhatian (1)'), findsOneWidget);
      expect(find.byType(AttentionCard), findsNWidgets(1));
      expect(find.text('Pelatih Satu'), findsOneWidget);
      expect(find.text('Nama Atlet Dua'), findsNothing);

      // Tap back to 'Semua 3'
      await tester.ensureVisible(find.text('Semua 3'));
      await tester.tap(find.text('Semua 3'));
      await tester.pumpAndSettle();

      expect(find.text('Perlu Perhatian (3)'), findsOneWidget);
      expect(find.byType(AttentionCard), findsNWidgets(3));
    },
  );

  testWidgets('AttentionPage respects type parameter in constructor', (
    tester,
  ) async {
    await pumpAttentionPage(
      tester,
      child: const AttentionPage(type: 'license'),
    );

    // Opens with license filter directly
    expect(find.text('Perlu Perhatian (1)'), findsOneWidget);
    expect(find.byType(AttentionCard), findsNWidgets(1));
    expect(find.text('Pelatih Satu'), findsOneWidget);
  });

  testWidgets('Tapping AttentionCard navigates to person detail page', (
    tester,
  ) async {
    await pumpAttentionPage(tester);

    await tester.tap(find.text('Nama Atlet Dua'));
    await tester.pumpAndSettle();

    expect(find.text('Person Detail: p1'), findsOneWidget);
  });

  testWidgets('Shows EmptyState when no people match criteria', (tester) async {
    final emptySnapshot = KokSnapshot(
      clubs: const [
        Club(
          id: 'garuda',
          name: 'Klub Garuda Muda',
          sport: 'Sepak Bola',
          village: 'Pakuwon',
        ),
      ],
      people: const [
        SportPerson(
          id: 'p1',
          name: 'Atlet Bersih',
          clubId: 'garuda',
          role: 'Atlet',
          group: 'U-16',
        ),
      ],
      committee: const [],
      loadedAt: DateTime(2026, 9, 5),
    );

    await pumpAttentionPage(
      tester,
      child: const AttentionPage(),
      snapshot: emptySnapshot,
    );

    expect(find.text('Perlu Perhatian (0)'), findsOneWidget);
    expect(find.text('Semua 0'), findsOneWidget);
    expect(find.text('Berkas Atlet 0'), findsOneWidget);
    expect(find.text('Lisensi 0'), findsOneWidget);
    expect(find.byType(EmptyState), findsOneWidget);
    expect(find.text('Tidak ada data yang perlu ditinjau.'), findsOneWidget);
    expect(find.byType(AttentionCard), findsNothing);
  });

  testWidgets(
    'Works seamlessly with DemoKokRepository snapshot (13 total, 8 docs, 5 licenses)',
    (tester) async {
      final data = await tester.runAsync(() => DemoKokRepository().fetch());
      await pumpAttentionPage(
        tester,
        child: const AttentionPage(),
        snapshot: data,
      );

      expect(find.text('Perlu Perhatian (13)'), findsOneWidget);
      expect(find.text('Semua 13'), findsOneWidget);
      expect(find.text('Berkas Atlet 8'), findsOneWidget);
      expect(find.text('Lisensi 5'), findsOneWidget);
    },
  );
}
