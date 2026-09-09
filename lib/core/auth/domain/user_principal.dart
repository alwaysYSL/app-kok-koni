import 'package:flutter/foundation.dart';

@immutable
class UserPrincipal {
  final String id;
  final String skNumber;
  final String fullName;
  final String roleTitle;
  final String districtId;
  final String districtName;
  final String? profileImageUrl;
  final Set<String> permissions;

  UserPrincipal({
    required this.id,
    required this.skNumber,
    String? fullName,
    String? roleTitle,
    String? name,
    String? role,
    required this.districtId,
    required this.districtName,
    this.profileImageUrl,
    Set<String> permissions = const {},
  })  : fullName = fullName ?? name ?? '',
        roleTitle = roleTitle ?? role ?? '',
        permissions = Set.unmodifiable(permissions);

  String get name => fullName;
  String get role => roleTitle;

  bool hasPermission(String permission) => permissions.contains(permission);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserPrincipal &&
        other.id == id &&
        other.skNumber == skNumber &&
        other.fullName == fullName &&
        other.roleTitle == roleTitle &&
        other.districtId == districtId &&
        other.districtName == districtName &&
        other.profileImageUrl == profileImageUrl &&
        setEquals(other.permissions, permissions);
  }

  @override
  int get hashCode => Object.hash(
        id,
        skNumber,
        fullName,
        roleTitle,
        districtId,
        districtName,
        profileImageUrl,
        Object.hashAllUnordered(permissions),
      );
}
