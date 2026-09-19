// ignore_for_file: prefer_initializing_formals

import 'package:shared_preferences/shared_preferences.dart';
import 'session_metadata_store.dart';

final class RememberedUsernameStore {
  RememberedUsernameStore({
    required SharedPreferences prefs,
    required String key,
  }) : _prefs = prefs,
       _key = key;

  final SharedPreferences _prefs;
  final String _key;

  Future<String?> readUsername() async => _prefs.getString(_key);

  Future<void> saveUsername(String username) async {
    final ok = await _prefs.setString(_key, username);
    if (!ok) {
      throw const MetadataStorageException('Gagal menyimpan username');
    }
  }

  Future<void> clear() async {
    final ok = await _prefs.remove(_key);
    if (!ok && _prefs.containsKey(_key)) {
      throw const MetadataStorageException('Gagal menghapus username');
    }
  }
}
