import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kok_app/app.dart';
import 'package:kok_app/core/auth/domain/auth_state.dart';
import 'package:kok_app/core/auth/presentation/auth_controller.dart';
import 'app_test.dart' as helpers;

class _PreviewAuthController extends AuthController {
  bool freezeBootstrap = false;

  void setPreviewState(AuthState nextState) {
    state = nextState;
  }

  @override
  Future<void> bootstrap() async {
    if (freezeBootstrap) return;
    return super.bootstrap();
  }
}

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

      final previewController = _PreviewAuthController();
      final container = await helpers.start(
        tester,
        overrides: [
          authControllerProvider.overrideWith(() => previewController),
        ],
      );

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

      await helpers.signInTestUser(container);
      await tester.pumpAndSettle();

      for (final entry in {
        'session_startup': '/session',
        'session_unavailable': '/session-unavailable',
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
        if (entry.key == 'session_startup') {
          previewController.freezeBootstrap = true;
          previewController.setPreviewState(const AuthBootstrapping());
          container.read(routerProvider).go(entry.value);
          await tester.pump(const Duration(milliseconds: 200));
        } else if (entry.key == 'session_unavailable') {
          previewController.setPreviewState(
            const AuthTemporarilyUnavailable(
              reason:
                  'Aplikasi tidak dapat memvalidasi token sesi ke server. Periksa koneksi internet Anda atau masuk kembali.',
            ),
          );
          container.read(routerProvider).go(entry.value);
          await tester.pumpAndSettle();
        } else {
          previewController.freezeBootstrap = false;
          await helpers.signInTestUser(container);
          container.read(routerProvider).go(entry.value);
          await tester.pumpAndSettle();
        }

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
