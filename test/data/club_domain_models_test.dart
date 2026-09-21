import 'package:flutter_test/flutter_test.dart';
import 'package:kok_app/data/models/club.dart';
import 'package:kok_app/data/models/club_detail.dart';

void main() {
  group('Club Domain Models Tests', () {
    test('ClubCabor instantiates correctly with equality and hashCode', () {
      const cabor1 = ClubCabor(id: 10, code: 'KGCB-0010', name: 'ARUNG JERAM');
      const cabor2 = ClubCabor(id: 10, code: 'KGCB-0010', name: 'ARUNG JERAM');
      const cabor3 = ClubCabor(id: 11, code: 'KGCB-0011', name: 'ATLETIK');

      expect(cabor1.id, equals(10));
      expect(cabor1.code, equals('KGCB-0010'));
      expect(cabor1.name, equals('ARUNG JERAM'));

      expect(cabor1, equals(cabor2));
      expect(cabor1.hashCode, equals(cabor2.hashCode));
      expect(cabor1, isNot(equals(cabor3)));
    });

    test('ClubAddress instantiates correctly with equality and hashCode', () {
      const address1 = ClubAddress(
        address: 'Jl. Ahmad Yani No. 12',
        subdistrictId: 1728,
        subdistrictName: 'Garut Kota',
        districtId: 126,
        districtName: 'Garut',
      );
      const address2 = ClubAddress(
        address: 'Jl. Ahmad Yani No. 12',
        subdistrictId: 1728,
        subdistrictName: 'Garut Kota',
        districtId: 126,
        districtName: 'Garut',
      );
      const address3 = ClubAddress(
        address: null,
        subdistrictId: 1728,
        subdistrictName: 'Garut Kota',
        districtId: 126,
        districtName: 'Garut',
      );

      expect(address1.address, equals('Jl. Ahmad Yani No. 12'));
      expect(address1.subdistrictId, equals(1728));
      expect(address1.subdistrictName, equals('Garut Kota'));
      expect(address1.districtId, equals(126));
      expect(address1.districtName, equals('Garut'));

      expect(address1, equals(address2));
      expect(address1.hashCode, equals(address2.hashCode));
      expect(address1, isNot(equals(address3)));
      expect(address3.address, isNull);
    });

    test('Club instantiates correctly with equality and hashCode', () {
      const cabor = ClubCabor(id: 10, code: 'KGCB-0010', name: 'ARUNG JERAM');
      const secretariat = ClubAddress(
        address: 'Jl. Pramuka No. 5',
        subdistrictId: 1728,
        subdistrictName: 'Garut Kota',
        districtId: 126,
        districtName: 'Garut',
      );

      const club1 = Club(
        id: 1,
        code: 'KLUB-0001',
        name: 'Dayung Garut',
        logoUrl: 'https://sicabor.test/logo/1.png',
        cabor: cabor,
        headName: 'Budi Santoso',
        phone: '08123456789',
        email: 'dayung@garut.test',
        since: '2015',
        noSk: 'SK-001/2015',
        status: 1,
        statusLabel: 'Aktif',
        secretariat: secretariat,
        totalAthleteInClub: 12,
      );

      const club2 = Club(
        id: 1,
        code: 'KLUB-0001',
        name: 'Dayung Garut',
        logoUrl: 'https://sicabor.test/logo/1.png',
        cabor: cabor,
        headName: 'Budi Santoso',
        phone: '08123456789',
        email: 'dayung@garut.test',
        since: '2015',
        noSk: 'SK-001/2015',
        status: 1,
        statusLabel: 'Aktif',
        secretariat: secretariat,
        totalAthleteInClub: 12,
      );

      const club3 = Club(
        id: 2,
        code: 'KLUB-0002',
        name: 'Arung Indah',
        logoUrl: null,
        cabor: cabor,
        headName: null,
        phone: null,
        email: null,
        since: null,
        noSk: null,
        status: 0,
        statusLabel: 'Non-Aktif',
        secretariat: secretariat,
        totalAthleteInClub: 0,
      );

      expect(club1.id, equals(1));
      expect(club1.code, equals('KLUB-0001'));
      expect(club1.name, equals('Dayung Garut'));
      expect(club1.logoUrl, equals('https://sicabor.test/logo/1.png'));
      expect(club1.cabor, equals(cabor));
      expect(club1.headName, equals('Budi Santoso'));
      expect(club1.phone, equals('08123456789'));
      expect(club1.email, equals('dayung@garut.test'));
      expect(club1.since, equals('2015'));
      expect(club1.noSk, equals('SK-001/2015'));
      expect(club1.status, equals(1));
      expect(club1.statusLabel, equals('Aktif'));
      expect(club1.secretariat, equals(secretariat));
      expect(club1.totalAthleteInClub, equals(12));

      expect(club3.logoUrl, isNull);
      expect(club3.headName, isNull);
      expect(club3.phone, isNull);
      expect(club3.email, isNull);
      expect(club3.since, isNull);
      expect(club3.noSk, isNull);

      expect(club1, equals(club2));
      expect(club1.hashCode, equals(club2.hashCode));
      expect(club1, isNot(equals(club3)));
    });

    test(
      'ClubPersonnelItem instantiates correctly with equality and hashCode, including null id',
      () {
        const item1 = ClubPersonnelItem(
          id: 101,
          name: 'Coach Joko',
          role: 'Pelatih Kepala',
          phone: '0811111111',
          email: 'joko@test.com',
          photoUrl: 'https://sicabor.test/photos/joko.png',
          source: 'cabor',
        );

        const item2 = ClubPersonnelItem(
          id: 101,
          name: 'Coach Joko',
          role: 'Pelatih Kepala',
          phone: '0811111111',
          email: 'joko@test.com',
          photoUrl: 'https://sicabor.test/photos/joko.png',
          source: 'cabor',
        );

        const itemWithNullId = ClubPersonnelItem(
          id: null,
          name: 'Official Anonim',
          role: 'Medis',
          phone: null,
          email: null,
          photoUrl: null,
          source: null,
        );

        expect(item1.id, equals(101));
        expect(item1.name, equals('Coach Joko'));
        expect(item1.role, equals('Pelatih Kepala'));
        expect(item1.phone, equals('0811111111'));
        expect(item1.email, equals('joko@test.com'));
        expect(item1.photoUrl, equals('https://sicabor.test/photos/joko.png'));
        expect(item1.source, equals('cabor'));

        expect(itemWithNullId.id, isNull);
        expect(itemWithNullId.name, equals('Official Anonim'));
        expect(itemWithNullId.role, equals('Medis'));
        expect(itemWithNullId.phone, isNull);
        expect(itemWithNullId.email, isNull);
        expect(itemWithNullId.photoUrl, isNull);
        expect(itemWithNullId.source, isNull);

        expect(item1, equals(item2));
        expect(item1.hashCode, equals(item2.hashCode));
        expect(item1, isNot(equals(itemWithNullId)));
      },
    );

    test(
      'ClubPersonnelBlock instantiates correctly with equality and hashCode',
      () {
        const item = ClubPersonnelItem(
          id: 1,
          name: 'Pelatih A',
          role: 'Pelatih',
        );

        const block1 = ClubPersonnelBlock(
          dataAvailable: true,
          reason: null,
          items: [item],
        );

        const block2 = ClubPersonnelBlock(
          dataAvailable: true,
          reason: null,
          items: [item],
        );

        const block3 = ClubPersonnelBlock(
          dataAvailable: false,
          reason: 'Belum ada data',
          items: [],
        );

        expect(block1.dataAvailable, isTrue);
        expect(block1.reason, isNull);
        expect(block1.items, equals([item]));

        expect(block3.dataAvailable, isFalse);
        expect(block3.reason, equals('Belum ada data'));
        expect(block3.items, isEmpty);

        expect(block1, equals(block2));
        expect(block1.hashCode, equals(block2.hashCode));
        expect(block1, isNot(equals(block3)));
      },
    );

    test(
      'ClubManagementBlock instantiates correctly with equality and hashCode',
      () {
        const item = ClubPersonnelItem(
          id: 2,
          name: 'Pengurus B',
          role: 'Sekretaris',
          source: 'cabor',
        );

        const block1 = ClubManagementBlock(
          dataAvailable: true,
          partial: false,
          source: 'cabor',
          items: [item],
        );

        const block2 = ClubManagementBlock(
          dataAvailable: true,
          partial: false,
          source: 'cabor',
          items: [item],
        );

        const block3 = ClubManagementBlock(
          dataAvailable: true,
          partial: true,
          source: 'fallback',
          items: [],
        );

        expect(block1.dataAvailable, isTrue);
        expect(block1.partial, isFalse);
        expect(block1.source, equals('cabor'));
        expect(block1.items, equals([item]));

        expect(block3.dataAvailable, isTrue);
        expect(block3.partial, isTrue);
        expect(block3.source, equals('fallback'));
        expect(block3.items, isEmpty);

        expect(block1, equals(block2));
        expect(block1.hashCode, equals(block2.hashCode));
        expect(block1, isNot(equals(block3)));
      },
    );

    test('ClubDetail instantiates correctly with equality and hashCode', () {
      const cabor = ClubCabor(id: 10, code: 'KGCB-0010', name: 'ARUNG JERAM');
      const secretariat = ClubAddress(
        address: 'Jl. Pramuka No. 5',
        subdistrictId: 1728,
        subdistrictName: 'Garut Kota',
        districtId: 126,
        districtName: 'Garut',
      );
      const training = ClubAddress(
        address: 'Sungai Cimanuk',
        subdistrictId: 1728,
        subdistrictName: 'Garut Kota',
        districtId: 126,
        districtName: 'Garut',
      );
      const officialItem = ClubPersonnelItem(
        id: 1,
        name: 'Official 1',
        role: 'Manajer',
      );
      const coachItem = ClubPersonnelItem(
        id: 2,
        name: 'Coach 1',
        role: 'Pelatih',
      );
      const managementItem = ClubPersonnelItem(
        id: 3,
        name: 'Pengurus 1',
        role: 'Ketua',
      );

      const officials = ClubPersonnelBlock(
        dataAvailable: true,
        reason: null,
        items: [officialItem],
      );
      const coaches = ClubPersonnelBlock(
        dataAvailable: true,
        reason: null,
        items: [coachItem],
      );
      const management = ClubManagementBlock(
        dataAvailable: true,
        partial: false,
        source: 'cabor',
        items: [managementItem],
      );

      const detail1 = ClubDetail(
        id: 1,
        code: 'KLUB-0001',
        name: 'Dayung Garut',
        logoUrl: 'https://sicabor.test/logo/1.png',
        cabor: cabor,
        headName: 'Budi Santoso',
        phone: '08123456789',
        email: 'dayung@garut.test',
        since: '2015',
        noSk: 'SK-001/2015',
        status: 1,
        statusLabel: 'Aktif',
        secretariat: secretariat,
        totalAthleteInClub: 12,
        training: training,
        fileSkUrl: 'https://sicabor.test/files/sk-001.pdf',
        officials: officials,
        coaches: coaches,
        management: management,
      );

      const detail2 = ClubDetail(
        id: 1,
        code: 'KLUB-0001',
        name: 'Dayung Garut',
        logoUrl: 'https://sicabor.test/logo/1.png',
        cabor: cabor,
        headName: 'Budi Santoso',
        phone: '08123456789',
        email: 'dayung@garut.test',
        since: '2015',
        noSk: 'SK-001/2015',
        status: 1,
        statusLabel: 'Aktif',
        secretariat: secretariat,
        totalAthleteInClub: 12,
        training: training,
        fileSkUrl: 'https://sicabor.test/files/sk-001.pdf',
        officials: officials,
        coaches: coaches,
        management: management,
      );

      const detail3 = ClubDetail(
        id: 2,
        code: 'KLUB-0002',
        name: 'Arung Indah',
        logoUrl: null,
        cabor: cabor,
        headName: null,
        phone: null,
        email: null,
        since: null,
        noSk: null,
        status: 0,
        statusLabel: 'Non-Aktif',
        secretariat: secretariat,
        totalAthleteInClub: 0,
        training: null,
        fileSkUrl: null,
        officials: ClubPersonnelBlock(
          dataAvailable: false,
          reason: 'Data tidak tersedia',
          items: [],
        ),
        coaches: ClubPersonnelBlock(
          dataAvailable: false,
          reason: 'Data tidak tersedia',
          items: [],
        ),
        management: ClubManagementBlock(
          dataAvailable: false,
          partial: false,
          source: null,
          items: [],
        ),
      );

      expect(detail1.id, equals(1));
      expect(detail1.code, equals('KLUB-0001'));
      expect(detail1.name, equals('Dayung Garut'));
      expect(detail1.logoUrl, equals('https://sicabor.test/logo/1.png'));
      expect(detail1.cabor, equals(cabor));
      expect(detail1.headName, equals('Budi Santoso'));
      expect(detail1.phone, equals('08123456789'));
      expect(detail1.email, equals('dayung@garut.test'));
      expect(detail1.since, equals('2015'));
      expect(detail1.noSk, equals('SK-001/2015'));
      expect(detail1.status, equals(1));
      expect(detail1.statusLabel, equals('Aktif'));
      expect(detail1.secretariat, equals(secretariat));
      expect(detail1.totalAthleteInClub, equals(12));
      expect(detail1.training, equals(training));
      expect(
        detail1.fileSkUrl,
        equals('https://sicabor.test/files/sk-001.pdf'),
      );
      expect(detail1.officials, equals(officials));
      expect(detail1.coaches, equals(coaches));
      expect(detail1.management, equals(management));

      expect(detail3.training, isNull);
      expect(detail3.fileSkUrl, isNull);

      expect(detail1, equals(detail2));
      expect(detail1.hashCode, equals(detail2.hashCode));
      expect(detail1, isNot(equals(detail3)));
    });
  });
}
