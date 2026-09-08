import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../session.dart';
import '../data/auth_repository.dart';
import '../data/auth_token_storage.dart';
import '../data/demo_auth_repository.dart';
import '../data/remembered_sk_store.dart';
import '../domain/auth_failure.dart';
import '../domain/auth_state.dart';
import '../domain/user_principal.dart';

final authTokenStorageProvider = Provider<AuthTokenStorage>((ref) {
  return SecureAuthTokenStorage();
});

final rememberedSkStoreProvider = Provider<RememberedSkStore>((ref) {
  final prefs = ref.watch(preferencesProvider);
  return RememberedSkStore(prefs);
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return DemoAuthRepository(
    tokenStorage: ref.watch(authTokenStorageProvider),
    skStore: ref.watch(rememberedSkStoreProvider),
  );
});

final authControllerProvider =
    NotifierProvider<AuthController, AuthState>(AuthController.new);

final currentUserProvider = Provider<UserPrincipal?>((ref) {
  final state = ref.watch(authControllerProvider);
  if (state is AuthSignedIn) {
    return state.user;
  }
  return null;
});

class AuthController extends Notifier<AuthState> {
  int _sessionGeneration = 0;
  int get currentGeneration => _sessionGeneration;

  @override
  AuthState build() {
    return const AuthBootstrapping();
  }

  Future<void> bootstrap() async {
    state = const AuthBootstrapping();
    final repo = ref.read(authRepositoryProvider);
    try {
      final result = await repo.restoreSession();
      if (result.isSuccess && result.user != null) {
        _sessionGeneration++;
        state = AuthSignedIn(
          user: result.user!,
          generation: _sessionGeneration,
          accessToken: result.accessToken,
        );
      } else {
        state = const AuthSignedOut();
      }
    } catch (_) {
      state = const AuthTemporarilyUnavailable(
        reason: 'Gagal menghubungkan ke layanan autentikasi.',
      );
    }
  }

  Future<bool> login({
    required String skNumber,
    required String password,
    required bool staySignedIn,
    required bool rememberSk,
  }) async {
    state = const AuthSigningIn();
    final repo = ref.read(authRepositoryProvider);

    try {
      final result = await repo.login(
        skNumber: skNumber,
        password: password,
        staySignedIn: staySignedIn,
      );

      if (result.isSuccess && result.user != null) {
        final skStore = ref.read(rememberedSkStoreProvider);
        if (rememberSk) {
          await skStore.saveSk(skNumber);
        } else {
          await skStore.clear();
        }

        _sessionGeneration++;
        state = AuthSignedIn(
          user: result.user!,
          generation: _sessionGeneration,
          accessToken: result.accessToken,
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
    _sessionGeneration++;
    state = const AuthSigningOut();
    try {
      final repo = ref.read(authRepositoryProvider);
      await repo.logout();
    } finally {
      state = const AuthSignedOut();
    }
  }
}
