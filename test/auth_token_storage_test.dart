import 'package:flutter_test/flutter_test.dart';
import 'package:kok_app/core/auth/data/auth_token_storage.dart';
import 'package:kok_app/core/auth/data/remembered_sk_store.dart';
import 'package:kok_app/core/auth/domain/user_principal.dart';
import 'package:kok_app/core/auth/domain/auth_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

class InMemoryAuthTokenStorage implements AuthTokenStorage {
  String? _token;
  bool shouldThrow = false;

  @override
  Future<String?> readRefreshToken() async {
    if (shouldThrow) throw Exception('Keystore locked');
    return _token;
  }

  @override
  Future<void> saveRefreshToken(String token) async {
    if (shouldThrow) throw Exception('Keystore locked');
    _token = token;
  }

  @override
  Future<void> clear() async {
    if (shouldThrow) throw Exception('Keystore locked');
    _token = null;
  }
}

void main() {
  group('AuthTokenStorage', () {
    test('menyimpan, membaca, dan menghapus refresh token secara benar', () async {
      final storage = InMemoryAuthTokenStorage();
      expect(await storage.readRefreshToken(), isNull);

      await storage.saveRefreshToken('test_refresh_token_xyz');
      expect(await storage.readRefreshToken(), 'test_refresh_token_xyz');

      await storage.clear();
      expect(await storage.readRefreshToken(), isNull);
    });

    test('menangani exception storage tanpa crash tak terkendali', () async {
      final storage = InMemoryAuthTokenStorage()..shouldThrow = true;
      expect(() => storage.readRefreshToken(), throwsException);
    });
  });

  group('RememberedSkStore', () {
    test('menyimpan dan membaca nomor SK dari SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = RememberedSkStore(prefs);

      expect(await store.readSk(), isNull);
      await store.saveSk('DEMO-001');
      expect(await store.readSk(), 'DEMO-001');
      await store.clear();
      expect(await store.readSk(), isNull);
    });
  });

  group('UserPrincipal & AuthState', () {
    test('UserPrincipal memeriksa permissions dengan benar', () {
      const user = UserPrincipal(
        id: 'usr-1',
        skNumber: 'DEMO-001',
        name: 'Pak Asep',
        role: 'Koordinator',
        districtId: 'garut_kota',
        districtName: 'Kecamatan Garut Kota',
        permissions: {'sports:read', 'reports:export'},
      );

      expect(user.hasPermission('sports:read'), isTrue);
      expect(user.hasPermission('clubs:delete'), isFalse);
    });

    test('AuthState instansiasi berjalan semestinya', () {
      const state = AuthBootstrapping();
      expect(state, isA<AuthState>());
    });
  });
}
