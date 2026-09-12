import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kok_app/core/auth/domain/user_principal.dart';
import 'package:kok_app/core/config/deployment_profile.dart';
import 'package:kok_app/data/demo_kok_repository.dart';
import 'package:kok_app/data/kok_repository.dart';
import 'package:kok_app/data/models.dart';
import 'package:kok_app/data/providers/club_providers.dart';
import 'package:kok_app/data/providers/snapshot_provider.dart';
import 'package:kok_app/data/request_cancellation.dart';

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

  test('granular provider membatalkan token saat provider di-dispose', () async {
    final testRepo = _CancellableTestRepository();
    final container = ProviderContainer(
      overrides: [
        dataRequestContextProvider.overrideWithValue(context),
        repositoryProvider.overrideWithValue(testRepo),
      ],
    );

    container.listen(clubDetailProvider('garuda'), (previous, next) {});

    expect(testRepo.capturedCancellation, isNotNull);
    expect(testRepo.capturedCancellation!.isCancelled, isFalse);

    container.dispose();

    expect(testRepo.capturedCancellation!.isCancelled, isTrue);
    expect(testRepo.capturedCancellation!.reason, 'Provider disposed');
  });

  test('granular provider retry policy mengabaikan lifecycle exceptions', () {
    final retryPolicy = clubDetailProvider('garuda').retry;
    expect(retryPolicy, isNotNull);

    expect(retryPolicy!(1, const SessionRequiredException()), isNull);
    expect(retryPolicy(1, const RequestCancelledException()), isNull);
    expect(
      retryPolicy(
        1,
        const UnsupportedScopeException(
          AccessScope(
            type: AccessScopeType.district,
            id: 'garut_kota',
            name: 'Kecamatan Garut Kota',
          ),
        ),
      ),
      isNull,
    );
    expect(
      retryPolicy(1, const KokResourceNotFoundException('club', 'garuda')),
      isNull,
    );

    final regularError = Exception('Transient connection error');
    expect(
      retryPolicy(1, regularError),
      equals(ProviderContainer.defaultRetry(1, regularError)),
    );
  });

  test(
    'runGranularRequest menolak respons basi saat konteks sesi berubah di tengah request',
    () async {
      var activeContext = context;
      late final ProviderContainer container;

      container = ProviderContainer(
        overrides: [
          dataRequestContextProvider.overrideWith((ref) => activeContext),
        ],
      );
      addTearDown(container.dispose);

      var callCount = 0;
      Object? caughtError;
      final testProvider = FutureProvider<void>((ref) async {
        callCount++;
        if (callCount > 1) return;
        try {
          await runGranularRequest(ref, (cancellation, ctx) async {
            expect(ctx, equals(context));
            activeContext = const DataRequestContext(
              environment: AppEnv.demo,
              userId: 'usr-2',
              scope: AccessScope(
                type: AccessScopeType.district,
                id: 'tarogong_kidul',
                name: 'Kecamatan Tarogong Kidul',
              ),
              generation: 2,
            );
            container.refresh(dataRequestContextProvider);
            return 'data';
          });
        } catch (e) {
          caughtError = e;
        }
      });

      await container.read(testProvider.future);

      expect(caughtError, isA<RequestCancelledException>());
    },
  );

  test(
    'committeeProvider meneruskan scope dari konteks tervalidasi ke repository',
    () async {
      final testRepo = _CancellableTestRepository();
      final container = ProviderContainer(
        overrides: [
          dataRequestContextProvider.overrideWithValue(context),
          repositoryProvider.overrideWithValue(testRepo),
        ],
      );
      addTearDown(container.dispose);

      final future = container.read(committeeProvider.future);
      expect(testRepo.capturedScope, equals(context.scope));
      expect(testRepo.capturedCancellation, isNotNull);

      testRepo.committeeCompleter.complete(const <CommitteeMember>[]);
      final result = await future;
      expect(result, isEmpty);
    },
  );
}

class _CancellableTestRepository implements KokRepository {
  RequestCancellation? capturedCancellation;
  AccessScope? capturedScope;
  final Completer<Club> clubCompleter = Completer<Club>();
  final Completer<List<CommitteeMember>> committeeCompleter =
      Completer<List<CommitteeMember>>();

  @override
  Future<Club> fetchClubDetail(
    String clubId, {
    RequestCancellation? cancellation,
  }) {
    capturedCancellation = cancellation;
    return clubCompleter.future;
  }

  @override
  Future<List<CommitteeMember>> fetchCommittee(
    AccessScope scope, {
    RequestCancellation? cancellation,
  }) {
    capturedScope = scope;
    capturedCancellation = cancellation;
    return committeeCompleter.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}



