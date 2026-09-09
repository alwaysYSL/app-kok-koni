import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:kok_app/core/auth/data/session_metadata_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FailingSharedPreferences implements SharedPreferences {
  FailingSharedPreferences({
    this.failSetString = false,
    this.failRemove = false,
    this.containsKeyResult = true,
  });

  final bool failSetString;
  final bool failRemove;
  final bool containsKeyResult;

  @override
  Future<bool> setString(String key, String value) async {
    if (failSetString) return false;
    return true;
  }

  @override
  Future<bool> remove(String key) async {
    if (failRemove) return false;
    return true;
  }

  @override
  bool containsKey(String key) => containsKeyResult;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  const testKey = 'kok.auth.v2.test.metadata';

  group('SessionMetadata Invariant Constructors', () {
    test('signedOutClean creates valid metadata with default values', () {
      const metadata = SessionMetadata.signedOutClean();
      expect(metadata.schemaVersion, 1);
      expect(metadata.restoreAllowed, isFalse);
      expect(metadata.cleanupStatus, LocalCleanupStatus.clean);
      expect(metadata.expectedCredentialId, isNull);
    });

    test('cleanupPending creates valid pending metadata', () {
      const metadata = SessionMetadata.cleanupPending();
      expect(metadata.schemaVersion, 1);
      expect(metadata.restoreAllowed, isFalse);
      expect(metadata.cleanupStatus, LocalCleanupStatus.pending);
      expect(metadata.expectedCredentialId, isNull);
    });

    test('cleanupFailed creates valid failed metadata', () {
      const metadata = SessionMetadata.cleanupFailed();
      expect(metadata.schemaVersion, 1);
      expect(metadata.restoreAllowed, isFalse);
      expect(metadata.cleanupStatus, LocalCleanupStatus.failed);
      expect(metadata.expectedCredentialId, isNull);
    });

    test('restoreEnabled creates valid metadata with expectedCredentialId', () {
      final metadata = SessionMetadata.restoreEnabled('cred-valid-123');
      expect(metadata.schemaVersion, 1);
      expect(metadata.restoreAllowed, isTrue);
      expect(metadata.cleanupStatus, LocalCleanupStatus.clean);
      expect(metadata.expectedCredentialId, 'cred-valid-123');
    });

    test(
      'restoreEnabled rejects empty, whitespace, or excessively long id',
      () {
        expect(
          () => SessionMetadata.restoreEnabled(''),
          throwsA(isA<CorruptMetadataException>()),
        );
        expect(
          () => SessionMetadata.restoreEnabled('   '),
          throwsA(isA<CorruptMetadataException>()),
        );
        final tooLongId = 'a' * 129;
        expect(
          () => SessionMetadata.restoreEnabled(tooLongId),
          throwsA(isA<CorruptMetadataException>()),
        );
      },
    );
  });

  group('SessionMetadata.fromJson Strict Parsing', () {
    test('throws CorruptMetadataException when value is not a Map', () {
      expect(
        () => SessionMetadata.fromJson('not_a_map'),
        throwsA(isA<CorruptMetadataException>()),
      );
      expect(
        () => SessionMetadata.fromJson(123),
        throwsA(isA<CorruptMetadataException>()),
      );
      expect(
        () => SessionMetadata.fromJson([1, 2, 3]),
        throwsA(isA<CorruptMetadataException>()),
      );
    });

    test('throws CorruptMetadataException on invalid schemaVersion', () {
      expect(
        () => SessionMetadata.fromJson({
          'schemaVersion': 2,
          'restoreAllowed': false,
          'cleanupStatus': 'clean',
          'expectedCredentialId': null,
        }),
        throwsA(isA<CorruptMetadataException>()),
      );
      expect(
        () => SessionMetadata.fromJson({
          'schemaVersion': '1',
          'restoreAllowed': false,
          'cleanupStatus': 'clean',
          'expectedCredentialId': null,
        }),
        throwsA(isA<CorruptMetadataException>()),
      );
    });

    test('throws CorruptMetadataException on invalid restoreAllowed', () {
      expect(
        () => SessionMetadata.fromJson({
          'schemaVersion': 1,
          'restoreAllowed': 'false',
          'cleanupStatus': 'clean',
          'expectedCredentialId': null,
        }),
        throwsA(isA<CorruptMetadataException>()),
      );
    });

    test('throws CorruptMetadataException on invalid cleanupStatus', () {
      expect(
        () => SessionMetadata.fromJson({
          'schemaVersion': 1,
          'restoreAllowed': false,
          'cleanupStatus': 'unknown_status',
          'expectedCredentialId': null,
        }),
        throwsA(isA<CorruptMetadataException>()),
      );
    });

    test(
      'throws CorruptMetadataException when expectedCredentialId is not string or null',
      () {
        expect(
          () => SessionMetadata.fromJson({
            'schemaVersion': 1,
            'restoreAllowed': false,
            'cleanupStatus': 'clean',
            'expectedCredentialId': 12345,
          }),
          throwsA(isA<CorruptMetadataException>()),
        );
      },
    );

    test(
      'throws CorruptMetadataException when restoreAllowed=false but expectedCredentialId is provided',
      () {
        expect(
          () => SessionMetadata.fromJson({
            'schemaVersion': 1,
            'restoreAllowed': false,
            'cleanupStatus': 'clean',
            'expectedCredentialId': 'cred-abc',
          }),
          throwsA(isA<CorruptMetadataException>()),
        );
      },
    );

    test(
      'throws CorruptMetadataException when restoreAllowed=true and status is not clean',
      () {
        expect(
          () => SessionMetadata.fromJson({
            'schemaVersion': 1,
            'restoreAllowed': true,
            'cleanupStatus': 'pending',
            'expectedCredentialId': 'cred-abc',
          }),
          throwsA(isA<CorruptMetadataException>()),
        );
        expect(
          () => SessionMetadata.fromJson({
            'schemaVersion': 1,
            'restoreAllowed': true,
            'cleanupStatus': 'failed',
            'expectedCredentialId': 'cred-abc',
          }),
          throwsA(isA<CorruptMetadataException>()),
        );
      },
    );

    test(
      'throws CorruptMetadataException when restoreAllowed=true and expectedCredentialId is invalid',
      () {
        expect(
          () => SessionMetadata.fromJson({
            'schemaVersion': 1,
            'restoreAllowed': true,
            'cleanupStatus': 'clean',
            'expectedCredentialId': null,
          }),
          throwsA(isA<CorruptMetadataException>()),
        );
        expect(
          () => SessionMetadata.fromJson({
            'schemaVersion': 1,
            'restoreAllowed': true,
            'cleanupStatus': 'clean',
            'expectedCredentialId': '   ',
          }),
          throwsA(isA<CorruptMetadataException>()),
        );
        expect(
          () => SessionMetadata.fromJson({
            'schemaVersion': 1,
            'restoreAllowed': true,
            'cleanupStatus': 'clean',
            'expectedCredentialId': 'a' * 129,
          }),
          throwsA(isA<CorruptMetadataException>()),
        );
      },
    );

    test('parses valid metadata correctly', () {
      final clean = SessionMetadata.fromJson({
        'schemaVersion': 1,
        'restoreAllowed': false,
        'cleanupStatus': 'clean',
        'expectedCredentialId': null,
      });
      expect(clean.restoreAllowed, isFalse);
      expect(clean.cleanupStatus, LocalCleanupStatus.clean);

      final pending = SessionMetadata.fromJson({
        'schemaVersion': 1,
        'restoreAllowed': false,
        'cleanupStatus': 'pending',
        'expectedCredentialId': null,
      });
      expect(pending.cleanupStatus, LocalCleanupStatus.pending);

      final failed = SessionMetadata.fromJson({
        'schemaVersion': 1,
        'restoreAllowed': false,
        'cleanupStatus': 'failed',
        'expectedCredentialId': null,
      });
      expect(failed.cleanupStatus, LocalCleanupStatus.failed);

      final restore = SessionMetadata.fromJson({
        'schemaVersion': 1,
        'restoreAllowed': true,
        'cleanupStatus': 'clean',
        'expectedCredentialId': 'cred-123',
      });
      expect(restore.restoreAllowed, isTrue);
      expect(restore.cleanupStatus, LocalCleanupStatus.clean);
      expect(restore.expectedCredentialId, 'cred-123');
    });
  });

  group('SharedPrefsSessionMetadataStore', () {
    test('read() returns null when key is absent', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = SharedPrefsSessionMetadataStore(prefs: prefs, key: testKey);

      final result = await store.read();
      expect(result, isNull);
    });

    test(
      'read() throws CorruptMetadataException on empty or whitespace string',
      () async {
        SharedPreferences.setMockInitialValues({testKey: ''});
        var prefs = await SharedPreferences.getInstance();
        var store = SharedPrefsSessionMetadataStore(prefs: prefs, key: testKey);
        expect(() => store.read(), throwsA(isA<CorruptMetadataException>()));

        SharedPreferences.setMockInitialValues({testKey: '   '});
        prefs = await SharedPreferences.getInstance();
        store = SharedPrefsSessionMetadataStore(prefs: prefs, key: testKey);
        expect(() => store.read(), throwsA(isA<CorruptMetadataException>()));
      },
    );

    test('read() throws CorruptMetadataException on invalid JSON', () async {
      SharedPreferences.setMockInitialValues({testKey: '{invalid_json'});
      final prefs = await SharedPreferences.getInstance();
      final store = SharedPrefsSessionMetadataStore(prefs: prefs, key: testKey);
      expect(() => store.read(), throwsA(isA<CorruptMetadataException>()));
    });

    test(
      'read() throws CorruptMetadataException when JSON structure is corrupt',
      () async {
        SharedPreferences.setMockInitialValues({
          testKey: jsonEncode({'schemaVersion': 99}),
        });
        final prefs = await SharedPreferences.getInstance();
        final store = SharedPrefsSessionMetadataStore(
          prefs: prefs,
          key: testKey,
        );
        expect(() => store.read(), throwsA(isA<CorruptMetadataException>()));
      },
    );

    test('write() and read() round-trip preserves session metadata', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = SharedPrefsSessionMetadataStore(prefs: prefs, key: testKey);

      final metadata = SessionMetadata.restoreEnabled('cred-789');
      await store.write(metadata);

      final loaded = await store.read();
      expect(loaded, isNotNull);
      expect(loaded!.schemaVersion, metadata.schemaVersion);
      expect(loaded.restoreAllowed, metadata.restoreAllowed);
      expect(loaded.cleanupStatus, metadata.cleanupStatus);
      expect(loaded.expectedCredentialId, metadata.expectedCredentialId);

      const cleanMetadata = SessionMetadata.signedOutClean();
      await store.write(cleanMetadata);

      final loadedClean = await store.read();
      expect(loadedClean, isNotNull);
      expect(loadedClean!.restoreAllowed, isFalse);
      expect(loadedClean.cleanupStatus, LocalCleanupStatus.clean);
      expect(loadedClean.expectedCredentialId, isNull);
    });

    test(
      'write() throws MetadataStorageException when setString fails',
      () async {
        final store = SharedPrefsSessionMetadataStore(
          prefs: FailingSharedPreferences(failSetString: true),
          key: testKey,
        );
        expect(
          () => store.write(const SessionMetadata.signedOutClean()),
          throwsA(isA<MetadataStorageException>()),
        );
      },
    );

    test('clear() removes metadata successfully', () async {
      SharedPreferences.setMockInitialValues({
        testKey: jsonEncode(const SessionMetadata.signedOutClean().toJson()),
      });
      final prefs = await SharedPreferences.getInstance();
      final store = SharedPrefsSessionMetadataStore(prefs: prefs, key: testKey);

      expect(await store.read(), isNotNull);
      await store.clear();
      expect(await store.read(), isNull);
    });

    test(
      'clear() throws MetadataStorageException when remove fails and key still present',
      () async {
        final store = SharedPrefsSessionMetadataStore(
          prefs: FailingSharedPreferences(
            failRemove: true,
            containsKeyResult: true,
          ),
          key: testKey,
        );
        expect(() => store.clear(), throwsA(isA<MetadataStorageException>()));
      },
    );
  });
}
