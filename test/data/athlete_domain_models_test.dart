import 'package:flutter_test/flutter_test.dart';
import 'package:kok_app/data/models/athlete.dart';
import 'package:kok_app/data/models/athlete_detail.dart';
import 'package:kok_app/data/models/paginated_result.dart';

void main() {
  group('Athlete Domain Models Tests', () {
    test('AthleteCabor instantiates correctly with equality and hashCode', () {
      const cabor1 = AthleteCabor(
        id: 10,
        code: 'KGCB-0010',
        name: 'ARUNG JERAM',
      );
      const cabor2 = AthleteCabor(
        id: 10,
        code: 'KGCB-0010',
        name: 'ARUNG JERAM',
      );
      const cabor3 = AthleteCabor(id: 11, code: 'KGCB-0011', name: 'ATLETIK');

      expect(cabor1.id, equals(10));
      expect(cabor1.code, equals('KGCB-0010'));
      expect(cabor1.name, equals('ARUNG JERAM'));

      expect(cabor1, equals(cabor2));
      expect(cabor1.hashCode, equals(cabor2.hashCode));
      expect(cabor1, isNot(equals(cabor3)));
    });

    test('AthleteClub instantiates correctly with equality and hashCode', () {
      const club1 = AthleteClub(
        id: 5,
        code: 'KLUB-0005',
        name: 'Voli Bina Muda',
      );
      const club2 = AthleteClub(
        id: 5,
        code: 'KLUB-0005',
        name: 'Voli Bina Muda',
      );
      const club3 = AthleteClub(id: 6, code: 'KLUB-0006', name: 'Garuda Muda');

      expect(club1.id, equals(5));
      expect(club1.code, equals('KLUB-0005'));
      expect(club1.name, equals('Voli Bina Muda'));

      expect(club1, equals(club2));
      expect(club1.hashCode, equals(club2.hashCode));
      expect(club1, isNot(equals(club3)));
    });

    test(
      'AthleteDomicile instantiates correctly with equality and hashCode',
      () {
        const domicile1 = AthleteDomicile(
          subdistrictId: 1728,
          subdistrictName: 'Garut Kota',
          districtId: 126,
          districtName: 'Garut',
          village: 'Sukajaya',
        );
        const domicile2 = AthleteDomicile(
          subdistrictId: 1728,
          subdistrictName: 'Garut Kota',
          districtId: 126,
          districtName: 'Garut',
          village: 'Sukajaya',
        );
        const domicile3 = AthleteDomicile(
          subdistrictId: 1728,
          subdistrictName: 'Garut Kota',
          districtId: 126,
          districtName: 'Garut',
          village: null,
        );

        expect(domicile1.subdistrictId, equals(1728));
        expect(domicile1.subdistrictName, equals('Garut Kota'));
        expect(domicile1.districtId, equals(126));
        expect(domicile1.districtName, equals('Garut'));
        expect(domicile1.village, equals('Sukajaya'));

        expect(domicile1, equals(domicile2));
        expect(domicile1.hashCode, equals(domicile2.hashCode));
        expect(domicile1, isNot(equals(domicile3)));
      },
    );

    test('Athlete instantiates correctly with equality and hashCode', () {
      const cabor = AthleteCabor(
        id: 10,
        code: 'KGCB-0010',
        name: 'ARUNG JERAM',
      );
      const club = AthleteClub(
        id: 5,
        code: 'KLUB-0005',
        name: 'Voli Bina Muda',
      );
      const domicile = AthleteDomicile(
        subdistrictId: 1728,
        subdistrictName: 'Garut Kota',
        districtId: 126,
        districtName: 'Garut',
        village: 'Sukajaya',
      );

      const athlete1 = Athlete(
        id: 101,
        code: 'ATL-0101',
        name: 'Ahmad Fauzi',
        sex: 'l',
        sexLabel: 'Laki-Laki',
        pob: 'Garut',
        dob: '2005-04-12',
        age: 21,
        photoUrl: 'https://sicabor.test/photos/101.jpg',
        status: 1,
        statusLabel: 'Aktif',
        cabor: cabor,
        club: club,
        domicile: domicile,
      );

      const athlete2 = Athlete(
        id: 101,
        code: 'ATL-0101',
        name: 'Ahmad Fauzi',
        sex: 'l',
        sexLabel: 'Laki-Laki',
        pob: 'Garut',
        dob: '2005-04-12',
        age: 21,
        photoUrl: 'https://sicabor.test/photos/101.jpg',
        status: 1,
        statusLabel: 'Aktif',
        cabor: cabor,
        club: club,
        domicile: domicile,
      );

      const athlete3 = Athlete(
        id: 102,
        code: 'ATL-0102',
        name: 'Siti Rahma',
        sex: 'p',
        sexLabel: 'Perempuan',
        photoUrl: 'https://sicabor.test/photos/102.jpg',
        status: 1,
        statusLabel: 'Aktif',
        cabor: cabor,
        club: null,
        domicile: domicile,
      );

      expect(athlete1.id, equals(101));
      expect(athlete1.code, equals('ATL-0101'));
      expect(athlete1.name, equals('Ahmad Fauzi'));
      expect(athlete1.sex, equals('l'));
      expect(athlete1.sexLabel, equals('Laki-Laki'));
      expect(athlete1.pob, equals('Garut'));
      expect(athlete1.dob, equals('2005-04-12'));
      expect(athlete1.age, equals(21));
      expect(athlete1.photoUrl, equals('https://sicabor.test/photos/101.jpg'));
      expect(athlete1.status, equals(1));
      expect(athlete1.statusLabel, equals('Aktif'));
      expect(athlete1.cabor, equals(cabor));
      expect(athlete1.club, equals(club));
      expect(athlete1.domicile, equals(domicile));

      expect(athlete3.club, isNull);
      expect(athlete3.pob, isNull);
      expect(athlete3.dob, isNull);
      expect(athlete3.age, isNull);

      expect(athlete1, equals(athlete2));
      expect(athlete1.hashCode, equals(athlete2.hashCode));
      expect(athlete1, isNot(equals(athlete3)));
    });

    test('AthleteDetail instantiates correctly with equality and hashCode', () {
      const cabor = AthleteCabor(
        id: 10,
        code: 'KGCB-0010',
        name: 'ARUNG JERAM',
      );
      const club = AthleteClub(
        id: 5,
        code: 'KLUB-0005',
        name: 'Voli Bina Muda',
      );
      const domicile = AthleteDomicile(
        subdistrictId: 1728,
        subdistrictName: 'Garut Kota',
        districtId: 126,
        districtName: 'Garut',
        village: 'Sukajaya',
      );

      const detail1 = AthleteDetail(
        id: 101,
        code: 'ATL-0101',
        name: 'Ahmad Fauzi',
        sex: 'l',
        sexLabel: 'Laki-Laki',
        pob: 'Garut',
        dob: '2005-04-12',
        age: 21,
        photoUrl: 'https://sicabor.test/photos/101.jpg',
        status: 1,
        statusLabel: 'Aktif',
        cabor: cabor,
        club: club,
        domicile: domicile,
        phone: '081234567890',
        email: 'ahmad@example.test',
        height: 175,
        weight: 68,
        bloodType: 'O',
        address: 'Jl. Merdeka No. 45',
      );

      const detail2 = AthleteDetail(
        id: 101,
        code: 'ATL-0101',
        name: 'Ahmad Fauzi',
        sex: 'l',
        sexLabel: 'Laki-Laki',
        pob: 'Garut',
        dob: '2005-04-12',
        age: 21,
        photoUrl: 'https://sicabor.test/photos/101.jpg',
        status: 1,
        statusLabel: 'Aktif',
        cabor: cabor,
        club: club,
        domicile: domicile,
        phone: '081234567890',
        email: 'ahmad@example.test',
        height: 175,
        weight: 68,
        bloodType: 'O',
        address: 'Jl. Merdeka No. 45',
      );

      const detail3 = AthleteDetail(
        id: 101,
        code: 'ATL-0101',
        name: 'Ahmad Fauzi',
        sex: 'l',
        sexLabel: 'Laki-Laki',
        photoUrl: 'https://sicabor.test/photos/101.jpg',
        status: 1,
        statusLabel: 'Aktif',
        cabor: cabor,
        club: null,
        domicile: domicile,
      );

      expect(detail1.id, equals(101));
      expect(detail1.code, equals('ATL-0101'));
      expect(detail1.name, equals('Ahmad Fauzi'));
      expect(detail1.sex, equals('l'));
      expect(detail1.sexLabel, equals('Laki-Laki'));
      expect(detail1.pob, equals('Garut'));
      expect(detail1.dob, equals('2005-04-12'));
      expect(detail1.age, equals(21));
      expect(detail1.photoUrl, equals('https://sicabor.test/photos/101.jpg'));
      expect(detail1.status, equals(1));
      expect(detail1.statusLabel, equals('Aktif'));
      expect(detail1.cabor, equals(cabor));
      expect(detail1.club, equals(club));
      expect(detail1.domicile, equals(domicile));
      expect(detail1.phone, equals('081234567890'));
      expect(detail1.email, equals('ahmad@example.test'));
      expect(detail1.height, equals(175));
      expect(detail1.weight, equals(68));
      expect(detail1.bloodType, equals('O'));
      expect(detail1.address, equals('Jl. Merdeka No. 45'));

      expect(detail3.phone, isNull);
      expect(detail3.email, isNull);
      expect(detail3.height, isNull);
      expect(detail3.weight, isNull);
      expect(detail3.bloodType, isNull);
      expect(detail3.address, isNull);

      expect(detail1, equals(detail2));
      expect(detail1.hashCode, equals(detail2.hashCode));
      expect(detail1, isNot(equals(detail3)));
    });

    test('PaginatedResult supports optional filterWarning', () {
      const withoutWarning = PaginatedResult<String>(
        items: ['a', 'b'],
        limit: 10,
        offset: 0,
        total: 2,
      );

      expect(withoutWarning.hasFilterWarning, isFalse);
      expect(withoutWarning.filterWarning, isNull);
      expect(withoutWarning.filterWarningMessage, isNull);

      const withWarning = PaginatedResult<String>(
        items: ['a', 'b'],
        limit: 10,
        offset: 0,
        total: 2,
        filterWarning: {
          'message': 'Parameter cabor_id diabaikan karena scope kecamatan',
        },
      );

      expect(withWarning.hasFilterWarning, isTrue);
      expect(withWarning.filterWarning, isNotNull);
      expect(
        withWarning.filterWarningMessage,
        equals('Parameter cabor_id diabaikan karena scope kecamatan'),
      );

      const withSameWarning = PaginatedResult<String>(
        items: ['a', 'b'],
        limit: 10,
        offset: 0,
        total: 2,
        filterWarning: {
          'message': 'Parameter cabor_id diabaikan karena scope kecamatan',
        },
      );

      expect(withWarning, equals(withSameWarning));
      expect(withWarning.hashCode, equals(withSameWarning.hashCode));
      expect(withWarning, isNot(equals(withoutWarning)));
    });
  });
}
