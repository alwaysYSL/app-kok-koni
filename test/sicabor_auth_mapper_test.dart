import 'package:flutter_test/flutter_test.dart';
import 'package:kok_app/core/auth/data/dto/sicabor_login_response.dart';
import 'package:kok_app/core/auth/data/dto/sicabor_profile_response.dart';
import 'package:kok_app/core/auth/data/mapper/sicabor_auth_mapper.dart';
import 'package:kok_app/core/auth/domain/auth_failure.dart';
import 'package:kok_app/core/auth/domain/user_principal.dart';

void main() {
  group('SicaborAuthMapper', () {
    const sampleProfileResponse = SicaborProfileResponse(
      success: true,
      message: 'OK',
      scope: SicaborScope(
        subdistrictId: 1728,
        subdistrictName: 'Garut Kota',
        districtId: 126,
        districtName: 'Garut',
      ),
      data: SicaborProfileData(
        member: SicaborMember(
          id: 578,
          username: 'kt.garutkota',
          name: 'ADMIN KONTINGEN GARUT KOTA',
          email: null,
          type: 'admin_kok',
          status: 1,
          statusLabel: 'Aktif',
        ),
        kontingen: null,
        summary: SicaborSummary(
          totalCabor: 10,
          totalCaborFromClub: 2,
          totalCaborFromAthlete: 8,
          totalClub: 5,
          totalAthlete: 40,
          totalAthleteWithoutClub: 10,
        ),
        dataNotes: [],
      ),
    );

    test(
      'maps profile response to UserPrincipal with subdistrict as district scope',
      () {
        final user = SicaborAuthMapper.mapProfileOnlyToUserPrincipal(
          profileResponse: sampleProfileResponse,
        );

        expect(user.id, equals('578'));
        expect(user.username, equals('kt.garutkota'));
        expect(user.fullName, equals('ADMIN KONTINGEN GARUT KOTA'));
        expect(user.roleTitle, equals('Koordinator Kecamatan'));
        expect(user.scope.type, equals(AccessScopeType.district));
        expect(user.scope.id, equals('1728'));
        expect(user.scope.name, equals('Garut Kota'));
        expect(user.permissions, isEmpty);
        expect(user.profileImageUrl, isNull);
      },
    );

    test('maps profile and login data to UserPrincipal', () {
      const loginData = SicaborLoginData(
        id: '578',
        username: 'kt.garutkota',
        name: 'ADMIN KONTINGEN GARUT KOTA',
        email: null,
        type: 'admin_kok',
      );

      final user = SicaborAuthMapper.mapProfileToUserPrincipal(
        loginData: loginData,
        profileResponse: sampleProfileResponse,
      );

      expect(user.id, equals('578'));
      expect(user.username, equals('kt.garutkota'));
      expect(user.fullName, equals('ADMIN KONTINGEN GARUT KOTA'));
      expect(user.roleTitle, equals('Koordinator Kecamatan'));
      expect(user.scope.type, equals(AccessScopeType.district));
      expect(user.scope.id, equals('1728'));
      expect(user.scope.name, equals('Garut Kota'));
      expect(user.permissions, isEmpty);
    });

    group('mapErrorCodeToFailure', () {
      test(
        'maps known error codes to appropriate AuthFailure types with custom messages',
        () {
          final notKok = SicaborAuthMapper.mapErrorCodeToFailure(
            errorCode: 'NOT_KOK',
            message: 'Bukan akun KOK',
          );
          expect(notKok, isA<AccountNotKokFailure>());
          expect(notKok.message, equals('Bukan akun KOK'));

          final inactive = SicaborAuthMapper.mapErrorCodeToFailure(
            errorCode: 'MEMBER_INACTIVE',
            message: 'Akun non-aktif',
          );
          expect(inactive, isA<AccountInactiveFailure>());
          expect(inactive.message, equals('Akun non-aktif'));

          final noSubdistrict = SicaborAuthMapper.mapErrorCodeToFailure(
            errorCode: 'NO_SUBDISTRICT',
            message: 'Tidak ada kecamatan',
          );
          expect(noSubdistrict, isA<NoSubdistrictFailure>());
          expect(noSubdistrict.message, equals('Tidak ada kecamatan'));

          final notFound = SicaborAuthMapper.mapErrorCodeToFailure(
            errorCode: 'MEMBER_NOT_FOUND',
            message: 'Member tidak ditemukan',
          );
          expect(notFound, isA<MemberNotFoundFailure>());
          expect(notFound.message, equals('Member tidak ditemukan'));
        },
      );

      test(
        'maps known error codes with null message to default AuthFailure messages',
        () {
          final notKok = SicaborAuthMapper.mapErrorCodeToFailure(
            errorCode: 'NOT_KOK',
          );
          expect(notKok, isA<AccountNotKokFailure>());
          expect(
            notKok.message,
            equals('Akun ini bukan akun KOK dan tidak memiliki akses.'),
          );

          final inactive = SicaborAuthMapper.mapErrorCodeToFailure(
            errorCode: 'MEMBER_INACTIVE',
          );
          expect(inactive, isA<AccountInactiveFailure>());
          expect(
            inactive.message,
            equals('Akun Anda berstatus non-aktif. Hubungi admin SICABOR.'),
          );

          final noSubdistrict = SicaborAuthMapper.mapErrorCodeToFailure(
            errorCode: 'NO_SUBDISTRICT',
          );
          expect(noSubdistrict, isA<NoSubdistrictFailure>());
          expect(
            noSubdistrict.message,
            equals(
              'Akun belum memiliki kecamatan yang terdaftar. Hubungi admin.',
            ),
          );

          final notFound = SicaborAuthMapper.mapErrorCodeToFailure(
            errorCode: 'MEMBER_NOT_FOUND',
          );
          expect(notFound, isA<MemberNotFoundFailure>());
          expect(
            notFound.message,
            equals('Data akun anggota tidak ditemukan pada sistem SICABOR.'),
          );
        },
      );

      test('maps unknown or null error codes to InvalidCredentialsFailure', () {
        final unknown = SicaborAuthMapper.mapErrorCodeToFailure(
          errorCode: 'INVALID_CREDENTIALS',
          message: 'Password salah',
        );
        expect(unknown, isA<InvalidCredentialsFailure>());
        expect(unknown.message, equals('Password salah'));

        final nullCode = SicaborAuthMapper.mapErrorCodeToFailure(
          errorCode: null,
        );
        expect(nullCode, isA<InvalidCredentialsFailure>());
        expect(
          nullCode.message,
          equals('Username atau kata sandi tidak sesuai.'),
        );
      });
    });
  });
}
