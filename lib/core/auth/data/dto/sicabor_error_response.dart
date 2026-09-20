import 'package:flutter/foundation.dart';

@immutable
final class SicaborErrorResponse {
  const SicaborErrorResponse({
    required this.success,
    required this.message,
    this.errorCode,
  });

  final bool success;
  final String message;
  final String? errorCode;

  factory SicaborErrorResponse.fromJson(Map<String, dynamic> json) {
    return SicaborErrorResponse(
      success: json['success'] as bool? ?? false,
      message: json['message']?.toString() ?? '',
      errorCode: json['error_code'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'success': success,
    'message': message,
    'error_code': errorCode,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SicaborErrorResponse &&
          runtimeType == other.runtimeType &&
          success == other.success &&
          message == other.message &&
          errorCode == other.errorCode;

  @override
  int get hashCode => Object.hash(success, message, errorCode);
}
