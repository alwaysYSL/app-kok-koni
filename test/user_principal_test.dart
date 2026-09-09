import 'package:flutter_test/flutter_test.dart';
import 'package:kok_app/core/auth/domain/user_principal.dart';

void main() {
  group('UserPrincipal Hardening Tests', () {
    test('permissions set harus unmodifiable', () {
      final principal = UserPrincipal(
        id: 'usr_01',
        skNumber: 'SK-01',
        fullName: 'Nama User',
        roleTitle: 'Koordinator',
        districtId: 'garut_kota',
        districtName: 'Kecamatan Garut Kota',
        permissions: {'read:district', 'edit:club'},
      );

      expect(
        () => (principal.permissions as dynamic).add('malicious:permission'),
        throwsUnsupportedError,
      );
    });

    test('value equality dan hashCode harus memperhitungkan seluruh field dan permissions', () {
      final p1 = UserPrincipal(
        id: 'usr_01',
        skNumber: 'SK-01',
        fullName: 'Nama User',
        roleTitle: 'Koordinator',
        districtId: 'garut_kota',
        districtName: 'Kecamatan Garut Kota',
        permissions: {'read:district'},
      );
      final p2 = UserPrincipal(
        id: 'usr_01',
        skNumber: 'SK-01',
        fullName: 'Nama User',
        roleTitle: 'Koordinator',
        districtId: 'garut_kota',
        districtName: 'Kecamatan Garut Kota',
        permissions: {'read:district'},
      );
      final p3 = UserPrincipal(
        id: 'usr_01',
        skNumber: 'SK-01',
        fullName: 'Nama Berbeda',
        roleTitle: 'Koordinator',
        districtId: 'garut_kota',
        districtName: 'Kecamatan Garut Kota',
        permissions: {'read:district'},
      );
      final p4 = UserPrincipal(
        id: 'usr_01',
        skNumber: 'SK-01',
        fullName: 'Nama User',
        roleTitle: 'Koordinator',
        districtId: 'garut_kota',
        districtName: 'Kecamatan Garut Kota',
        permissions: {'read:district', 'extra:perm'},
      );

      expect(p1, equals(p2));
      expect(p1.hashCode, equals(p2.hashCode));
      expect(p1, isNot(equals(p3)));
      expect(p1, isNot(equals(p4)));
    });
  });
}
