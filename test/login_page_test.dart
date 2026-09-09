import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kok_app/core/auth/data/auth_token_storage.dart';
import 'package:kok_app/core/auth/data/demo_auth_repository.dart';
import 'package:kok_app/core/auth/data/remembered_sk_store.dart';
import 'package:kok_app/core/auth/presentation/auth_controller.dart';
import 'package:kok_app/features/login_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeTokenStorage implements AuthTokenStorage {
  String? token;
  @override
  Future<String?> getRefreshToken() async => token;
  @override
  Future<String?> readRefreshToken() async => token;
  @override
  Future<void> saveRefreshToken(String t) async => token = t;
  @override
  Future<void> clear() async => token = null;
}

void main() {
  testWidgets('LoginPage merender form, checkbox, dan opsi akun demo', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues({'remembered_sk': 'DEMO-001'});
    final prefs = await SharedPreferences.getInstance();
    final tokenStorage = _FakeTokenStorage();
    final skStore = RememberedSkStore(prefs);
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
        child: const MaterialApp(
          home: LoginPage(),
        ),
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
}
