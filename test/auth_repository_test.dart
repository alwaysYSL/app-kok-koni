import 'package:flutter_test/flutter_test.dart';
import 'package:kok_app/core/auth/data/demo_auth_repository.dart';
import 'package:kok_app/core/auth/data/remembered_sk_store.dart';
import 'package:kok_app/core/auth/domain/auth_failure.dart';
import 'package:kok_app/data/repository.dart';
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
    skStore = RememberedSkStore(prefs);
    repository = DemoAuthRepository(
      tokenStorage: tokenStorage,
      skStore: skStore,
      simulateLatency: false,
    );
  });

  group('DemoAuthRepository Login', () {
    test('login sukses akun Garut Kota (Pak Asep) dengan persistent session', () async {
      final result = await repository.login(
        skNumber: 'DEMO-001',
        password: 'kokgarut123',
        staySignedIn: true,
      );

      expect(result.isSuccess, isTrue);
      expect(result.user?.name, 'Pak Asep');
      expect(result.user?.districtId, 'garut_kota');
      expect(await tokenStorage.readRefreshToken(), isNotNull);
    });

    test('login sukses akun Tarogong Kidul (Pak Cecep) tanpa persistent session', () async {
      final result = await repository.login(
        skNumber: 'DEMO-002',
        password: 'koktarogong123',
        staySignedIn: false,
      );

      expect(result.isSuccess, isTrue);
      expect(result.user?.name, 'Pak Cecep');
      expect(result.user?.districtId, 'tarogong_kidul');
      expect(await tokenStorage.readRefreshToken(), isNull);
    });

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

  group('DemoAuthRepository Session Restore & Logout', () {
    test('restore session saat token tersimpan', () async {
      await tokenStorage.saveRefreshToken('token_usr_garut_kota');
      final result = await repository.restoreSession();

      expect(result.isSuccess, isTrue);
      expect(result.user?.id, 'usr-garut-kota-001');
    });

    test('restore session gagal saat storage kosong', () async {
      final result = await repository.restoreSession();
      expect(result.isSuccess, isFalse);
    });

    test('logout menghapus token dari storage', () async {
      await tokenStorage.saveRefreshToken('token_usr_garut_kota');
      await repository.logout();
      expect(await tokenStorage.readRefreshToken(), isNull);
    });
  });

  group('KokRepository Multi-District Fixtures', () {
    late DemoKokRepository kokRepo;

    setUp(() {
      kokRepo = DemoKokRepository();
    });

    test('fetchDistrict garut_kota menghasilkan 5 cabor dan 125 atlet', () async {
      final snapshot = await kokRepo.fetchDistrict('garut_kota');
      final athletes = snapshot.people.where((p) => p.role == 'Atlet').toList();
      final sports = snapshot.clubs.map((c) => c.sport).toSet();

      expect(snapshot.clubs.length, 5);
      expect(sports.length, 5);
      expect(athletes.length, 125);
      expect(snapshot.districtName, 'Kecamatan Garut Kota');
    });

    test('fetchDistrict tarogong_kidul menghasilkan 4 cabor dan 88 atlet', () async {
      final snapshot = await kokRepo.fetchDistrict('tarogong_kidul');
      final athletes = snapshot.people.where((p) => p.role == 'Atlet').toList();
      final sports = snapshot.clubs.map((c) => c.sport).toSet();

      expect(snapshot.clubs.length, 4);
      expect(sports.length, 4);
      expect(athletes.length, 88);
      expect(snapshot.districtName, 'Kecamatan Tarogong Kidul');
    });
  });
}
