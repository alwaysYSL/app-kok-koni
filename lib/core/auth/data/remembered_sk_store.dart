import 'package:shared_preferences/shared_preferences.dart';

class RememberedSkStore {
  static const String _key = 'remembered_sk';
  final SharedPreferences _prefs;

  const RememberedSkStore(this._prefs);

  Future<String?> readSk() async => _prefs.getString(_key);

  Future<void> saveSk(String sk) async => _prefs.setString(_key, sk);

  Future<void> clear() async => _prefs.remove(_key);
}
