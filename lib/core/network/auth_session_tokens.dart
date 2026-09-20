final class AuthSessionTokens {
  String? _accessToken;
  String? _sessionToken;

  String? get accessToken => _accessToken;
  String? get sessionToken => _sessionToken;

  void replace({String? accessToken, String? sessionToken}) {
    _accessToken = accessToken;
    _sessionToken = sessionToken;
  }

  void clear() {
    _accessToken = null;
    _sessionToken = null;
  }
}
