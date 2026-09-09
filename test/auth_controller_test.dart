import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kok_app/core/auth/data/auth_repository.dart';
import 'package:kok_app/core/auth/data/auth_token_storage.dart';
import 'package:kok_app/core/auth/data/demo_auth_repository.dart';
import 'package:kok_app/core/auth/data/remembered_sk_store.dart';
import 'package:kok_app/core/auth/data/session_metadata_store.dart';
import 'package:kok_app/core/auth/domain/auth_failure.dart';
import 'package:kok_app/core/auth/domain/auth_state.dart';
import 'package:kok_app/core/auth/domain/user_principal.dart';
import 'package:kok_app/core/auth/presentation/auth_controller.dart';
import 'package:kok_app/core/preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_token_storage_test.dart';

final fakeGarutKotaUser = UserPrincipal(
  id: 'usr-garut-kota-001',
  skNumber: 'DEMO-001',
  fullName: 'Pak Asep',
  roleTitle: 'Koordinator Kecamatan',
  scope: const AccessScope(
    type: AccessScopeType.district,
    id: 'garut_kota',
    name: 'Kecamatan Garut Kota',
  ),
  permissions: {'sports:read', 'clubs:read', 'members:read', 'reports:export'},
);

class InMemoryRememberedSkStore implements RememberedSkStore {
  String? _sk;

  @override
  Future<String?> readSk() async => _sk;

  @override
  Future<void> saveSk(String sk) async {
    _sk = sk;
  }

  @override
  Future<void> clear() async {
    _sk = null;
  }
}

class CompleterAuthRepository implements AuthRepository {
  final Completer<AuthResult>? loginCompleter;
  final Completer<AuthResult>? restoreCompleter;
  int restoreCallCount = 0;
  int loginCallCount = 0;
  int logoutCallCount = 0;
  String? lastRestoreRefreshToken;

  CompleterAuthRepository({this.loginCompleter, this.restoreCompleter});

  @override
  Future<AuthResult> login({
    required String skNumber,
    required String password,
    required bool staySignedIn,
  }) async {
    loginCallCount++;
    if (loginCompleter != null) {
      return loginCompleter!.future;
    }
    return const AuthResult.failed(InvalidCredentialsFailure());
  }

  @override
  Future<AuthResult> restoreSession([String? refreshToken]) async {
    restoreCallCount++;
    lastRestoreRefreshToken = refreshToken;
    if (restoreCompleter != null) {
      return restoreCompleter!.future;
    }
    return const AuthResult.failed(SessionExpiredFailure('None'));
  }

  @override
  Future<AuthResult> refreshToken(String refreshToken) async {
    return restoreSession(refreshToken);
  }

  @override
  Future<RemoteRevocationResult> revokeSession(
    RemoteSessionHandle session,
  ) async {
    return const RemoteRevocationResult(RemoteRevocationStatus.revoked);
  }

  @override
  Future<void> logout() async {
    logoutCallCount++;
  }
}

class FakeSessionMetadataStore implements SessionMetadataStore {
  SessionMetadata? metadata;
  bool shouldThrowOnRead = false;
  bool shouldThrowOnWrite = false;
  bool shouldThrowCorrupt = false;
  int writeCallCount = 0;
  SessionMetadata? lastWritten;

  FakeSessionMetadataStore({this.metadata});

  @override
  Future<SessionMetadata?> read() async {
    if (shouldThrowCorrupt) {
      throw const CorruptMetadataException('Corrupt metadata test');
    }
    if (shouldThrowOnRead) {
      throw const StorageException('Metadata read error');
    }
    return metadata;
  }

  @override
  Future<void> write(SessionMetadata metadata) async {
    if (shouldThrowOnWrite) {
      throw const StorageException('Metadata write error');
    }
    writeCallCount++;
    this.metadata = metadata;
    lastWritten = metadata;
  }

  @override
  Future<void> clear() async {
    metadata = null;
  }
}

class FakeAuthTokenStorage implements AuthTokenStorage {
  StoredCredential? credential;
  bool shouldThrowOnRead = false;
  bool shouldThrowCorrupt = false;
  bool shouldThrowOnWrite = false;
  bool shouldThrowOnForceClear = false;
  bool shouldThrowOnClearIfOwned = false;
  bool shouldThrowOnMigrate = false;
  bool? clearIfOwnedReturnOverride;
  int forceClearCallCount = 0;
  int clearIfOwnedCallCount = 0;
  int migrateLegacyCallCount = 0;
  int writeCallCount = 0;
  List<String> operationLog = [];

  FakeAuthTokenStorage({this.credential});

  @override
  Future<StoredCredential?> read() async {
    operationLog.add('read');
    if (shouldThrowCorrupt) {
      throw const CorruptCredentialException('Corrupt credential test');
    }
    if (shouldThrowOnRead) {
      throw const StorageException('Token storage read error');
    }
    return credential;
  }

  @override
  Future<void> write(StoredCredential credential) async {
    operationLog.add('write');
    if (shouldThrowOnWrite) {
      throw const StorageException('Token storage write error');
    }
    writeCallCount++;
    this.credential = credential;
  }

  @override
  Future<bool> clearIfOwnedBy(String credentialId) async {
    operationLog.add('clearIfOwnedBy:$credentialId');
    if (shouldThrowOnClearIfOwned) {
      throw const StorageException('clearIfOwnedBy error');
    }
    clearIfOwnedCallCount++;
    if (clearIfOwnedReturnOverride != null) {
      if (clearIfOwnedReturnOverride == true) {
        credential = null;
      }
      return clearIfOwnedReturnOverride!;
    }
    if (credential != null && credential!.credentialId == credentialId) {
      credential = null;
      return true;
    }
    return false;
  }

  @override
  Future<void> forceClearForRecovery() async {
    operationLog.add('forceClearForRecovery');
    if (shouldThrowOnForceClear) {
      throw const StorageException('forceClear error');
    }
    forceClearCallCount++;
    credential = null;
  }

  @override
  Future<void> migrateLegacyStorage() async {
    operationLog.add('migrateLegacyStorage');
    if (shouldThrowOnMigrate) {
      throw const StorageException('migrateLegacyStorage error');
    }
    migrateLegacyCallCount++;
  }

  @override
  Future<String?> readRefreshToken() async => credential?.refreshToken;

  @override
  Future<String?> getRefreshToken() async => credential?.refreshToken;

  @override
  Future<void> saveRefreshToken(String token) async {
    credential = StoredCredential(credentialId: 'legacy', refreshToken: token);
  }

  @override
  Future<void> clear() async {
    await forceClearForRecovery();
  }
}

class ControlledAuthRepo implements AuthRepository {
  AuthResult? restoreResult;
  Exception? restoreException;
  int restoreCallCount = 0;
  String? lastRestoreRefreshToken;

  ControlledAuthRepo({this.restoreResult, this.restoreException});

  @override
  Future<AuthResult> restoreSession([String? refreshToken]) async {
    restoreCallCount++;
    lastRestoreRefreshToken = refreshToken;
    if (restoreException != null) {
      throw restoreException!;
    }
    return restoreResult ?? const AuthResult.failed(SessionExpiredFailure());
  }

  @override
  Future<AuthResult> login({
    required String skNumber,
    required String password,
    required bool staySignedIn,
  }) async {
    return const AuthResult.failed(InvalidCredentialsFailure());
  }

  @override
  Future<AuthResult> refreshToken(String refreshToken) =>
      restoreSession(refreshToken);

  @override
  Future<RemoteRevocationResult> revokeSession(
    RemoteSessionHandle session,
  ) async {
    return const RemoteRevocationResult(RemoteRevocationStatus.revoked);
  }

  @override
  Future<void> logout() async {}
}

void main() {
  late SharedPreferences prefs;
  late InMemoryAuthTokenStorage tokenStorage;
  late RememberedSkStore skStore;
  late DemoAuthRepository authRepository;

  setUp(() async {
    tokenStorage = InMemoryAuthTokenStorage();
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    skStore = RememberedSkStore(prefs: prefs, key: 'test_remembered_sk');
    authRepository = DemoAuthRepository(
      tokenStorage: tokenStorage,
      skStore: skStore,
      simulateLatency: false,
    );
  });

  group('Mutation Queue Resilience', () {
    test(
      'mutasi pertama melempar Exception, mutasi kedua tetap dieksekusi dengan sukses',
      () async {
        final container = ProviderContainer(
          overrides: [
            authTokenStorageProvider.overrideWithValue(tokenStorage),
            authRepositoryProvider.overrideWithValue(authRepository),
            rememberedSkStoreProvider.overrideWithValue(skStore),
          ],
        );
        addTearDown(container.dispose);

        final controller = container.read(authControllerProvider.notifier);

        final future1 = controller.enqueueMutation<int>(() async {
          throw Exception('Mutasi pertama gagal');
        });

        final future2 = controller.enqueueMutation<int>(() async {
          return 42;
        });

        // Caller mutasi pertama tetap menerima exception
        expect(future1, throwsA(isA<Exception>()));

        // Caller mutasi kedua berhasil menerima hasilnya
        final result2 = await future2;
        expect(result2, equals(42));
      },
    );

    test('antrian mutasi dieksekusi secara sekuensial', () async {
      final container = ProviderContainer(
        overrides: [
          authTokenStorageProvider.overrideWithValue(tokenStorage),
          authRepositoryProvider.overrideWithValue(authRepository),
          rememberedSkStoreProvider.overrideWithValue(skStore),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(authControllerProvider.notifier);
      final executionOrder = <int>[];

      final f1 = controller.enqueueMutation(() async {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        executionOrder.add(1);
      });
      final f2 = controller.enqueueMutation(() async {
        await Future<void>.delayed(const Duration(milliseconds: 5));
        executionOrder.add(2);
      });
      final f3 = controller.enqueueMutation(() async {
        executionOrder.add(3);
      });

      await Future.wait([f1, f2, f3]);
      expect(executionOrder, equals([1, 2, 3]));
    });
  });

  group('Single-Flight Bootstrap & Migration', () {
    test(
      'dua pemanggilan bootstrap() secara bersamaan hanya memanggil repo.restoreSession satu kali',
      () async {
        final bootstrapCompleter = Completer<AuthResult>();
        final fakeRepo = CompleterAuthRepository(
          restoreCompleter: bootstrapCompleter,
        );
        final storage = FakeAuthTokenStorage(
          credential: const StoredCredential(
            credentialId: 'cred-single-flight',
            refreshToken: 'token-single-flight',
          ),
        );
        final metadataStore = FakeSessionMetadataStore(
          metadata: SessionMetadata.restoreEnabled('cred-single-flight'),
        );

        final container = ProviderContainer(
          overrides: [
            authRepositoryProvider.overrideWithValue(fakeRepo),
            authTokenStorageProvider.overrideWithValue(storage),
            sessionMetadataStoreProvider.overrideWithValue(metadataStore),
            rememberedSkStoreProvider.overrideWithValue(
              InMemoryRememberedSkStore(),
            ),
          ],
        );
        addTearDown(container.dispose);

        final controller = container.read(authControllerProvider.notifier);

        final f1 = controller.bootstrap();
        final f2 = controller.bootstrap();

        await pumpEventQueue();

        expect(fakeRepo.restoreCallCount, equals(1));

        bootstrapCompleter.complete(
          AuthResult.success(
            user: fakeGarutKotaUser,
            accessToken: 'access_demo',
            refreshToken: 'token-single-flight',
          ),
        );
        await Future.wait([f1, f2]);

        expect(fakeRepo.restoreCallCount, equals(1));
        expect(container.read(authControllerProvider), isA<AuthSignedIn>());
      },
    );

    test(
      'migrasi legacy dipanggil saat bootstrap sebelum membaca storage v2',
      () async {
        final storage = FakeAuthTokenStorage();
        final metadataStore = FakeSessionMetadataStore();

        final container = ProviderContainer(
          overrides: [
            authTokenStorageProvider.overrideWithValue(storage),
            sessionMetadataStoreProvider.overrideWithValue(metadataStore),
            authRepositoryProvider.overrideWithValue(authRepository),
            rememberedSkStoreProvider.overrideWithValue(skStore),
          ],
        );
        addTearDown(container.dispose);

        final controller = container.read(authControllerProvider.notifier);
        await controller.bootstrap();

        expect(storage.migrateLegacyCallCount, equals(1));
        expect(storage.operationLog.first, equals('migrateLegacyStorage'));
      },
    );
  });

  group('Bootstrap Truth Table (Canonical Rows 1-10)', () {
    // Row 1: absent metadata, absent credential -> signed-out clean (first run)
    test(
      'Row 1: absent metadata + absent credential -> AuthSignedOut(clean) tanpa memanggil remote',
      () async {
        final storage = FakeAuthTokenStorage(credential: null);
        final metadataStore = FakeSessionMetadataStore(metadata: null);
        final repo = ControlledAuthRepo();

        final container = ProviderContainer(
          overrides: [
            authTokenStorageProvider.overrideWithValue(storage),
            sessionMetadataStoreProvider.overrideWithValue(metadataStore),
            authRepositoryProvider.overrideWithValue(repo),
            rememberedSkStoreProvider.overrideWithValue(skStore),
          ],
        );
        addTearDown(container.dispose);

        final controller = container.read(authControllerProvider.notifier);
        await controller.bootstrap();

        expect(
          container.read(authControllerProvider),
          equals(const AuthSignedOut(cleanupStatus: LocalCleanupStatus.clean)),
        );
        expect(repo.restoreCallCount, equals(0));
      },
    );

    // Row 2: absent metadata, orphan credential -> force clear + write clean -> clean bila keduanya sukses; selain itu failed
    test(
      'Row 2a: absent metadata + orphan credential -> force clear + metadata clean -> AuthSignedOut(clean)',
      () async {
        final storage = FakeAuthTokenStorage(
          credential: const StoredCredential(
            credentialId: 'orphan-1',
            refreshToken: 'tok-orphan',
          ),
        );
        final metadataStore = FakeSessionMetadataStore(metadata: null);
        final repo = ControlledAuthRepo();

        final container = ProviderContainer(
          overrides: [
            authTokenStorageProvider.overrideWithValue(storage),
            sessionMetadataStoreProvider.overrideWithValue(metadataStore),
            authRepositoryProvider.overrideWithValue(repo),
            rememberedSkStoreProvider.overrideWithValue(skStore),
          ],
        );
        addTearDown(container.dispose);

        final controller = container.read(authControllerProvider.notifier);
        await controller.bootstrap();

        expect(
          container.read(authControllerProvider),
          equals(const AuthSignedOut(cleanupStatus: LocalCleanupStatus.clean)),
        );
        expect(storage.forceClearCallCount, equals(1));
        expect(storage.credential, isNull);
        expect(
          metadataStore.lastWritten,
          equals(const SessionMetadata.signedOutClean()),
        );
        expect(repo.restoreCallCount, equals(0));
      },
    );

    test(
      'Row 2b: absent metadata + orphan credential -> force clear gagal -> AuthSignedOut(failed)',
      () async {
        final storage = FakeAuthTokenStorage(
          credential: const StoredCredential(
            credentialId: 'orphan-1',
            refreshToken: 'tok-orphan',
          ),
        )..shouldThrowOnForceClear = true;
        final metadataStore = FakeSessionMetadataStore(metadata: null);
        final repo = ControlledAuthRepo();

        final container = ProviderContainer(
          overrides: [
            authTokenStorageProvider.overrideWithValue(storage),
            sessionMetadataStoreProvider.overrideWithValue(metadataStore),
            authRepositoryProvider.overrideWithValue(repo),
            rememberedSkStoreProvider.overrideWithValue(skStore),
          ],
        );
        addTearDown(container.dispose);

        final controller = container.read(authControllerProvider.notifier);
        await controller.bootstrap();

        expect(
          container.read(authControllerProvider),
          equals(const AuthSignedOut(cleanupStatus: LocalCleanupStatus.failed)),
        );
      },
    );

    test(
      'Row 2c: absent metadata + orphan credential -> write metadata clean gagal -> AuthSignedOut(failed)',
      () async {
        final storage = FakeAuthTokenStorage(
          credential: const StoredCredential(
            credentialId: 'orphan-1',
            refreshToken: 'tok-orphan',
          ),
        );
        final metadataStore = FakeSessionMetadataStore(metadata: null)
          ..shouldThrowOnWrite = true;
        final repo = ControlledAuthRepo();

        final container = ProviderContainer(
          overrides: [
            authTokenStorageProvider.overrideWithValue(storage),
            sessionMetadataStoreProvider.overrideWithValue(metadataStore),
            authRepositoryProvider.overrideWithValue(repo),
            rememberedSkStoreProvider.overrideWithValue(skStore),
          ],
        );
        addTearDown(container.dispose);

        final controller = container.read(authControllerProvider.notifier);
        await controller.bootstrap();

        expect(
          container.read(authControllerProvider),
          equals(const AuthSignedOut(cleanupStatus: LocalCleanupStatus.failed)),
        );
      },
    );

    // Row 3: corrupt metadata or read error -> signed-out failed (no restore)
    test(
      'Row 3a: corrupt metadata -> AuthSignedOut(failed) tanpa memanggil remote',
      () async {
        final storage = FakeAuthTokenStorage();
        final metadataStore = FakeSessionMetadataStore()
          ..shouldThrowCorrupt = true;
        final repo = ControlledAuthRepo();

        final container = ProviderContainer(
          overrides: [
            authTokenStorageProvider.overrideWithValue(storage),
            sessionMetadataStoreProvider.overrideWithValue(metadataStore),
            authRepositoryProvider.overrideWithValue(repo),
            rememberedSkStoreProvider.overrideWithValue(skStore),
          ],
        );
        addTearDown(container.dispose);

        final controller = container.read(authControllerProvider.notifier);
        await controller.bootstrap();

        expect(
          container.read(authControllerProvider),
          equals(const AuthSignedOut(cleanupStatus: LocalCleanupStatus.failed)),
        );
        expect(repo.restoreCallCount, equals(0));
      },
    );

    test(
      'Row 3b: metadata read error (StorageException) -> AuthSignedOut(failed)',
      () async {
        final storage = FakeAuthTokenStorage();
        final metadataStore = FakeSessionMetadataStore()
          ..shouldThrowOnRead = true;
        final repo = ControlledAuthRepo();

        final container = ProviderContainer(
          overrides: [
            authTokenStorageProvider.overrideWithValue(storage),
            sessionMetadataStoreProvider.overrideWithValue(metadataStore),
            authRepositoryProvider.overrideWithValue(repo),
            rememberedSkStoreProvider.overrideWithValue(skStore),
          ],
        );
        addTearDown(container.dispose);

        final controller = container.read(authControllerProvider.notifier);
        await controller.bootstrap();

        expect(
          container.read(authControllerProvider),
          equals(const AuthSignedOut(cleanupStatus: LocalCleanupStatus.failed)),
        );
        expect(repo.restoreCallCount, equals(0));
      },
    );

    test(
      'Row 3c: corrupt credential saat restoreAllowed true -> AuthSignedOut(failed) tanpa restore',
      () async {
        final storage = FakeAuthTokenStorage()..shouldThrowCorrupt = true;
        final metadataStore = FakeSessionMetadataStore(
          metadata: SessionMetadata.restoreEnabled('cred-valid'),
        );
        final repo = ControlledAuthRepo();

        final container = ProviderContainer(
          overrides: [
            authTokenStorageProvider.overrideWithValue(storage),
            sessionMetadataStoreProvider.overrideWithValue(metadataStore),
            authRepositoryProvider.overrideWithValue(repo),
            rememberedSkStoreProvider.overrideWithValue(skStore),
          ],
        );
        addTearDown(container.dispose);

        final controller = container.read(authControllerProvider.notifier);
        await controller.bootstrap();

        expect(
          container.read(authControllerProvider),
          equals(const AuthSignedOut(cleanupStatus: LocalCleanupStatus.failed)),
        );
        expect(repo.restoreCallCount, equals(0));
      },
    );

    // Row 4: restoreAllowed=false, cleanupStatus=pending/failed -> AuthSignedOut(failed)
    test(
      'Row 4a: restoreAllowed false + pending cleanupStatus -> AuthSignedOut(failed)',
      () async {
        final storage = FakeAuthTokenStorage();
        final metadataStore = FakeSessionMetadataStore(
          metadata: const SessionMetadata.cleanupPending(),
        );
        final repo = ControlledAuthRepo();

        final container = ProviderContainer(
          overrides: [
            authTokenStorageProvider.overrideWithValue(storage),
            sessionMetadataStoreProvider.overrideWithValue(metadataStore),
            authRepositoryProvider.overrideWithValue(repo),
            rememberedSkStoreProvider.overrideWithValue(skStore),
          ],
        );
        addTearDown(container.dispose);

        final controller = container.read(authControllerProvider.notifier);
        await controller.bootstrap();

        expect(
          container.read(authControllerProvider),
          equals(const AuthSignedOut(cleanupStatus: LocalCleanupStatus.failed)),
        );
        expect(repo.restoreCallCount, equals(0));
      },
    );

    test(
      'Row 4b: restoreAllowed false + failed cleanupStatus -> AuthSignedOut(failed)',
      () async {
        final storage = FakeAuthTokenStorage();
        final metadataStore = FakeSessionMetadataStore(
          metadata: const SessionMetadata.cleanupFailed(),
        );
        final repo = ControlledAuthRepo();

        final container = ProviderContainer(
          overrides: [
            authTokenStorageProvider.overrideWithValue(storage),
            sessionMetadataStoreProvider.overrideWithValue(metadataStore),
            authRepositoryProvider.overrideWithValue(repo),
            rememberedSkStoreProvider.overrideWithValue(skStore),
          ],
        );
        addTearDown(container.dispose);

        final controller = container.read(authControllerProvider.notifier);
        await controller.bootstrap();

        expect(
          container.read(authControllerProvider),
          equals(const AuthSignedOut(cleanupStatus: LocalCleanupStatus.failed)),
        );
        expect(repo.restoreCallCount, equals(0));
      },
    );

    // Row 5: restoreAllowed=false, cleanupStatus=clean, absent credential -> AuthSignedOut(clean)
    test(
      'Row 5: restoreAllowed false + clean + absent credential -> AuthSignedOut(clean)',
      () async {
        final storage = FakeAuthTokenStorage(credential: null);
        final metadataStore = FakeSessionMetadataStore(
          metadata: const SessionMetadata.signedOutClean(),
        );
        final repo = ControlledAuthRepo();

        final container = ProviderContainer(
          overrides: [
            authTokenStorageProvider.overrideWithValue(storage),
            sessionMetadataStoreProvider.overrideWithValue(metadataStore),
            authRepositoryProvider.overrideWithValue(repo),
            rememberedSkStoreProvider.overrideWithValue(skStore),
          ],
        );
        addTearDown(container.dispose);

        final controller = container.read(authControllerProvider.notifier);
        await controller.bootstrap();

        expect(
          container.read(authControllerProvider),
          equals(const AuthSignedOut(cleanupStatus: LocalCleanupStatus.clean)),
        );
        expect(repo.restoreCallCount, equals(0));
      },
    );

    // Row 6: restoreAllowed=false, cleanupStatus=clean, orphan credential exists -> force clear + write clean
    test(
      'Row 6a: restoreAllowed false + clean + orphan credential -> force clear + metadata clean -> AuthSignedOut(clean)',
      () async {
        final storage = FakeAuthTokenStorage(
          credential: const StoredCredential(
            credentialId: 'orphan-row6',
            refreshToken: 'tok-row6',
          ),
        );
        final metadataStore = FakeSessionMetadataStore(
          metadata: const SessionMetadata.signedOutClean(),
        );
        final repo = ControlledAuthRepo();

        final container = ProviderContainer(
          overrides: [
            authTokenStorageProvider.overrideWithValue(storage),
            sessionMetadataStoreProvider.overrideWithValue(metadataStore),
            authRepositoryProvider.overrideWithValue(repo),
            rememberedSkStoreProvider.overrideWithValue(skStore),
          ],
        );
        addTearDown(container.dispose);

        final controller = container.read(authControllerProvider.notifier);
        await controller.bootstrap();

        expect(
          container.read(authControllerProvider),
          equals(const AuthSignedOut(cleanupStatus: LocalCleanupStatus.clean)),
        );
        expect(storage.forceClearCallCount, equals(1));
        expect(storage.credential, isNull);
        expect(
          metadataStore.lastWritten,
          equals(const SessionMetadata.signedOutClean()),
        );
      },
    );

    test(
      'Row 6b: restoreAllowed false + clean + orphan credential -> force clear gagal -> AuthSignedOut(failed)',
      () async {
        final storage = FakeAuthTokenStorage(
          credential: const StoredCredential(
            credentialId: 'orphan-row6',
            refreshToken: 'tok-row6',
          ),
        )..shouldThrowOnForceClear = true;
        final metadataStore = FakeSessionMetadataStore(
          metadata: const SessionMetadata.signedOutClean(),
        );
        final repo = ControlledAuthRepo();

        final container = ProviderContainer(
          overrides: [
            authTokenStorageProvider.overrideWithValue(storage),
            sessionMetadataStoreProvider.overrideWithValue(metadataStore),
            authRepositoryProvider.overrideWithValue(repo),
            rememberedSkStoreProvider.overrideWithValue(skStore),
          ],
        );
        addTearDown(container.dispose);

        final controller = container.read(authControllerProvider.notifier);
        await controller.bootstrap();

        expect(
          container.read(authControllerProvider),
          equals(const AuthSignedOut(cleanupStatus: LocalCleanupStatus.failed)),
        );
      },
    );

    // Row 7: restoreAllowed=true, clean, credential absent -> write clean -> clean bila sukses; selain itu failed
    test(
      'Row 7a: restoreAllowed true + clean + credential absent -> tulis clean sukses -> AuthSignedOut(clean)',
      () async {
        final storage = FakeAuthTokenStorage(credential: null);
        final metadataStore = FakeSessionMetadataStore(
          metadata: SessionMetadata.restoreEnabled('cred-gone'),
        );
        final repo = ControlledAuthRepo();

        final container = ProviderContainer(
          overrides: [
            authTokenStorageProvider.overrideWithValue(storage),
            sessionMetadataStoreProvider.overrideWithValue(metadataStore),
            authRepositoryProvider.overrideWithValue(repo),
            rememberedSkStoreProvider.overrideWithValue(skStore),
          ],
        );
        addTearDown(container.dispose);

        final controller = container.read(authControllerProvider.notifier);
        await controller.bootstrap();

        expect(
          container.read(authControllerProvider),
          equals(const AuthSignedOut(cleanupStatus: LocalCleanupStatus.clean)),
        );
        expect(
          metadataStore.lastWritten,
          equals(const SessionMetadata.signedOutClean()),
        );
        expect(repo.restoreCallCount, equals(0));
      },
    );

    test(
      'Row 7b: restoreAllowed true + clean + credential absent -> tulis clean gagal -> AuthSignedOut(failed)',
      () async {
        final storage = FakeAuthTokenStorage(credential: null);
        final metadataStore = FakeSessionMetadataStore(
          metadata: SessionMetadata.restoreEnabled('cred-gone'),
        )..shouldThrowOnWrite = true;
        final repo = ControlledAuthRepo();

        final container = ProviderContainer(
          overrides: [
            authTokenStorageProvider.overrideWithValue(storage),
            sessionMetadataStoreProvider.overrideWithValue(metadataStore),
            authRepositoryProvider.overrideWithValue(repo),
            rememberedSkStoreProvider.overrideWithValue(skStore),
          ],
        );
        addTearDown(container.dispose);

        final controller = container.read(authControllerProvider.notifier);
        await controller.bootstrap();

        expect(
          container.read(authControllerProvider),
          equals(const AuthSignedOut(cleanupStatus: LocalCleanupStatus.failed)),
        );
      },
    );

    // Row 8: restoreAllowed=true, clean, credential ID mismatch -> jangan hapus foreign credential -> AuthSignedOut(failed)
    test(
      'Row 8: restoreAllowed true + credential ID mismatch -> foreign credential utuh, state failed',
      () async {
        final foreignCred = const StoredCredential(
          credentialId: 'cred-foreign-999',
          refreshToken: 'tok-foreign-999',
        );
        final storage = FakeAuthTokenStorage(credential: foreignCred);
        final metadataStore = FakeSessionMetadataStore(
          metadata: SessionMetadata.restoreEnabled('cred-expected-111'),
        );
        final repo = ControlledAuthRepo();

        final container = ProviderContainer(
          overrides: [
            authTokenStorageProvider.overrideWithValue(storage),
            sessionMetadataStoreProvider.overrideWithValue(metadataStore),
            authRepositoryProvider.overrideWithValue(repo),
            rememberedSkStoreProvider.overrideWithValue(skStore),
          ],
        );
        addTearDown(container.dispose);

        final controller = container.read(authControllerProvider.notifier);
        await controller.bootstrap();

        expect(
          container.read(authControllerProvider),
          equals(const AuthSignedOut(cleanupStatus: LocalCleanupStatus.failed)),
        );
        // Foreign credential tidak boleh dihapus!
        expect(storage.credential, equals(foreignCred));
        expect(storage.forceClearCallCount, equals(0));
        expect(storage.clearIfOwnedCallCount, equals(0));
        expect(repo.restoreCallCount, equals(0));
      },
    );

    // Row 9: restoreAllowed=true, clean, credential ID cocok -> repo.restoreSession(credential.refreshToken)
    test(
      'Row 9a: restoreAllowed true + credential ID cocok -> restoreSession berhasil -> AuthSignedIn',
      () async {
        final storage = FakeAuthTokenStorage(
          credential: const StoredCredential(
            credentialId: 'cred-asep',
            refreshToken: 'token_usr_garut_kota',
          ),
        );
        final metadataStore = FakeSessionMetadataStore(
          metadata: SessionMetadata.restoreEnabled('cred-asep'),
        );
        final repo = ControlledAuthRepo(
          restoreResult: AuthResult.success(
            user: fakeGarutKotaUser,
            accessToken: 'acc_demo',
            refreshToken: 'token_usr_garut_kota',
          ),
        );

        final container = ProviderContainer(
          overrides: [
            authTokenStorageProvider.overrideWithValue(storage),
            sessionMetadataStoreProvider.overrideWithValue(metadataStore),
            authRepositoryProvider.overrideWithValue(repo),
            rememberedSkStoreProvider.overrideWithValue(skStore),
          ],
        );
        addTearDown(container.dispose);

        final controller = container.read(authControllerProvider.notifier);
        await controller.bootstrap();

        final state = container.read(authControllerProvider);
        expect(state, isA<AuthSignedIn>());
        expect((state as AuthSignedIn).user.fullName, equals('Pak Asep'));
        expect(state.generation, greaterThan(0));
        expect(repo.restoreCallCount, equals(1));
        expect(repo.lastRestoreRefreshToken, equals('token_usr_garut_kota'));
      },
    );

    test(
      'Row 9b: restoreAllowed true + credential ID cocok -> restore timeout failure -> AuthTemporarilyUnavailable',
      () async {
        final storage = FakeAuthTokenStorage(
          credential: const StoredCredential(
            credentialId: 'cred-asep',
            refreshToken: 'tok-timeout',
          ),
        );
        final metadataStore = FakeSessionMetadataStore(
          metadata: SessionMetadata.restoreEnabled('cred-asep'),
        );
        final repo = ControlledAuthRepo(
          restoreResult: const AuthResult.failed(
            NetworkTimeoutFailure('Server timeout'),
          ),
        );

        final container = ProviderContainer(
          overrides: [
            authTokenStorageProvider.overrideWithValue(storage),
            sessionMetadataStoreProvider.overrideWithValue(metadataStore),
            authRepositoryProvider.overrideWithValue(repo),
            rememberedSkStoreProvider.overrideWithValue(skStore),
          ],
        );
        addTearDown(container.dispose);

        final controller = container.read(authControllerProvider.notifier);
        await controller.bootstrap();

        final state = container.read(authControllerProvider);
        expect(state, isA<AuthTemporarilyUnavailable>());
        expect(
          (state as AuthTemporarilyUnavailable).reason,
          equals('Server timeout'),
        );
      },
    );

    test(
      'Row 9c: restoreAllowed true + credential ID cocok -> restore melempar TimeoutException -> AuthTemporarilyUnavailable',
      () async {
        final storage = FakeAuthTokenStorage(
          credential: const StoredCredential(
            credentialId: 'cred-asep',
            refreshToken: 'tok-timeout',
          ),
        );
        final metadataStore = FakeSessionMetadataStore(
          metadata: SessionMetadata.restoreEnabled('cred-asep'),
        );
        final repo = ControlledAuthRepo(
          restoreException: TimeoutException('Timeout'),
        );

        final container = ProviderContainer(
          overrides: [
            authTokenStorageProvider.overrideWithValue(storage),
            sessionMetadataStoreProvider.overrideWithValue(metadataStore),
            authRepositoryProvider.overrideWithValue(repo),
            rememberedSkStoreProvider.overrideWithValue(skStore),
          ],
        );
        addTearDown(container.dispose);

        final controller = container.read(authControllerProvider.notifier);
        await controller.bootstrap();

        final state = container.read(authControllerProvider);
        expect(state, isA<AuthTemporarilyUnavailable>());
      },
    );

    // Row 10: restoreAllowed=true, clean, credential ID cocok, restore expired -> clearIfOwnedBy + metadata clean -> clean bila keduanya sukses, selain itu failed
    test(
      'Row 10a: restore expired -> clearIfOwnedBy + metadata clean sukses -> AuthSignedOut(clean)',
      () async {
        final storage = FakeAuthTokenStorage(
          credential: const StoredCredential(
            credentialId: 'cred-expired',
            refreshToken: 'tok-expired',
          ),
        );
        final metadataStore = FakeSessionMetadataStore(
          metadata: SessionMetadata.restoreEnabled('cred-expired'),
        );
        final repo = ControlledAuthRepo(
          restoreResult: const AuthResult.failed(
            SessionExpiredFailure('Expired'),
          ),
        );

        final container = ProviderContainer(
          overrides: [
            authTokenStorageProvider.overrideWithValue(storage),
            sessionMetadataStoreProvider.overrideWithValue(metadataStore),
            authRepositoryProvider.overrideWithValue(repo),
            rememberedSkStoreProvider.overrideWithValue(skStore),
          ],
        );
        addTearDown(container.dispose);

        final controller = container.read(authControllerProvider.notifier);
        await controller.bootstrap();

        expect(
          container.read(authControllerProvider),
          equals(const AuthSignedOut(cleanupStatus: LocalCleanupStatus.clean)),
        );
        expect(storage.clearIfOwnedCallCount, equals(1));
        expect(storage.credential, isNull);
        expect(
          metadataStore.lastWritten,
          equals(const SessionMetadata.signedOutClean()),
        );
      },
    );

    test(
      'Row 10b: restore expired -> clearIfOwnedBy return false -> AuthSignedOut(failed)',
      () async {
        final storage = FakeAuthTokenStorage(
          credential: const StoredCredential(
            credentialId: 'cred-expired',
            refreshToken: 'tok-expired',
          ),
        )..clearIfOwnedReturnOverride = false;
        final metadataStore = FakeSessionMetadataStore(
          metadata: SessionMetadata.restoreEnabled('cred-expired'),
        );
        final repo = ControlledAuthRepo(
          restoreResult: const AuthResult.failed(
            SessionExpiredFailure('Expired'),
          ),
        );

        final container = ProviderContainer(
          overrides: [
            authTokenStorageProvider.overrideWithValue(storage),
            sessionMetadataStoreProvider.overrideWithValue(metadataStore),
            authRepositoryProvider.overrideWithValue(repo),
            rememberedSkStoreProvider.overrideWithValue(skStore),
          ],
        );
        addTearDown(container.dispose);

        final controller = container.read(authControllerProvider.notifier);
        await controller.bootstrap();

        expect(
          container.read(authControllerProvider),
          equals(const AuthSignedOut(cleanupStatus: LocalCleanupStatus.failed)),
        );
      },
    );

    test(
      'Row 10c: restore expired -> clearIfOwnedBy melempar exception -> AuthSignedOut(failed)',
      () async {
        final storage = FakeAuthTokenStorage(
          credential: const StoredCredential(
            credentialId: 'cred-expired',
            refreshToken: 'tok-expired',
          ),
        )..shouldThrowOnClearIfOwned = true;
        final metadataStore = FakeSessionMetadataStore(
          metadata: SessionMetadata.restoreEnabled('cred-expired'),
        );
        final repo = ControlledAuthRepo(
          restoreResult: const AuthResult.failed(
            SessionExpiredFailure('Expired'),
          ),
        );

        final container = ProviderContainer(
          overrides: [
            authTokenStorageProvider.overrideWithValue(storage),
            sessionMetadataStoreProvider.overrideWithValue(metadataStore),
            authRepositoryProvider.overrideWithValue(repo),
            rememberedSkStoreProvider.overrideWithValue(skStore),
          ],
        );
        addTearDown(container.dispose);

        final controller = container.read(authControllerProvider.notifier);
        await controller.bootstrap();

        expect(
          container.read(authControllerProvider),
          equals(const AuthSignedOut(cleanupStatus: LocalCleanupStatus.failed)),
        );
      },
    );

    test(
      'Row 10d: restore expired -> write metadata clean gagal -> AuthSignedOut(failed)',
      () async {
        final storage = FakeAuthTokenStorage(
          credential: const StoredCredential(
            credentialId: 'cred-expired',
            refreshToken: 'tok-expired',
          ),
        );
        final metadataStore = FakeSessionMetadataStore(
          metadata: SessionMetadata.restoreEnabled('cred-expired'),
        )..shouldThrowOnWrite = true;
        final repo = ControlledAuthRepo(
          restoreResult: const AuthResult.failed(
            SessionExpiredFailure('Expired'),
          ),
        );

        final container = ProviderContainer(
          overrides: [
            authTokenStorageProvider.overrideWithValue(storage),
            sessionMetadataStoreProvider.overrideWithValue(metadataStore),
            authRepositoryProvider.overrideWithValue(repo),
            rememberedSkStoreProvider.overrideWithValue(skStore),
          ],
        );
        addTearDown(container.dispose);

        final controller = container.read(authControllerProvider.notifier);
        await controller.bootstrap();

        expect(
          container.read(authControllerProvider),
          equals(const AuthSignedOut(cleanupStatus: LocalCleanupStatus.failed)),
        );
      },
    );
  });

  group('AuthController Existing Operations (Login / Logout / Race)', () {
    test(
      'bootstrap mengarahkan ke AuthSignedOut jika storage kosong',
      () async {
        final container = ProviderContainer(
          overrides: [
            authTokenStorageProvider.overrideWithValue(tokenStorage),
            authRepositoryProvider.overrideWithValue(authRepository),
            rememberedSkStoreProvider.overrideWithValue(skStore),
            preferencesProvider.overrideWithValue(prefs),
          ],
        );
        addTearDown(container.dispose);

        final controller = container.read(authControllerProvider.notifier);
        await controller.bootstrap();

        expect(container.read(authControllerProvider), isA<AuthSignedOut>());
      },
    );

    test(
      'login sukses menaikkan session generation dan set AuthSignedIn',
      () async {
        final container = ProviderContainer(
          overrides: [
            authTokenStorageProvider.overrideWithValue(tokenStorage),
            authRepositoryProvider.overrideWithValue(authRepository),
            rememberedSkStoreProvider.overrideWithValue(skStore),
          ],
        );
        addTearDown(container.dispose);

        final controller = container.read(authControllerProvider.notifier);
        final success = await controller.login(
          skNumber: 'DEMO-001',
          password: 'kokgarut123',
          staySignedIn: true,
          rememberSk: true,
        );

        expect(success, isTrue);
        final state = container.read(authControllerProvider);
        expect(state, isA<AuthSignedIn>());
        expect((state as AuthSignedIn).generation, greaterThan(0));
        expect(await skStore.readSk(), 'DEMO-001');
      },
    );

    test('logout membersihkan sesi dan menaikkan generation counter', () async {
      final container = ProviderContainer(
        overrides: [
          authTokenStorageProvider.overrideWithValue(tokenStorage),
          authRepositoryProvider.overrideWithValue(authRepository),
          rememberedSkStoreProvider.overrideWithValue(skStore),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(authControllerProvider.notifier);
      await controller.login(
        skNumber: 'DEMO-001',
        password: 'kokgarut123',
        staySignedIn: true,
        rememberSk: false,
      );
      final gen1 =
          (container.read(authControllerProvider) as AuthSignedIn).generation;

      await controller.logout();
      expect(container.read(authControllerProvider), isA<AuthSignedOut>());
      expect(controller.currentGeneration, greaterThan(gen1));
    });

    test(
      'logout saat login masih berjalan membatalkan commit token dan menghasilkan AuthSignedOut',
      () async {
        final loginCompleter = Completer<AuthResult>();
        final fakeRepo = CompleterAuthRepository(
          loginCompleter: loginCompleter,
        );
        final fakeStorage = InMemoryAuthTokenStorage();
        final fakeSkStore = InMemoryRememberedSkStore();

        final container = ProviderContainer(
          overrides: [
            authRepositoryProvider.overrideWithValue(fakeRepo),
            authTokenStorageProvider.overrideWithValue(fakeStorage),
            rememberedSkStoreProvider.overrideWithValue(fakeSkStore),
          ],
        );
        addTearDown(container.dispose);

        final controller = container.read(authControllerProvider.notifier);

        // 1. Mulai login (asinkron tertahan)
        final loginFuture = controller.login(
          skNumber: 'DEMO-001',
          password: 'password',
          staySignedIn: true,
          rememberSk: true,
        );
        expect(container.read(authControllerProvider), isA<AuthSigningIn>());

        // 2. Pengguna memanggil logout sebelum login selesai
        await controller.logout();
        expect(container.read(authControllerProvider), isA<AuthSignedOut>());

        // 3. Selesaikan operasi login yang tertunda
        loginCompleter.complete(
          AuthResult.success(
            user: fakeGarutKotaUser,
            accessToken: 'acc_token',
            refreshToken: 'token_usr_garut_kota',
          ),
        );
        final loginResult = await loginFuture;

        // 4. Verifikasi: login harus ditolak (return false), state tetap AuthSignedOut, storage token kosong
        expect(loginResult, isFalse);
        expect(container.read(authControllerProvider), isA<AuthSignedOut>());
        expect(await fakeStorage.getRefreshToken(), isNull);
      },
    );
  });
}
