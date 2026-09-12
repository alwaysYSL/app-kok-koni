import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kok_app/core/auth/domain/user_principal.dart';
import 'package:kok_app/data/models.dart';
import 'package:kok_app/data/demo_kok_repository.dart';
import 'package:kok_app/data/providers/snapshot_provider.dart';
import 'package:kok_app/features/committee_page.dart';
import 'package:kok_app/shared/widgets.dart';

Widget buildTestableWidget({
  required Widget child,
  KokSnapshot? snapshot,
  GoRouter? router,
}) {
  final snap =
      snapshot ??
      KokSnapshot(
        scope: const AccessScope(
          type: AccessScopeType.district,
          id: 'garut_kota',
          name: 'Kecamatan Garut Kota',
        ),
        clubs: const [],
        people: const [],
        committee: const [
          CommitteeMember(
            id: 'ketua',
            name: 'Asep (contoh)',
            position: 'Ketua KOK',
            division: 'Pengurus inti',
          ),
          CommitteeMember(
            id: 'wakil',
            name: 'Dedi (contoh)',
            position: 'Wakil Ketua',
            division: 'Pengurus inti',
          ),
          CommitteeMember(
            id: 'sekretaris',
            name: 'Rina (contoh)',
            position: 'Sekretaris',
            division: 'Pengurus inti',
          ),
          CommitteeMember(
            id: 'bendahara',
            name: 'Siti (contoh)',
            position: 'Bendahara',
            division: 'Pengurus inti',
          ),
          CommitteeMember(
            id: 'pembinaan',
            name: 'Hendra (contoh)',
            position: 'Koordinator Pembinaan',
            division: 'Pembinaan prestasi',
          ),
        ],
        loadedAt: DateTime(2026, 9, 5),
      );

  final appRouter =
      router ??
      GoRouter(
        initialLocation: '/committee',
        routes: [GoRoute(path: '/committee', builder: (_, _) => child)],
      );

  return ProviderScope(
    overrides: [snapshotProvider.overrideWith((_) async => snap)],
    child: MaterialApp.router(routerConfig: appRouter),
  );
}

Future<void> pumpCommitteePage(
  WidgetTester tester, {
  Widget child = const CommitteePage(),
  KokSnapshot? snapshot,
  GoRouter? router,
}) async {
  tester.view.physicalSize = const Size(390, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final appRouter =
      router ??
      GoRouter(
        initialLocation: '/committee',
        routes: [GoRoute(path: '/committee', builder: (_, _) => child)],
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
    'CommitteePage renders dynamic title, sort button, header card, search bar, chips, and member cards',
    (tester) async {
      await pumpCommitteePage(tester);

      // Dynamic title
      expect(find.text('Anggota KOK (5)'), findsOneWidget);

      // Rounded sort button with swap_vert icon
      expect(find.byIcon(Icons.swap_vert), findsOneWidget);

      // Header card
      expect(find.text('KEPENGURUSAN KOK'), findsOneWidget);
      expect(find.text('Kecamatan Garut Kota'), findsOneWidget);
      expect(find.text('5 pengurus · Periode 2025–2029'), findsOneWidget);

      // Search bar
      expect(find.text('Cari nama atau jabatan...'), findsOneWidget);
      expect(find.byIcon(Icons.search), findsOneWidget);

      // Filter chips
      expect(find.text('Semua 5'), findsOneWidget);
      expect(find.text('Pengurus inti 4'), findsOneWidget);
      expect(find.text('Pembinaan prestasi 1'), findsOneWidget);

      // Section header
      expect(find.text('Struktur kepengurusan'), findsOneWidget);
      expect(find.text('5 pengurus'), findsOneWidget);

      // Member cards
      expect(find.byType(CommitteeMemberCard), findsNWidgets(5));
      expect(find.text('Asep (contoh)'), findsOneWidget);
      expect(find.text('Ketua KOK'), findsOneWidget);
      expect(find.text('Dedi (contoh)'), findsOneWidget);
      expect(find.text('Wakil Ketua'), findsOneWidget);
      expect(find.text('Rina (contoh)'), findsOneWidget);
      expect(find.text('Sekretaris'), findsOneWidget);
      expect(find.text('Siti (contoh)'), findsOneWidget);
      expect(find.text('Bendahara'), findsOneWidget);
      expect(find.text('Hendra (contoh)'), findsOneWidget);
      expect(find.text('Koordinator Pembinaan'), findsOneWidget);

      // Chevron icons on cards
      expect(find.byIcon(Icons.chevron_right), findsNWidgets(5));
    },
  );

  testWidgets('Search filtering by name and position', (tester) async {
    await pumpCommitteePage(tester);

    // Search by name
    await tester.enterText(find.byType(TextField), 'Asep');
    await tester.pumpAndSettle();

    expect(find.text('Anggota KOK (1)'), findsOneWidget);
    expect(find.byType(CommitteeMemberCard), findsNWidgets(1));
    expect(find.text('Asep (contoh)'), findsOneWidget);
    expect(find.text('Dedi (contoh)'), findsNothing);

    // Search by position
    await tester.enterText(find.byType(TextField), 'Bendahara');
    await tester.pumpAndSettle();

    expect(find.text('Anggota KOK (1)'), findsOneWidget);
    expect(find.byType(CommitteeMemberCard), findsNWidgets(1));
    expect(find.text('Siti (contoh)'), findsOneWidget);
    expect(find.text('Asep (contoh)'), findsNothing);

    // Search not found -> EmptyState
    await tester.enterText(find.byType(TextField), 'Zzzzz');
    await tester.pumpAndSettle();

    expect(find.text('Anggota KOK (0)'), findsOneWidget);
    expect(find.byType(CommitteeMemberCard), findsNothing);
    expect(find.byType(EmptyState), findsOneWidget);
    expect(find.text('Tidak ada pengurus yang cocok.'), findsOneWidget);
  });

  testWidgets('Division filter chip filters members', (tester) async {
    await pumpCommitteePage(tester);

    // Tap 'Pembinaan prestasi 1'
    await tester.ensureVisible(find.text('Pembinaan prestasi 1'));
    await tester.tap(find.text('Pembinaan prestasi 1'));
    await tester.pumpAndSettle();

    expect(find.text('Anggota KOK (1)'), findsOneWidget);
    expect(find.byType(CommitteeMemberCard), findsNWidgets(1));
    expect(find.text('Hendra (contoh)'), findsOneWidget);
    expect(find.text('Asep (contoh)'), findsNothing);

    // Tap 'Pengurus inti 4'
    await tester.ensureVisible(find.text('Pengurus inti 4'));
    await tester.tap(find.text('Pengurus inti 4'));
    await tester.pumpAndSettle();

    expect(find.text('Anggota KOK (4)'), findsOneWidget);
    expect(find.byType(CommitteeMemberCard), findsNWidgets(4));
    expect(find.text('Hendra (contoh)'), findsNothing);

    // Tap 'Semua 5' to reset
    await tester.ensureVisible(find.text('Semua 5'));
    await tester.tap(find.text('Semua 5'));
    await tester.pumpAndSettle();

    expect(find.text('Anggota KOK (5)'), findsOneWidget);
    expect(find.byType(CommitteeMemberCard), findsNWidgets(5));
  });

  testWidgets('Sort modal allows changing sorting option', (tester) async {
    await pumpCommitteePage(tester);

    // Tap sort button
    await tester.tap(find.byIcon(Icons.swap_vert));
    await tester.pumpAndSettle();

    expect(find.text('Urutkan Pengurus'), findsOneWidget);
    expect(find.text('Struktur Jabatan (Default)'), findsOneWidget);
    expect(find.text('Nama (A → Z)'), findsOneWidget);
    expect(find.text('Nama (Z → A)'), findsOneWidget);
    expect(find.text('Bidang / Divisi (A → Z)'), findsOneWidget);

    // Select Nama (Z → A)
    await tester.tap(find.text('Nama (Z → A)'));
    await tester.pumpAndSettle();

    // Modal closed
    expect(find.text('Urutkan Pengurus'), findsNothing);

    // Verify first card is Siti, last is Asep
    final cards = tester
        .widgetList<CommitteeMemberCard>(find.byType(CommitteeMemberCard))
        .toList();
    expect(cards.first.member.name, 'Siti (contoh)');
    expect(cards.last.member.name, 'Asep (contoh)');

    // Open sort modal again and select Nama (A → Z)
    await tester.tap(find.byIcon(Icons.swap_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nama (A → Z)'));
    await tester.pumpAndSettle();

    final cardsAsc = tester
        .widgetList<CommitteeMemberCard>(find.byType(CommitteeMemberCard))
        .toList();
    expect(cardsAsc.first.member.name, 'Asep (contoh)');
    expect(cardsAsc.last.member.name, 'Siti (contoh)');
  });

  testWidgets('Tapping member card opens Digital ID Card bottom sheet modal', (
    tester,
  ) async {
    await pumpCommitteePage(tester);

    // Tap card of Ketua KOK
    await tester.tap(find.text('Asep (contoh)'));
    await tester.pumpAndSettle();

    // Digital ID Card modal contents
    expect(find.text('Asep (contoh)'), findsWidgets);
    expect(find.text('Ketua KOK'), findsWidgets);
    expect(find.text('Jabatan'), findsOneWidget);
    expect(find.text('Bidang'), findsOneWidget);
    expect(find.text('Pengurus inti'), findsWidgets);
    expect(find.text('Periode'), findsOneWidget);
    expect(find.text('2025–2029'), findsWidgets);
    expect(find.text('Kecamatan'), findsOneWidget);
    expect(find.text('Garut Kota'), findsWidgets);
    expect(
      find.text('Status kepengurusan terdaftar pada SK KOK Garut Kota.'),
      findsOneWidget,
    );
    expect(find.text('Tutup'), findsOneWidget);

    // Tap 'Tutup' button to dismiss modal
    await tester.ensureVisible(find.text('Tutup'));
    await tester.tap(find.text('Tutup'));
    await tester.pumpAndSettle();

    expect(
      find.text('Status kepengurusan terdaftar pada SK KOK Garut Kota.'),
      findsNothing,
    );
  });

  testWidgets('Works seamlessly with DemoKokRepository snapshot', (
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
    await pumpCommitteePage(
      tester,
      child: const CommitteePage(),
      snapshot: data,
    );

    expect(find.text('Anggota KOK (5)'), findsOneWidget);
    expect(find.byType(CommitteeMemberCard), findsNWidgets(5));
    expect(find.text('Asep (contoh)'), findsOneWidget);
    expect(find.text('Hendra (contoh)'), findsOneWidget);
  });
}
