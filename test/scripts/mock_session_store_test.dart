import 'package:flutter_test/flutter_test.dart';
import '../../scripts/mock_server/mock_data.dart';
import '../../scripts/mock_server/mock_session_store.dart';

void main() {
  group('MockSessionStore Unit Tests', () {
    late DateTime currentTime;
    late MockSessionStore store;
    late MockAccount testAccount;

    setUp(() {
      currentTime = DateTime(2026, 9, 23, 10, 0, 0);
      store = MockSessionStore(clock: () => currentTime);
      testAccount = MockData.findAccountByUsername('kt.garutkota')!;
    });

    test('issues a secure non-empty token and stores session', () {
      final token = store.issue(testAccount);
      expect(token, isNotEmpty);
      expect(token.contains('='), isFalse); // base64Url padding stripped
    });

    test('issues distinct tokens for multiple issue calls', () {
      final token1 = store.issue(testAccount);
      final token2 = store.issue(testAccount);
      expect(token1, isNot(equals(token2)));
    });

    test('resolves valid token before expiration', () {
      final token = store.issue(testAccount);

      // Advance clock by 23 hours 59 minutes (before 24h expiration)
      currentTime = currentTime.add(const Duration(hours: 23, minutes: 59));

      final lookup = store.lookup(
        token,
        accountResolver: (id) => MockData.findAccountById(id),
      );

      expect(lookup.status, equals(MockSessionStatus.valid));
      expect(lookup.account, isNotNull);
      expect(lookup.account?.id, equals(testAccount.id));
      expect(lookup.account?.username, equals('kt.garutkota'));
    });

    test(
      'returns unknownOrExpired at exactly 24 hours expiration threshold',
      () {
        final token = store.issue(testAccount);

        // Advance clock by exactly 24 hours
        currentTime = currentTime.add(const Duration(hours: 24));

        final lookup = store.lookup(
          token,
          accountResolver: (id) => MockData.findAccountById(id),
        );

        expect(lookup.status, equals(MockSessionStatus.unknownOrExpired));
        expect(lookup.account, isNull);
      },
    );

    test(
      'returns unknownOrExpired and purges expired token after 24 hours',
      () {
        final token = store.issue(testAccount);

        // Advance clock by 25 hours
        currentTime = currentTime.add(const Duration(hours: 25));

        final lookup = store.lookup(
          token,
          accountResolver: (id) => MockData.findAccountById(id),
        );

        expect(lookup.status, equals(MockSessionStatus.unknownOrExpired));
        expect(lookup.account, isNull);

        // Subsequent lookup should still return unknownOrExpired
        final lookup2 = store.lookup(
          token,
          accountResolver: (id) => MockData.findAccountById(id),
        );
        expect(lookup2.status, equals(MockSessionStatus.unknownOrExpired));
      },
    );

    test(
      'returns memberMissing when accountResolver returns null for existing session',
      () {
        final token = store.issue(testAccount);

        final lookup = store.lookup(
          token,
          accountResolver: (_) => null, // Account deleted or not found
        );

        expect(lookup.status, equals(MockSessionStatus.memberMissing));
        expect(lookup.account, isNull);
      },
    );

    test('returns unknownOrExpired for unknown or forged tokens', () {
      final lookup = store.lookup(
        'forged-token-kt.garutkota-1000',
        accountResolver: (id) => MockData.findAccountById(id),
      );

      expect(lookup.status, equals(MockSessionStatus.unknownOrExpired));
      expect(lookup.account, isNull);
    });

    test('revokes specific session correctly', () {
      final token = store.issue(testAccount);
      store.revoke(token);

      final lookup = store.lookup(
        token,
        accountResolver: (id) => MockData.findAccountById(id),
      );
      expect(lookup.status, equals(MockSessionStatus.unknownOrExpired));
    });

    test('clears all sessions correctly', () {
      final account2 = MockData.findAccountByUsername('kt.bllimbangan')!;
      final token1 = store.issue(testAccount);
      final token2 = store.issue(account2);

      store.clear();

      expect(
        store
            .lookup(
              token1,
              accountResolver: (id) => MockData.findAccountById(id),
            )
            .status,
        equals(MockSessionStatus.unknownOrExpired),
      );
      expect(
        store
            .lookup(
              token2,
              accountResolver: (id) => MockData.findAccountById(id),
            )
            .status,
        equals(MockSessionStatus.unknownOrExpired),
      );
    });

    test('supports custom duration during token issuance', () {
      final token = store.issue(
        testAccount,
        duration: const Duration(minutes: 30),
      );

      // Advance by 15 mins (valid)
      currentTime = currentTime.add(const Duration(minutes: 15));
      expect(
        store
            .lookup(
              token,
              accountResolver: (id) => MockData.findAccountById(id),
            )
            .status,
        equals(MockSessionStatus.valid),
      );

      // Advance by 16 more mins (total 31 mins, expired)
      currentTime = currentTime.add(const Duration(minutes: 16));
      expect(
        store
            .lookup(
              token,
              accountResolver: (id) => MockData.findAccountById(id),
            )
            .status,
        equals(MockSessionStatus.unknownOrExpired),
      );
    });
  });
}
