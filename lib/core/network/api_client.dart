import 'dart:convert';

import 'package:dio/dio.dart';

import '../config/deployment_profile.dart';
import '../../data/request_cancellation.dart';
import 'api_exceptions.dart';
import 'auth_session_tokens.dart';

final class ApiClient {
  ApiClient({
    required DeploymentProfile profile,
    required AuthSessionTokens tokens,
    Dio? dio,
  }) : _tokens = tokens, // ignore: prefer_initializing_formals
       _dio = dio ?? Dio(_optionsFor(profile)) {
    profile.validate();
  }

  final Dio _dio;
  final AuthSessionTokens _tokens;

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
  }) async {
    cancellation?.throwIfCancelled();

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

  ApiException _mapException(DioException error) {
    final status = error.response?.statusCode;
    final jsonMap = _extractJson(error.response?.data);
    final errorCode = jsonMap?['error_code']?.toString();
    final serverMessage = jsonMap?['message']?.toString();
    final fallbackMessage = error.message;

    if (status == 401) {
      final message = serverMessage ?? fallbackMessage ?? 'Sesi tidak sah';
      return UnauthorizedException(message, errorCode, serverMessage);
    }
    if (status == 403) {
      final message = serverMessage ?? fallbackMessage ?? 'Akses ditolak';
      return ForbiddenException(message, errorCode, serverMessage);
    }
    if (status == 404) {
      final message =
          serverMessage ?? fallbackMessage ?? 'Data tidak ditemukan';
      return NotFoundException(message);
    }
    if (status != null && status >= 400 && status < 500) {
      final message =
          serverMessage ?? fallbackMessage ?? 'Permintaan tidak valid';
      return BadRequestException(message, statusCode: status);
    }
    if (status != null && status >= 500) {
      final message =
          serverMessage ?? fallbackMessage ?? 'Server gagal memproses request';
      return ServerErrorException(message, statusCode: status);
    }
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.receiveTimeout) {
      return ApiTimeoutException(fallbackMessage ?? 'Request timeout');
    }
    if (error.type == DioExceptionType.cancel) {
      return NetworkOfflineException(fallbackMessage ?? 'Request dibatalkan');
    }
    if (error.type == DioExceptionType.connectionError) {
      return NetworkOfflineException(fallbackMessage ?? 'Tidak ada koneksi');
    }
    return NetworkOfflineException(fallbackMessage ?? 'Tidak ada koneksi');
  }

  Map<String, dynamic>? _extractJson(Object? data) {
    if (data is Map<String, dynamic>) {
      return data;
    }
    if (data is Map) {
      return data.cast<String, dynamic>();
    }
    if (data is String && data.isNotEmpty) {
      try {
        final decoded = jsonDecode(data);
        if (decoded is Map<String, dynamic>) {
          return decoded;
        }
        if (decoded is Map) {
          return decoded.cast<String, dynamic>();
        }
      } catch (_) {
        return null;
      }
    }
    return null;
  }
}
