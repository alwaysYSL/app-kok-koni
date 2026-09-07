import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kok_app/app.dart';
import 'package:kok_app/core/session.dart';
import 'app_test.dart' as helpers;

void main() {
  testWidgets(
    'Capture rendered mobile previews',
    (tester) async {
      final font = FontLoader('KokSans')
        ..addFont(rootBundle.load('assets/fonts/PlusJakartaSans.ttf'));
      await font.load();
      final icons = FontLoader('MaterialIcons')
        ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
      await icons.load();
      final container = await helpers.start(tester);
      await tester.runAsync(() async {
        final context = tester.element(find.byType(KokApp));
        await precacheImage(
          const AssetImage('assets/branding/logo-koni.png'),
          context,
        );
        if (context.mounted) {
          await precacheImage(
            const AssetImage('assets/branding/mascot.png'),
            context,
          );
        }
      });
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(KokApp),
        matchesGoldenFile('../previews/login.png'),
      );
      await container
          .read(sessionProvider.notifier)
          .signIn('DEMO-001', 'kokgarut123', false);
      await tester.pumpAndSettle();
      for (final entry in {
        'home': '/home',
        'cabor': '/sports',
        'klub': '/clubs',
        'anggota': '/committee',
        'profil': '/profile',
        'detail-klub': '/club/garuda',
        'detail-klub-pb': '/club/pb',
        'detail-klub-voli': '/club/voli',
        'detail-atlet': '/person/voli-atlet-0',
        'detail-cabor': '/sport/Sepak%20Bola',
        'perlu-perhatian': '/attention',
        'pencarian': '/search',
      }.entries) {
        container.read(routerProvider).go(entry.value);
        await tester.pumpAndSettle();
        await expectLater(
          find.byType(KokApp),
          matchesGoldenFile('../previews/${entry.key}.png'),
        );
        expect(tester.takeException(), isNull);
      }
    },
    skip: !const bool.fromEnvironment('CAPTURE_PREVIEWS'),
  );
}
