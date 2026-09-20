import 'package:flutter_test/flutter_test.dart';
import 'package:kok_app/core/auth/data/dto/sicabor_profile_response.dart';
import 'package:kok_app/data/dto/sicabor_athlete_detail_item.dart';
import 'package:kok_app/data/dto/sicabor_athlete_item.dart';
import 'package:kok_app/data/dto/sicabor_detail_envelope.dart';

void main() {
  group('SicaborAthleteItem', () {
    test('fromJson parses complete JSON with club', () {
      final json = {
        'id': 2375,
        'code': 'KGAT-002281',
        'name': 'Abimanyu Alfathir Kumara',
        'sex': 'l',
        'sex_label': 'Laki-Laki',
        'pob': 'Garut',
        'dob': '2005-08-03',
        'age': 21,
        'photo': 'https://sicabor.test/photos/2375.jpg',
        'status': 1,
        'status_label': 'Aktif',
        'cabor': {'id': 15, 'code': 'KGCB-0016', 'name': 'PANJAT TEBING'},
        'club': {'id': 5, 'code': 'KLUB-0005', 'name': 'Voli Bina Muda'},
        'domicile': {
          'subdistrict_id': 1728,
          'subdistrict_name': 'Garut Kota',
          'district_id': 126,
          'district_name': 'Kabupaten Garut',
          'village': 'Muara Sanding',
        },
      };

      final item = SicaborAthleteItem.fromJson(json);

      expect(item.id, equals(2375));
      expect(item.code, equals('KGAT-002281'));
      expect(item.name, equals('Abimanyu Alfathir Kumara'));
      expect(item.sex, equals('l'));
      expect(item.sexLabel, equals('Laki-Laki'));
      expect(item.pob, equals('Garut'));
      expect(item.dob, equals('2005-08-03'));
      expect(item.age, equals(21));
      expect(item.photo, equals('https://sicabor.test/photos/2375.jpg'));
      expect(item.status, equals(1));
      expect(item.statusLabel, equals('Aktif'));
      expect(item.cabor['id'], equals(15));
      expect(item.cabor['name'], equals('PANJAT TEBING'));
      expect(item.club, isNotNull);
      expect(item.club!['id'], equals(5));
      expect(item.club!['name'], equals('Voli Bina Muda'));
      expect(item.domicile['subdistrict_id'], equals(1728));
      expect(item.domicile['subdistrict_name'], equals('Garut Kota'));
      expect(item.domicile['village'], equals('Muara Sanding'));
    });

    test('fromJson parses complete JSON without club (null club)', () {
      final json = {
        'id': 2375,
        'code': 'KGAT-002281',
        'name': 'Abimanyu Alfathir Kumara',
        'sex': 'l',
        'sex_label': 'Laki-Laki',
        'pob': null,
        'dob': null,
        'age': null,
        'photo': 'https://sicabor.test/photos/default.png',
        'status': 1,
        'status_label': 'Aktif',
        'cabor': {'id': 15, 'code': 'KGCB-0016', 'name': 'PANJAT TEBING'},
        'club': null,
        'domicile': {
          'subdistrict_id': 1728,
          'subdistrict_name': 'Garut Kota',
          'district_id': 126,
          'district_name': 'Kabupaten Garut',
        },
      };

      final item = SicaborAthleteItem.fromJson(json);

      expect(item.id, equals(2375));
      expect(item.pob, isNull);
      expect(item.dob, isNull);
      expect(item.age, isNull);
      expect(item.club, isNull);
      expect(item.domicile['village'], isNull);
    });

    test('fromJson handles string numbers and missing optional fields', () {
      final json = {
        'id': '2375',
        'code': 'KGAT-002281',
        'name': 'Abimanyu Alfathir Kumara',
        'sex': 'l',
        'sex_label': 'Laki-Laki',
        'age': '21',
        'photo': 'https://sicabor.test/photos/default.png',
        'status': '1',
        'status_label': 'Aktif',
        'cabor': {'id': 15, 'code': 'KGCB-0016', 'name': 'PANJAT TEBING'},
      };

      final item = SicaborAthleteItem.fromJson(json);

      expect(item.id, equals(2375));
      expect(item.age, equals(21));
      expect(item.status, equals(1));
      expect(item.club, isNull);
      expect(item.domicile, isEmpty);
    });

    test('toJson and equality work as expected', () {
      const item1 = SicaborAthleteItem(
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

      final json = item1.toJson();
      final item2 = SicaborAthleteItem.fromJson(json);

      expect(item1, equals(item2));
      expect(item1.hashCode, equals(item2.hashCode));
    });
  });

  group('SicaborAthleteDetailItem', () {
    test('fromJson parses complete detail JSON with all fields', () {
      final json = {
        'id': 2375,
        'code': 'KGAT-002281',
        'name': 'Abimanyu Alfathir Kumara',
        'sex': 'l',
        'sex_label': 'Laki-Laki',
        'pob': 'Garut',
        'dob': '2005-08-03',
        'age': 21,
        'photo': 'https://sicabor.test/photos/2375.jpg',
        'status': 1,
        'status_label': 'Aktif',
        'cabor': {'id': 15, 'code': 'KGCB-0016', 'name': 'PANJAT TEBING'},
        'club': {'id': 5, 'code': 'KLUB-0005', 'name': 'Voli Bina Muda'},
        'domicile': {
          'subdistrict_id': 1728,
          'subdistrict_name': 'Garut Kota',
          'district_id': 126,
          'district_name': 'Kabupaten Garut',
          'village': 'Muara Sanding',
        },
        'phone': '081234567890',
        'email': 'abimanyu@example.test',
        'height': 175,
        'weight': 68,
        'blood_type': 'O',
        'address': 'Jl. Merdeka No. 45',
      };

      final item = SicaborAthleteDetailItem.fromJson(json);

      expect(item.id, equals(2375));
      expect(item.code, equals('KGAT-002281'));
      expect(item.name, equals('Abimanyu Alfathir Kumara'));
      expect(item.sex, equals('l'));
      expect(item.sexLabel, equals('Laki-Laki'));
      expect(item.pob, equals('Garut'));
      expect(item.dob, equals('2005-08-03'));
      expect(item.age, equals(21));
      expect(item.photo, equals('https://sicabor.test/photos/2375.jpg'));
      expect(item.status, equals(1));
      expect(item.statusLabel, equals('Aktif'));
      expect(item.cabor['id'], equals(15));
      expect(item.club?['id'], equals(5));
      expect(item.domicile['village'], equals('Muara Sanding'));
      expect(item.phone, equals('081234567890'));
      expect(item.email, equals('abimanyu@example.test'));
      expect(item.height, equals(175));
      expect(item.weight, equals(68));
      expect(item.bloodType, equals('O'));
      expect(item.address, equals('Jl. Merdeka No. 45'));
    });

    test('fromJson parses detail JSON with optional fields as null', () {
      final json = {
        'id': 2375,
        'code': 'KGAT-002281',
        'name': 'Abimanyu Alfathir Kumara',
        'sex': 'l',
        'sex_label': 'Laki-Laki',
        'photo': 'https://sicabor.test/photos/2375.jpg',
        'status': 1,
        'status_label': 'Aktif',
        'cabor': {'id': 15, 'code': 'KGCB-0016', 'name': 'PANJAT TEBING'},
        'club': null,
        'domicile': {
          'subdistrict_id': 1728,
          'subdistrict_name': 'Garut Kota',
          'district_id': 126,
          'district_name': 'Kabupaten Garut',
        },
        'phone': null,
        'email': null,
        'height': null,
        'weight': null,
        'blood_type': null,
        'address': null,
      };

      final item = SicaborAthleteDetailItem.fromJson(json);

      expect(item.id, equals(2375));
      expect(item.phone, isNull);
      expect(item.email, isNull);
      expect(item.height, isNull);
      expect(item.weight, isNull);
      expect(item.bloodType, isNull);
      expect(item.address, isNull);
    });

    test('fromJson handles string numbers for height, weight, and age', () {
      final json = {
        'id': '2375',
        'code': 'KGAT-002281',
        'name': 'Abimanyu Alfathir Kumara',
        'sex': 'l',
        'sex_label': 'Laki-Laki',
        'age': '21',
        'photo': 'https://sicabor.test/photos/2375.jpg',
        'status': '1',
        'status_label': 'Aktif',
        'cabor': {'id': 15, 'code': 'KGCB-0016', 'name': 'PANJAT TEBING'},
        'domicile': {},
        'height': '175',
        'weight': '68',
      };

      final item = SicaborAthleteDetailItem.fromJson(json);

      expect(item.id, equals(2375));
      expect(item.age, equals(21));
      expect(item.height, equals(175));
      expect(item.weight, equals(68));
    });

    test('toJson and equality work as expected', () {
      const item1 = SicaborAthleteDetailItem(
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
        },
        phone: '081234567890',
        email: 'abimanyu@example.test',
        height: 175,
        weight: 68,
        bloodType: 'O',
        address: 'Jl. Merdeka No. 45',
      );

      final json = item1.toJson();
      final item2 = SicaborAthleteDetailItem.fromJson(json);

      expect(item1, equals(item2));
      expect(item1.hashCode, equals(item2.hashCode));
    });
  });

  group('SicaborDetailEnvelope', () {
    test(
      'fromJson parses generic detail response with scope and object data',
      () {
        final json = {
          'success': true,
          'message': 'Berhasil mengambil detail atlet.',
          'scope': {
            'subdistrict_id': 1728,
            'subdistrict_name': 'Garut Kota',
            'district_id': 126,
            'district_name': 'Garut',
          },
          'data': {
            'id': 2375,
            'code': 'KGAT-002281',
            'name': 'Abimanyu Alfathir Kumara',
            'sex': 'l',
            'sex_label': 'Laki-Laki',
            'photo': 'https://sicabor.test/photos/2375.jpg',
            'status': 1,
            'status_label': 'Aktif',
            'cabor': {'id': 15, 'code': 'KGCB-0016', 'name': 'PANJAT TEBING'},
            'club': null,
            'domicile': {
              'subdistrict_id': 1728,
              'subdistrict_name': 'Garut Kota',
              'district_id': 126,
              'district_name': 'Garut',
            },
            'phone': '081234567890',
            'email': null,
            'height': 175,
            'weight': 68,
            'blood_type': 'O',
            'address': 'Jl. Merdeka No. 45',
          },
        };

        final envelope =
            SicaborDetailEnvelope<SicaborAthleteDetailItem>.fromJson(
              json,
              SicaborAthleteDetailItem.fromJson,
            );

        expect(envelope.success, isTrue);
        expect(envelope.message, equals('Berhasil mengambil detail atlet.'));
        expect(envelope.scope.subdistrictId, equals(1728));
        expect(envelope.scope.subdistrictName, equals('Garut Kota'));
        expect(envelope.data.id, equals(2375));
        expect(envelope.data.code, equals('KGAT-002281'));
        expect(envelope.data.name, equals('Abimanyu Alfathir Kumara'));
        expect(envelope.data.phone, equals('081234567890'));
        expect(envelope.data.bloodType, equals('O'));
      },
    );

    test('fromJson handles null or empty scope and data gracefully', () {
      final json = {
        'success': true,
        'message': 'Data kosong',
        'scope': null,
        'data': {
          'id': 1,
          'code': 'CODE-1',
          'name': 'Test',
          'sex': 'l',
          'sex_label': 'Laki-Laki',
          'photo': '',
          'status': 1,
          'status_label': 'Aktif',
          'cabor': {'id': 1, 'code': 'C1', 'name': 'Cabor 1'},
          'domicile': {},
        },
      };

      final envelope = SicaborDetailEnvelope<SicaborAthleteDetailItem>.fromJson(
        json,
        SicaborAthleteDetailItem.fromJson,
      );

      expect(envelope.success, isTrue);
      expect(envelope.scope.subdistrictId, equals(0));
      expect(envelope.data.id, equals(1));
    });

    test('toJson and equality work as expected', () {
      const envelope1 = SicaborDetailEnvelope<SicaborAthleteDetailItem>(
        success: true,
        message: 'Berhasil',
        scope: SicaborScope(
          subdistrictId: 1728,
          subdistrictName: 'Garut Kota',
          districtId: 126,
          districtName: 'Garut',
        ),
        data: SicaborAthleteDetailItem(
          id: 2375,
          code: 'KGAT-002281',
          name: 'Abimanyu Alfathir Kumara',
          sex: 'l',
          sexLabel: 'Laki-Laki',
          photo: 'https://sicabor.test/photos/2375.jpg',
          status: 1,
          statusLabel: 'Aktif',
          cabor: {'id': 15, 'code': 'KGCB-0016', 'name': 'PANJAT TEBING'},
          club: null,
          domicile: {
            'subdistrict_id': 1728,
            'subdistrict_name': 'Garut Kota',
            'district_id': 126,
            'district_name': 'Garut',
          },
        ),
      );

      final json = envelope1.toJson((item) => item.toJson());
      final envelope2 =
          SicaborDetailEnvelope<SicaborAthleteDetailItem>.fromJson(
            json,
            SicaborAthleteDetailItem.fromJson,
          );

      expect(envelope1, equals(envelope2));
      expect(envelope1.hashCode, equals(envelope2.hashCode));
    });
  });
}
