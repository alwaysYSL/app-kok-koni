import 'package:flutter_test/flutter_test.dart';
import '../../scripts/mock_server/mock_data.dart';

void main() {
  group('MockData Accounts', () {
    test(
      'contains valid accounts for garut kota, limbangan, and tarogong kidul',
      () {
        final garut = MockData.findAccountByUsername('kt.garutkota');
        expect(garut, isNotNull);
        expect(garut?.id, equals(578));
        expect(garut?.name, equals('ADMIN KONTINGEN GARUT KOTA'));
        expect(garut?.type, equals('admin_kok'));
        expect(garut?.status, equals(1));
        expect(garut?.statusLabel, equals('Aktif'));
        expect(garut?.subdistrictId, equals(1728));
        expect(garut?.subdistrictName, equals('Garut Kota'));
        expect(garut?.districtId, equals(126));
        expect(garut?.districtName, equals('Garut'));

        final limbangan = MockData.findAccountByUsername('kt.bllimbangan');
        expect(limbangan, isNotNull);
        expect(limbangan?.id, equals(560));
        expect(limbangan?.name, equals('ADMIN KONTINGEN BL.LIMBANGAN'));
        expect(limbangan?.type, equals('admin_kok'));
        expect(limbangan?.status, equals(1));
        expect(limbangan?.subdistrictId, equals(1714));
        expect(limbangan?.subdistrictName, equals('Blubur Limbangan'));
        expect(limbangan?.kontingen?['id'], equals(3));
        expect(limbangan?.kontingen?['code'], equals('KGPK-0044'));
        expect(limbangan?.kontingen?['name'], equals('Balubur Limbangan'));

        final tarogong = MockData.findAccountByUsername('kt.tarogongkidul');
        expect(tarogong, isNotNull);
        expect(tarogong?.id, equals(561));
        expect(tarogong?.name, equals('ADMIN KONTINGEN TAROGONG KIDUL'));
        expect(tarogong?.type, equals('admin_kok'));
        expect(tarogong?.status, equals(1));
        expect(tarogong?.subdistrictId, equals(1729));
        expect(tarogong?.subdistrictName, equals('Tarogong Kidul'));
        expect(tarogong?.kontingen?['id'], equals(4));
      },
    );

    test(
      'contains edge case accounts: bukan_kok, non_aktif, and tanpa_kecamatan',
      () {
        final bukanKok = MockData.findAccountByUsername('bukan_kok');
        expect(bukanKok, isNotNull);
        expect(bukanKok?.type, equals('cabor'));
        expect(bukanKok?.isKok, isFalse);

        final nonAktif = MockData.findAccountByUsername('non_aktif');
        expect(nonAktif, isNotNull);
        expect(nonAktif?.status, equals(0));
        expect(nonAktif?.isActive, isFalse);

        final tanpaKecamatan = MockData.findAccountByUsername(
          'tanpa_kecamatan',
        );
        expect(tanpaKecamatan, isNotNull);
        expect(tanpaKecamatan?.subdistrictId, isNull);
        expect(tanpaKecamatan?.hasSubdistrict, isFalse);
      },
    );

    test('finds account by ID correctly', () {
      final garut = MockData.findAccountById(578);
      expect(garut, isNotNull);
      expect(garut?.username, equals('kt.garutkota'));

      final limbangan = MockData.findAccountById(560);
      expect(limbangan, isNotNull);
      expect(limbangan?.username, equals('kt.bllimbangan'));

      expect(MockData.findAccountById(99999), isNull);
    });

    test('returns null for unknown username', () {
      expect(MockData.findAccountByUsername('non_existent_user'), isNull);
    });
  });

  group('Password Verification', () {
    test(
      'verifies standard password and rejects wrong or universal passwords',
      () {
        final garut = MockData.findAccountByUsername('kt.garutkota')!;

        // Account password
        expect(MockData.verifyPassword(garut, 'password123'), isTrue);

        // Incorrect password
        expect(MockData.verifyPassword(garut, 'wrong_password'), isFalse);

        // Former global master password should no longer be accepted
        expect(MockData.verifyPassword(garut, 'sicabor4K0N1'), isFalse);
      },
    );
  });

  group('MockData JSON Builders', () {
    late MockAccount garutAccount;
    late MockAccount limbanganAccount;

    setUp(() {
      garutAccount = MockData.findAccountByUsername('kt.garutkota')!;
      limbanganAccount = MockData.findAccountByUsername('kt.bllimbangan')!;
    });

    test('buildProfileJson produces compliant envelope', () {
      final json = MockData.buildProfileJson(garutAccount);
      expect(json['success'], isTrue);
      expect(json['message'], equals('Berhasil mengambil data.'));
      expect(json['scope'], isA<Map<String, dynamic>>());
      expect(json['scope']['subdistrict_id'], equals(1728));
      expect(json['scope']['subdistrict_name'], equals('Garut Kota'));
      expect(json['scope']['district_id'], equals(126));

      final data = json['data'] as Map<String, dynamic>;
      expect(data['member']['username'], equals('kt.garutkota'));
      expect(data['member']['type'], equals('admin_kok'));
      expect(data['summary']['total_cabor'], equals(32));
      expect(data['summary']['total_club'], equals(10));
      expect(data['summary']['total_athlete'], equals(361));
      expect(data['data_notes'], isA<List>());
    });

    test('buildCaborListJson filters and computes counts correctly', () {
      // Garut Kota
      final garutCabor = MockData.buildCaborListJson(
        garutAccount,
        source: 'all',
      );
      expect(garutCabor['success'], isTrue);
      expect(garutCabor['scope']['subdistrict_id'], equals(1728));
      expect(garutCabor['meta']['source'], equals('all'));
      expect(garutCabor['meta']['derived_from'], equals('club_or_athlete'));
      expect(garutCabor['meta']['total'], equals(32));
      final garutList = garutCabor['data'] as List;
      expect(garutList.length, lessThanOrEqualTo(25));

      // Blubur Limbangan: 0 cabor from club, 17 from athlete, union 17
      final limbanganAll = MockData.buildCaborListJson(
        limbanganAccount,
        source: 'all',
      );
      expect(limbanganAll['meta']['total'], equals(17));

      final limbanganClub = MockData.buildCaborListJson(
        limbanganAccount,
        source: 'club',
      );
      expect(limbanganClub['meta']['total'], equals(0));
      expect((limbanganClub['data'] as List), isEmpty);

      final limbanganAthlete = MockData.buildCaborListJson(
        limbanganAccount,
        source: 'athlete',
      );
      expect(limbanganAthlete['meta']['total'], equals(17));
    });

    test('buildClubListJson and Detail produce compliant data', () {
      final clubList = MockData.buildClubListJson(garutAccount);
      expect(clubList['success'], isTrue);
      expect(clubList['meta']['total'], equals(10));
      final clubs = clubList['data'] as List;
      expect(clubs.isNotEmpty, isTrue);

      final firstClub = clubs.first as Map<String, dynamic>;
      final clubId = firstClub['id'] as int;

      final clubDetail = MockData.buildClubDetailJson(clubId);
      expect(clubDetail, isNotNull);
      expect(clubDetail?['success'], isTrue);
      final detailData = clubDetail?['data'] as Map<String, dynamic>;
      expect(detailData['id'], equals(clubId));
      expect(detailData['training'], isNotNull);
      expect(detailData['officials']['data_available'], isFalse);
      expect(detailData['coaches']['data_available'], isFalse);
      expect(detailData['management']['data_available'], isTrue);
      expect(detailData['management']['partial'], isTrue);

      // Detail with account scoping: limbangan has 0 clubs so clubId should return null
      final crossDetail = MockData.buildClubDetailJson(
        clubId,
        account: limbanganAccount,
      );
      expect(crossDetail, isNull);
    });

    test('buildClubOfficial, Coach, and Management endpoints', () {
      final official = MockData.buildClubOfficialJson(29);
      expect(official['success'], isTrue);
      expect(official['meta']['data_available'], isFalse);
      expect(official['meta']['reason'], equals('NOT_RECORDED_IN_SYSTEM'));
      expect(official['data'], isEmpty);

      final coach = MockData.buildClubCoachJson(29);
      expect(coach['success'], isTrue);
      expect(coach['meta']['data_available'], isFalse);
      expect(coach['data'], isEmpty);

      final mgmt = MockData.buildClubManagementJson(29);
      expect(mgmt, isNotNull);
      expect(mgmt?['success'], isTrue);
      expect(mgmt?['meta']['data_available'], isTrue);
      expect(mgmt?['meta']['partial'], isTrue);
      final mgmtData = mgmt?['data'] as List;
      expect(mgmtData.length, equals(1));
      expect(mgmtData[0]['role'], equals('Ketua'));
    });

    test('buildAthleteListJson and Detail produce compliant data', () {
      final athleteList = MockData.buildAthleteListJson(garutAccount);
      expect(athleteList['success'], isTrue);
      expect(athleteList['meta']['total'], equals(361));
      expect(athleteList['meta']['scope_basis'], equals('athlete_domicile'));
      final athletes = athleteList['data'] as List;
      expect(athletes.isNotEmpty, isTrue);

      final firstAthlete = athletes.first as Map<String, dynamic>;
      final athleteId = firstAthlete['id'] as int;

      final detail = MockData.buildAthleteDetailJson(athleteId);
      expect(detail, isNotNull);
      expect(detail?['success'], isTrue);
      final detailData = detail?['data'] as Map<String, dynamic>;
      expect(detailData['id'], equals(athleteId));
      expect(detailData.containsKey('phone'), isTrue);
      expect(detailData.containsKey('blood_type'), isTrue);
      expect(detailData.containsKey('height'), isTrue);
      expect(detailData.containsKey('weight'), isTrue);

      // Filtering by idClub includes filter_warning
      final filteredByClub = MockData.buildAthleteListJson(
        garutAccount,
        idClub: 29,
      );
      expect(filteredByClub['meta']['filter_warning'], isNotNull);
      expect(
        filteredByClub['meta']['filter_warning']['code'],
        equals('CLUB_MEMBERSHIP_SPARSE'),
      );

      // Detail with account scoping
      final crossAthlete = MockData.buildAthleteDetailJson(
        athleteId,
        account: limbanganAccount,
      );
      expect(crossAthlete, isNull);
    });

    test(
      'handles clamping of limit and offset for cabor, club, and athlete',
      () {
        final caborClamped = MockData.buildCaborListJson(
          garutAccount,
          limit: 9999,
          offset: -5,
        );
        expect(caborClamped['meta']['limit'], equals(100));
        expect(caborClamped['meta']['offset'], equals(0));

        final clubClamped = MockData.buildClubListJson(
          garutAccount,
          limit: -10,
          offset: 0,
        );
        expect(clubClamped['meta']['limit'], equals(25));

        final athleteClamped = MockData.buildAthleteListJson(
          garutAccount,
          limit: 0,
          offset: -1,
        );
        expect(athleteClamped['meta']['limit'], equals(25));
        expect(athleteClamped['meta']['offset'], equals(0));
      },
    );
  });
}
