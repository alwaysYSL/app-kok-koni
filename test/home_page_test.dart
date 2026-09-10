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
  final cecepUser = UserPrincipal(
    id: 'usr_tarogong_kidul',
    skNumber: 'DEMO-002',
    fullName: 'Pak Cecep',
    roleTitle: 'Koordinator Kecamatan',
    scope: const AccessScope(
      type: AccessScopeType.district,
      id: 'tarogong_kidul',
      name: 'Kecamatan Tarogong Kidul',
    ),
    permissions: {'sports:read'},
  );

  testWidgets('HomePage menampilkan nama pengurus dan wilayah secara dinamis', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(
            () => _FakeHomeAuthController(cecepUser),
          ),
          snapshotProvider.overrideWith(
            (ref) => DemoKokRepository().fetchScope(cecepUser.scope),
          ),
        ],
        child: const MaterialApp(home: HomePage()),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.textContaining('Pak Cecep'), findsWidgets);
    expect(find.textContaining('Kecamatan Tarogong Kidul'), findsWidgets);
  });

  testWidgets(
    'HomePage menampilkan label Terakhir Dimuat dengan format WIB yang jujur',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authControllerProvider.overrideWith(
              () => _FakeHomeAuthController(cecepUser),
            ),
            snapshotProvider.overrideWith(
              (ref) => DemoKokRepository().fetchScope(cecepUser.scope),
            ),
          ],
          child: const MaterialApp(home: HomePage()),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.textContaining('Terakhir Dimuat:'), findsOneWidget);
      expect(find.textContaining('WIB'), findsWidgets);
      expect(find.textContaining('Terakhir Tersinkron SICABOR'), findsNothing);
    },
  );
}
