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
import 'package:kok_app/core/auth/domain/credential_id_generator.dart';
import 'package:kok_app/core/auth/domain/user_principal.dart';
import 'package:kok_app/core/auth/presentation/auth_controller.dart';
import 'package:kok_app/core/preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_token_storage_test.dart';

final fakeGarutKotaUser = UserPrincipal(
  id: 'usr_garut_kota',
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
  bool shouldThrowOnSave = false;
  bool shouldThrowOnClear = false;

  @override
  Future<String?> readSk() async => _sk;

  @override
  Future<void> saveSk(String sk) async {
    if (shouldThrowOnSave) {
      throw const MetadataStorageException('Simulated saveSk failure');
    }
    _sk = sk;
  }

  @override
  Future<void> clear() async {
    if (shouldThrowOnClear) {
      throw const MetadataStorageException('Simulated clear failure');
    }
    _sk = null;
  }
}

class CompleterAuthRepository implements AuthRepository {
  final Completer<AuthResult>? loginCompleter;
  final Completer<AuthResult>? restoreCompleter;
  AuthResult? loginResult;
  int restoreCallCount = 0;
  int loginCallCount = 0;
  String? lastRestoreRefreshToken;

  CompleterAuthRepository({
    this.loginCompleter,
    this.restoreCompleter,
    this.loginResult,
  });

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
    if (loginResult != null) {
      return loginResult!;
    }
    if (skNumber == 'DEMO-001' && password == 'kokgarut123') {
      return AuthResult.success(
        user: UserPrincipal(
          id: 'usr-1',
          skNumber: 'DEMO-001',
          fullName: 'Test User',
          roleTitle: 'Tester',
          scope: const AccessScope(
            type: AccessScopeType.county,
            id: '1',
            name: 'Garut',
          ),
          permissions: const {},
        ),
        accessToken: 'access_1',
        refreshToken: staySignedIn ? 'refresh_1' : null,
        sessionHandle: RemoteSessionHandle('remote_handle_1'),
      );
    }
    return const AuthResult.failed(InvalidCredentialsFailure());
  }

  @override
  Future<AuthResult> restoreSession(String refreshToken) async {
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

  Duration? revokeDelay;
  bool shouldThrowOnRevoke = false;
  int revokeCallCount = 0;
  Completer<void>? revokeCompleter;

  @override
  Future<RemoteRevocationResult> revokeSession(
    RemoteSessionHandle session,
  ) async {
    revokeCallCount++;
    if (revokeCompleter != null) {
      await revokeCompleter!.future;
    }
    if (revokeDelay != null) {
      await Future<void>.delayed(revokeDelay!);
    }
    if (shouldThrowOnRevoke) {
      throw Exception('Revoke error');
    }
    return const RemoteRevocationResult(RemoteRevocationStatus.revoked);
  }
}

class FakeSessionMetadataStore implements SessionMetadataStore {
  SessionMetadata? metadata;
  bool shouldThrowOnRead = false;
  bool shouldThrowOnWrite = false;
  bool shouldThrowCorrupt = false;
  int? throwOnWriteCallIndex;
  int writeCallCount = 0;
  SessionMetadata? lastWritten;
  Completer<void>? onWriteCompleter;
  void Function(SessionMetadata metadata)? onWriteHook;

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
    writeCallCount++;
    if (onWriteHook != null) {
      onWriteHook!(metadata);
    }
    if (onWriteCompleter != null) {
      await onWriteCompleter!.future;
    }
    if (shouldThrowOnWrite ||
        (throwOnWriteCallIndex != null &&
            writeCallCount == throwOnWriteCallIndex)) {
      throw const StorageException('Metadata write error');
    }
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
  void Function()? onWriteHook;
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
    if (onWriteHook != null) onWriteHook!();
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
}

class ControlledAuthRepo implements AuthRepository {
  AuthResult? restoreResult;
  Exception? restoreException;
  int restoreCallCount = 0;
  String? lastRestoreRefreshToken;

  ControlledAuthRepo({this.restoreResult, this.restoreException});

  @override
  Future<AuthResult> restoreSession(String refreshToken) async {
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
}

class SequencedLogoutAuthRepository implements AuthRepository {
  final List<AuthResult> loginResults;
  final Completer<void> firstRevocation;
  final Completer<void> firstRevocationStarted = Completer<void>();
  final List<RemoteSessionHandle> revokedHandles = [];
  int _loginIndex = 0;

  SequencedLogoutAuthRepository({
    required this.loginResults,
    required this.firstRevocation,
  });

  @override
  Future<AuthResult> login({
    required String skNumber,
    required String password,
    required bool staySignedIn,
  }) async => loginResults[_loginIndex++];

  @override
  Future<AuthResult> restoreSession(String refreshToken) async =>
      const AuthResult.failed(SessionExpiredFailure());

  @override
  Future<AuthResult> refreshToken(String refreshToken) =>
      restoreSession(refreshToken);

  @override
  Future<RemoteRevocationResult> revokeSession(
    RemoteSessionHandle session,
  ) async {
    revokedHandles.add(session);
    if (revokedHandles.length == 1) {
      firstRevocationStarted.complete();
      await firstRevocation.future;
    }
    return const RemoteRevocationResult(RemoteRevocationStatus.revoked);
  }
}

class FixedCredentialIdGenerator implements CredentialIdGenerator {
  final String value;

  const FixedCredentialIdGenerator(this.value);

  @override
  String generate() => value;
}

class ThrowingCredentialIdGenerator implements CredentialIdGenerator {
  const ThrowingCredentialIdGenerator();

  @override
  String generate() => throw StateError('credential ID generator failed');
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
    authRepository = DemoAuthRepository(simulateLatency: false);
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
        await controller.bootstrap();
        expect(container.read(authControllerProvider), isA<AuthSignedOut>());

        final result = await controller.login(
          skNumber: 'DEMO-001',
          password: 'kokgarut123',
          staySignedIn: true,
          rememberSk: true,
        );

        expect(result.isSuccess, isTrue);
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
      await controller.bootstrap();
      expect(container.read(authControllerProvider), isA<AuthSignedOut>());

      final loginResult = await controller.login(
        skNumber: 'DEMO-001',
        password: 'kokgarut123',
        staySignedIn: true,
        rememberSk: false,
      );
      expect(loginResult.isSuccess, isTrue);
      final gen1 =
          (container.read(authControllerProvider) as AuthSignedIn).generation;

      final logoutResult = await controller.logout();
      expect(logoutResult.localSessionClosed, isTrue);
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
        await controller.bootstrap();
        expect(container.read(authControllerProvider), isA<AuthSignedOut>());

        // 1. Mulai login (asinkron tertahan)
        final loginFuture = controller.login(
          skNumber: 'DEMO-001',
          password: 'password',
          staySignedIn: true,
          rememberSk: true,
        );
        expect(container.read(authControllerProvider), isA<AuthSigningIn>());

        // 2. Pengguna memanggil logout sebelum login selesai
        final logoutResult = await controller.logout();
        expect(logoutResult.localSessionClosed, isTrue);
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

        // 4. Verifikasi: login dibatalkan, state tetap AuthSignedOut, storage token kosong
        expect(loginResult.isSuccess, isFalse);
        expect(loginResult.status, equals(AuthCommandStatus.cancelled));
        expect(container.read(authControllerProvider), isA<AuthSignedOut>());
        expect(await fakeStorage.read(), isNull);
      },
    );
  });

  group('Two-Phase Login & Logical Cancellation', () {
    test('login ditolak jika state bukan AuthSignedOut clean', () async {
      final container = ProviderContainer(
        overrides: [
          authTokenStorageProvider.overrideWithValue(tokenStorage),
          authRepositoryProvider.overrideWithValue(authRepository),
          rememberedSkStoreProvider.overrideWithValue(skStore),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(authControllerProvider.notifier);

      // 1. Dari AuthBootstrapping (belum bootstrap)
      final res1 = await controller.login(
        skNumber: 'DEMO-001',
        password: 'kokgarut123',
        staySignedIn: false,
        rememberSk: false,
      );
      expect(res1.status, equals(AuthCommandStatus.rejected));

      // Bootstrap agar clean
      await controller.bootstrap();

      // 2. Login pertama sukses -> AuthSignedIn
      final res2 = await controller.login(
        skNumber: 'DEMO-001',
        password: 'kokgarut123',
        staySignedIn: false,
        rememberSk: false,
      );
      expect(res2.isSuccess, isTrue);

      // 3. Panggil login lagi saat sudah signed in -> ditolak
      final res3 = await controller.login(
        skNumber: 'DEMO-001',
        password: 'kokgarut123',
        staySignedIn: false,
        rememberSk: false,
      );
      expect(res3.status, equals(AuthCommandStatus.rejected));
    });

    test(
      'login nonpersisten: menulis metadata clean, simpan session handle di memori, tanpa credential storage',
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

        final result = await controller.login(
          skNumber: 'DEMO-001',
          password: 'kokgarut123',
          staySignedIn: false,
          rememberSk: true,
        );

        expect(result.isSuccess, isTrue);
        expect(result.status, equals(AuthCommandStatus.success));
        expect(container.read(authControllerProvider), isA<AuthSignedIn>());
        expect(controller.activeRemoteHandle, isNotNull);
        expect(controller.activeCredentialId, isNull);
        expect(storage.credential, isNull);
        expect(
          metadataStore.lastWritten,
          equals(const SessionMetadata.signedOutClean()),
        );
        expect(controller.signInPhase, equals(SignInPhase.idle));
        expect(await skStore.readSk(), equals('DEMO-001'));
      },
    );

    test(
      'login nonpersisten: jika penulisan metadata gagal -> state AuthTemporarilyUnavailable dan return failed',
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

        metadataStore.shouldThrowOnWrite = true;

        final result = await controller.login(
          skNumber: 'DEMO-001',
          password: 'kokgarut123',
          staySignedIn: false,
          rememberSk: false,
        );

        expect(result.isSuccess, isFalse);
        expect(result.status, equals(AuthCommandStatus.failed));
        expect(
          container.read(authControllerProvider),
          isA<AuthTemporarilyUnavailable>(),
        );
        expect(controller.activeRemoteHandle, isNull);
      },
    );

    test(
      'login persisten: menulis pending, token storage, restore-enabled, menyimpan activeCredentialId',
      () async {
        final storage = FakeAuthTokenStorage();
        final metadataStore = FakeSessionMetadataStore();
        final generator = DeterministicCredentialIdGenerator('custom-cred');
        final container = ProviderContainer(
          overrides: [
            authTokenStorageProvider.overrideWithValue(storage),
            sessionMetadataStoreProvider.overrideWithValue(metadataStore),
            authRepositoryProvider.overrideWithValue(authRepository),
            rememberedSkStoreProvider.overrideWithValue(skStore),
            credentialIdGeneratorProvider.overrideWithValue(generator),
          ],
        );
        addTearDown(container.dispose);

        final controller = container.read(authControllerProvider.notifier);
        await controller.bootstrap();

        final result = await controller.login(
          skNumber: 'DEMO-001',
          password: 'kokgarut123',
          staySignedIn: true,
          rememberSk: false,
        );

        expect(result.isSuccess, isTrue);
        expect(container.read(authControllerProvider), isA<AuthSignedIn>());
        expect(controller.activeCredentialId, equals('custom-cred-1'));
        expect(controller.activeRemoteHandle, isNotNull);
        expect(storage.credential?.credentialId, equals('custom-cred-1'));
        expect(
          metadataStore.lastWritten,
          equals(SessionMetadata.restoreEnabled('custom-cred-1')),
        );
        expect(controller.signInPhase, equals(SignInPhase.idle));
      },
    );

    test(
      'cancelSignIn saat executing membatalkan login via Future.any dan mengembalikan state ke signedOut clean',
      () async {
        final loginCompleter = Completer<AuthResult>();
        final fakeRepo = CompleterAuthRepository(
          loginCompleter: loginCompleter,
        );
        final storage = FakeAuthTokenStorage();
        final metadataStore = FakeSessionMetadataStore();

        final container = ProviderContainer(
          overrides: [
            authRepositoryProvider.overrideWithValue(fakeRepo),
            authTokenStorageProvider.overrideWithValue(storage),
            sessionMetadataStoreProvider.overrideWithValue(metadataStore),
            rememberedSkStoreProvider.overrideWithValue(skStore),
          ],
        );
        addTearDown(container.dispose);

        final controller = container.read(authControllerProvider.notifier);
        await controller.bootstrap();

        final loginFuture = controller.login(
          skNumber: 'DEMO-001',
          password: 'password',
          staySignedIn: true,
          rememberSk: false,
        );

        expect(controller.signInPhase, equals(SignInPhase.executing));
        expect(container.read(authControllerProvider), isA<AuthSigningIn>());

        final cancelResult = await controller.cancelSignIn();
        expect(cancelResult.status, equals(AuthCommandStatus.success));
        expect(controller.signInPhase, equals(SignInPhase.idle));
        expect(
          container.read(authControllerProvider),
          equals(const AuthSignedOut(cleanupStatus: LocalCleanupStatus.clean)),
        );

        final loginResult = await loginFuture;
        expect(loginResult.status, equals(AuthCommandStatus.cancelled));
        expect(storage.credential, isNull);
      },
    );

    test('cancelSignIn saat idle ditolak dengan status rejected', () async {
      final container = ProviderContainer(
        overrides: [
          authTokenStorageProvider.overrideWithValue(tokenStorage),
          authRepositoryProvider.overrideWithValue(authRepository),
          rememberedSkStoreProvider.overrideWithValue(skStore),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(authControllerProvider.notifier);
      await controller.bootstrap();

      final result = await controller.cancelSignIn();
      expect(result.status, equals(AuthCommandStatus.rejected));
      expect(result.errorMessage, contains('Tidak ada proses login aktif'));
    });
  });

  group('Logout Semantics & In-Memory Eviction', () {
    test(
      'logout mengeviksi memori segera dan mengembalikan LogoutResult lengkap',
      () async {
        final storage = FakeAuthTokenStorage();
        final metadataStore = FakeSessionMetadataStore();
        final fakeRepo = CompleterAuthRepository();

        final container = ProviderContainer(
          overrides: [
            authTokenStorageProvider.overrideWithValue(storage),
            sessionMetadataStoreProvider.overrideWithValue(metadataStore),
            authRepositoryProvider.overrideWithValue(fakeRepo),
            rememberedSkStoreProvider.overrideWithValue(skStore),
          ],
        );
        addTearDown(container.dispose);

        final controller = container.read(authControllerProvider.notifier);
        await controller.bootstrap();

        // Login persisten sukses
        final loginRes = await controller.login(
          skNumber: 'DEMO-001',
          password: 'kokgarut123',
          staySignedIn: true,
          rememberSk: false,
        );
        expect(loginRes.isSuccess, isTrue);
        expect(controller.activeCredentialId, isNotNull);
        final genBefore = controller.currentGeneration;

        // Panggil logout
        final logoutResult = await controller.logout();

        expect(logoutResult.localSessionClosed, isTrue);
        expect(logoutResult.credentialCleared, isTrue);
        expect(logoutResult.metadataClean, isTrue);
        expect(
          logoutResult.remoteRevocationStatus,
          equals(RemoteRevocationStatus.revoked),
        );

        expect(controller.activeRemoteHandle, isNull);
        expect(controller.activeCredentialId, isNull);
        expect(controller.currentGeneration, greaterThan(genBefore));
        expect(storage.clearIfOwnedCallCount, equals(1));
        expect(storage.credential, isNull);
        expect(
          metadataStore.lastWritten,
          equals(const SessionMetadata.signedOutClean()),
        );
        expect(
          container.read(authControllerProvider),
          equals(const AuthSignedOut(cleanupStatus: LocalCleanupStatus.clean)),
        );
      },
    );

    test(
      'logout timeout pada remote revocation mengembalikan remoteRevocationStatus failed',
      () async {
        final storage = FakeAuthTokenStorage();
        final metadataStore = FakeSessionMetadataStore();
        final fakeRepo = CompleterAuthRepository()
          ..revokeDelay = const Duration(milliseconds: 100);

        final container = ProviderContainer(
          overrides: [
            authTokenStorageProvider.overrideWithValue(storage),
            sessionMetadataStoreProvider.overrideWithValue(metadataStore),
            authRepositoryProvider.overrideWithValue(fakeRepo),
            rememberedSkStoreProvider.overrideWithValue(skStore),
          ],
        );
        addTearDown(container.dispose);

        final controller = container.read(authControllerProvider.notifier);
        await controller.bootstrap();

        await controller.login(
          skNumber: 'DEMO-001',
          password: 'kokgarut123',
          staySignedIn: true,
          rememberSk: false,
        );

        // Beri revocationTimeout sangat kecil (1ms) untuk memicu timeout
        final logoutResult = await controller.logout(
          revocationTimeout: const Duration(milliseconds: 1),
        );

        expect(logoutResult.localSessionClosed, isTrue);
        expect(logoutResult.credentialCleared, isTrue);
        expect(logoutResult.metadataClean, isTrue);
        expect(
          logoutResult.remoteRevocationStatus,
          equals(RemoteRevocationStatus.failed),
        );
      },
    );

    test(
      'logout sesi nonpersisten: credentialCleared tetap true tanpa memanggil clearIfOwnedBy',
      () async {
        final storage = FakeAuthTokenStorage();
        final metadataStore = FakeSessionMetadataStore();
        final fakeRepo = CompleterAuthRepository();

        final container = ProviderContainer(
          overrides: [
            authTokenStorageProvider.overrideWithValue(storage),
            sessionMetadataStoreProvider.overrideWithValue(metadataStore),
            authRepositoryProvider.overrideWithValue(fakeRepo),
            rememberedSkStoreProvider.overrideWithValue(skStore),
          ],
        );
        addTearDown(container.dispose);

        final controller = container.read(authControllerProvider.notifier);
        await controller.bootstrap();

        await controller.login(
          skNumber: 'DEMO-001',
          password: 'kokgarut123',
          staySignedIn: false,
          rememberSk: false,
        );

        final logoutResult = await controller.logout();
        expect(logoutResult.localSessionClosed, isTrue);
        expect(logoutResult.credentialCleared, isTrue);
        expect(storage.clearIfOwnedCallCount, equals(0));
      },
    );
  });

  group('Recovery (retryLocalCredentialCleanup)', () {
    test(
      'retryLocalCredentialCleanup ditolak bila state bukan AuthSignedOut failed',
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
        await controller.bootstrap();
        expect(
          container.read(authControllerProvider),
          equals(const AuthSignedOut(cleanupStatus: LocalCleanupStatus.clean)),
        );

        // State adalah clean, bukan failed -> ditolak
        final success = await controller.retryLocalCredentialCleanup();
        expect(success, isFalse);
      },
    );

    test(
      'retryLocalCredentialCleanup berhasil mengubah state ke clean bila forceClear dan metadata clean sukses',
      () async {
        final storage = FakeAuthTokenStorage(
          credential: const StoredCredential(
            credentialId: 'cred-failed',
            refreshToken: 'tok-failed',
          ),
        );
        final metadataStore = FakeSessionMetadataStore(
          metadata: const SessionMetadata.cleanupFailed(),
        );

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
        expect(
          container.read(authControllerProvider),
          equals(const AuthSignedOut(cleanupStatus: LocalCleanupStatus.failed)),
        );

        final success = await controller.retryLocalCredentialCleanup();
        expect(success, isTrue);
        expect(storage.forceClearCallCount, equals(1));
        expect(storage.credential, isNull);
        expect(
          metadataStore.lastWritten,
          equals(const SessionMetadata.signedOutClean()),
        );
        expect(
          container.read(authControllerProvider),
          equals(const AuthSignedOut(cleanupStatus: LocalCleanupStatus.clean)),
        );
      },
    );
  });

  group('Controller Fault-Injection Suite (FT-01 s/d FT-08)', () {
    // FT-01: Metadata pending login gagal
    test(
      'FT-01: Metadata pending login gagal -> tidak ada credential baru, state AuthTemporarilyUnavailable',
      () async {
        final storage = FakeAuthTokenStorage();
        final metadataStore = FakeSessionMetadataStore()
          ..throwOnWriteCallIndex = 1;

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

        final result = await controller.login(
          skNumber: 'DEMO-001',
          password: 'kokgarut123',
          staySignedIn: true,
          rememberSk: false,
        );

        expect(result.isSuccess, isFalse);
        expect(result.status, equals(AuthCommandStatus.failed));
        expect(
          container.read(authControllerProvider),
          isA<AuthTemporarilyUnavailable>(),
        );
        expect(storage.credential, isNull);
      },
    );

    // FT-02: Credential write melempar
    test(
      'FT-02: Credential write melempar -> metadata failed, state AuthSignedOut(failed)',
      () async {
        final storage = FakeAuthTokenStorage()..shouldThrowOnWrite = true;
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

        final result = await controller.login(
          skNumber: 'DEMO-001',
          password: 'kokgarut123',
          staySignedIn: true,
          rememberSk: false,
        );

        expect(result.isSuccess, isFalse);
        expect(result.status, equals(AuthCommandStatus.failed));
        expect(
          container.read(authControllerProvider),
          equals(const AuthSignedOut(cleanupStatus: LocalCleanupStatus.failed)),
        );
        expect(
          metadataStore.lastWritten,
          equals(const SessionMetadata.cleanupFailed()),
        );
      },
    );

    // FT-03: Epoch berubah setelah credential write
    test(
      'FT-03: Epoch berubah setelah credential write -> rollback owned credential',
      () async {
        final storage = FakeAuthTokenStorage();
        final metadataStore = FakeSessionMetadataStore();
        late ProviderContainer container;

        container = ProviderContainer(
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

        Future<LogoutResult>? logoutFuture;
        storage.onWriteHook = () {
          logoutFuture = controller.logout();
        };

        final result = await controller.login(
          skNumber: 'DEMO-001',
          password: 'kokgarut123',
          staySignedIn: true,
          rememberSk: false,
        );

        await logoutFuture;

        expect(result.status, equals(AuthCommandStatus.cancelled));
        expect(storage.credential, isNull);
        expect(storage.clearIfOwnedCallCount, greaterThanOrEqualTo(1));
      },
    );

    // FT-04: Metadata final gagal -> rollback credential
    test(
      'FT-04: Metadata final gagal -> rollback credential dan set clean bila clean write berhasil',
      () async {
        final storage = FakeAuthTokenStorage();
        final metadataStore = FakeSessionMetadataStore()
          ..throwOnWriteCallIndex = 2; // Gagal saat write restore-enabled

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

        final result = await controller.login(
          skNumber: 'DEMO-001',
          password: 'kokgarut123',
          staySignedIn: true,
          rememberSk: false,
        );

        expect(result.isSuccess, isFalse);
        expect(result.status, equals(AuthCommandStatus.failed));
        expect(storage.credential, isNull);
        expect(storage.clearIfOwnedCallCount, equals(1));
        expect(
          container.read(authControllerProvider),
          equals(const AuthSignedOut(cleanupStatus: LocalCleanupStatus.clean)),
        );
      },
    );

    // FT-05: clearIfOwnedBy return false saat logout -> foreign credential utuh, state failed
    test(
      'FT-05: clearIfOwnedBy return false saat logout -> foreign credential utuh, state failed',
      () async {
        final foreignCred = const StoredCredential(
          credentialId: 'foreign-123',
          refreshToken: 'foreign-token',
        );
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

        await controller.login(
          skNumber: 'DEMO-001',
          password: 'kokgarut123',
          staySignedIn: true,
          rememberSk: false,
        );

        // Ganti credential menjadi foreign
        storage.credential = foreignCred;

        final logoutRes = await controller.logout();
        expect(logoutRes.credentialCleared, isFalse);
        expect(storage.credential, equals(foreignCred));
        expect(
          container.read(authControllerProvider),
          equals(const AuthSignedOut(cleanupStatus: LocalCleanupStatus.failed)),
        );
      },
    );

    // FT-06: Restore expired dan clearIfOwnedBy gagal
    test(
      'logout kedua setelah FT-05 tetap melaporkan credential dan metadata belum bersih',
      () async {
        final foreignCredential = const StoredCredential(
          credentialId: 'foreign-after-ft05',
          refreshToken: 'foreign-token-after-ft05',
        );
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
        await controller.login(
          skNumber: 'DEMO-001',
          password: 'kokgarut123',
          staySignedIn: true,
          rememberSk: false,
        );
        storage.credential = foreignCredential;

        await controller.logout();
        final secondLogout = await controller.logout();

        expect(secondLogout.credentialCleared, isFalse);
        expect(secondLogout.metadataClean, isFalse);
        expect(storage.credential, equals(foreignCredential));
        expect(
          container.read(authControllerProvider),
          equals(const AuthSignedOut(cleanupStatus: LocalCleanupStatus.failed)),
        );
        expect(
          metadataStore.metadata,
          isNot(equals(const SessionMetadata.signedOutClean())),
        );
      },
    );

    test(
      'FT-06: Restore expired dan clearIfOwnedBy gagal -> AuthSignedOut(failed)',
      () async {
        final expiredCred = const StoredCredential(
          credentialId: 'cred-ft06',
          refreshToken: 'tok-ft06',
        );
        final storage = FakeAuthTokenStorage(credential: expiredCred)
          ..clearIfOwnedReturnOverride = false;
        final metadataStore = FakeSessionMetadataStore(
          metadata: SessionMetadata.restoreEnabled('cred-ft06'),
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

    // FT-07: Token clear sukses tetapi metadata clean gagal saat logout
    test(
      'FT-07: Token clear sukses tetapi metadata clean gagal saat logout -> state failed',
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

        await controller.login(
          skNumber: 'DEMO-001',
          password: 'kokgarut123',
          staySignedIn: true,
          rememberSk: false,
        );

        // Saat logout: write pending (ok), clear cred (ok), write clean (gagal)
        metadataStore.throwOnWriteCallIndex = metadataStore.writeCallCount + 2;

        final logoutRes = await controller.logout();
        expect(logoutRes.credentialCleared, isTrue);
        expect(logoutRes.metadataClean, isFalse);
        expect(
          container.read(authControllerProvider),
          equals(const AuthSignedOut(cleanupStatus: LocalCleanupStatus.failed)),
        );
      },
    );

    // FT-08: Force clear sukses tetapi metadata recovery gagal
    test(
      'FT-08: Force clear sukses tetapi metadata recovery gagal -> state failed dan return false',
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
        // Paksa ke signed-out failed
        storage.shouldThrowOnRead = true;
        await controller.bootstrap();
        expect(
          container.read(authControllerProvider),
          equals(const AuthSignedOut(cleanupStatus: LocalCleanupStatus.failed)),
        );

        storage.shouldThrowOnRead = false;
        metadataStore.shouldThrowOnWrite = true;

        final success = await controller.retryLocalCredentialCleanup();
        expect(success, isFalse);
        expect(storage.forceClearCallCount, equals(1));
        expect(
          container.read(authControllerProvider),
          equals(const AuthSignedOut(cleanupStatus: LocalCleanupStatus.failed)),
        );
      },
    );

    // FT-08b: Force clear melempar exception saat recovery
    test(
      'FT-08b: Force clear melempar exception saat recovery -> metadata tidak ditulis clean, state failed dan return false',
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
        // Paksa ke signed-out failed
        storage.shouldThrowOnRead = true;
        await controller.bootstrap();
        expect(
          container.read(authControllerProvider),
          equals(const AuthSignedOut(cleanupStatus: LocalCleanupStatus.failed)),
        );

        storage.shouldThrowOnRead = false;
        storage.shouldThrowOnForceClear = true;

        final success = await controller.retryLocalCredentialCleanup();
        expect(success, isFalse);
        expect(storage.forceClearCallCount, equals(0));
        expect(
          metadataStore.lastWritten,
          isNot(equals(const SessionMetadata.signedOutClean())),
        );
        expect(
          container.read(authControllerProvider),
          equals(const AuthSignedOut(cleanupStatus: LocalCleanupStatus.failed)),
        );
      },
    );
  });

  group(
    'Concurrency Hardening & Typed Rejections (Patch 3: SC-06, SC-07, SC-13, SC-16, P1-08)',
    () {
      test(
        'SC-06: concurrent logout() returns same Future instance and performs single cleanup cycle',
        () async {
          final storage = FakeAuthTokenStorage();
          final metadataStore = FakeSessionMetadataStore();
          final fakeRepo = CompleterAuthRepository();
          final revokeCompleter = Completer<void>();
          fakeRepo.revokeCompleter = revokeCompleter;

          final container = ProviderContainer(
            overrides: [
              authTokenStorageProvider.overrideWithValue(storage),
              sessionMetadataStoreProvider.overrideWithValue(metadataStore),
              authRepositoryProvider.overrideWithValue(fakeRepo),
              rememberedSkStoreProvider.overrideWithValue(skStore),
            ],
          );
          addTearDown(container.dispose);

          final controller = container.read(authControllerProvider.notifier);
          await controller.bootstrap();

          final loginRes = await controller.login(
            skNumber: 'DEMO-001',
            password: 'kokgarut123',
            staySignedIn: true,
            rememberSk: false,
          );
          expect(loginRes.isSuccess, isTrue);

          final future1 = controller.logout();
          final future2 = controller.logout();

          expect(identical(future1, future2), isTrue);

          revokeCompleter.complete();

          final result1 = await future1;
          final result2 = await future2;

          expect(result1, equals(result2));
          expect(fakeRepo.revokeCallCount, equals(1));
          expect(storage.clearIfOwnedCallCount, equals(1));
          expect(container.read(authControllerProvider), isA<AuthSignedOut>());
        },
      );

      test(
        'SC-07: login during cleanup failed/pending returns AuthCommandStatus.rejected and rejection: AuthCommandRejection.cleanupRequired',
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

          // Bootstrap into failed state
          storage.shouldThrowOnRead = true;
          await controller.bootstrap();
          expect(
            container.read(authControllerProvider),
            equals(
              const AuthSignedOut(cleanupStatus: LocalCleanupStatus.failed),
            ),
          );

          // Attempt login while cleanup is failed -> cleanupRequired
          final failedResult = await controller.login(
            skNumber: 'DEMO-001',
            password: 'kokgarut123',
            staySignedIn: false,
            rememberSk: false,
          );
          expect(failedResult.status, equals(AuthCommandStatus.rejected));
          expect(failedResult.isRejected, isTrue);
          expect(
            failedResult.rejection,
            equals(AuthCommandRejection.cleanupRequired),
          );
          expect(
            failedResult.errorMessage,
            equals('Pembersihan sesi lokal sebelumnya belum selesai.'),
          );

          // Now test when cleanup is pending
          storage.shouldThrowOnRead = false;
          final queueBlocker = Completer<void>();
          final blockerFuture = controller.enqueueMutation(
            () => queueBlocker.future,
          );

          final retryFuture = controller.retryLocalCredentialCleanup();
          expect(
            container.read(authControllerProvider),
            equals(
              const AuthSignedOut(cleanupStatus: LocalCleanupStatus.pending),
            ),
          );

          final pendingResult = await controller.login(
            skNumber: 'DEMO-001',
            password: 'kokgarut123',
            staySignedIn: false,
            rememberSk: false,
          );
          expect(pendingResult.status, equals(AuthCommandStatus.rejected));
          expect(pendingResult.isRejected, isTrue);
          expect(
            pendingResult.rejection,
            equals(AuthCommandRejection.cleanupRequired),
          );
          expect(
            pendingResult.errorMessage,
            equals('Pembersihan sesi lokal sebelumnya belum selesai.'),
          );

          queueBlocker.complete();
          await blockerFuture;
          await retryFuture;

          // Verify invalidState when not AuthSignedOut
          expect(
            container.read(authControllerProvider),
            equals(
              const AuthSignedOut(cleanupStatus: LocalCleanupStatus.clean),
            ),
          );
          final loginOk = await controller.login(
            skNumber: 'DEMO-001',
            password: 'kokgarut123',
            staySignedIn: false,
            rememberSk: false,
          );
          expect(loginOk.isSuccess, isTrue);

          final invalidStateResult = await controller.login(
            skNumber: 'DEMO-001',
            password: 'kokgarut123',
            staySignedIn: false,
            rememberSk: false,
          );
          expect(invalidStateResult.status, equals(AuthCommandStatus.rejected));
          expect(invalidStateResult.isRejected, isTrue);
          expect(
            invalidStateResult.rejection,
            equals(AuthCommandRejection.invalidState),
          );
          expect(
            invalidStateResult.errorMessage,
            equals('Operasi login tidak valid pada state saat ini.'),
          );
        },
      );

      test(
        'SC-13: barrier test verifying stale ticket while waiting for mutation queue drops commit without writing credentials/metadata',
        () async {
          final storage = FakeAuthTokenStorage();
          final metadataStore = FakeSessionMetadataStore();
          final generator = DeterministicCredentialIdGenerator('sc13-cred');

          final container = ProviderContainer(
            overrides: [
              authTokenStorageProvider.overrideWithValue(storage),
              sessionMetadataStoreProvider.overrideWithValue(metadataStore),
              authRepositoryProvider.overrideWithValue(authRepository),
              rememberedSkStoreProvider.overrideWithValue(skStore),
              credentialIdGeneratorProvider.overrideWithValue(generator),
            ],
          );
          addTearDown(container.dispose);

          final controller = container.read(authControllerProvider.notifier);
          await controller.bootstrap();
          expect(
            container.read(authControllerProvider),
            equals(
              const AuthSignedOut(cleanupStatus: LocalCleanupStatus.clean),
            ),
          );

          final queueBlocker = Completer<void>();
          final blockerFuture = controller.enqueueMutation(
            () => queueBlocker.future,
          );

          final loginFuture = controller.login(
            skNumber: 'DEMO-001',
            password: 'kokgarut123',
            staySignedIn: true,
            rememberSk: false,
          );

          await Future<void>.delayed(Duration.zero);
          expect(controller.signInPhase, equals(SignInPhase.waitingForCommit));

          final cancelResult = await controller.cancelSignIn();
          expect(cancelResult.status, equals(AuthCommandStatus.success));
          expect(cancelResult.isSuccess, isTrue);

          queueBlocker.complete();
          await blockerFuture;

          final loginResult = await loginFuture;
          expect(loginResult.status, equals(AuthCommandStatus.cancelled));

          expect(storage.writeCallCount, equals(0));
          expect(storage.credential, isNull);
          expect(metadataStore.writeCallCount, equals(0));
          expect(metadataStore.lastWritten, isNull);
          expect(
            container.read(authControllerProvider),
            equals(
              const AuthSignedOut(cleanupStatus: LocalCleanupStatus.clean),
            ),
          );
        },
      );

      test(
        'SC-16: barrier test verifying cancel while committing returns AuthCommandStatus.rejected and rejection: AuthCommandRejection.operationInProgress',
        () async {
          final storage = FakeAuthTokenStorage();
          final metadataStore = FakeSessionMetadataStore();
          final commitBlocker = Completer<void>();
          final enteredCommit = Completer<void>();

          metadataStore.onWriteHook = (_) {
            if (!enteredCommit.isCompleted) {
              enteredCommit.complete();
            }
          };
          metadataStore.onWriteCompleter = commitBlocker;

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

          final loginFuture = controller.login(
            skNumber: 'DEMO-001',
            password: 'kokgarut123',
            staySignedIn: true,
            rememberSk: false,
          );

          await enteredCommit.future;
          expect(controller.signInPhase, equals(SignInPhase.committing));

          final cancelResult = await controller.cancelSignIn();
          expect(cancelResult.status, equals(AuthCommandStatus.rejected));
          expect(cancelResult.isRejected, isTrue);
          expect(
            cancelResult.rejection,
            equals(AuthCommandRejection.operationInProgress),
          );
          expect(
            cancelResult.errorMessage,
            equals('Proses sign in sedang melakukan commit data.'),
          );

          metadataStore.onWriteCompleter = null;
          metadataStore.onWriteHook = null;
          commitBlocker.complete();

          final loginResult = await loginFuture;
          expect(loginResult.isSuccess, isTrue);
          expect(container.read(authControllerProvider), isA<AuthSignedIn>());
        },
      );

      test(
        'P1-08: login where skStore.saveSk throws MetadataStorageException succeeds with AuthCommandStatus.success and AuthSignedIn state',
        () async {
          final storage = FakeAuthTokenStorage();
          final metadataStore = FakeSessionMetadataStore();
          final failingSkStore = InMemoryRememberedSkStore()
            ..shouldThrowOnSave = true;

          final container = ProviderContainer(
            overrides: [
              authTokenStorageProvider.overrideWithValue(storage),
              sessionMetadataStoreProvider.overrideWithValue(metadataStore),
              authRepositoryProvider.overrideWithValue(authRepository),
              rememberedSkStoreProvider.overrideWithValue(failingSkStore),
            ],
          );
          addTearDown(container.dispose);

          final controller = container.read(authControllerProvider.notifier);
          await controller.bootstrap();

          // 1. Persistent login with rememberSk: true
          final persistentResult = await controller.login(
            skNumber: 'DEMO-001',
            password: 'kokgarut123',
            staySignedIn: true,
            rememberSk: true,
          );
          expect(persistentResult.isSuccess, isTrue);
          expect(persistentResult.status, equals(AuthCommandStatus.success));
          expect(container.read(authControllerProvider), isA<AuthSignedIn>());

          // Logout
          await controller.logout();
          expect(container.read(authControllerProvider), isA<AuthSignedOut>());

          // 2. Non-persistent login with rememberSk: true
          final nonPersistentResult = await controller.login(
            skNumber: 'DEMO-001',
            password: 'kokgarut123',
            staySignedIn: false,
            rememberSk: true,
          );
          expect(nonPersistentResult.isSuccess, isTrue);
          expect(nonPersistentResult.status, equals(AuthCommandStatus.success));
          expect(container.read(authControllerProvider), isA<AuthSignedIn>());

          // 3. Non-persistent login with rememberSk: false when clear throws
          await controller.logout();
          failingSkStore.shouldThrowOnSave = false;
          failingSkStore.shouldThrowOnClear = true;

          final clearFailResult = await controller.login(
            skNumber: 'DEMO-001',
            password: 'kokgarut123',
            staySignedIn: false,
            rememberSk: false,
          );
          expect(clearFailResult.isSuccess, isTrue);
          expect(clearFailResult.status, equals(AuthCommandStatus.success));
          expect(container.read(authControllerProvider), isA<AuthSignedIn>());
        },
      );

      test(
        'logout B starts an independent cleanup while logout A revocation is pending',
        () async {
          final firstRevocation = Completer<void>();
          final repository = SequencedLogoutAuthRepository(
            firstRevocation: firstRevocation,
            loginResults: [
              AuthResult.success(
                user: UserPrincipal(
                  id: 'session-a-user',
                  skNumber: 'SESSION-A',
                  fullName: 'Session A',
                  roleTitle: 'Tester',
                  scope: const AccessScope(
                    type: AccessScopeType.county,
                    id: 'a',
                    name: 'A',
                  ),
                ),
                accessToken: 'access-a',
                refreshToken: 'refresh-a',
                sessionHandle: RemoteSessionHandle('remote-handle-a'),
              ),
              AuthResult.success(
                user: UserPrincipal(
                  id: 'session-b-user',
                  skNumber: 'SESSION-B',
                  fullName: 'Session B',
                  roleTitle: 'Tester',
                  scope: const AccessScope(
                    type: AccessScopeType.county,
                    id: 'b',
                    name: 'B',
                  ),
                ),
                accessToken: 'access-b',
                refreshToken: 'refresh-b',
                sessionHandle: RemoteSessionHandle('remote-handle-b'),
              ),
            ],
          );
          final storage = FakeAuthTokenStorage();
          final metadataStore = FakeSessionMetadataStore();
          final container = ProviderContainer(
            overrides: [
              authRepositoryProvider.overrideWithValue(repository),
              authTokenStorageProvider.overrideWithValue(storage),
              sessionMetadataStoreProvider.overrideWithValue(metadataStore),
              rememberedSkStoreProvider.overrideWithValue(skStore),
            ],
          );
          addTearDown(container.dispose);

          final controller = container.read(authControllerProvider.notifier);
          await controller.bootstrap();
          await controller.login(
            skNumber: 'SESSION-A',
            password: 'password-a',
            staySignedIn: true,
            rememberSk: false,
          );

          final logoutA = controller.logout();
          await repository.firstRevocationStarted.future;
          expect(
            container.read(authControllerProvider),
            equals(
              const AuthSignedOut(cleanupStatus: LocalCleanupStatus.clean),
            ),
          );

          await controller.login(
            skNumber: 'SESSION-B',
            password: 'password-b',
            staySignedIn: true,
            rememberSk: false,
          );
          final logoutB = controller.logout();
          final hasIndependentLogout = !identical(logoutA, logoutB);

          firstRevocation.complete();
          await logoutA;
          await logoutB;

          expect(hasIndependentLogout, isTrue);
          expect(storage.credential, isNull);
          expect(
            container.read(authControllerProvider),
            equals(
              const AuthSignedOut(cleanupStatus: LocalCleanupStatus.clean),
            ),
          );
          expect(repository.revokedHandles, hasLength(2));
          expect(
            repository.revokedHandles[0],
            isNot(equals(repository.revokedHandles[1])),
          );
        },
      );

      test('persistent credential precondition rejects invalid values before local writes', () async {
        final cases = <
          ({
            String name,
            AuthResult result,
            CredentialIdGenerator generator,
            String expectedFailure,
          })
        >[
          (
            name: 'null refresh token',
            result: AuthResult.success(
              user: fakeGarutKotaUser,
              refreshToken: null,
            ),
            generator: const FixedCredentialIdGenerator('credential-null'),
            expectedFailure: 'AuthCommandFailure.invalidPersistentCredential',
          ),
          (
            name: 'empty refresh token',
            result: AuthResult.success(
              user: fakeGarutKotaUser,
              refreshToken: '',
            ),
            generator: const FixedCredentialIdGenerator('credential-empty'),
            expectedFailure: 'AuthCommandFailure.invalidPersistentCredential',
          ),
          (
            name: 'generator exception',
            result: AuthResult.success(
              user: fakeGarutKotaUser,
              refreshToken: 'valid-refresh-token',
            ),
            generator: const ThrowingCredentialIdGenerator(),
            expectedFailure: 'AuthCommandFailure.credentialIdGenerationFailed',
          ),
          (
            name: 'blank credential ID',
            result: AuthResult.success(
              user: fakeGarutKotaUser,
              refreshToken: 'valid-refresh-token',
            ),
            generator: const FixedCredentialIdGenerator('   '),
            expectedFailure: 'AuthCommandFailure.invalidPersistentCredential',
          ),
          (
            name: 'overlong credential ID',
            result: AuthResult.success(
              user: fakeGarutKotaUser,
              refreshToken: 'valid-refresh-token',
            ),
            generator: FixedCredentialIdGenerator('x' * 129),
            expectedFailure: 'AuthCommandFailure.invalidPersistentCredential',
          ),
        ];

        for (final testCase in cases) {
          final storage = FakeAuthTokenStorage();
          final metadataStore = FakeSessionMetadataStore();
          final repository = CompleterAuthRepository(
            loginResult: testCase.result,
          );
          final container = ProviderContainer(
            overrides: [
              authRepositoryProvider.overrideWithValue(repository),
              authTokenStorageProvider.overrideWithValue(storage),
              sessionMetadataStoreProvider.overrideWithValue(metadataStore),
              rememberedSkStoreProvider.overrideWithValue(skStore),
              credentialIdGeneratorProvider.overrideWithValue(testCase.generator),
            ],
          );
          addTearDown(container.dispose);

          final controller = container.read(authControllerProvider.notifier);
          await controller.bootstrap();

          final result = await controller.login(
            skNumber: 'DEMO-001',
            password: 'kokgarut123',
            staySignedIn: true,
            rememberSk: false,
          );

          expect(result.status, AuthCommandStatus.failed, reason: testCase.name);
          expect(
            container.read(authControllerProvider),
            equals(
              const AuthSignedOut(cleanupStatus: LocalCleanupStatus.clean),
            ),
            reason: testCase.name,
          );
          expect(metadataStore.writeCallCount, 0, reason: testCase.name);
          expect(storage.writeCallCount, 0, reason: testCase.name);
          final dynamic typedResult = result;
          expect(
            typedResult.internalFailure.toString(),
            equals(testCase.expectedFailure),
            reason: testCase.name,
          );
        }
      });
    },
  );
}
