import 'package:flutter_test/flutter_test.dart';
import 'package:kok_app/data/dto/sicabor_athlete_detail_item.dart';
import 'package:kok_app/data/dto/sicabor_athlete_item.dart';
import 'package:kok_app/data/mapper/sicabor_data_mapper.dart';
import 'package:kok_app/data/models/athlete.dart';
import 'package:kok_app/data/models/athlete_detail.dart';

void main() {
  group('SicaborDataMapper Athlete Tests', () {
    const mapper = SicaborDataMapper();

    test(
      'mapAthlete correctly maps SicaborAthleteItem with club to Athlete domain model',
      () {
        const dto = SicaborAthleteItem(
          id: 2375,
          code: 'KGAT-002281',
          name: 'Abimanyu Alfathir Kumara',
          sex: 'l',
          sexLabel: 'Laki-Laki',
          pob: 'Garut',
          dob: '2005-08-03',
          age: 21,
          photo: 'https://sicabor.test/photos/2375.jpg',
          status: 1,
          statusLabel: 'Aktif',
          cabor: {'id': 15, 'code': 'KGCB-0016', 'name': 'PANJAT TEBING'},
          club: {'id': 5, 'code': 'KLUB-0005', 'name': 'Voli Bina Muda'},
          domicile: {
            'subdistrict_id': 1728,
            'subdistrict_name': 'Garut Kota',
            'district_id': 126,
            'district_name': 'Kabupaten Garut',
            'village': 'Muara Sanding',
          },
        );

        final domain = mapper.mapAthlete(dto);

        expect(
          domain,
          equals(
            const Athlete(
              id: 2375,
              code: 'KGAT-002281',
              name: 'Abimanyu Alfathir Kumara',
              sex: 'l',
              sexLabel: 'Laki-Laki',
              pob: 'Garut',
              dob: '2005-08-03',
              age: 21,
              photoUrl: 'https://sicabor.test/photos/2375.jpg',
              status: 1,
              statusLabel: 'Aktif',
              cabor: AthleteCabor(
                id: 15,
                code: 'KGCB-0016',
                name: 'PANJAT TEBING',
              ),
              club: AthleteClub(
                id: 5,
                code: 'KLUB-0005',
                name: 'Voli Bina Muda',
              ),
              domicile: AthleteDomicile(
                subdistrictId: 1728,
                subdistrictName: 'Garut Kota',
                districtId: 126,
                districtName: 'Kabupaten Garut',
                village: 'Muara Sanding',
              ),
            ),
          ),
        );
      },
    );

    test(
      'mapAthlete correctly maps SicaborAthleteItem without club (null club)',
      () {
        const dto = SicaborAthleteItem(
          id: 2376,
          code: 'KGAT-002282',
          name: 'Siti Nurhaliza',
          sex: 'p',
          sexLabel: 'Perempuan',
          pob: null,
          dob: null,
          age: null,
          photo: 'https://sicabor.test/photos/2376.jpg',
          status: 1,
          statusLabel: 'Aktif',
          cabor: {'id': 10, 'code': 'KGCB-0010', 'name': 'ATLETIK'},
          club: null,
          domicile: {
            'subdistrict_id': 1728,
            'subdistrict_name': 'Garut Kota',
            'district_id': 126,
            'district_name': 'Kabupaten Garut',
          },
        );

        final domain = mapper.mapAthlete(dto);

        expect(domain.id, equals(2376));
        expect(domain.club, isNull);
        expect(domain.pob, isNull);
        expect(domain.dob, isNull);
        expect(domain.age, isNull);
        expect(domain.domicile.village, isNull);
        expect(domain.cabor.name, equals('ATLETIK'));
      },
    );

    test('mapAthlete handles string numbers inside nested maps', () {
      const dto = SicaborAthleteItem(
        id: 2377,
        code: 'KGAT-002283',
        name: 'Budi Santoso',
        sex: 'l',
        sexLabel: 'Laki-Laki',
        photo: 'https://sicabor.test/photos/2377.jpg',
        status: 1,
        statusLabel: 'Aktif',
        cabor: {'id': '15', 'code': 'KGCB-0016', 'name': 'PANJAT TEBING'},
        club: {'id': '5', 'code': 'KLUB-0005', 'name': 'Voli Bina Muda'},
        domicile: {
          'subdistrict_id': '1728',
          'subdistrict_name': 'Garut Kota',
          'district_id': '126',
          'district_name': 'Kabupaten Garut',
        },
      );

      final domain = mapper.mapAthlete(dto);

      expect(domain.cabor.id, equals(15));
      expect(domain.club?.id, equals(5));
      expect(domain.domicile.subdistrictId, equals(1728));
      expect(domain.domicile.districtId, equals(126));
    });

    test(
      'mapAthleteDetail correctly maps SicaborAthleteDetailItem with all fields',
      () {
        const dto = SicaborAthleteDetailItem(
          id: 2375,
          code: 'KGAT-002281',
          name: 'Abimanyu Alfathir Kumara',
          sex: 'l',
          sexLabel: 'Laki-Laki',
          pob: 'Garut',
          dob: '2005-08-03',
          age: 21,
          photo: 'https://sicabor.test/photos/2375.jpg',
          status: 1,
          statusLabel: 'Aktif',
          cabor: {'id': 15, 'code': 'KGCB-0016', 'name': 'PANJAT TEBING'},
          club: {'id': 5, 'code': 'KLUB-0005', 'name': 'Voli Bina Muda'},
          domicile: {
            'subdistrict_id': 1728,
            'subdistrict_name': 'Garut Kota',
            'district_id': 126,
            'district_name': 'Kabupaten Garut',
            'village': 'Muara Sanding',
          },
          phone: '081234567890',
          email: 'abimanyu@example.test',
          height: 175,
          weight: 68,
          bloodType: 'O',
          address: 'Jl. Merdeka No. 45',
        );

        final domain = mapper.mapAthleteDetail(dto);

        expect(
          domain,
          equals(
            const AthleteDetail(
              id: 2375,
              code: 'KGAT-002281',
              name: 'Abimanyu Alfathir Kumara',
              sex: 'l',
              sexLabel: 'Laki-Laki',
              pob: 'Garut',
              dob: '2005-08-03',
              age: 21,
              photoUrl: 'https://sicabor.test/photos/2375.jpg',
              status: 1,
              statusLabel: 'Aktif',
              cabor: AthleteCabor(
                id: 15,
                code: 'KGCB-0016',
                name: 'PANJAT TEBING',
              ),
              club: AthleteClub(
                id: 5,
                code: 'KLUB-0005',
                name: 'Voli Bina Muda',
              ),
              domicile: AthleteDomicile(
                subdistrictId: 1728,
                subdistrictName: 'Garut Kota',
                districtId: 126,
                districtName: 'Kabupaten Garut',
                village: 'Muara Sanding',
              ),
              phone: '081234567890',
              email: 'abimanyu@example.test',
              height: 175,
              weight: 68,
              bloodType: 'O',
              address: 'Jl. Merdeka No. 45',
            ),
          ),
        );
      },
    );

    test(
      'mapAthleteDetail correctly maps SicaborAthleteDetailItem with optional fields null',
      () {
        const dto = SicaborAthleteDetailItem(
          id: 2376,
          code: 'KGAT-002282',
          name: 'Siti Nurhaliza',
          sex: 'p',
          sexLabel: 'Perempuan',
          photo: 'https://sicabor.test/photos/2376.jpg',
          status: 1,
          statusLabel: 'Aktif',
          cabor: {'id': 10, 'code': 'KGCB-0010', 'name': 'ATLETIK'},
          club: null,
          domicile: {
            'subdistrict_id': 1728,
            'subdistrict_name': 'Garut Kota',
            'district_id': 126,
            'district_name': 'Kabupaten Garut',
          },
        );

        final domain = mapper.mapAthleteDetail(dto);

        expect(domain.id, equals(2376));
        expect(domain.club, isNull);
        expect(domain.phone, isNull);
        expect(domain.email, isNull);
        expect(domain.height, isNull);
        expect(domain.weight, isNull);
        expect(domain.bloodType, isNull);
        expect(domain.address, isNull);
      },
    );
  });
}
