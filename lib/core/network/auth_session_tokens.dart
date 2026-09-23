final class AuthSessionTokens {
  String? _accessToken;
  String? _sessionToken;
  int _revision = 0;

  String? get accessToken => _accessToken;
  String? get sessionToken => _sessionToken;
  int get revision => _revision;

  void replace({String? accessToken, String? sessionToken}) {
    _accessToken = accessToken;
    _sessionToken = sessionToken;
    _revision++;
  }

  void clear() {
    _accessToken = null;
    _sessionToken = null;
    _revision++;
  }
}
