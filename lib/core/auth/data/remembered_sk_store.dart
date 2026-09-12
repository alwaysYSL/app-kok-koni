// ignore_for_file: prefer_initializing_formals

import 'package:shared_preferences/shared_preferences.dart';
import 'session_metadata_store.dart';

class RememberedSkStore {
  RememberedSkStore({required SharedPreferences prefs, required String key})
    : _prefs = prefs,
      _key = key;

  final SharedPreferences _prefs;
  final String _key;

  Future<String?> readSk() async => _prefs.getString(_key);

  Future<void> saveSk(String sk) async {
    final ok = await _prefs.setString(_key, sk);
    if (!ok) {
      throw const MetadataStorageException('Gagal menyimpan nomor SK');
    }
  }

  Future<void> clear() async {
    final ok = await _prefs.remove(_key);
    if (!ok && _prefs.containsKey(_key)) {
      throw const MetadataStorageException('Gagal menghapus nomor SK');
    }
  }
}
