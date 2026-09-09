import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../config/app_environment.dart';
import '../../preferences.dart';
import '../data/auth_repository.dart';
import '../data/auth_token_storage.dart';
import '../data/demo_auth_repository.dart';
import '../data/remembered_sk_store.dart';
import '../data/session_metadata_store.dart';
import '../domain/auth_failure.dart';
import '../domain/auth_state.dart';
import '../domain/user_principal.dart';

final authTokenStorageProvider = Provider<AuthTokenStorage>((ref) {
  return SecureAuthTokenStorage(
    store: const FlutterSecureKeyValStore(
      FlutterSecureStorage(
        aOptions: AndroidOptions(encryptedSharedPreferences: true),
        iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
      ),
    ),
    key: 'kok.auth.v2.${currentEnvironment.name}.credential',
  );
});

final sessionMetadataStoreProvider = Provider<SessionMetadataStore>((ref) {
  try {
    final prefs = ref.watch(preferencesProvider);
    return SharedPrefsSessionMetadataStore(
      prefs: prefs,
      key: 'kok.auth.v2.${currentEnvironment.name}.metadata',
    );
  } catch (_) {
    return _FallbackSessionMetadataStore();
  }
});

class _FallbackSessionMetadataStore implements SessionMetadataStore {
  SessionMetadata? _metadata;

  @override
  Future<SessionMetadata?> read() async => _metadata;

  @override
  Future<void> write(SessionMetadata metadata) async {
    _metadata = metadata;
  }

  @override
  Future<void> clear() async {
    _metadata = null;
  }
}

final rememberedSkStoreProvider = Provider<RememberedSkStore>((ref) {
  final prefs = ref.watch(preferencesProvider);
  return RememberedSkStore(
    prefs: prefs,
    key: 'kok.auth.v2.${currentEnvironment.name}.remembered_sk',
  );
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return DemoAuthRepository(
    tokenStorage: ref.watch(authTokenStorageProvider),
    skStore: ref.watch(rememberedSkStoreProvider),
  );
});

final authControllerProvider = NotifierProvider<AuthController, AuthState>(
  AuthController.new,
);

final currentUserProvider = Provider<UserPrincipal?>((ref) {
  final state = ref.watch(authControllerProvider);
  if (state is AuthSignedIn) {
    return state.user;
  }
  return null;
});

class AuthController extends Notifier<AuthState> {
  int _sessionGeneration = 0;
  int _operationEpoch = 0;
  Future<void>? _activeBootstrapFuture;
  Future<void> _mutationTail = Future<void>.value();

  int get sessionGeneration => _sessionGeneration;
  int get currentGeneration => _sessionGeneration;

  @visibleForTesting
  Future<T> enqueueMutation<T>(Future<T> Function() mutation) =>
      _enqueueMutation(mutation);

  Future<T> _enqueueMutation<T>(Future<T> Function() mutation) {
    final run = _mutationTail.catchError((_) {}).then((_) => mutation());
    _mutationTail = run.then<void>((_) {}, onError: (_, _) {});
    return run;
  }

  @override
  AuthState build() {
    return const AuthBootstrapping();
  }

  Future<void> bootstrap() async {
    if (_activeBootstrapFuture != null) return _activeBootstrapFuture!;
    final future = _runBootstrap();
    _activeBootstrapFuture = future;
    try {
      await future;
    } finally {
      _activeBootstrapFuture = null;
    }
  }

  Future<void> _runBootstrap() async {
    _operationEpoch++;
    final currentEpoch = _operationEpoch;
    state = const AuthBootstrapping();

    final repo = ref.read(authRepositoryProvider);
    final tokenStorage = ref.read(authTokenStorageProvider);
    final metadataStore = ref.read(sessionMetadataStoreProvider);

    // 1. Migrasi legacy dijalankan pertama kali melalui mutation queue
    try {
      await _enqueueMutation(() => tokenStorage.migrateLegacyStorage());
    } catch (_) {
      if (currentEpoch != _operationEpoch) return;
      state = const AuthSignedOut(cleanupStatus: LocalCleanupStatus.failed);
      return;
    }

    if (currentEpoch != _operationEpoch) return;

    // 2. Baca metadata dan credential (tangani corrupt/read error tanpa crash)
    SessionMetadata? metadata;
    try {
      metadata = await metadataStore.read();
    } catch (_) {
      if (currentEpoch != _operationEpoch) return;
      state = const AuthSignedOut(cleanupStatus: LocalCleanupStatus.failed);
      return;
    }

    if (currentEpoch != _operationEpoch) return;

    StoredCredential? credential;
    try {
      credential = await tokenStorage.read();
    } catch (_) {
      if (currentEpoch != _operationEpoch) return;
      state = const AuthSignedOut(cleanupStatus: LocalCleanupStatus.failed);
      return;
    }

    if (currentEpoch != _operationEpoch) return;

    // 3. Truth Table Cases:
    // Case 1 & 2: Metadata absent
    if (metadata == null) {
      if (credential == null) {
        // Row 1: absent metadata, absent credential -> first run -> signed-out clean
        state = const AuthSignedOut(cleanupStatus: LocalCleanupStatus.clean);
        return;
      } else {
        // Row 2: absent metadata, orphan credential -> force clear + tulis clean -> clean bila keduanya sukses; selain itu failed
        final success = await _forceClearAndWriteClean(
          tokenStorage,
          metadataStore,
        );
        if (currentEpoch != _operationEpoch) return;
        state = AuthSignedOut(
          cleanupStatus: success
              ? LocalCleanupStatus.clean
              : LocalCleanupStatus.failed,
        );
        return;
      }
    }

    // Case 3, 4, 5, 6: metadata.restoreAllowed == false
    if (!metadata.restoreAllowed) {
      if (metadata.cleanupStatus != LocalCleanupStatus.clean) {
        // Row 4: restoreAllowed false, pending/failed -> jangan restore -> failed
        state = const AuthSignedOut(cleanupStatus: LocalCleanupStatus.failed);
        return;
      }
      if (credential == null) {
        // Row 5: restoreAllowed false, clean, absent credential -> normal -> clean
        state = const AuthSignedOut(cleanupStatus: LocalCleanupStatus.clean);
        return;
      } else {
        // Row 6: restoreAllowed false, clean, ada credential -> force clear + tulis clean -> clean bila keduanya sukses; selain itu failed
        final success = await _forceClearAndWriteClean(
          tokenStorage,
          metadataStore,
        );
        if (currentEpoch != _operationEpoch) return;
        state = AuthSignedOut(
          cleanupStatus: success
              ? LocalCleanupStatus.clean
              : LocalCleanupStatus.failed,
        );
        return;
      }
    }

    // Case 7, 8, 9, 10: metadata.restoreAllowed == true
    if (credential == null) {
      // Row 7: restoreAllowed true, clean, absent credential -> tulis clean -> clean bila sukses; selain itu failed
      var writeCleanOk = false;
      try {
        await _enqueueMutation(
          () => metadataStore.write(const SessionMetadata.signedOutClean()),
        );
        writeCleanOk = true;
      } catch (_) {
        writeCleanOk = false;
      }
      if (currentEpoch != _operationEpoch) return;
      state = AuthSignedOut(
        cleanupStatus: writeCleanOk
            ? LocalCleanupStatus.clean
            : LocalCleanupStatus.failed,
      );
      return;
    }

    // Credential ada. Periksa apakah credentialId cocok dengan expectedCredentialId
    if (credential.credentialId != metadata.expectedCredentialId) {
      // Row 8: restoreAllowed true, clean, credential ID mismatch -> jangan hapus foreign credential -> failed
      state = const AuthSignedOut(cleanupStatus: LocalCleanupStatus.failed);
      return;
    }

    // Credential ID cocok -> panggil repo.restoreSession(credential.refreshToken)
    final AuthResult result;
    try {
      result = await repo.restoreSession(credential.refreshToken);
    } on TimeoutException {
      if (currentEpoch != _operationEpoch) return;
      state = const AuthTemporarilyUnavailable(
        reason: 'Koneksi ke server autentikasi terputus. Silakan coba lagi.',
      );
      return;
    } catch (_) {
      if (currentEpoch != _operationEpoch) return;
      state = const AuthTemporarilyUnavailable(
        reason: 'Gagal menghubungkan ke layanan autentikasi.',
      );
      return;
    }

    if (currentEpoch != _operationEpoch) return;

    if (result.isSuccess && result.user != null) {
      // Row 9a: restore success -> signed-in
      _sessionGeneration++;
      state = AuthSignedIn(user: result.user!, generation: _sessionGeneration);
      return;
    }

    if (result.failure is NetworkTimeoutFailure) {
      // Row 9b: network timeout failure -> temporarilyUnavailable
      state = AuthTemporarilyUnavailable(reason: result.failure!.message);
      return;
    }

    // Row 10: restore expired -> clearIfOwnedBy + tulis clean -> clean bila keduanya sukses, selain itu failed
    var cleanupSuccess = false;
    try {
      await _enqueueMutation(() async {
        final cleared = await tokenStorage.clearIfOwnedBy(
          credential!.credentialId,
        );
        if (!cleared) {
          throw const StorageException('clearIfOwnedBy returned false');
        }
        await metadataStore.write(const SessionMetadata.signedOutClean());
      });
      cleanupSuccess = true;
    } catch (_) {
      cleanupSuccess = false;
    }

    if (currentEpoch != _operationEpoch) return;
    state = AuthSignedOut(
      cleanupStatus: cleanupSuccess
          ? LocalCleanupStatus.clean
          : LocalCleanupStatus.failed,
    );
  }

  Future<bool> _forceClearAndWriteClean(
    AuthTokenStorage tokenStorage,
    SessionMetadataStore metadataStore,
  ) async {
    try {
      await _enqueueMutation(() async {
        await tokenStorage.forceClearForRecovery();
        await metadataStore.write(const SessionMetadata.signedOutClean());
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> login({
    required String skNumber,
    required String password,
    required bool staySignedIn,
    required bool rememberSk,
  }) async {
    _operationEpoch++;
    final currentEpoch = _operationEpoch;
    state = const AuthSigningIn();

    final repo = ref.read(authRepositoryProvider);
    try {
      final result = await repo.login(
        skNumber: skNumber,
        password: password,
        staySignedIn: staySignedIn,
      );
      if (currentEpoch != _operationEpoch) return false;

      if (result.isSuccess && result.user != null) {
        final tokenStorage = (repo is DemoAuthRepository)
            ? repo.tokenStorage
            : ref.read(authTokenStorageProvider);
        if (staySignedIn && result.refreshToken != null) {
          await tokenStorage.saveRefreshToken(result.refreshToken!);
          if (currentEpoch != _operationEpoch) {
            await tokenStorage.clear();
            return false;
          }
        } else {
          await tokenStorage.clear();
          if (currentEpoch != _operationEpoch) return false;
        }

        final skStore = (repo is DemoAuthRepository && repo.skStore != null)
            ? repo.skStore!
            : ref.read(rememberedSkStoreProvider);
        if (rememberSk) {
          await skStore.saveSk(skNumber);
        } else {
          await skStore.clear();
        }
        if (currentEpoch != _operationEpoch) return false;

        _sessionGeneration++;
        state = AuthSignedIn(
          user: result.user!,
          generation: _sessionGeneration,
        );
        return true;
      } else {
        final errorMsg =
            result.failure?.message ?? 'Nomor SK atau kata sandi tidak sesuai.';
        if (result.failure is NetworkTimeoutFailure) {
          state = AuthTemporarilyUnavailable(reason: errorMsg);
        } else {
          state = AuthSignedOut(errorMessage: errorMsg);
        }
        return false;
      }
    } catch (_) {
      if (currentEpoch != _operationEpoch) return false;
      state = const AuthTemporarilyUnavailable(
        reason: 'Terjadi gangguan sistem. Silakan coba lagi.',
      );
      return false;
    }
  }

  Future<void> retrySession() async {
    await bootstrap();
  }

  Future<void> logout() async {
    _operationEpoch++;
    final currentEpoch = _operationEpoch;
    _sessionGeneration++;
    state = const AuthSigningOut();

    try {
      final repo = ref.read(authRepositoryProvider);
      await repo.logout();
    } finally {
      if (currentEpoch == _operationEpoch) {
        state = const AuthSignedOut();
      }
    }
  }
}
