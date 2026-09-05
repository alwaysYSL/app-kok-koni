import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final preferencesProvider = Provider<SharedPreferences>(
  (ref) => throw StateError('Preferences must be initialized at startup.'),
);
final sessionProvider = NotifierProvider<SessionController, bool>(
  SessionController.new,
);

class SessionController extends Notifier<bool> {
  @override
  bool build() => false;

  Future<bool> signIn(String sk, String password, bool remember) async {
    if (sk.trim() != 'DEMO-001' || password != 'kokgarut123') return false;
    final prefs = ref.read(preferencesProvider);
    if (remember) {
      await prefs.setString('remembered_sk', sk.trim());
    } else {
      await prefs.remove('remembered_sk');
    }
    // Only an in-memory demo session. Passwords/tokens never enter preferences.
    state = true;
    return true;
  }

  void signOut() => state = false;
}
