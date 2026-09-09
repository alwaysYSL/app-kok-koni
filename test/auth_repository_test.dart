import 'package:flutter_test/flutter_test.dart';
import 'package:kok_app/core/auth/data/auth_repository.dart';
import 'package:kok_app/core/auth/data/demo_auth_repository.dart';
import 'package:kok_app/core/auth/data/remembered_sk_store.dart';
import 'package:kok_app/core/auth/domain/auth_failure.dart';
import 'package:kok_app/core/auth/domain/user_principal.dart';
import 'package:kok_app/data/demo_kok_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_token_storage_test.dart';

void main() {
  late InMemoryAuthTokenStorage tokenStorage;
  late RememberedSkStore skStore;
  late DemoAuthRepository repository;

  setUp(() async {
    tokenStorage = InMemoryAuthTokenStorage();
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    skStore = RememberedSkStore(prefs: prefs, key: 'test_remembered_sk');
    repository = DemoAuthRepository(
      tokenStorage: tokenStorage,
      skStore: skStore,
      simulateLatency: false,
    );
  });

  group('RemoteSessionHandle Contract', () {
    test('instansiasi valid dan redacted toString()', () {
      final handle = RemoteSessionHandle('valid_token_123');
      expect(handle.revocationToken, 'valid_token_123');
      expect(handle.toString(), 'RemoteSessionHandle([REDACTED])');
    });

    test('menolak token kosong atau whitespace', () {
      expect(() => RemoteSessionHandle(''), throwsA(isA<FormatException>()));
      expect(() => RemoteSessionHandle('   '), throwsA(isA<FormatException>()));
    });

    test('menolak token melebihi batas 8192 karakter', () {
      final oversizedToken = 'a' * 8193;
      expect(
        () => RemoteSessionHandle(oversizedToken),
        throwsA(isA<FormatException>()),
      );
      final maxToken = 'a' * 8192;
      expect(RemoteSessionHandle(maxToken).revocationToken.length, 8192);
    });
  });

  group('DemoAuthRepository Login (3 Pemetaan Akun)', () {
    test(
      'login sukses akun DEMO-001 Garut Kota (Pak Asep) dengan persistent session',
      () async {
        final result = await repository.login(
          skNumber: 'DEMO-001',
          password: 'kokgarut123',
          staySignedIn: true,
        );

        expect(result.isSuccess, isTrue);
        expect(result.user?.fullName, 'Pak Asep');
        expect(result.user?.scope.id, 'garut_kota');
        expect(result.user?.scope.type, AccessScopeType.district);
        expect(result.refreshToken, 'token_usr_garut_kota');
        expect(result.sessionHandle, isNotNull);
        expect(result.sessionHandle?.revocationToken, isNotEmpty);
      },
    );

    test(
      'login sukses akun DEMO-002 Tarogong Kidul (Pak Cecep) dengan persistent session',
      () async {
        final result = await repository.login(
          skNumber: 'DEMO-002',
          password: 'koktarogong123',
          staySignedIn: true,
        );

        expect(result.isSuccess, isTrue);
        expect(result.user?.fullName, 'Pak Cecep');
        expect(result.user?.scope.id, 'tarogong_kidul');
        expect(result.user?.scope.type, AccessScopeType.district);
        expect(result.refreshToken, 'token_usr_tarogong_kidul');
        expect(result.sessionHandle, isNotNull);
      },
    );

    test(
      'login sukses akun DEMO-003 Kabupaten Garut (Ibu Rina) dengan persistent session',
      () async {
        final result = await repository.login(
          skNumber: 'DEMO-003',
          password: 'konigarut123',
          staySignedIn: true,
        );

        expect(result.isSuccess, isTrue);
        expect(result.user?.fullName, 'Ibu Rina');
        expect(result.user?.scope.id, 'koni_kab');
        expect(result.user?.scope.type, AccessScopeType.county);
        expect(result.refreshToken, 'token_usr_koni_kab');
        expect(result.sessionHandle, isNotNull);
      },
    );

    test(
      'login nonpersisten (staySignedIn: false) tetap menghasilkan RemoteSessionHandle',
      () async {
        final result = await repository.login(
          skNumber: 'DEMO-002',
          password: 'koktarogong123',
          staySignedIn: false,
        );

        expect(result.isSuccess, isTrue);
        expect(result.user?.fullName, 'Pak Cecep');
        expect(result.refreshToken, isNull);
        expect(result.sessionHandle, isNotNull);
      },
    );

    test('kredensial salah mengembalikan pesan generik', () async {
      final result = await repository.login(
        skNumber: 'DEMO-001',
        password: 'salah_password',
        staySignedIn: false,
      );

      expect(result.isSuccess, isFalse);
      expect(result.failure, isA<InvalidCredentialsFailure>());
      expect(result.failure?.message, 'Nomor SK atau kata sandi tidak sesuai.');
    });

    test('simulasi network timeout DEMO-TIMEOUT', () async {
      final result = await repository.login(
        skNumber: 'DEMO-TIMEOUT',
        password: 'timeout123',
        staySignedIn: false,
      );

      expect(result.isSuccess, isFalse);
      expect(result.failure, isA<NetworkTimeoutFailure>());
    });
  });

  group('DemoAuthRepository Session Restore, Revoke, & Logout', () {
    test('restore session saat token tersimpan (Garut Kota)', () async {
      await tokenStorage.saveRefreshToken('token_usr_garut_kota');
      final result = await repository.restoreSession();

      expect(result.isSuccess, isTrue);
      expect(result.user?.id, 'usr-garut-kota-001');
      expect(result.sessionHandle, isNotNull);
    });

    test('restore session dengan token Tarogong Kidul via parameter', () async {
      final result = await repository.restoreSession(
        'token_usr_tarogong_kidul',
      );

      expect(result.isSuccess, isTrue);
      expect(result.user?.id, 'usr-tarogong-kidul-002');
      expect(result.user?.scope.id, 'tarogong_kidul');
      expect(result.sessionHandle, isNotNull);
    });

    test(
      'restore session dengan token Kabupaten Garut via parameter',
      () async {
        final result = await repository.restoreSession('token_usr_koni_kab');

        expect(result.isSuccess, isTrue);
        expect(result.user?.id, 'usr-koni-kab-003');
        expect(result.user?.scope.id, 'koni_kab');
        expect(result.sessionHandle, isNotNull);
      },
    );

    test(
      'restore session gagal saat storage kosong dan argumen null',
      () async {
        final result = await repository.restoreSession();
        expect(result.isSuccess, isFalse);
        expect(result.failure, isA<SessionExpiredFailure>());
      },
    );

    test(
      'restoreSession menolak token acak atau tak dikenal dengan SessionExpiredFailure',
      () async {
        final storage = InMemoryAuthTokenStorage();
        await storage.saveRefreshToken('token_acak_palsu_123');
        final repo = DemoAuthRepository(storage: storage);

        final result = await repo.restoreSession();
        expect(result.isSuccess, isFalse);
        expect(result.failure, isA<SessionExpiredFailure>());
        expect(result.user, isNull);
      },
    );

    test('revokeSession mengembalikan status revoked', () async {
      final handle = RemoteSessionHandle('test_revocation_token');
      final revocation = await repository.revokeSession(handle);

      expect(revocation.status, RemoteRevocationStatus.revoked);
    });

    test('logout menghapus token dari storage', () async {
      await tokenStorage.saveRefreshToken('token_usr_garut_kota');
      await repository.logout();
      expect(await tokenStorage.readRefreshToken(), isNull);
    });
  });

  group('KokRepository Multi-District Fixtures via fetchScope', () {
    late DemoKokRepository kokRepo;

    setUp(() {
      kokRepo = DemoKokRepository(simulateLatency: false);
    });

    test('fetchScope garut_kota menghasilkan 5 cabor dan 125 atlet', () async {
      final snapshot = await kokRepo.fetchScope(
        const AccessScope(
          type: AccessScopeType.district,
          id: 'garut_kota',
          name: 'Kecamatan Garut Kota',
        ),
      );
      final athletes = snapshot.people.where((p) => p.role == 'Atlet').toList();
      final sports = snapshot.clubs.map((c) => c.sport).toSet();

      expect(snapshot.clubs.length, 5);
      expect(sports.length, 5);
      expect(athletes.length, 125);
      expect(snapshot.scope.name, 'Kecamatan Garut Kota');
    });

    test(
      'fetchScope tarogong_kidul menghasilkan 4 cabor dan 88 atlet',
      () async {
        final snapshot = await kokRepo.fetchScope(
          const AccessScope(
            type: AccessScopeType.district,
            id: 'tarogong_kidul',
            name: 'Kecamatan Tarogong Kidul',
          ),
        );
        final athletes = snapshot.people
            .where((p) => p.role == 'Atlet')
            .toList();
        final sports = snapshot.clubs.map((c) => c.sport).toSet();

        expect(snapshot.clubs.length, 4);
        expect(sports.length, 4);
        expect(athletes.length, 88);
        expect(snapshot.scope.name, 'Kecamatan Tarogong Kidul');
      },
    );
  });
}
