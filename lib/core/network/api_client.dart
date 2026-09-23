import 'dart:convert';

import 'package:dio/dio.dart';

import '../config/deployment_profile.dart';
import '../../data/request_cancellation.dart';
import 'api_exceptions.dart';
import 'auth_session_interceptor.dart';
import 'auth_session_tokens.dart';
import 'json_response_guard.dart';

final class ApiClient {
  ApiClient({
    required DeploymentProfile profile,
    required AuthSessionTokens tokens,
    AuthSessionInterceptor? sessionInterceptor,
    Dio? dio,
  }) : _tokens = tokens, // ignore: prefer_initializing_formals
       sessionInterceptor =
           sessionInterceptor ??
           AuthSessionInterceptor(
             tokens: tokens,
             currentRevisionProvider: () => tokens.revision,
           ),
       _dio = dio ?? Dio(_optionsFor(profile)) {
    profile.validate();
    if (!_dio.interceptors.contains(this.sessionInterceptor)) {
      _dio.interceptors.add(this.sessionInterceptor);
    }
  }

  final Dio _dio;
  final AuthSessionTokens _tokens;
  final AuthSessionInterceptor sessionInterceptor;

  void attachUnauthorizedHandler(
    void Function({String? errorCode, String? serverMessage}) handler,
  ) {
    sessionInterceptor.attachUnauthorizedHandler(handler);
  }

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
      final response = await _dio.request<dynamic>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: _optionsWithAuth(options, method: method, skipAuth: skipAuth),
        cancelToken: cancelToken,
      );
      cancellation?.throwIfCancelled();
      requireJsonContentType(response.headers);
      return Response<T>(
        data: response.data as T,
        headers: response.headers,
        requestOptions: response.requestOptions,
        isRedirect: response.isRedirect,
        statusCode: response.statusCode,
        statusMessage: response.statusMessage,
        redirects: response.redirects,
        extra: response.extra,
      );
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
    final extra = <String, dynamic>{...?options.extra};
    if (!skipAuth) {
      final accessToken = _tokens.accessToken;
      if (accessToken != null && accessToken.isNotEmpty) {
        headers['Authorization'] = 'Bearer $accessToken';
        extra[AuthSessionInterceptor.sessionRevisionExtraKey] =
            _tokens.revision;
      }
    } else {
      headers.remove('Authorization');
    }
    return options.copyWith(method: method, headers: headers, extra: extra);
  }

  ApiException _mapException(DioException error) {
    final response = error.response;
    final status = response?.statusCode;
    final headers = response?.headers;
    final jsonMap = _extractJson(response?.data);
    final errorCode = jsonMap?['error_code']?.toString();
    final serverMessage = jsonMap?['message']?.toString();
    final fallbackMessage = error.message;

    if (status == 401) {
      final message = serverMessage ?? fallbackMessage ?? 'Sesi tidak sah';
      return UnauthorizedException(message, errorCode, serverMessage);
    }
    if (headers != null && !isJsonContentType(headers)) {
      return const ApiConfigurationException();
    }
    if (error.error is FormatException || error.error is TypeError) {
      return const ApiConfigurationException();
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
