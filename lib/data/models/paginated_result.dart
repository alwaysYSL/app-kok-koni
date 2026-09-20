import 'package:flutter/foundation.dart';

@immutable
final class PaginatedResult<T> {
  const PaginatedResult({
    required this.items,
    required this.limit,
    required this.offset,
    required this.total,
    this.filterWarning,
  });

  final List<T> items;
  final int limit;
  final int offset;
  final int total;
  final Map<String, dynamic>? filterWarning;

  bool get hasFilterWarning => filterWarning != null;
  String? get filterWarningMessage => filterWarning?['message'] as String?;

  bool get hasMore => offset + items.length < total;
  int get nextOffset => offset + items.length;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PaginatedResult<T> &&
          runtimeType == other.runtimeType &&
          listEquals(items, other.items) &&
          limit == other.limit &&
          offset == other.offset &&
          total == other.total &&
          mapEquals(filterWarning, other.filterWarning);

  @override
  int get hashCode => Object.hash(
    Object.hashAll(items),
    limit,
    offset,
    total,
    filterWarning == null
        ? null
        : Object.hash(
            Object.hashAll(filterWarning!.keys),
            Object.hashAll(filterWarning!.values),
          ),
  );
}
