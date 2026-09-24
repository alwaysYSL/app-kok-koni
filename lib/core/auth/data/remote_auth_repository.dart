import 'package:dio/dio.dart';

import '../../config/deployment_profile.dart';
import '../../network/json_response_guard.dart';
import '../domain/auth_failure.dart';
import '../domain/user_principal.dart';
import 'auth_repository.dart';
import 'dto/sicabor_login_response.dart';
import 'dto/sicabor_profile_response.dart';
import 'mapper/sicabor_auth_mapper.dart';

final class RemoteAuthRepository implements AuthRepository {
  RemoteAuthRepository({required this.dio, required this.profile});

  final Dio dio;
  final DeploymentProfile profile;

  String get _authUrl {
    final baseUri = Uri.parse(profile.apiBaseUrl);
    return baseUri.replace(path: '/api/auth').toString();
  }

  String get _profileUrl {
    final base = profile.apiBaseUrl.replaceAll(RegExp(r'/+$'), '');
    return '$base/profile';
  }

  @override
  Future<AuthResult> login({
    required String username,
    required String password,
    required bool staySignedIn,
  }) async {
    final Response<dynamic> loginResponse;
    try {
      loginResponse = await dio.post<dynamic>(
        _authUrl,
        data: {'username': username, 'password': password},
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          responseType: ResponseType.json,
        ),
      );
    } on DioException catch (e) {
      return _handleLoginDioException(e);
    } catch (_) {
      return const AuthResult.failed(InvalidCredentialsFailure());
    }

    final loginData = loginResponse.data;
    if (!isJsonContentType(loginResponse.headers) ||
        loginData is! Map<String, dynamic>) {
      return const AuthResult.failed(
        InvalidCredentialsFailure('Format respons login tidak valid.'),
      );
    }

    final loginRes = SicaborLoginResponse.fromJson(loginData);
    final token = loginRes.token;
    if (!loginRes.status || token == null || token.trim().isEmpty) {
      final msg = loginRes.message.isNotEmpty
          ? loginRes.message
          : 'Username atau kata sandi tidak sesuai.';
      return AuthResult.failed(InvalidCredentialsFailure(msg));
    }

    if (loginRes.data?.type != 'admin_kok') {
      return const AuthResult.failed(AccountNotKokFailure());
    }

    final Response<dynamic> profileResponse;
    try {
      profileResponse = await dio.get<dynamic>(
        _profileUrl,
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
          responseType: ResponseType.json,
        ),
      );
    } on DioException catch (e) {
      return _handleProfileDioException(e, isLoginPhase: true);
    } catch (_) {
      return const AuthResult.failed(ProfileFetchFailedFailure());
    }

    final profileData = profileResponse.data;
    if (!isJsonContentType(profileResponse.headers) ||
        profileData is! Map<String, dynamic> ||
        profileData['scope'] is! Map ||
        profileData['data'] is! Map ||
        (profileData['data'] as Map)['member'] is! Map ||
        (profileData['data'] as Map)['summary'] is! Map) {
      return const AuthResult.failed(ProfileFetchFailedFailure());
    }

    final SicaborProfileResponse profileRes;
    try {
      profileRes = SicaborProfileResponse.fromJson(profileData);
    } catch (_) {
      return const AuthResult.failed(ProfileFetchFailedFailure());
    }

    if (!profileRes.success) {
      return AuthResult.failed(
        ProfileFetchFailedFailure(
          profileRes.message.isNotEmpty
              ? profileRes.message
              : 'Gagal memuat data profil akun dari server.',
        ),
      );
    }

    final validationError = _validateProfile(profileRes);
    if (validationError != null) {
      return validationError;
    }

    final UserPrincipal principal;
    try {
      principal = SicaborAuthMapper.mapProfileToUserPrincipal(
        loginData: loginRes.data!,
        profileResponse: profileRes,
      );
    } catch (_) {
      return const AuthResult.failed(ProfileFetchFailedFailure());
    }

    return AuthResult.success(
      user: principal,
      accessToken: token,
      sessionToken: staySignedIn ? token : null,
    );
  }

  @override
  Future<AuthResult> restoreSession(String sessionToken) async {
    if (sessionToken.trim().isEmpty) {
      return const AuthResult.failed(SessionExpiredFailure());
    }

    final Response<dynamic> profileResponse;
    try {
      profileResponse = await dio.get<dynamic>(
        _profileUrl,
        options: Options(
          headers: {'Authorization': 'Bearer $sessionToken'},
          responseType: ResponseType.json,
        ),
      );
    } on DioException catch (e) {
      return _handleProfileDioException(e, isLoginPhase: false);
    } catch (_) {
      return const AuthResult.failed(ProfileFetchFailedFailure());
    }

    final profileData = profileResponse.data;
    if (!isJsonContentType(profileResponse.headers) ||
        profileData is! Map<String, dynamic> ||
        profileData['scope'] is! Map ||
        profileData['data'] is! Map ||
        (profileData['data'] as Map)['member'] is! Map ||
        (profileData['data'] as Map)['summary'] is! Map) {
      return const AuthResult.failed(ProfileFetchFailedFailure());
    }

    final SicaborProfileResponse profileRes;
    try {
      profileRes = SicaborProfileResponse.fromJson(profileData);
    } catch (_) {
      return const AuthResult.failed(ProfileFetchFailedFailure());
    }

    if (!profileRes.success) {
      return AuthResult.failed(
        ProfileFetchFailedFailure(
          profileRes.message.isNotEmpty
              ? profileRes.message
              : 'Gagal memuat data profil akun dari server.',
        ),
      );
    }

    final validationError = _validateProfile(profileRes);
    if (validationError != null) {
      return validationError;
    }

    final UserPrincipal principal;
    try {
      principal = SicaborAuthMapper.mapProfileOnlyToUserPrincipal(
        profileResponse: profileRes,
      );
    } catch (_) {
      return const AuthResult.failed(ProfileFetchFailedFailure());
    }

    return AuthResult.success(
      user: principal,
      accessToken: sessionToken,
      sessionToken: sessionToken,
    );
  }

  AuthResult? _validateProfile(SicaborProfileResponse profileRes) {
    final member = profileRes.data.member;
    final scope = profileRes.scope;

    if (member.type.trim() != 'admin_kok') {
      return const AuthResult.failed(AccountNotKokFailure());
    }

    if (member.status != 1) {
      return const AuthResult.failed(AccountInactiveFailure());
    }

    if (member.id <= 0 ||
        member.username.trim().isEmpty ||
        member.name.trim().isEmpty ||
        scope.subdistrictId <= 0 ||
        scope.subdistrictName.trim().isEmpty) {
      return const AuthResult.failed(ProfileFetchFailedFailure());
    }

    return null;
  }

  @override
  Future<RemoteRevocationResult> revokeSession(
    RemoteSessionHandle session,
  ) async {
    return const RemoteRevocationResult(RemoteRevocationStatus.notApplicable);
  }

  AuthResult _handleLoginDioException(DioException e) {
    if (_isNetworkOrTimeout(e)) {
      return const AuthResult.failed(NetworkTimeoutFailure());
    }

    final statusCode = e.response?.statusCode;
    final data = e.response?.data;
    final Map<String, dynamic>? errorJson = data is Map<String, dynamic>
        ? data
        : null;

    final message = errorJson?['message']?.toString();
    final errorCode = errorJson?['error_code']?.toString();

    if (statusCode == 401) {
      return AuthResult.failed(
        message != null && message.isNotEmpty
            ? InvalidCredentialsFailure(message)
            : const InvalidCredentialsFailure(),
      );
    }

    if (statusCode == 403) {
      return AuthResult.failed(
        SicaborAuthMapper.mapErrorCodeToFailure(
          errorCode: errorCode,
          message: message,
        ),
      );
    }

    return AuthResult.failed(
      message != null && message.isNotEmpty
          ? InvalidCredentialsFailure(message)
          : const InvalidCredentialsFailure(),
    );
  }

  AuthResult _handleProfileDioException(
    DioException e, {
    required bool isLoginPhase,
  }) {
    if (_isNetworkOrTimeout(e)) {
      return const AuthResult.failed(NetworkTimeoutFailure());
    }

    final statusCode = e.response?.statusCode;
    final data = e.response?.data;
    final Map<String, dynamic>? errorJson = data is Map<String, dynamic>
        ? data
        : null;

    final message = errorJson?['message']?.toString();
    final errorCode = errorJson?['error_code']?.toString();

    if (statusCode == 401) {
      if (isLoginPhase) {
        return const AuthResult.failed(ProfileFetchFailedFailure());
      } else {
        return const AuthResult.failed(SessionExpiredFailure());
      }
    }

    if (statusCode == 403) {
      return AuthResult.failed(
        SicaborAuthMapper.mapErrorCodeToFailure(
          errorCode: errorCode,
          message: message,
        ),
      );
    }

    return AuthResult.failed(
      message != null && message.isNotEmpty
          ? ProfileFetchFailedFailure(message)
          : const ProfileFetchFailedFailure(),
    );
  }

  bool _isNetworkOrTimeout(DioException e) {
    return e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.unknown;
  }
}
