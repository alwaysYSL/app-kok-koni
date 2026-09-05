import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kok_app/app.dart';
import 'package:kok_app/core/session.dart';
import 'package:kok_app/data/repository.dart';

Future<ProviderContainer> start(
  WidgetTester tester, {
  double width = 390,
  double scale = 1,
}) async {
  tester.view.physicalSize = Size(width, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final data = await tester.runAsync(() => DemoKokRepository().fetch());
  final container = ProviderContainer(
    overrides: [
      preferencesProvider.overrideWithValue(prefs),
      snapshotProvider.overrideWith((ref) async => data!),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const KokApp()),
  );
  await tester.pumpAndSettle();
  return container;
}

void main() {
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
    await tester.tap(find.text('Bulu Tangkis'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('PB Citra Garut'));
    await tester.pumpAndSettle();
    expect(find.text('Detail Klub'), findsOneWidget);
    await tester.tap(find.text('Atlet 1 · PB Citra Garut'));
    await tester.pumpAndSettle();
    expect(find.text('Detail Atlet'), findsOneWidget);
    container.read(routerProvider).go('/committee');
    await tester.pumpAndSettle();
    expect(find.text('Ketua KOK'), findsOneWidget);
    expect(find.text('Nama Atlet Satu'), findsNothing);
    container.read(routerProvider).go('/profile');
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Keluar'), 200);
    await tester.tap(find.text('Keluar'));
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
    await container
        .read(sessionProvider.notifier)
        .signIn('DEMO-001', 'kokgarut123', false);
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
}
