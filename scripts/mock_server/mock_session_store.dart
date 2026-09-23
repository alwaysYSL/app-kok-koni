import 'dart:convert';
import 'dart:math';
import 'mock_data.dart';

enum MockSessionStatus { valid, unknownOrExpired, memberMissing }

class MockSessionLookup {
  const MockSessionLookup({required this.status, this.account});

  final MockSessionStatus status;
  final MockAccount? account;
}

class MockSession {
  const MockSession({
    required this.accountId,
    required this.issuedAt,
    required this.expiresAt,
  });

  final int accountId;
  final DateTime issuedAt;
  final DateTime expiresAt;
}

class MockSessionStore {
  MockSessionStore({DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;
  final Map<String, MockSession> _sessions = {};
  final Random _random = Random.secure();

  String issue(
    MockAccount account, {
    Duration duration = const Duration(hours: 24),
  }) {
    final bytes = List<int>.generate(32, (_) => _random.nextInt(256));
    final token = base64UrlEncode(bytes).replaceAll('=', '');
    final now = _clock();
    _sessions[token] = MockSession(
      accountId: account.id,
      issuedAt: now,
      expiresAt: now.add(duration),
    );
    return token;
  }

  MockSessionLookup lookup(
    String token, {
    MockAccount? Function(int accountId)? accountResolver,
  }) {
    final session = _sessions[token];
    if (session == null) {
      return const MockSessionLookup(
        status: MockSessionStatus.unknownOrExpired,
      );
    }
    final now = _clock();
    if (!now.isBefore(session.expiresAt)) {
      _sessions.remove(token);
      return const MockSessionLookup(
        status: MockSessionStatus.unknownOrExpired,
      );
    }
    final account = accountResolver?.call(session.accountId);
    if (account == null) {
      return const MockSessionLookup(status: MockSessionStatus.memberMissing);
    }
    return MockSessionLookup(status: MockSessionStatus.valid, account: account);
  }

  void revoke(String token) {
    _sessions.remove(token);
  }

  void clear() {
    _sessions.clear();
  }
}
