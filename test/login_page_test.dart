import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kok_app/core/auth/data/auth_token_storage.dart';
import 'package:kok_app/core/auth/data/demo_auth_repository.dart';
import 'package:kok_app/core/auth/data/remembered_sk_store.dart';
import 'package:kok_app/core/auth/domain/auth_state.dart';
import 'package:kok_app/core/auth/presentation/auth_controller.dart';
import 'package:kok_app/features/login_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeTokenStorage implements AuthTokenStorage {
  String? token;

  @override
  Future<StoredCredential?> read() async => token != null
      ? StoredCredential(credentialId: 'legacy', refreshToken: token!)
      : null;

  @override
  Future<void> write(StoredCredential credential) async =>
      token = credential.refreshToken;

  @override
  Future<bool> clearIfOwnedBy(String credentialId) async {
    if (token != null) {
      token = null;
      return true;
    }
    return false;
  }

  @override
  Future<void> forceClearForRecovery() async => token = null;

  @override
  Future<void> migrateLegacyStorage() async {}

  @override
  Future<String?> getRefreshToken() async => token;
  @override
  Future<String?> readRefreshToken() async => token;
  @override
  Future<void> saveRefreshToken(String t) async => token = t;
  @override
  Future<void> clear() async => token = null;
}

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
    final tokenStorage = _FakeTokenStorage();
    final skStore = RememberedSkStore(prefs: prefs, key: 'remembered_sk');
    final repo = DemoAuthRepository(
      tokenStorage: tokenStorage,
      skStore: skStore,
      simulateLatency: false,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
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

  testWidgets('DEMO-003 tercantum di bottom sheet akun demo', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final tokenStorage = _FakeTokenStorage();
    final skStore = RememberedSkStore(prefs: prefs, key: 'remembered_sk');
    final repo = DemoAuthRepository(
      tokenStorage: tokenStorage,
      skStore: skStore,
      simulateLatency: false,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(repo),
          rememberedSkStoreProvider.overrideWithValue(skStore),
        ],
        child: const MaterialApp(home: LoginPage()),
      ),
    );

    await tester.tap(find.text('Pilih Akun Demo'));
    await tester.pumpAndSettle();

    expect(find.textContaining('DEMO-003'), findsOneWidget);
    expect(find.textContaining('Ibu Rina'), findsOneWidget);
  });

  testWidgets(
    'Saat authState AuthSignedOut dengan cleanupStatus failed, tampil banner amber recovery dan form dinonaktifkan',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final controller = _MockLoginStateAuthController(
        const AuthSignedOut(cleanupStatus: LocalCleanupStatus.failed),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [authControllerProvider.overrideWith(() => controller)],
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

      // Tap 'Coba Bersihkan Lagi'
      await tester.tap(find.text('Coba Bersihkan Lagi'));
      await tester.pump();

      expect(controller.retryCleanupCalled, isTrue);
    },
  );
}
