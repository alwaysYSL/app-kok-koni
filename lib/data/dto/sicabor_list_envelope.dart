import 'package:flutter/foundation.dart';
import '../../core/auth/data/dto/sicabor_profile_response.dart';

@immutable
final class SicaborPaginationMeta {
  const SicaborPaginationMeta({
    this.limit = 25,
    this.offset = 0,
    this.total = 0,
    this.extra = const {},
  });

  final int limit;
  final int offset;
  final int total;
  final Map<String, dynamic> extra;

  factory SicaborPaginationMeta.fromJson(Map<String, dynamic> json) {
    final extra = <String, dynamic>{};
    json.forEach((key, value) {
      if (key != 'limit' && key != 'offset' && key != 'total') {
        extra[key] = value;
      }
    });

    return SicaborPaginationMeta(
      limit: _asInt(json['limit'], fallback: 25),
      offset: _asInt(json['offset'], fallback: 0),
      total: _asInt(json['total'], fallback: 0),
      extra: extra,
    );
  }

  Map<String, dynamic> toJson() => {
    'limit': limit,
    'offset': offset,
    'total': total,
    ...extra,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SicaborPaginationMeta &&
          runtimeType == other.runtimeType &&
          limit == other.limit &&
          offset == other.offset &&
          total == other.total &&
          mapEquals(extra, other.extra);

  @override
  int get hashCode => Object.hash(
    limit,
    offset,
    total,
    Object.hashAll(extra.entries.map((e) => Object.hash(e.key, e.value))),
  );
}

@immutable
final class SicaborListEnvelope<T> {
  const SicaborListEnvelope({
    required this.success,
    required this.message,
    required this.scope,
    required this.meta,
    required this.data,
  });

  final bool success;
  final String message;
  final SicaborScope scope;
  final SicaborPaginationMeta meta;
  final List<T> data;

  factory SicaborListEnvelope.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic> json) itemParser,
  ) {
    final rawData = json['data'];
    final items = <T>[];
    if (rawData is List) {
      for (final item in rawData) {
        if (item is Map<String, dynamic>) {
          items.add(itemParser(item));
        } else if (item is Map) {
          items.add(itemParser(Map<String, dynamic>.from(item)));
        }
      }
    }

    final rawScope = json['scope'];
    final scopeMap = rawScope is Map<String, dynamic>
        ? rawScope
        : rawScope is Map
        ? Map<String, dynamic>.from(rawScope)
        : const <String, dynamic>{};

    final rawMeta = json['meta'];
    final metaMap = rawMeta is Map<String, dynamic>
        ? rawMeta
        : rawMeta is Map
        ? Map<String, dynamic>.from(rawMeta)
        : const <String, dynamic>{};

    return SicaborListEnvelope<T>(
      success: json['success'] as bool? ?? false,
      message: json['message']?.toString() ?? '',
      scope: SicaborScope.fromJson(scopeMap),
      meta: SicaborPaginationMeta.fromJson(metaMap),
      data: items,
    );
  }

  Map<String, dynamic> toJson([
    Map<String, dynamic> Function(T item)? itemSerializer,
  ]) => {
    'success': success,
    'message': message,
    'scope': scope.toJson(),
    'meta': meta.toJson(),
    'data': itemSerializer != null ? data.map(itemSerializer).toList() : data,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SicaborListEnvelope<T> &&
          runtimeType == other.runtimeType &&
          success == other.success &&
          message == other.message &&
          scope == other.scope &&
          meta == other.meta &&
          listEquals(data, other.data);

  @override
  int get hashCode =>
      Object.hash(success, message, scope, meta, Object.hashAll(data));
}

int _asInt(dynamic value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? fallback;
  return fallback;
}
