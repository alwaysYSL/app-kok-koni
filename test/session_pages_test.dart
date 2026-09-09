import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kok_app/core/auth/domain/auth_state.dart';
import 'package:kok_app/core/auth/presentation/auth_controller.dart';
import 'package:kok_app/core/auth/presentation/session_signing_out_page.dart';
import 'package:kok_app/core/auth/presentation/session_startup_page.dart';
import 'package:kok_app/core/auth/presentation/session_unavailable_page.dart';
import 'package:kok_app/core/theme.dart';

class _MockAuthController extends AuthController {
  bool retryCalled = false;
  bool logoutCalled = false;

  @override
  AuthState build() =>
      const AuthTemporarilyUnavailable(reason: 'Gangguan sementara');

  @override
  Future<void> retrySession() async {
    retryCalled = true;
  }

  @override
  Future<LogoutResult> logout({
    Duration revocationTimeout = const Duration(seconds: 5),
  }) async {
    logoutCalled = true;
    return const LogoutResult(
      localSessionClosed: true,
      credentialCleared: true,
      metadataClean: true,
      remoteRevocationStatus: RemoteRevocationStatus.revoked,
    );
  }
}

void main() {
  testWidgets(
    'SessionStartupPage merender branding KOK dan indikator pemuatan',
    (tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: SessionStartupPage())),
      );

      expect(find.text('SISTEM INFORMASI KOORDINATOR'), findsOneWidget);
      expect(find.text('KONI Kabupaten Garut'), findsOneWidget);
      expect(find.text('Memeriksa sesi pengguna...'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    },
  );

  testWidgets(
    'SessionUnavailablePage menampilkan kartu kendala dan tombol aksi',
    (tester) async {
      var retryCalled = false;
      var logoutCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: SessionUnavailablePage(
            reason: 'Koneksi ke server terputus.',
            onRetry: () => retryCalled = true,
            onSignOut: () => logoutCalled = true,
          ),
        ),
      );

      expect(find.text('Koneksi Sesi Terganggu'), findsOneWidget);
      expect(find.text('Koneksi ke server terputus.'), findsOneWidget);

      await tester.tap(find.text('Coba Hubungkan Kembali'));
      expect(retryCalled, isTrue);

      await tester.tap(find.text('Masuk Ulang / Ganti Akun'));
      expect(logoutCalled, isTrue);
    },
  );

  testWidgets(
    'Semua teks pada SessionStartupPage memiliki ukuran font >= 12px',
    (tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: SessionStartupPage())),
      );

      final textWidgets = tester.widgetList<Text>(find.byType(Text));
      expect(textWidgets, isNotEmpty);
      for (final text in textWidgets) {
        final fontSize = text.style?.fontSize;
        expect(fontSize, isNotNull);
        expect(
          fontSize!,
          greaterThanOrEqualTo(12.0),
          reason:
              'Teks "${text.data}" memiliki ukuran di bawah 12px: $fontSize',
        );
      }
    },
  );

  testWidgets(
    'Semua teks pada SessionUnavailablePage memiliki ukuran font >= 12px dan judul kartu cardTitle',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: SessionUnavailablePage()),
      );

      final textWidgets = tester.widgetList<Text>(find.byType(Text));
      expect(textWidgets, isNotEmpty);
      for (final text in textWidgets) {
        final fontSize = text.style?.fontSize;
        expect(fontSize, isNotNull);
        expect(
          fontSize!,
          greaterThanOrEqualTo(12.0),
          reason:
              'Teks "${text.data}" memiliki ukuran di bawah 12px: $fontSize',
        );
      }

      final titleText = tester.widget<Text>(
        find.text('Koneksi Sesi Terganggu'),
      );
      expect(titleText.style?.color, KokColors.cardTitle);
    },
  );

  testWidgets(
    'SessionUnavailablePage memicu retrySession dan logout pada authController jika callback tidak disuplai',
    (tester) async {
      final mockController = _MockAuthController();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authControllerProvider.overrideWith(() => mockController),
          ],
          child: const MaterialApp(home: SessionUnavailablePage()),
        ),
      );

      expect(
        find.textContaining(
          'Aplikasi tidak dapat memvalidasi token sesi ke server',
        ),
        findsOneWidget,
      );

      await tester.tap(find.text('Coba Hubungkan Kembali'));
      expect(mockController.retryCalled, isTrue);

      await tester.tap(find.text('Masuk Ulang / Ganti Akun'));
      expect(mockController.logoutCalled, isTrue);
    },
  );

  testWidgets(
    'SessionSigningOutPage menampilkan teks Mengeluarkan Akun dan pattern KOK',
    (tester) async {
      await tester.pumpWidget(const MaterialApp(home: SessionSigningOutPage()));

      expect(find.text('Mengeluarkan Akun'), findsOneWidget);
      expect(
        find.text('Membersihkan sesi lokal dan mengamankan data...'),
        findsOneWidget,
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    },
  );

  testWidgets(
    'SessionUnavailablePage menampilkan custom reason saat diberikan',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SessionUnavailablePage(
            reason: 'Penyimpanan hardware keystore tidak merespons.',
            onRetry: () {},
            onSignOut: () {},
          ),
        ),
      );

      expect(
        find.text('Penyimpanan hardware keystore tidak merespons.'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'Semua teks pada SessionSigningOutPage memiliki ukuran font >= 12px',
    (tester) async {
      await tester.pumpWidget(const MaterialApp(home: SessionSigningOutPage()));

      final textWidgets = tester.widgetList<Text>(find.byType(Text));
      expect(textWidgets, isNotEmpty);
      for (final text in textWidgets) {
        final fontSize = text.style?.fontSize;
        expect(fontSize, isNotNull);
        expect(
          fontSize!,
          greaterThanOrEqualTo(12.0),
          reason:
              'Teks "${text.data}" memiliki ukuran di bawah 12px: $fontSize',
        );
      }
    },
  );
}
