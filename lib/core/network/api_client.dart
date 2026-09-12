import 'package:dio/dio.dart';

import '../auth/data/auth_repository.dart';
import '../config/deployment_profile.dart';
import '../../data/request_cancellation.dart';
import 'api_exceptions.dart';
import 'auth_session_tokens.dart';

typedef RefreshSession = Future<AuthResult> Function(String refreshToken);

final class ApiClient {
  ApiClient({
    required DeploymentProfile profile,
    required this._tokens,
    required this._refreshSession,
    Dio? dio,
  }) : _dio = dio ?? Dio(_optionsFor(profile)) {
    profile.validate();
  }

  final Dio _dio;
  final AuthSessionTokens _tokens;
  final RefreshSession _refreshSession;
  Future<String>? _refreshFlight;

  static BaseOptions _optionsFor(DeploymentProfile profile) {
    profile.validate();
    return BaseOptions(
      baseUrl: profile.apiBaseUrl,
      connectTimeout: profile.connectTimeout,
      receiveTimeout: profile.receiveTimeout,
    );
  }

  Future<Response<T>> request<T>(
    String path, {
    required String method,
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    RequestCancellation? cancellation,
    bool skipAuth = false,
    bool retryAttempt = false,
  }) async {
    cancellation?.throwIfCancelled();
    final requestAccessToken = _tokens.accessToken;

    CancelToken? cancelToken;
    if (cancellation != null) {
      final token = CancelToken();
      cancelToken = token;
      if (cancellation.isCancelled) {
        token.cancel(cancellation.reason);
      } else {
        cancellation.whenCancelled.then((reason) {
          if (!token.isCancelled) {
            token.cancel(reason);
          }
        });
      }
    }

    try {
      final response = await _dio.request<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: _optionsWithAuth(options, method: method, skipAuth: skipAuth),
        cancelToken: cancelToken,
      );
      cancellation?.throwIfCancelled();
      return response;
    } on DioException catch (error) {
      if ((cancellation?.isCancelled ?? false) ||
          (error.type == DioExceptionType.cancel && cancellation != null)) {
        throw RequestCancelledException(cancellation?.reason);
      }
      cancellation?.throwIfCancelled();
      if (error.response?.statusCode == 401 && !skipAuth && !retryAttempt) {
        if (_tokens.accessToken != null &&
            _tokens.accessToken != requestAccessToken) {
          return request<T>(
            path,
            method: method,
            data: data,
            queryParameters: queryParameters,
            options: options,
            cancellation: cancellation,
            retryAttempt: true,
          );
        }

        await _refreshAccessToken(cancellation: cancellation);
        return request<T>(
          path,
          method: method,
          data: data,
          queryParameters: queryParameters,
          options: options,
          cancellation: cancellation,
          retryAttempt: true,
        );
      }
      throw _mapException(error);
    }
  }

  Options _optionsWithAuth(
    Options? source, {
    required String method,
    required bool skipAuth,
  }) {
    final options = source ?? Options();
    final headers = <String, dynamic>{...?options.headers};
    if (!skipAuth) {
      final accessToken = _tokens.accessToken;
      if (accessToken != null && accessToken.isNotEmpty) {
        headers['Authorization'] = 'Bearer $accessToken';
      }
    } else {
      headers.remove('Authorization');
    }
    return options.copyWith(method: method, headers: headers);
  }

  Future<String> _refreshAccessToken({RequestCancellation? cancellation}) {
    final active = _refreshFlight;
    if (active != null) return active;

    cancellation?.throwIfCancelled();
    final refreshToken = _tokens.refreshToken;
    if (refreshToken == null || refreshToken.isEmpty) {
      return Future<String>.error(const UnauthorizedException());
    }

    final future = () async {
      final result = await _refreshSession(refreshToken);
      cancellation?.throwIfCancelled();
      final accessToken = result.accessToken;
      if (!result.isSuccess || accessToken == null || accessToken.isEmpty) {
        throw const UnauthorizedException('Refresh sesi gagal');
      }
      _tokens.replace(
        accessToken: accessToken,
        refreshToken: result.refreshToken ?? refreshToken,
      );
      return accessToken;
    }();
    _refreshFlight = future;
    return future.whenComplete(() {
      if (identical(_refreshFlight, future)) _refreshFlight = null;
    });
  }

  ApiException _mapException(DioException error) {
    final status = error.response?.statusCode;
    final message = error.message;
    if (status == 401) {
      return UnauthorizedException(message ?? 'Sesi tidak sah');
    }
    if (status == 403) return ForbiddenException(message ?? 'Akses ditolak');
    if (status == 404) {
      return NotFoundException(message ?? 'Data tidak ditemukan');
    }
    if (status != null && status >= 400 && status < 500) {
      return BadRequestException(
        message ?? 'Permintaan tidak valid',
        statusCode: status,
      );
    }
    if (status != null && status >= 500) {
      return ServerErrorException(
        message ?? 'Server gagal memproses request',
        statusCode: status,
      );
    }
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.receiveTimeout) {
      return ApiTimeoutException(message ?? 'Request timeout');
    }
    if (error.type == DioExceptionType.cancel) {
      return NetworkOfflineException(message ?? 'Request dibatalkan');
    }
    return NetworkOfflineException(message ?? 'Tidak ada koneksi');
  }
}
