import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../composition/app_composition.dart';
import '../../preferences.dart';
import '../data/auth_repository.dart';
import '../data/auth_token_storage.dart';
import '../data/demo_auth_repository.dart';
import '../data/remembered_sk_store.dart';
import '../data/session_metadata_store.dart';
import '../domain/auth_failure.dart';
import '../domain/auth_state.dart';
import '../domain/credential_id_generator.dart';
import '../domain/user_principal.dart';

export '../data/auth_repository.dart' show RemoteRevocationStatus;

String get _defaultEnvName =>
    DeploymentProfile.fromEnvironment().environment.name;

final authTokenStorageProvider = Provider<AuthTokenStorage>((ref) {
  final composition = ref.watch(appCompositionProvider);
  if (composition != null) {
    return composition.authTokenStorage;
  }
  return SecureAuthTokenStorage(
    store: const FlutterSecureKeyValStore(
      FlutterSecureStorage(
        aOptions: AndroidOptions(encryptedSharedPreferences: true),
        iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
      ),
    ),
    key: 'kok.auth.v2.$_defaultEnvName.credential',
  );
});

final sessionMetadataStoreProvider = Provider<SessionMetadataStore>((ref) {
  final composition = ref.watch(appCompositionProvider);
  if (composition != null) {
    return composition.sessionMetadataStore;
  }
  try {
    final prefs = ref.watch(preferencesProvider);
    return SharedPrefsSessionMetadataStore(
      prefs: prefs,
      key: 'kok.auth.v2.$_defaultEnvName.metadata',
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
  final composition = ref.watch(appCompositionProvider);
  if (composition != null) {
    return composition.rememberedSkStore;
  }
  try {
    final prefs = ref.watch(preferencesProvider);
    return RememberedSkStore(
      prefs: prefs,
      key: 'kok.auth.v2.$_defaultEnvName.remembered_sk',
    );
  } catch (_) {
    return RememberedSkStore(key: 'kok.auth.v2.$_defaultEnvName.remembered_sk');
  }
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final composition = ref.watch(appCompositionProvider);
  if (composition != null) {
    return composition.authRepository;
  }
  return DemoAuthRepository();
});

final credentialIdGeneratorProvider = Provider<CredentialIdGenerator>((ref) {
  final composition = ref.watch(appCompositionProvider);
  if (composition != null) {
    return composition.credentialIdGenerator;
  }
  return UuidCredentialIdGenerator();
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

enum SignInPhase { idle, executing, waitingForCommit, committing }

enum AuthCommandStatus { success, failed, rejected, cancelled }

enum AuthCommandRejection { cleanupRequired, operationInProgress, invalidState }

enum AuthCommandFailure {
  invalidPersistentCredential,
  credentialIdGenerationFailed,
}

final class AuthCommandResult {
  const AuthCommandResult({
    required this.status,
    this.rejection,
    this.internalFailure,
    this.errorMessage,
  });

  final AuthCommandStatus status;
  final AuthCommandRejection? rejection;
  final AuthCommandFailure? internalFailure;
  final String? errorMessage;

  bool get isSuccess => status == AuthCommandStatus.success;
  bool get isRejected => status == AuthCommandStatus.rejected;

  @override
  String toString() =>
      'AuthCommandResult(status: $status, rejection: $rejection, internalFailure: $internalFailure, errorMessage: $errorMessage)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AuthCommandResult &&
          other.status == status &&
          other.rejection == rejection &&
          other.internalFailure == internalFailure &&
          other.errorMessage == errorMessage;

  @override
  int get hashCode =>
      Object.hash(status, rejection, internalFailure, errorMessage);
}

final class LogoutResult {
  const LogoutResult({
    required this.localSessionClosed,
    required this.credentialCleared,
    required this.metadataClean,
    required this.remoteRevocationStatus,
  });
  final bool localSessionClosed;
  final bool credentialCleared;
  final bool metadataClean;
  final RemoteRevocationStatus remoteRevocationStatus;

  @override
  String toString() =>
      'LogoutResult(localSessionClosed: $localSessionClosed, credentialCleared: $credentialCleared, metadataClean: $metadataClean, remoteRevocationStatus: $remoteRevocationStatus)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LogoutResult &&
          other.localSessionClosed == localSessionClosed &&
          other.credentialCleared == credentialCleared &&
          other.metadataClean == metadataClean &&
          other.remoteRevocationStatus == remoteRevocationStatus;

  @override
  int get hashCode => Object.hash(
    localSessionClosed,
    credentialCleared,
    metadataClean,
    remoteRevocationStatus,
  );
}

final class SignInCancelledException implements Exception {
  const SignInCancelledException();

  @override
  String toString() => 'SignInCancelledException()';
}

final class _LogoutFlight {
  const _LogoutFlight({
    required this.sourceGeneration,
    required this.cleanupGeneration,
    required this.future,
  });

  final int sourceGeneration;
  final int cleanupGeneration;
  final Future<LogoutResult> future;
}

class AuthController extends Notifier<AuthState> {
  int _sessionGeneration = 0;
  int _operationEpoch = 0;
  Future<void>? _activeBootstrapFuture;
  Future<void> _mutationTail = Future<void>.value();

  SignInPhase _signInPhase = SignInPhase.idle;
  Completer<void>? _cancelTrigger;
  RemoteSessionHandle? _activeRemoteHandle;
  String? _activeCredentialId;
  _LogoutFlight? _activeLogoutFlight;

  SignInPhase get signInPhase => _signInPhase;
  int get sessionGeneration => _sessionGeneration;
  int get currentGeneration => _sessionGeneration;
  int get operationEpoch => _operationEpoch;

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
      _activeRemoteHandle = result.remoteHandle ?? result.sessionHandle;
      _activeCredentialId = credential.credentialId;
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

  Future<AuthCommandResult> login({
    required String skNumber,
    required String password,
    required bool staySignedIn,
    required bool rememberSk,
  }) async {
    // 1. Reserve:
    // Validasi state: hanya boleh login dari AuthSignedOut dengan cleanupStatus == LocalCleanupStatus.clean.
    // Jika sedang login atau state lain, tolak dengan AuthCommandStatus.rejected.
    if (state is AuthSignedOut &&
        (state as AuthSignedOut).cleanupStatus != LocalCleanupStatus.clean) {
      return const AuthCommandResult(
        status: AuthCommandStatus.rejected,
        rejection: AuthCommandRejection.cleanupRequired,
        errorMessage: 'Pembersihan sesi lokal sebelumnya belum selesai.',
      );
    }
    if (state is! AuthSignedOut || _signInPhase != SignInPhase.idle) {
      return const AuthCommandResult(
        status: AuthCommandStatus.rejected,
        rejection: AuthCommandRejection.invalidState,
        errorMessage: 'Operasi login tidak valid pada state saat ini.',
      );
    }

    _operationEpoch++;
    final currentEpoch = _operationEpoch;
    _signInPhase = SignInPhase.executing;
    state = const AuthSigningIn();

    final cancelTrigger = Completer<void>();
    _cancelTrigger = cancelTrigger;

    final repo = ref.read(authRepositoryProvider);
    final tokenStorage = ref.read(authTokenStorageProvider);
    final metadataStore = ref.read(sessionMetadataStoreProvider);
    final credentialIdGenerator = ref.read(credentialIdGeneratorProvider);
    final skStore = ref.read(rememberedSkStoreProvider);

    // 2. Execute di luar queue:
    final AuthResult result;
    try {
      result = await Future.any<AuthResult>([
        repo.login(
          skNumber: skNumber,
          password: password,
          staySignedIn: staySignedIn,
        ),
        cancelTrigger.future.then<AuthResult>(
          (_) => throw const SignInCancelledException(),
        ),
      ]);
    } on SignInCancelledException {
      if (currentEpoch == _operationEpoch) {
        _signInPhase = SignInPhase.idle;
      }
      return const AuthCommandResult(
        status: AuthCommandStatus.cancelled,
        errorMessage: 'Login dibatalkan.',
      );
    } catch (_) {
      if (currentEpoch != _operationEpoch) {
        return const AuthCommandResult(
          status: AuthCommandStatus.cancelled,
          errorMessage: 'Login dibatalkan.',
        );
      }
      _signInPhase = SignInPhase.idle;
      state = const AuthTemporarilyUnavailable(
        reason: 'Terjadi gangguan sistem. Silakan coba lagi.',
      );
      return const AuthCommandResult(
        status: AuthCommandStatus.failed,
        errorMessage: 'Terjadi gangguan sistem. Silakan coba lagi.',
      );
    }

    if (currentEpoch != _operationEpoch) {
      return const AuthCommandResult(
        status: AuthCommandStatus.cancelled,
        errorMessage: 'Login dibatalkan.',
      );
    }

    if (!result.isSuccess || result.user == null) {
      _signInPhase = SignInPhase.idle;
      final errorMsg =
          result.failure?.message ?? 'Nomor SK atau kata sandi tidak sesuai.';
      if (result.failure is NetworkTimeoutFailure) {
        state = AuthTemporarilyUnavailable(reason: errorMsg);
      } else {
        state = AuthSignedOut(
          cleanupStatus: LocalCleanupStatus.clean,
          errorMessage: errorMsg,
        );
      }
      return AuthCommandResult(
        status: AuthCommandStatus.failed,
        errorMessage: errorMsg,
      );
    }

    // 3. Waiting for Commit:
    _signInPhase = SignInPhase.waitingForCommit;

    // 4. Commit di dalam mutation queue:
    return await _enqueueMutation<AuthCommandResult>(() async {
      try {
        if (currentEpoch != _operationEpoch) {
          return const AuthCommandResult(
            status: AuthCommandStatus.cancelled,
            errorMessage: 'Login dibatalkan.',
          );
        }

        _signInPhase = SignInPhase.committing;

        if (!staySignedIn) {
          try {
            await metadataStore.write(const SessionMetadata.signedOutClean());
          } catch (_) {
            state = const AuthTemporarilyUnavailable(
              reason: 'Gagal mengamankan status sesi.',
            );
            return const AuthCommandResult(
              status: AuthCommandStatus.failed,
              errorMessage: 'Gagal mengamankan status sesi.',
            );
          }
          _activeRemoteHandle = result.remoteHandle ?? result.sessionHandle;
          _activeCredentialId = null;
          _sessionGeneration++;
          state = AuthSignedIn(
            user: result.user!,
            generation: _sessionGeneration,
          );

          try {
            if (rememberSk) {
              await skStore.saveSk(skNumber);
            } else {
              await skStore.clear();
            }
          } catch (_) {
            // Kegagalan preferensi non-kritis tidak membatalkan atau merusak sesi yang sudah sah
          }

          return const AuthCommandResult(status: AuthCommandStatus.success);
        }

        // Persisten:
        // Validate all persistent material before the first local mutation.
        final refreshToken = result.refreshToken;
        if (refreshToken == null ||
            refreshToken.trim().isEmpty ||
            refreshToken.length > 8192) {
          return _failPersistentCredential(
            AuthCommandFailure.invalidPersistentCredential,
          );
        }

        final String credId;
        try {
          credId = credentialIdGenerator.generate();
        } catch (_) {
          return _failPersistentCredential(
            AuthCommandFailure.credentialIdGenerationFailed,
          );
        }

        final StoredCredential credential;
        try {
          credential = StoredCredential(
            credentialId: credId,
            refreshToken: refreshToken,
          );
        } on CorruptCredentialException {
          return _failPersistentCredential(
            AuthCommandFailure.invalidPersistentCredential,
          );
        }

        // FT-01: Tulis metadata pending
        try {
          await metadataStore.write(const SessionMetadata.cleanupPending());
        } catch (_) {
          state = const AuthTemporarilyUnavailable(
            reason: 'Gagal mengamankan status sesi.',
          );
          return const AuthCommandResult(
            status: AuthCommandStatus.failed,
            errorMessage: 'Gagal mengamankan status sesi.',
          );
        }

        // FT-02: Tulis credential ke tokenStorage
        try {
          await tokenStorage.write(credential);
        } catch (_) {
          await _tryWriteFailedMetadata(metadataStore);
          state = const AuthSignedOut(cleanupStatus: LocalCleanupStatus.failed);
          return const AuthCommandResult(
            status: AuthCommandStatus.failed,
            errorMessage: 'Gagal menyimpan kredensial sesi.',
          );
        }

        // FT-03: Cek epoch setelah write credential
        if (currentEpoch != _operationEpoch) {
          final clearOk = await _tryClearIfOwnedBy(tokenStorage, credId);
          if (clearOk) {
            final cleanOk = await _tryWriteCleanMetadata(metadataStore);
            if (!cleanOk) {
              await _tryWriteFailedMetadata(metadataStore);
            }
          } else {
            await _tryWriteFailedMetadata(metadataStore);
          }
          return const AuthCommandResult(
            status: AuthCommandStatus.cancelled,
            errorMessage: 'Login dibatalkan.',
          );
        }

        // FT-04: Tulis metadata restore-enabled
        try {
          await metadataStore.write(SessionMetadata.restoreEnabled(credId));
        } catch (_) {
          final rollbackOk = await _tryClearIfOwnedBy(tokenStorage, credId);
          var cleanOk = false;
          if (rollbackOk) {
            cleanOk = await _tryWriteCleanMetadata(metadataStore);
          }
          if (!cleanOk) {
            await _tryWriteFailedMetadata(metadataStore);
          }
          state = AuthSignedOut(
            cleanupStatus: cleanOk
                ? LocalCleanupStatus.clean
                : LocalCleanupStatus.failed,
          );
          return const AuthCommandResult(
            status: AuthCommandStatus.failed,
            errorMessage: 'Gagal menyimpan metadata sesi.',
          );
        }

        _activeRemoteHandle = result.remoteHandle ?? result.sessionHandle;
        _activeCredentialId = credId;
        _sessionGeneration++;
        state = AuthSignedIn(
          user: result.user!,
          generation: _sessionGeneration,
        );

        try {
          if (rememberSk) {
            await skStore.saveSk(skNumber);
          } else {
            await skStore.clear();
          }
        } catch (_) {
          // Kegagalan preferensi non-kritis tidak membatalkan atau merusak sesi yang sudah sah
        }

        return const AuthCommandResult(status: AuthCommandStatus.success);
      } finally {
        if (currentEpoch == _operationEpoch) {
          _signInPhase = SignInPhase.idle;
        }
      }
    });
  }

  AuthCommandResult _failPersistentCredential(AuthCommandFailure failure) {
    state = const AuthSignedOut(cleanupStatus: LocalCleanupStatus.clean);
    return AuthCommandResult(
      status: AuthCommandStatus.failed,
      internalFailure: failure,
      errorMessage: 'Kredensial sesi persisten tidak valid.',
    );
  }

  Future<AuthCommandResult> cancelSignIn() async {
    if (_signInPhase == SignInPhase.executing ||
        _signInPhase == SignInPhase.waitingForCommit) {
      _operationEpoch++;
      if (_cancelTrigger != null && !_cancelTrigger!.isCompleted) {
        _cancelTrigger!.complete();
      }
      _signInPhase = SignInPhase.idle;
      state = const AuthSignedOut(cleanupStatus: LocalCleanupStatus.clean);
      return const AuthCommandResult(status: AuthCommandStatus.success);
    }

    if (_signInPhase == SignInPhase.committing) {
      return const AuthCommandResult(
        status: AuthCommandStatus.rejected,
        rejection: AuthCommandRejection.operationInProgress,
        errorMessage: 'Proses sign in sedang melakukan commit data.',
      );
    }

    return const AuthCommandResult(
      status: AuthCommandStatus.rejected,
      rejection: AuthCommandRejection.invalidState,
      errorMessage: 'Tidak ada proses login aktif.',
    );
  }

  Future<void> retrySession() async {
    await bootstrap();
  }

  Future<LogoutResult> logout({
    Duration revocationTimeout = const Duration(seconds: 5),
  }) {
    final active = _activeLogoutFlight;
    if (active != null &&
        (active.sourceGeneration == _sessionGeneration ||
            (active.cleanupGeneration == _sessionGeneration &&
                (state is AuthSigningOut || state is AuthSignedOut)))) {
      return active.future;
    }

    if (state is AuthSignedOut &&
        (state as AuthSignedOut).cleanupStatus != LocalCleanupStatus.clean) {
      return Future.value(
        const LogoutResult(
          localSessionClosed: true,
          credentialCleared: false,
          metadataClean: false,
          remoteRevocationStatus: RemoteRevocationStatus.notApplicable,
        ),
      );
    }

    final completion = Completer<LogoutResult>();
    final flight = _LogoutFlight(
      sourceGeneration: _sessionGeneration,
      cleanupGeneration: _sessionGeneration + 1,
      future: completion.future,
    );
    // Publish before AuthSigningOut can notify a reentrant logout caller.
    _activeLogoutFlight = flight;
    unawaited(
      _runLogout(revocationTimeout: revocationTimeout).then<void>(
        (result) {
          if (identical(_activeLogoutFlight, flight)) {
            _activeLogoutFlight = null;
          }
          completion.complete(result);
        },
        onError: (Object error, StackTrace stackTrace) {
          if (identical(_activeLogoutFlight, flight)) {
            _activeLogoutFlight = null;
          }
          completion.completeError(error, stackTrace);
        },
      ),
    );
    return flight.future;
  }

  Future<LogoutResult> _runLogout({
    Duration revocationTimeout = const Duration(seconds: 5),
  }) async {
    final compositionTimeout = ref
        .read(appCompositionProvider)
        ?.revocationTimeout;
    final effectiveTimeout = (revocationTimeout != const Duration(seconds: 5))
        ? revocationTimeout
        : (compositionTimeout ?? revocationTimeout);

    final remoteHandle = _activeRemoteHandle;
    final activeCredentialId = _activeCredentialId;

    _operationEpoch++;
    final currentEpoch = _operationEpoch;
    _sessionGeneration++;

    _activeRemoteHandle = null;
    _activeCredentialId = null;
    _signInPhase = SignInPhase.idle;
    if (_cancelTrigger != null && !_cancelTrigger!.isCompleted) {
      _cancelTrigger!.complete();
    }

    state = const AuthSigningOut();

    final repo = ref.read(authRepositoryProvider);
    final tokenStorage = ref.read(authTokenStorageProvider);
    final metadataStore = ref.read(sessionMetadataStoreProvider);

    final localCleanup =
        await _enqueueMutation<({bool credentialCleared, bool metadataClean})>(
          () async {
            try {
              await metadataStore.write(const SessionMetadata.cleanupPending());
            } catch (_) {
              // Jangan hentikan proses bila pending write gagal
            }

            var credClearSuccess = false;
            if (activeCredentialId != null) {
              credClearSuccess = await _tryClearIfOwnedBy(
                tokenStorage,
                activeCredentialId,
              );
            } else {
              // A missing in-memory owner is not proof that storage is empty.
              // Read it while holding the mutation queue before allowing clean
              // metadata; a foreign or unreadable credential keeps cleanup
              // failed and is left for explicit recovery.
              try {
                credClearSuccess = await tokenStorage.read() == null;
              } catch (_) {
                credClearSuccess = false;
              }
            }

            var metadataCleanSuccess = false;
            if (credClearSuccess) {
              metadataCleanSuccess = await _tryWriteCleanMetadata(
                metadataStore,
              );
            }

            if (!metadataCleanSuccess) {
              await _tryWriteFailedMetadata(metadataStore);
            }

            return (
              credentialCleared: credClearSuccess,
              metadataClean: metadataCleanSuccess,
            );
          },
        );

    if (currentEpoch == _operationEpoch) {
      final isClean =
          localCleanup.credentialCleared && localCleanup.metadataClean;
      state = AuthSignedOut(
        cleanupStatus: isClean
            ? LocalCleanupStatus.clean
            : LocalCleanupStatus.failed,
      );
    }

    RemoteRevocationResult revocationResult = const RemoteRevocationResult(
      RemoteRevocationStatus.notApplicable,
    );

    if (remoteHandle != null) {
      try {
        revocationResult = await repo
            .revokeSession(remoteHandle)
            .timeout(effectiveTimeout);
      } on TimeoutException {
        revocationResult = const RemoteRevocationResult(
          RemoteRevocationStatus.failed,
          'Remote revocation timeout',
        );
      } catch (e) {
        revocationResult = RemoteRevocationResult(
          RemoteRevocationStatus.failed,
          e.toString(),
        );
      }
    }

    return LogoutResult(
      localSessionClosed: true,
      credentialCleared: localCleanup.credentialCleared,
      metadataClean: localCleanup.metadataClean,
      remoteRevocationStatus: revocationResult.status,
    );
  }

  Future<bool> retryLocalCredentialCleanup() async {
    if (state is! AuthSignedOut ||
        (state as AuthSignedOut).cleanupStatus != LocalCleanupStatus.failed) {
      return false;
    }

    _operationEpoch++;
    final currentEpoch = _operationEpoch;
    state = const AuthSignedOut(cleanupStatus: LocalCleanupStatus.pending);

    final tokenStorage = ref.read(authTokenStorageProvider);
    final metadataStore = ref.read(sessionMetadataStoreProvider);

    return await _enqueueMutation<bool>(() async {
      var forceClearOk = false;
      try {
        await tokenStorage.forceClearForRecovery();
        forceClearOk = true;
      } catch (_) {
        forceClearOk = false;
      }

      var metadataCleanOk = false;
      if (forceClearOk) {
        try {
          await metadataStore.write(const SessionMetadata.signedOutClean());
          metadataCleanOk = true;
        } catch (_) {
          metadataCleanOk = false;
        }
      }

      if (!metadataCleanOk) {
        await _tryWriteFailedMetadata(metadataStore);
      }

      final success = forceClearOk && metadataCleanOk;
      if (currentEpoch == _operationEpoch) {
        state = AuthSignedOut(
          cleanupStatus: success
              ? LocalCleanupStatus.clean
              : LocalCleanupStatus.failed,
        );
      }
      return success;
    });
  }

  Future<bool> _tryClearIfOwnedBy(
    AuthTokenStorage storage,
    String credId,
  ) async {
    try {
      return await storage.clearIfOwnedBy(credId);
    } catch (_) {
      return false;
    }
  }

  Future<bool> _tryWriteCleanMetadata(SessionMetadataStore store) async {
    try {
      await store.write(const SessionMetadata.signedOutClean());
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _tryWriteFailedMetadata(SessionMetadataStore store) async {
    try {
      await store.write(const SessionMetadata.cleanupFailed());
      return true;
    } catch (_) {
      return false;
    }
  }
}
