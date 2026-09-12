import 'package:flutter/foundation.dart';

enum AccessScopeType { district, county }

@immutable
final class AccessScope {
  const AccessScope({required this.type, required this.id, required this.name});

  final AccessScopeType type;
  final String id;
  final String name;

  Map<String, dynamic> toJson() => {'type': type.name, 'id': id, 'name': name};

  factory AccessScope.fromJson(dynamic value) {
    if (value is! Map<String, dynamic>) {
      throw const FormatException('AccessScope harus berupa JSON object');
    }
    final rawType = value['type'];
    final rawId = value['id'];
    final rawName = value['name'];
    final type = rawType is String
        ? AccessScopeType.values.asNameMap()[rawType]
        : null;
    if (type == null ||
        rawId is! String ||
        rawId.trim().isEmpty ||
        rawName is! String ||
        rawName.trim().isEmpty) {
      throw const FormatException('AccessScope tidak valid');
    }
    return AccessScope(type: type, id: rawId, name: rawName);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AccessScope && other.type == type && other.id == id;

  @override
  int get hashCode => Object.hash(type, id);
}

@immutable
final class UserPrincipal {
  UserPrincipal({
    required this.id,
    required this.skNumber,
    required this.fullName,
    required this.roleTitle,
    required this.scope,
    this.profileImageUrl,
    Set<String> permissions = const {},
  }) : permissions = Set.unmodifiable(permissions);

  final String id;
  final String skNumber;
  final String fullName;
  final String roleTitle;
  final AccessScope scope;
  final String? profileImageUrl;
  final Set<String> permissions;

  bool hasPermission(String permission) => permissions.contains(permission);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserPrincipal &&
          other.id == id &&
          other.skNumber == skNumber &&
          other.fullName == fullName &&
          other.roleTitle == roleTitle &&
          other.scope == scope &&
          other.profileImageUrl == profileImageUrl &&
          setEquals(other.permissions, permissions);

  @override
  int get hashCode => Object.hash(
    id,
    skNumber,
    fullName,
    roleTitle,
    scope,
    profileImageUrl,
    Object.hashAllUnordered(permissions),
  );
}
