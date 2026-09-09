import 'package:flutter_test/flutter_test.dart';
import 'package:kok_app/core/auth/domain/user_principal.dart';

void main() {
  group('AccessScope Tests', () {
    test(
      'equality dan hashCode hanya berdasarkan type dan id, mengabaikan label name',
      () {
        const scope1 = AccessScope(
          type: AccessScopeType.district,
          id: 'garut_kota',
          name: 'Kecamatan Garut Kota',
        );
        const scope2 = AccessScope(
          type: AccessScopeType.district,
          id: 'garut_kota',
          name: 'Label Berbeda',
        );
        const scopeDifferentId = AccessScope(
          type: AccessScopeType.district,
          id: 'tarogong_kidul',
          name: 'Kecamatan Garut Kota',
        );
        const scopeDifferentType = AccessScope(
          type: AccessScopeType.county,
          id: 'garut_kota',
          name: 'Kecamatan Garut Kota',
        );

        expect(scope1, equals(scope2));
        expect(scope1.hashCode, equals(scope2.hashCode));

        expect(scope1, isNot(equals(scopeDifferentId)));
        expect(scope1, isNot(equals(scopeDifferentType)));
      },
    );

    test('toJson dan fromJson round-trip valid', () {
      const original = AccessScope(
        type: AccessScopeType.county,
        id: 'koni_kab',
        name: 'KONI Kabupaten Garut',
      );

      final json = original.toJson();
      expect(json, {
        'type': 'county',
        'id': 'koni_kab',
        'name': 'KONI Kabupaten Garut',
      });

      final restored = AccessScope.fromJson(json);
      expect(restored, equals(original));
      expect(restored.name, equals('KONI Kabupaten Garut'));
    });

    test(
      'fromJson melempar FormatException pada payload corrupt atau tidak valid',
      () {
        expect(
          () => AccessScope.fromJson('invalid-string'),
          throwsFormatException,
        );
        expect(() => AccessScope.fromJson(null), throwsFormatException);
        expect(() => AccessScope.fromJson([1, 2, 3]), throwsFormatException);

        // Unknown type
        expect(
          () => AccessScope.fromJson({
            'type': 'province',
            'id': 'garut_kota',
            'name': 'Garut Kota',
          }),
          throwsFormatException,
        );

        // Missing or empty id
        expect(
          () => AccessScope.fromJson({
            'type': 'district',
            'id': '',
            'name': 'Garut Kota',
          }),
          throwsFormatException,
        );
        expect(
          () => AccessScope.fromJson({
            'type': 'district',
            'id': '   ',
            'name': 'Garut Kota',
          }),
          throwsFormatException,
        );
        expect(
          () => AccessScope.fromJson({
            'type': 'district',
            'id': 123,
            'name': 'Garut Kota',
          }),
          throwsFormatException,
        );

        // Missing or empty name
        expect(
          () => AccessScope.fromJson({
            'type': 'district',
            'id': 'garut_kota',
            'name': '',
          }),
          throwsFormatException,
        );
        expect(
          () => AccessScope.fromJson({
            'type': 'district',
            'id': 'garut_kota',
            'name': '   ',
          }),
          throwsFormatException,
        );
      },
    );
  });

  group('UserPrincipal Hardening Tests', () {
    const defaultScope = AccessScope(
      type: AccessScopeType.district,
      id: 'garut_kota',
      name: 'Kecamatan Garut Kota',
    );

    test(
      'permissions set harus unmodifiable dan mempertahankan defensive copy',
      () {
        final mutablePermissions = <String>{'read:district', 'edit:club'};
        final principal = UserPrincipal(
          id: 'usr_01',
          skNumber: 'SK-01',
          fullName: 'Nama User',
          roleTitle: 'Koordinator',
          scope: defaultScope,
          permissions: mutablePermissions,
        );

        // Mutasi list sumber tidak mengubah principal
        mutablePermissions.add('injected:source');
        expect(principal.permissions.contains('injected:source'), isFalse);

        // Modifikasi langsung ke set throws UnsupportedError
        expect(
          () => (principal.permissions as dynamic).add('malicious:permission'),
          throwsUnsupportedError,
        );
      },
    );

    test(
      'value equality dan hashCode memperhitungkan seluruh field dan permissions tanpa sensitif urutan',
      () {
        final p1 = UserPrincipal(
          id: 'usr_01',
          skNumber: 'SK-01',
          fullName: 'Nama User',
          roleTitle: 'Koordinator',
          scope: defaultScope,
          profileImageUrl: 'https://example.com/p.jpg',
          permissions: {'permA', 'permB'},
        );

        final p2 = UserPrincipal(
          id: 'usr_01',
          skNumber: 'SK-01',
          fullName: 'Nama User',
          roleTitle: 'Koordinator',
          scope: defaultScope,
          profileImageUrl: 'https://example.com/p.jpg',
          permissions: {'permB', 'permA'}, // urutan berbeda
        );

        final pDifferentScope = UserPrincipal(
          id: 'usr_01',
          skNumber: 'SK-01',
          fullName: 'Nama User',
          roleTitle: 'Koordinator',
          scope: const AccessScope(
            type: AccessScopeType.district,
            id: 'tarogong_kidul',
            name: 'Kecamatan Tarogong Kidul',
          ),
          profileImageUrl: 'https://example.com/p.jpg',
          permissions: {'permA', 'permB'},
        );

        final pDifferentPermissions = UserPrincipal(
          id: 'usr_01',
          skNumber: 'SK-01',
          fullName: 'Nama User',
          roleTitle: 'Koordinator',
          scope: defaultScope,
          profileImageUrl: 'https://example.com/p.jpg',
          permissions: {'permA'},
        );

        expect(p1, equals(p2));
        expect(p1.hashCode, equals(p2.hashCode));

        expect(p1, isNot(equals(pDifferentScope)));
        expect(p1, isNot(equals(pDifferentPermissions)));
      },
    );

    test(
      'deprecated compatibility getters tetap mengembalikan data yang benar',
      () {
        final principal = UserPrincipal(
          id: 'usr_01',
          skNumber: 'SK-01',
          fullName: 'Nama Lengkap',
          roleTitle: 'Ketua Umum',
          scope: defaultScope,
        );

        // ignore: deprecated_member_use_from_same_package
        expect(principal.name, equals('Nama Lengkap'));
        // ignore: deprecated_member_use_from_same_package
        expect(principal.role, equals('Ketua Umum'));
        // ignore: deprecated_member_use_from_same_package
        expect(principal.districtId, equals('garut_kota'));
        // ignore: deprecated_member_use_from_same_package
        expect(principal.districtName, equals('Kecamatan Garut Kota'));
      },
    );

    test('hasPermission mengembalikan boolean status secara akurat', () {
      final principal = UserPrincipal(
        id: 'usr_01',
        skNumber: 'SK-01',
        fullName: 'Nama User',
        roleTitle: 'Koordinator',
        scope: defaultScope,
        permissions: {'sports:read'},
      );

      expect(principal.hasPermission('sports:read'), isTrue);
      expect(principal.hasPermission('sports:write'), isFalse);
    });
  });
}
