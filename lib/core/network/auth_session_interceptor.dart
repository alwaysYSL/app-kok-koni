// ignore_for_file: prefer_initializing_formals

import 'dart:convert';

import 'package:dio/dio.dart';

import 'auth_session_tokens.dart';

/// Interceptor that inspects responses for HTTP 401 Unauthorized or fatal
/// HTTP 403 Forbidden errors that indicate an expired or invalid session.
class AuthSessionInterceptor extends Interceptor {
  AuthSessionInterceptor({
    AuthSessionTokens? tokens,
    int Function()? currentRevisionProvider,
    void Function({String? errorCode, String? serverMessage})?
    onUnauthorizedSession,
  }) : _tokens = tokens,
       _currentRevisionProvider = currentRevisionProvider,
       _onUnauthorizedSession = onUnauthorizedSession;

  static const String sessionRevisionExtraKey = 'auth_session_revision';

  final AuthSessionTokens? _tokens;
  final int Function()? _currentRevisionProvider;
  void Function({String? errorCode, String? serverMessage})?
  _onUnauthorizedSession;

  int? get _currentRevision =>
      _currentRevisionProvider?.call() ?? _tokens?.revision;

  /// Error codes that indicate the member or session is permanently invalid.
  static const sessionEndingCodes = {
    'MEMBER_NOT_FOUND',
    'MEMBER_INACTIVE',
    'NOT_KOK',
  };

  /// Attaches or updates the callback invoked when an unauthorized session is detected.
  void attachUnauthorizedHandler(
    void Function({String? errorCode, String? serverMessage}) handler,
  ) {
    _onUnauthorizedSession = handler;
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final requestRevision = err.requestOptions.extra[sessionRevisionExtraKey];
    final currentRevision = _currentRevision;

    if (requestRevision == null ||
        currentRevision == null ||
        requestRevision != currentRevision) {
      handler.next(err);
      return;
    }

    final status = err.response?.statusCode;
    final body = _extractJson(err.response?.data);
    final serverMessage = body?['message']?.toString();
    final errorCode = body?['error_code']?.toString();

    if (status == 401) {
      _onUnauthorizedSession?.call(
        errorCode: errorCode ?? 'INVALID_TOKEN',
        serverMessage: serverMessage,
      );
      handler.next(err);
      return;
    }

    if (status == 403) {
      if (errorCode != null && sessionEndingCodes.contains(errorCode)) {
        _onUnauthorizedSession?.call(
          errorCode: errorCode,
          serverMessage: serverMessage,
        );
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
