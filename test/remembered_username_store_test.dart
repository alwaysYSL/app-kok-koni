import 'package:flutter_test/flutter_test.dart';
import 'package:kok_app/core/auth/data/remembered_username_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const testKey = 'test_remembered_username_key';

  group('RememberedUsernameStore Tests', () {
    test('readUsername mengembalikan null jika belum ada username tersimpan', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = RememberedUsernameStore(prefs: prefs, key: testKey);

      final username = await store.readUsername();
      expect(username, isNull);
    });

    test('readUsername mengembalikan username yang telah tersimpan', () async {
      SharedPreferences.setMockInitialValues({testKey: 'admin_kok'});
      final prefs = await SharedPreferences.getInstance();
      final store = RememberedUsernameStore(prefs: prefs, key: testKey);

      final username = await store.readUsername();
      expect(username, 'admin_kok');
    });

    test('saveUsername menyimpan username ke SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = RememberedUsernameStore(prefs: prefs, key: testKey);

      await store.saveUsername('kok_garut_01');

      expect(prefs.getString(testKey), 'kok_garut_01');
      expect(await store.readUsername(), 'kok_garut_01');
    });

    test('clear menghapus username dari SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({testKey: 'saved_username'});
      final prefs = await SharedPreferences.getInstance();
      final store = RememberedUsernameStore(prefs: prefs, key: testKey);

      await store.clear();

      expect(prefs.getString(testKey), isNull);
      expect(await store.readUsername(), isNull);
    });
  });
}
