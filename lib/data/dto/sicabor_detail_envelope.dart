import 'package:flutter/foundation.dart';
import '../../core/auth/data/dto/sicabor_profile_response.dart';

@immutable
final class SicaborDetailEnvelope<T> {
  const SicaborDetailEnvelope({
    required this.success,
    required this.message,
    required this.scope,
    required this.data,
  });

  final bool success;
  final String message;
  final SicaborScope scope;
  final T data;

  factory SicaborDetailEnvelope.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic> json) itemParser,
  ) {
    final rawData = json['data'];
    final dataMap = rawData is Map<String, dynamic>
        ? rawData
        : rawData is Map
        ? Map<String, dynamic>.from(rawData)
        : const <String, dynamic>{};

    final rawScope = json['scope'];
    final scopeMap = rawScope is Map<String, dynamic>
        ? rawScope
        : rawScope is Map
        ? Map<String, dynamic>.from(rawScope)
        : const <String, dynamic>{};

    return SicaborDetailEnvelope<T>(
      success: json['success'] as bool? ?? false,
      message: json['message']?.toString() ?? '',
      scope: SicaborScope.fromJson(scopeMap),
      data: itemParser(dataMap),
    );
  }

  Map<String, dynamic> toJson([
    Map<String, dynamic> Function(T item)? itemSerializer,
  ]) => {
    'success': success,
    'message': message,
    'scope': scope.toJson(),
    'data': itemSerializer != null ? itemSerializer(data) : data,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SicaborDetailEnvelope<T> &&
          runtimeType == other.runtimeType &&
          success == other.success &&
          message == other.message &&
          scope == other.scope &&
          data == other.data;

  @override
  int get hashCode => Object.hash(success, message, scope, data);
}
