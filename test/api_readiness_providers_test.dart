import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kok_app/core/auth/domain/user_principal.dart';
import 'package:kok_app/core/config/deployment_profile.dart';
import 'package:kok_app/data/demo_kok_repository.dart';
import 'package:kok_app/data/providers/club_providers.dart';
import 'package:kok_app/data/providers/snapshot_provider.dart';

void main() {
  const context = DataRequestContext(
    environment: AppEnv.demo,
    userId: 'usr-1',
    scope: AccessScope(
      type: AccessScopeType.district,
      id: 'garut_kota',
      name: 'Kecamatan Garut Kota',
    ),
    generation: 1,
  );

  test(
    'granular providers memanggil repository dengan parameter sesi',
    () async {
      final container = ProviderContainer(
        overrides: [
          dataRequestContextProvider.overrideWithValue(context),
          repositoryProvider.overrideWithValue(
            DemoKokRepository(simulateLatency: false),
          ),
        ],
      );
      addTearDown(container.dispose);

      final club = await container.read(clubDetailProvider('garuda').future);
      final members = await container.read(
        clubMembersProvider((clubId: 'garuda', role: 'Pelatih')).future,
      );
      final person = await container.read(
        personDetailProvider('garuda-atlet-0').future,
      );
      final committee = await container.read(committeeProvider.future);
      final helpdesk = await container.read(helpdeskProvider.future);

      expect(club.id, 'garuda');
      expect(members, isNotEmpty);
      expect(members.every((member) => member.role == 'Pelatih'), isTrue);
      expect(person.id, 'garuda-atlet-0');
      expect(committee, isNotEmpty);
      expect(helpdesk, isNotNull);
    },
  );

  test('granular provider menolak sesi yang tidak aktif', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final subscription = container.listen(
      clubDetailProvider('garuda'),
      (_, _) {},
    );
    addTearDown(subscription.close);

    await expectLater(
      container.read(clubDetailProvider('garuda').future),
      throwsA(isA<SessionRequiredException>()),
    );
  });
}
