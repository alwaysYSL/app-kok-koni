// ignore_for_file: prefer_initializing_formals

import 'dart:convert';

import 'package:dio/dio.dart';

/// Interceptor that inspects responses for HTTP 401 Unauthorized or fatal
/// HTTP 403 Forbidden errors that indicate an expired or invalid session.
class AuthSessionInterceptor extends Interceptor {
  AuthSessionInterceptor({
    void Function({String? errorCode})? onUnauthorizedSession,
  }) : _onUnauthorizedSession = onUnauthorizedSession;

  void Function({String? errorCode})? _onUnauthorizedSession;

  /// Error codes that indicate the member or session is permanently invalid.
  static const sessionEndingCodes = {
    'MEMBER_NOT_FOUND',
    'MEMBER_INACTIVE',
    'NOT_KOK',
  };

  /// Attaches or updates the callback invoked when an unauthorized session is detected.
  void attachUnauthorizedHandler(void Function({String? errorCode}) handler) {
    _onUnauthorizedSession = handler;
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final status = err.response?.statusCode;

    if (status == 401) {
      _onUnauthorizedSession?.call();
      handler.next(err);
      return;
    }

    if (status == 403) {
      final body = _extractJson(err.response?.data);
      if (body != null && body['error_code'] != null) {
        final errorCode = body['error_code']?.toString();
        if (errorCode != null && sessionEndingCodes.contains(errorCode)) {
          _onUnauthorizedSession?.call(errorCode: errorCode);
        }
      }
      handler.next(err);
      return;
    }

    handler.next(err);
  }

  static Map<String, dynamic>? _extractJson(Object? data) {
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
