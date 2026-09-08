import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kok_app/core/auth/domain/auth_state.dart';
import 'package:kok_app/core/auth/domain/user_principal.dart';
import 'package:kok_app/core/auth/presentation/auth_controller.dart';
import 'package:kok_app/data/repository.dart';
import 'package:kok_app/features/home_page.dart';

class _FakeHomeAuthController extends AuthController {
  final UserPrincipal user;
  _FakeHomeAuthController(this.user);

  @override
  AuthState build() => AuthSignedIn(user: user, generation: 1);
}

void main() {
  const cecepUser = UserPrincipal(
    id: 'usr-tarogong-kidul-002',
    skNumber: 'DEMO-002',
    name: 'Pak Cecep',
    role: 'Koordinator Kecamatan',
    districtId: 'tarogong_kidul',
    districtName: 'Kecamatan Tarogong Kidul',
    permissions: {'sports:read'},
  );

  testWidgets('HomePage menampilkan nama pengurus dan wilayah secara dinamis', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(() => _FakeHomeAuthController(cecepUser)),
          snapshotProvider.overrideWith((ref) => DemoKokRepository().fetchDistrict('tarogong_kidul')),
        ],
        child: const MaterialApp(
          home: HomePage(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.textContaining('Pak Cecep'), findsWidgets);
    expect(find.textContaining('Kecamatan Tarogong Kidul'), findsWidgets);
  });
}
