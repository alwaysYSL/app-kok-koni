import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kok_app/core/auth/data/demo_auth_repository.dart';
import 'package:kok_app/core/auth/data/remembered_sk_store.dart';
import 'package:kok_app/core/auth/data/secure_key_val_store.dart';
import 'package:kok_app/core/auth/domain/auth_state.dart';
import 'package:kok_app/core/auth/presentation/auth_controller.dart';
import 'package:kok_app/core/composition/app_composition.dart';
import 'package:kok_app/core/config/deployment_profile.dart';
import 'package:kok_app/features/login_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockLoginStateAuthController extends AuthController {
  final AuthState initialState;
  bool retryCleanupCalled = false;

  _MockLoginStateAuthController(this.initialState);

  @override
  AuthState build() => initialState;

  @override
  Future<bool> retryLocalCredentialCleanup() async {
    retryCleanupCalled = true;
    return true;
  }
}

final class _LoginSecureStore implements SecureKeyValStore {
  @override
  Future<String?> read({required String key}) async => null;

  @override
  Future<void> write({required String key, required String value}) async {}

  @override
  Future<void> delete({required String key}) async {}

  @override
  Future<bool> containsKey({required String key}) async => false;
}

AppComposition _demoComposition(SharedPreferences preferences) {
  return AppComposition.fromProfile(
    const DeploymentProfile(
      environment: AppEnv.demo,
      authMode: AuthMode.demo,
      dataMode: DataMode.demo,
    ),
    preferences: preferences,
    secureStore: _LoginSecureStore(),
  );
}

void main() {
  testWidgets('LoginPage merender form, checkbox, dan opsi akun demo', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues({'remembered_sk': 'DEMO-001'});
    final prefs = await SharedPreferences.getInstance();
    final skStore = RememberedSkStore(prefs: prefs, key: 'remembered_sk');
    final repo = DemoAuthRepository(simulateLatency: false);
    final composition = _demoComposition(prefs);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appCompositionProvider.overrideWithValue(composition),
          authRepositoryProvider.overrideWithValue(repo),
          rememberedSkStoreProvider.overrideWithValue(skStore),
        ],
        child: const MaterialApp(home: LoginPage()),
      ),
    );

    expect(find.text('Ingat nomor SK di perangkat ini'), findsOneWidget);
    expect(find.text('Tetap Masuk'), findsOneWidget);
    expect(find.text('Pilih Akun Demo'), findsOneWidget);

    // Buka BottomSheet Pilih Akun Demo
    await tester.tap(find.text('Pilih Akun Demo'));
    await tester.pumpAndSettle();

    expect(find.text('Pak Asep · Kec. Garut Kota'), findsOneWidget);
    expect(find.text('Pak Cecep · Kec. Tarogong Kidul'), findsOneWidget);
  });

  testWidgets('mode remote tidak menampilkan selector akun demo', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final composition = AppComposition.fromProfile(
      const DeploymentProfile(
        environment: AppEnv.staging,
        authMode: AuthMode.remote,
        dataMode: DataMode.demo,
        apiBaseUrl: 'https://api.example.test',
      ),
      preferences: prefs,
      secureStore: _LoginSecureStore(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appCompositionProvider.overrideWithValue(composition)],
        child: const MaterialApp(home: LoginPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Pilih Akun Demo'), findsNothing);
    expect(find.textContaining('Mode demo:'), findsNothing);
    expect(find.text('Masuk Akun'), findsOneWidget);
  });

  testWidgets('DEMO-003 menampilkan label kanonis Tim Verifikator', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final skStore = RememberedSkStore(prefs: prefs, key: 'remembered_sk');
    final repo = DemoAuthRepository(simulateLatency: false);
    final composition = _demoComposition(prefs);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appCompositionProvider.overrideWithValue(composition),
          authRepositoryProvider.overrideWithValue(repo),
          rememberedSkStoreProvider.overrideWithValue(skStore),
        ],
        child: const MaterialApp(home: LoginPage()),
      ),
    );

    await tester.tap(find.text('Pilih Akun Demo'));
    await tester.pumpAndSettle();

    expect(
      find.text('DEMO-003 · konigarut123 · Tim Verifikator KONI Kab. Garut'),
      findsOneWidget,
    );
    expect(find.textContaining('Admin KONI Kab. Garut'), findsNothing);
  });

  testWidgets(
    'Saat authState AuthSignedOut dengan cleanupStatus failed, tampil banner amber recovery dan form dinonaktifkan',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final skStore = RememberedSkStore(prefs: prefs, key: 'remembered_sk');
      final composition = _demoComposition(prefs);

      final controller = _MockLoginStateAuthController(
        const AuthSignedOut(cleanupStatus: LocalCleanupStatus.failed),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appCompositionProvider.overrideWithValue(composition),
            authControllerProvider.overrideWith(() => controller),
            rememberedSkStoreProvider.overrideWithValue(skStore),
          ],
          child: const MaterialApp(home: LoginPage()),
        ),
      );
      await tester.pumpAndSettle();

      // Verify amber banner text and button
      expect(find.textContaining('Pembersihan'), findsWidgets);
      expect(find.text('Coba Bersihkan Lagi'), findsOneWidget);

      // Verify input fields and submit button disabled
      final skField = tester.widget<TextFormField>(
        find.widgetWithText(TextFormField, 'Masukkan nomor SK'),
      );
      expect(skField.enabled, isFalse);

      final pwdField = tester.widget<TextFormField>(
        find.widgetWithText(TextFormField, 'Masukkan kata sandi'),
      );
      expect(pwdField.enabled, isFalse);

      final masukButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Masuk'),
      );
      expect(masukButton.onPressed, isNull);

      final demoButton = tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, 'Pilih Akun Demo'),
      );
      expect(demoButton.onPressed, isNull);

      // Tap 'Coba Bersihkan Lagi'
      await tester.tap(find.text('Coba Bersihkan Lagi'));
      await tester.pump();

      expect(controller.retryCleanupCalled, isTrue);
    },
  );
}
