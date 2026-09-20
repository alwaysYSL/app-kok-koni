import 'package:flutter_test/flutter_test.dart';
import 'package:kok_app/core/auth/data/dto/sicabor_profile_response.dart';
import 'package:kok_app/data/models/cabor.dart';
import 'package:kok_app/data/models/profile_summary.dart';
import 'package:kok_app/data/models/paginated_result.dart';

void main() {
  group('Domain Models Tests', () {
    test('Cabor model instantiates correctly with equality and hashCode', () {
      const cabor1 = Cabor(
        id: 9,
        code: 'KGCB-0010',
        name: 'ARUNG JERAM',
        groupName: 'FAJI',
        logoUrl: 'https://sicabor.test/logo.png',
        status: 1,
        statusLabel: 'Aktif',
        totalClub: 0,
        totalAthlete: 15,
      );

      const cabor2 = Cabor(
        id: 9,
        code: 'KGCB-0010',
        name: 'ARUNG JERAM',
        groupName: 'FAJI',
        logoUrl: 'https://sicabor.test/logo.png',
        status: 1,
        statusLabel: 'Aktif',
        totalClub: 0,
        totalAthlete: 15,
      );

      const cabor3 = Cabor(
        id: 10,
        code: 'KGCB-0011',
        name: 'ATLETIK',
        groupName: 'PASI',
        logoUrl: null,
        status: 1,
        statusLabel: 'Aktif',
        totalClub: 2,
        totalAthlete: 20,
      );

      expect(cabor1.id, equals(9));
      expect(cabor1.code, equals('KGCB-0010'));
      expect(cabor1.name, equals('ARUNG JERAM'));
      expect(cabor1.groupName, equals('FAJI'));
      expect(cabor1.logoUrl, equals('https://sicabor.test/logo.png'));
      expect(cabor1.status, equals(1));
      expect(cabor1.statusLabel, equals('Aktif'));
      expect(cabor1.totalClub, equals(0));
      expect(cabor1.totalAthlete, equals(15));

      expect(cabor1, equals(cabor2));
      expect(cabor1.hashCode, equals(cabor2.hashCode));
      expect(cabor1, isNot(equals(cabor3)));
    });

    test('ProfileSummary model instantiates with nested scope, member, summary', () {
      const summary1 = ProfileSummary(
        scope: SicaborScope(
          subdistrictId: 1728,
          subdistrictName: 'Garut Kota',
          districtId: 126,
          districtName: 'Garut',
        ),
        member: SicaborMember(
          id: 578,
          username: 'kt.garutkota',
          name: 'ADMIN KONTINGEN GARUT KOTA',
          email: null,
          type: 'admin_kok',
          status: 1,
          statusLabel: 'Aktif',
        ),
        kontingen: SicaborKontingen(
          id: 1,
          code: 'KGPK-0001',
          name: 'Garut Kota',
        ),
        totalCabor: 32,
        totalCaborFromClub: 5,
        totalCaborFromAthlete: 31,
        totalClub: 10,
        totalAthlete: 361,
        totalAthleteWithoutClub: 320,
        dataNotes: ['Catatan 1', 'Catatan 2'],
      );

      const summary2 = ProfileSummary(
        scope: SicaborScope(
          subdistrictId: 1728,
          subdistrictName: 'Garut Kota',
          districtId: 126,
          districtName: 'Garut',
        ),
        member: SicaborMember(
          id: 578,
          username: 'kt.garutkota',
          name: 'ADMIN KONTINGEN GARUT KOTA',
          email: null,
          type: 'admin_kok',
          status: 1,
          statusLabel: 'Aktif',
        ),
        kontingen: SicaborKontingen(
          id: 1,
          code: 'KGPK-0001',
          name: 'Garut Kota',
        ),
        totalCabor: 32,
        totalCaborFromClub: 5,
        totalCaborFromAthlete: 31,
        totalClub: 10,
        totalAthlete: 361,
        totalAthleteWithoutClub: 320,
        dataNotes: ['Catatan 1', 'Catatan 2'],
      );

      expect(summary1.scope.subdistrictName, equals('Garut Kota'));
      expect(summary1.member.username, equals('kt.garutkota'));
      expect(summary1.kontingen?.name, equals('Garut Kota'));
      expect(summary1.totalCabor, equals(32));
      expect(summary1.totalCaborFromClub, equals(5));
      expect(summary1.totalCaborFromAthlete, equals(31));
      expect(summary1.totalClub, equals(10));
      expect(summary1.totalAthlete, equals(361));
      expect(summary1.totalAthleteWithoutClub, equals(320));
      expect(summary1.dataNotes.length, equals(2));

      expect(summary1, equals(summary2));
      expect(summary1.hashCode, equals(summary2.hashCode));
    });

    test('PaginatedResult correctly calculates hasMore and nextOffset', () {
      const result1 = PaginatedResult<String>(
        items: ['a', 'b', 'c'],
        limit: 3,
        offset: 0,
        total: 10,
      );
      expect(result1.hasMore, isTrue);
      expect(result1.nextOffset, equals(3));

      const result2 = PaginatedResult<String>(
        items: ['d', 'e'],
        limit: 3,
        offset: 8,
        total: 10,
      );
      expect(result2.hasMore, isFalse);
      expect(result2.nextOffset, equals(10));

      const result3 = PaginatedResult<int>(
        items: [],
        limit: 10,
        offset: 0,
        total: 0,
      );
      expect(result3.hasMore, isFalse);
      expect(result3.nextOffset, equals(0));

      const result4 = PaginatedResult<String>(
        items: ['a', 'b', 'c'],
        limit: 3,
        offset: 0,
        total: 10,
      );
      expect(result1, equals(result4));
      expect(result1.hashCode, equals(result4.hashCode));
    });
  });
}
