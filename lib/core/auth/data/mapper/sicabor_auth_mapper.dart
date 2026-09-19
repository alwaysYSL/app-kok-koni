import 'package:kok_app/core/auth/data/dto/sicabor_login_response.dart';
import 'package:kok_app/core/auth/data/dto/sicabor_profile_response.dart';
import 'package:kok_app/core/auth/domain/auth_failure.dart';
import 'package:kok_app/core/auth/domain/user_principal.dart';

abstract final class SicaborAuthMapper {
  static const String defaultRoleTitle = 'Koordinator Kecamatan';

  static UserPrincipal mapProfileOnlyToUserPrincipal({
    required SicaborProfileResponse profileResponse,
  }) {
    final member = profileResponse.data.member;
    final scope = profileResponse.scope;

    return UserPrincipal(
      id: member.id.toString(),
      username: member.username,
      fullName: member.name,
      roleTitle: defaultRoleTitle,
      scope: AccessScope(
        type: AccessScopeType.district,
        id: scope.subdistrictId.toString(),
        name: scope.subdistrictName,
      ),
      permissions: const {},
    );
  }

  static UserPrincipal mapProfileToUserPrincipal({
    required SicaborLoginData loginData,
    required SicaborProfileResponse profileResponse,
  }) {
    final member = profileResponse.data.member;
    final scope = profileResponse.scope;

    final id = member.id != 0 ? member.id.toString() : loginData.id;
    final username = member.username.isNotEmpty
        ? member.username
        : loginData.username;
    final fullName = member.name.isNotEmpty ? member.name : loginData.name;

    return UserPrincipal(
      id: id,
      username: username,
      fullName: fullName,
      roleTitle: defaultRoleTitle,
      scope: AccessScope(
        type: AccessScopeType.district,
        id: scope.subdistrictId.toString(),
        name: scope.subdistrictName,
      ),
      permissions: const {},
    );
  }

  static AuthFailure mapErrorCodeToFailure({
    String? errorCode,
    String? message,
  }) {
    switch (errorCode) {
      case 'NOT_KOK':
        return message != null
            ? AccountNotKokFailure(message)
            : const AccountNotKokFailure();
      case 'MEMBER_INACTIVE':
        return message != null
            ? AccountInactiveFailure(message)
            : const AccountInactiveFailure();
      case 'NO_SUBDISTRICT':
        return message != null
            ? NoSubdistrictFailure(message)
            : const NoSubdistrictFailure();
      case 'MEMBER_NOT_FOUND':
        return message != null
            ? MemberNotFoundFailure(message)
            : const MemberNotFoundFailure();
      default:
        return message != null
            ? InvalidCredentialsFailure(message)
            : const InvalidCredentialsFailure();
    }
  }
}
