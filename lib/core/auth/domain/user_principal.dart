class UserPrincipal {
  final String id;
  final String skNumber;
  final String name;
  final String role;
  final String districtId;
  final String districtName;
  final Set<String> permissions;

  const UserPrincipal({
    required this.id,
    required this.skNumber,
    required this.name,
    required this.role,
    required this.districtId,
    required this.districtName,
    required this.permissions,
  });

  bool hasPermission(String permission) => permissions.contains(permission);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserPrincipal &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          skNumber == other.skNumber &&
          districtId == other.districtId;

  @override
  int get hashCode => id.hashCode ^ skNumber.hashCode ^ districtId.hashCode;
}
