// ignore_for_file: prefer_initializing_formals

import 'package:shared_preferences/shared_preferences.dart';
import 'session_metadata_store.dart';

class RememberedSkStore {
  RememberedSkStore({SharedPreferences? prefs, required String key})
    : _prefs = prefs,
      _key = key;

  final SharedPreferences? _prefs;
  final String _key;
  String? _inMemorySk;

  Future<String?> readSk() async => _prefs?.getString(_key) ?? _inMemorySk;

  Future<void> saveSk(String sk) async {
    final prefs = _prefs;
    if (prefs == null) {
      _inMemorySk = sk;
      return;
    }
    final ok = await prefs.setString(_key, sk);
    if (!ok) {
      throw const MetadataStorageException('Gagal menyimpan nomor SK');
    }
  }

  Future<void> clear() async {
    final prefs = _prefs;
    if (prefs == null) {
      _inMemorySk = null;
      return;
    }
    final ok = await prefs.remove(_key);
    if (!ok && prefs.containsKey(_key)) {
      throw const MetadataStorageException('Gagal menghapus nomor SK');
    }
  }
}
