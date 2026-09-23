import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kok_app/core/auth/data/auth_repository.dart';
import 'package:kok_app/core/auth/data/auth_token_storage.dart';
import 'package:kok_app/core/auth/data/remembered_username_store.dart';
import 'package:kok_app/core/auth/data/session_metadata_store.dart';
import 'package:kok_app/core/auth/domain/auth_failure.dart';
import 'package:kok_app/core/auth/domain/auth_state.dart';
import 'package:kok_app/core/auth/domain/credential_id_generator.dart';
import 'package:kok_app/core/auth/domain/user_principal.dart';
import 'package:kok_app/core/auth/presentation/auth_controller.dart';
import 'package:kok_app/core/composition/app_composition.dart';
import 'package:kok_app/core/config/deployment_profile.dart';
import 'package:kok_app/core/network/api_client.dart';
import 'package:kok_app/core/network/api_exceptions.dart';
import 'package:kok_app/core/network/auth_session_tokens.dart';
import 'package:kok_app/data/demo_kok_repository.dart';
import 'package:kok_app/data/services/demo/demo_athlete_service.dart';
import 'package:kok_app/data/services/demo/demo_cabor_service.dart';
import 'package:kok_app/data/services/demo/demo_club_service.dart';
import 'package:kok_app/data/services/demo/demo_profile_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

final class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.handler);

  Future<ResponseBody> Function(RequestOptions options) handler;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) => handler(options);

  @override
  void close({bool force = false}) {}
}

class _InMemoryAuthTokenStorage implements AuthTokenStorage {
  StoredCredential? _credential;

  @override
  Future<StoredCredential?> read() async => _credential;

  @override
  Future<void> write(StoredCredential credential) async {
    _credential = credential;
  }

  @override
  Future<bool> clearIfOwnedBy(String credentialId) async {
    if (_credential != null && _credential!.credentialId == credentialId) {
      _credential = null;
      return true;
    }
    return false;
  }

  @override
  Future<void> forceClearForRecovery() async {
    _credential = null;
  }

  @override
  Future<void> migrateLegacyStorage() async {}
}

class _TestAuthRepository implements AuthRepository {
  @override
  Future<AuthResult> login({
    required String username,
    required String password,
    required bool staySignedIn,
  }) async {
    return AuthResult.success(
      user: UserPrincipal(
        id: 'usr-1',
        username: 'DEMO-001',
        fullName: 'Test User',
        roleTitle: 'Koordinator',
        scope: const AccessScope(
          type: AccessScopeType.district,
          id: '1728',
          name: 'Garut Kota',
        ),
        permissions: {'athlete:read', 'club:read'},
      ),
      accessToken: 'test-access-token',
      sessionToken: staySignedIn ? 'test-session-token' : null,
      sessionHandle: RemoteSessionHandle('remote-handle-1'),
    );
  }

  @override
  Future<AuthResult> restoreSession(String sessionToken) async {
    return const AuthResult.failed(SessionExpiredFailure());
  }

  @override
  Future<RemoteRevocationResult> revokeSession(
    RemoteSessionHandle session,
  ) async {
    return const RemoteRevocationResult(RemoteRevocationStatus.revoked);
  }
}

void main() {
  const testProfile = DeploymentProfile(
    environment: AppEnv.staging,
    authMode: AuthMode.remote,
    dataMode: DataMode.remote,
    apiBaseUrl: 'https://api.example.test',
  );

  late SharedPreferences prefs;
  late _InMemoryAuthTokenStorage tokenStorage;
  late SharedPrefsSessionMetadataStore metadataStore;
  late RememberedUsernameStore usernameStore;
  late _TestAuthRepository authRepo;
  late AuthSessionTokens tokens;
  late _FakeAdapter fakeAdapter;
  late ApiClient apiClient;
  late AppComposition composition;
  late ProviderContainer container;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();

    tokenStorage = _InMemoryAuthTokenStorage();
    metadataStore = SharedPrefsSessionMetadataStore(
      prefs: prefs,
      key: 'test_metadata',
    );
    usernameStore = RememberedUsernameStore(
      prefs: prefs,
      key: 'test_remembered',
    );
    authRepo = _TestAuthRepository();
    tokens = AuthSessionTokens();

    fakeAdapter = _FakeAdapter((options) async {
      return ResponseBody.fromString(
        '{"data": []}',
        200,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        },
      );
    });

    final dio = Dio()..httpClientAdapter = fakeAdapter;

    apiClient = ApiClient(profile: testProfile, tokens: tokens, dio: dio);

    final demoRepo = DemoKokRepository(simulateLatency: false);

    composition = AppComposition(
      profile: testProfile,
      authTokenStorage: tokenStorage,
      sessionMetadataStore: metadataStore,
      rememberedUsernameStore: usernameStore,
      authRepository: authRepo,
      kokRepository: demoRepo,
      profileService: DemoProfileService(
        demoRepo: demoRepo,
        currentScopeProvider: () => const AccessScope(
          type: AccessScopeType.district,
          id: '1728',
          name: 'Garut Kota',
        ),
      ),
      caborService: DemoCaborService(
        demoRepo: demoRepo,
        currentScopeProvider: () => const AccessScope(
          type: AccessScopeType.district,
          id: '1728',
          name: 'Garut Kota',
        ),
      ),
      athleteService: DemoAthleteService(
        demoRepo: demoRepo,
        currentScopeProvider: () => const AccessScope(
          type: AccessScopeType.district,
          id: '1728',
          name: 'Garut Kota',
        ),
      ),
      clubService: DemoClubService(
        demoRepo: demoRepo,
        currentScopeProvider: () => const AccessScope(
          type: AccessScopeType.district,
          id: '1728',
          name: 'Garut Kota',
        ),
      ),
      credentialIdGenerator: const FixedCredentialIdGenerator('test-cred-id'),
      sessionTokens: tokens,
      apiClient: apiClient,
    );

    container = ProviderContainer(
      overrides: [appCompositionProvider.overrideWithValue(composition)],
    );
  });

  tearDown(() {
    container.dispose();
  });

  test(
    'End-to-End: 401 Unauthorized during API request automatically expires session and clears tokens',
    () async {
      final controller = container.read(authControllerProvider.notifier);

      // 1. Initial bootstrap
      await controller.bootstrap();
      expect(container.read(authControllerProvider), isA<AuthSignedOut>());

      // 2. Log in
      final loginResult = await controller.login(
        username: 'DEMO-001',
        password: 'password123',
        staySignedIn: true,
        rememberUsername: false,
      );
      expect(loginResult.isSuccess, isTrue);
      expect(container.read(authControllerProvider), isA<AuthSignedIn>());
      expect(tokens.accessToken, 'test-access-token');
      expect(await tokenStorage.read(), isNotNull);

      // 3. Configure mock adapter to respond with 401 Unauthorized
      fakeAdapter.handler = (options) async {
        return ResponseBody.fromString(
          '{"message":"Token expired or invalid"}',
          401,
          headers: {
            Headers.contentTypeHeader: ['application/json'],
          },
        );
      };

      // 4. Trigger an API call through ApiClient
      await expectLater(
        apiClient.request<Map<String, dynamic>>('/athletes', method: 'GET'),
        throwsA(isA<UnauthorizedException>()),
      );

      // 5. Allow asynchronous logout handlers to complete
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // 6. Verify full session expiration
      final state = container.read(authControllerProvider);
      expect(state, isA<AuthSignedOut>());
      expect((state as AuthSignedOut).cleanupStatus, LocalCleanupStatus.clean);

      // Verify token bridge is cleared
      expect(tokens.accessToken, isNull);
      expect(tokens.sessionToken, isNull);

      // Verify persistent token storage is cleared
      expect(await tokenStorage.read(), isNull);

      // Verify metadata is signed out clean
      final meta = await metadataStore.read();
      expect(meta?.cleanupStatus, LocalCleanupStatus.clean);
    },
  );

  test(
    'End-to-End: 403 Forbidden with MEMBER_NOT_FOUND automatically expires session',
    () async {
      final controller = container.read(authControllerProvider.notifier);

      await controller.bootstrap();
      await controller.login(
        username: 'DEMO-001',
        password: 'password123',
        staySignedIn: true,
        rememberUsername: false,
      );
      expect(container.read(authControllerProvider), isA<AuthSignedIn>());

      // Configure adapter to return 403 with session-ending code
      fakeAdapter.handler = (options) async {
        return ResponseBody.fromString(
          '{"error_code":"MEMBER_NOT_FOUND","message":"Pengurus tidak ditemukan"}',
          403,
          headers: {
            Headers.contentTypeHeader: ['application/json'],
          },
        );
      };

      await expectLater(
        apiClient.request<Map<String, dynamic>>('/clubs', method: 'GET'),
        throwsA(isA<ForbiddenException>()),
      );

      await Future<void>.delayed(const Duration(milliseconds: 50));

      final state = container.read(authControllerProvider);
      expect(state, isA<AuthSignedOut>());
      expect(tokens.accessToken, isNull);
      expect(await tokenStorage.read(), isNull);
    },
  );

  test(
    'End-to-End: 403 Forbidden with NO_SUBDISTRICT does NOT expire session',
    () async {
      final controller = container.read(authControllerProvider.notifier);

      await controller.bootstrap();
      await controller.login(
        username: 'DEMO-001',
        password: 'password123',
        staySignedIn: true,
        rememberUsername: false,
      );
      expect(container.read(authControllerProvider), isA<AuthSignedIn>());

      // Configure adapter to return 403 with non-session-ending code
      fakeAdapter.handler = (options) async {
        return ResponseBody.fromString(
          '{"error_code":"NO_SUBDISTRICT","message":"Kecamatan tidak ada"}',
          403,
          headers: {
            Headers.contentTypeHeader: ['application/json'],
          },
        );
      };

      await expectLater(
        apiClient.request<Map<String, dynamic>>('/sports', method: 'GET'),
        throwsA(isA<ForbiddenException>()),
      );

      await Future<void>.delayed(const Duration(milliseconds: 50));

      // State remains signed in
      final state = container.read(authControllerProvider);
      expect(state, isA<AuthSignedIn>());
      expect(tokens.accessToken, 'test-access-token');
      expect(await tokenStorage.read(), isNotNull);
    },
  );

  test('End-to-End: 500 Server Error does NOT expire session', () async {
    final controller = container.read(authControllerProvider.notifier);

    await controller.bootstrap();
    await controller.login(
      username: 'DEMO-001',
      password: 'password123',
      staySignedIn: true,
      rememberUsername: false,
    );
    expect(container.read(authControllerProvider), isA<AuthSignedIn>());

    fakeAdapter.handler = (options) async {
      return ResponseBody.fromString(
        '{"message":"Internal server error"}',
        500,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        },
      );
    };

    await expectLater(
      apiClient.request<Map<String, dynamic>>('/reports', method: 'GET'),
      throwsA(isA<ServerErrorException>()),
    );

    await Future<void>.delayed(const Duration(milliseconds: 50));

    final state = container.read(authControllerProvider);
    expect(state, isA<AuthSignedIn>());
    expect(tokens.accessToken, 'test-access-token');
  });

  test(
    'Stale session race condition: Delayed 401 from previous session does NOT expire active new session',
    () async {
      final controller = container.read(authControllerProvider.notifier);

      // 1. Initial bootstrap and login user A
      await controller.bootstrap();
      await controller.login(
        username: 'USER-A',
        password: 'password123',
        staySignedIn: true,
        rememberUsername: false,
      );
      expect(container.read(authControllerProvider), isA<AuthSignedIn>());
      expect(tokens.accessToken, 'test-access-token');

      // 2. User A initiates a delayed request (we control completion with Completer)
      final delayedCompleter = Completer<ResponseBody>();
      fakeAdapter.handler = (options) => delayedCompleter.future;

      final requestAFuture = apiClient.request<Map<String, dynamic>>(
        '/athletes',
        method: 'GET',
      );

      // 3. User A logs out
      await controller.logout();
      expect(container.read(authControllerProvider), isA<AuthSignedOut>());

      // 4. User B logs in
      await controller.login(
        username: 'USER-B',
        password: 'password123',
        staySignedIn: true,
        rememberUsername: false,
      );
      expect(container.read(authControllerProvider), isA<AuthSignedIn>());
      expect(tokens.accessToken, 'test-access-token');

      // 5. Request A now completes with 401 Unauthorized
      delayedCompleter.complete(
        ResponseBody.fromString(
          '{"message":"User A token expired"}',
          401,
          headers: {
            Headers.contentTypeHeader: ['application/json'],
          },
        ),
      );

      // Request A should throw UnauthorizedException
      await expectLater(requestAFuture, throwsA(isA<UnauthorizedException>()));

      await Future<void>.delayed(const Duration(milliseconds: 50));

      // 6. User B MUST remain signed in because request A belongs to old revision!
      final state = container.read(authControllerProvider);
      expect(state, isA<AuthSignedIn>());
      expect(tokens.accessToken, 'test-access-token');
      expect(await tokenStorage.read(), isNotNull);
    },
  );

  test(
    'Stale session race condition: Delayed 403 MEMBER_INACTIVE from previous session does NOT expire active new session',
    () async {
      final controller = container.read(authControllerProvider.notifier);

      await controller.bootstrap();
      await controller.login(
        username: 'USER-A',
        password: 'password123',
        staySignedIn: true,
        rememberUsername: false,
      );
      expect(container.read(authControllerProvider), isA<AuthSignedIn>());

      final delayedCompleter = Completer<ResponseBody>();
      fakeAdapter.handler = (options) => delayedCompleter.future;

      final requestAFuture = apiClient.request<Map<String, dynamic>>(
        '/cabor',
        method: 'GET',
      );

      await controller.logout();
      expect(container.read(authControllerProvider), isA<AuthSignedOut>());

      await controller.login(
        username: 'USER-B',
        password: 'password123',
        staySignedIn: true,
        rememberUsername: false,
      );
      expect(container.read(authControllerProvider), isA<AuthSignedIn>());

      delayedCompleter.complete(
        ResponseBody.fromString(
          '{"error_code":"MEMBER_INACTIVE","message":"User A is inactive"}',
          403,
          headers: {
            Headers.contentTypeHeader: ['application/json'],
          },
        ),
      );

      await expectLater(requestAFuture, throwsA(isA<ForbiddenException>()));

      await Future<void>.delayed(const Duration(milliseconds: 50));

      final state = container.read(authControllerProvider);
      expect(state, isA<AuthSignedIn>());
      expect(tokens.accessToken, 'test-access-token');
      expect(await tokenStorage.read(), isNotNull);
    },
  );

  test(
    'Simultaneous 401s for active session only execute a single logout flight',
    () async {
      final controller = container.read(authControllerProvider.notifier);

      await controller.bootstrap();
      await controller.login(
        username: 'DEMO-001',
        password: 'password123',
        staySignedIn: true,
        rememberUsername: false,
      );
      expect(container.read(authControllerProvider), isA<AuthSignedIn>());

      fakeAdapter.handler = (options) async {
        return ResponseBody.fromString(
          '{"message":"Token revoked"}',
          401,
          headers: {
            Headers.contentTypeHeader: ['application/json'],
          },
        );
      };

      // Fire 2 simultaneous requests
      final future1 = apiClient.request<Map<String, dynamic>>(
        '/req1',
        method: 'GET',
      );
      final future2 = apiClient.request<Map<String, dynamic>>(
        '/req2',
        method: 'GET',
      );

      await expectLater(future1, throwsA(isA<UnauthorizedException>()));
      await expectLater(future2, throwsA(isA<UnauthorizedException>()));

      await Future<void>.delayed(const Duration(milliseconds: 50));

      final state = container.read(authControllerProvider);
      expect(state, isA<AuthSignedOut>());
      expect((state as AuthSignedOut).cleanupStatus, LocalCleanupStatus.clean);
    },
  );

  test('404 and network timeout do NOT trigger session expiration', () async {
    final controller = container.read(authControllerProvider.notifier);

    await controller.bootstrap();
    await controller.login(
      username: 'DEMO-001',
      password: 'password123',
      staySignedIn: true,
      rememberUsername: false,
    );
    expect(container.read(authControllerProvider), isA<AuthSignedIn>());

    // 404 Not Found
    fakeAdapter.handler = (options) async {
      return ResponseBody.fromString(
        '{"message":"Not found"}',
        404,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        },
      );
    };

    await expectLater(
      apiClient.request<Map<String, dynamic>>('/not-found', method: 'GET'),
      throwsA(isA<NotFoundException>()),
    );

    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(container.read(authControllerProvider), isA<AuthSignedIn>());

    // Timeout
    fakeAdapter.handler = (options) async {
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.connectionTimeout,
        message: 'Connection timed out',
      );
    };

    await expectLater(
      apiClient.request<Map<String, dynamic>>('/timeout', method: 'GET'),
      throwsA(isA<ApiTimeoutException>()),
    );

    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(container.read(authControllerProvider), isA<AuthSignedIn>());
  });
}

class FixedCredentialIdGenerator implements CredentialIdGenerator {
  const FixedCredentialIdGenerator(this.value);

  final String value;

  @override
  String generate() => value;
}
