import 'package:flutter_test/flutter_test.dart';
import 'package:kok_app/data/dto/sicabor_club_detail_item.dart';
import 'package:kok_app/data/dto/sicabor_club_item.dart';
import 'package:kok_app/data/dto/sicabor_detail_envelope.dart';
import 'package:kok_app/data/dto/sicabor_list_envelope.dart';

void main() {
  group('SicaborClubItem', () {
    test('fromJson parses complete JSON', () {
      final json = {
        'id': 29,
        'code': 'KGCL-0029',
        'name': 'BAJA FIGHT ACADEMY',
        'logo': 'https://sicabor.test/logo/baja.png',
        'cabor': {'id': 22, 'code': 'KGCB-0023', 'name': 'MUAYTHAI'},
        'head_name': 'Djaka umaran',
        'phone': '089630325024',
        'email': 'bajafight@gmail.com',
        'since': '2022',
        'no_sk': 'SK-029/2022',
        'status': 1,
        'status_label': 'Aktif',
        'secretariat': {
          'address': 'Jl. A. Yani, Kp. Ciwalen',
          'subdistrict_id': 1728,
          'subdistrict_name': 'Garut Kota',
          'district_id': 126,
          'district_name': 'Kabupaten Garut',
        },
        'total_athlete_in_club': 15,
      };

      final item = SicaborClubItem.fromJson(json);

      expect(item.id, equals(29));
      expect(item.code, equals('KGCL-0029'));
      expect(item.name, equals('BAJA FIGHT ACADEMY'));
      expect(item.logo, equals('https://sicabor.test/logo/baja.png'));
      expect(item.cabor['id'], equals(22));
      expect(item.cabor['name'], equals('MUAYTHAI'));
      expect(item.headName, equals('Djaka umaran'));
      expect(item.phone, equals('089630325024'));
      expect(item.email, equals('bajafight@gmail.com'));
      expect(item.since, equals('2022'));
      expect(item.noSk, equals('SK-029/2022'));
      expect(item.status, equals(1));
      expect(item.statusLabel, equals('Aktif'));
      expect(item.secretariat['subdistrict_id'], equals(1728));
      expect(item.secretariat['subdistrict_name'], equals('Garut Kota'));
      expect(item.totalAthleteInClub, equals(15));
    });

    test('fromJson parses JSON with null optional fields', () {
      final json = {
        'id': 30,
        'code': 'KGCL-0030',
        'name': 'GARUT RUNNERS',
        'logo': null,
        'cabor': {'id': 10, 'code': 'KGCB-0010', 'name': 'ATLETIK'},
        'head_name': null,
        'phone': null,
        'email': null,
        'since': null,
        'no_sk': null,
        'status': 0,
        'status_label': 'Belum Aktif',
        'secretariat': {
          'address': null,
          'subdistrict_id': 1728,
          'subdistrict_name': 'Garut Kota',
          'district_id': 126,
          'district_name': 'Kabupaten Garut',
        },
        'total_athlete_in_club': 0,
      };

      final item = SicaborClubItem.fromJson(json);

      expect(item.id, equals(30));
      expect(item.logo, isNull);
      expect(item.headName, isNull);
      expect(item.phone, isNull);
      expect(item.email, isNull);
      expect(item.since, isNull);
      expect(item.noSk, isNull);
      expect(item.status, equals(0));
      expect(item.secretariat['address'], isNull);
      expect(item.totalAthleteInClub, equals(0));
    });

    test('fromJson handles string numbers and missing maps', () {
      final json = {
        'id': '29',
        'code': 'KGCL-0029',
        'name': 'BAJA FIGHT ACADEMY',
        'status': '1',
        'status_label': 'Aktif',
        'total_athlete_in_club': '15',
      };

      final item = SicaborClubItem.fromJson(json);

      expect(item.id, equals(29));
      expect(item.status, equals(1));
      expect(item.totalAthleteInClub, equals(15));
      expect(item.cabor, isEmpty);
      expect(item.secretariat, isEmpty);
    });

    test('toJson and equality work as expected', () {
      const item1 = SicaborClubItem(
        id: 29,
        code: 'KGCL-0029',
        name: 'BAJA FIGHT ACADEMY',
        logo: 'https://sicabor.test/logo/baja.png',
        cabor: {'id': 22, 'code': 'KGCB-0023', 'name': 'MUAYTHAI'},
        headName: 'Djaka umaran',
        phone: '089630325024',
        email: 'bajafight@gmail.com',
        since: '2022',
        noSk: 'SK-029/2022',
        status: 1,
        statusLabel: 'Aktif',
        secretariat: {
          'address': 'Jl. A. Yani, Kp. Ciwalen',
          'subdistrict_id': 1728,
          'subdistrict_name': 'Garut Kota',
          'district_id': 126,
          'district_name': 'Kabupaten Garut',
        },
        totalAthleteInClub: 15,
      );

      final json = item1.toJson();
      final item2 = SicaborClubItem.fromJson(json);

      expect(item1, equals(item2));
      expect(item1.hashCode, equals(item2.hashCode));
    });
  });

  group('SicaborClubDetailItem', () {
    test('fromJson parses complete detail JSON with all fields', () {
      final json = {
        'id': 29,
        'code': 'KGCL-0029',
        'name': 'BAJA FIGHT ACADEMY',
        'logo': 'https://sicabor.test/logo/baja.png',
        'cabor': {'id': 22, 'code': 'KGCB-0023', 'name': 'MUAYTHAI'},
        'head_name': 'Djaka umaran',
        'phone': '089630325024',
        'email': 'bajafight@gmail.com',
        'since': '2022',
        'no_sk': 'SK-029/2022',
        'status': 1,
        'status_label': 'Aktif',
        'secretariat': {
          'address': 'Jl. A. Yani, Kp. Ciwalen',
          'subdistrict_id': 1728,
          'subdistrict_name': 'Garut Kota',
          'district_id': 126,
          'district_name': 'Kabupaten Garut',
        },
        'total_athlete_in_club': 15,
        'training': {
          'address': 'GOR Ciateul',
          'subdistrict_id': 1729,
          'subdistrict_name': 'Tarogong Kidul',
          'district_id': 126,
          'district_name': 'Kabupaten Garut',
        },
        'file_sk': 'https://sicabor.test/files/sk-029.pdf',
        'officials': {
          'data_available': false,
          'reason': 'NOT_RECORDED_IN_SYSTEM',
          'total': 0,
          'data': [],
        },
        'coaches': {
          'data_available': false,
          'reason': 'NOT_RECORDED_IN_SYSTEM',
          'total': 0,
          'data': [],
        },
        'management': {
          'data_available': true,
          'partial': true,
          'source': 'club.head_name',
          'total': 1,
          'data': [
            {
              'id': null,
              'name': 'Djaka umaran',
              'role': 'Ketua',
              'phone': '089630325024',
              'email': 'bajafight@gmail.com',
              'photo': null,
              'source': 'club.head_name',
            },
          ],
        },
      };

      final item = SicaborClubDetailItem.fromJson(json);

      expect(item.id, equals(29));
      expect(item.code, equals('KGCL-0029'));
      expect(item.name, equals('BAJA FIGHT ACADEMY'));
      expect(item.logo, equals('https://sicabor.test/logo/baja.png'));
      expect(item.cabor['name'], equals('MUAYTHAI'));
      expect(item.headName, equals('Djaka umaran'));
      expect(item.training?['subdistrict_name'], equals('Tarogong Kidul'));
      expect(item.fileSk, equals('https://sicabor.test/files/sk-029.pdf'));
      expect(item.officials['data_available'], isFalse);
      expect(item.coaches['data_available'], isFalse);
      expect(item.management['data_available'], isTrue);
      expect(item.management['partial'], isTrue);
    });

    test('fromJson parses detail JSON with null optional fields', () {
      final json = {
        'id': 30,
        'code': 'KGCL-0030',
        'name': 'GARUT RUNNERS',
        'logo': null,
        'cabor': {'id': 10, 'code': 'KGCB-0010', 'name': 'ATLETIK'},
        'head_name': null,
        'phone': null,
        'email': null,
        'since': null,
        'no_sk': null,
        'status': 0,
        'status_label': 'Belum Aktif',
        'secretariat': {
          'address': null,
          'subdistrict_id': 1728,
          'subdistrict_name': 'Garut Kota',
          'district_id': 126,
          'district_name': 'Kabupaten Garut',
        },
        'total_athlete_in_club': 0,
        'training': null,
        'file_sk': null,
        'officials': {'data_available': false, 'items': []},
        'coaches': {'data_available': false, 'items': []},
        'management': {'data_available': false, 'partial': false, 'items': []},
      };

      final item = SicaborClubDetailItem.fromJson(json);

      expect(item.id, equals(30));
      expect(item.training, isNull);
      expect(item.fileSk, isNull);
    });

    test('toJson and equality work as expected', () {
      const item1 = SicaborClubDetailItem(
        id: 29,
        code: 'KGCL-0029',
        name: 'BAJA FIGHT ACADEMY',
        logo: 'https://sicabor.test/logo/baja.png',
        cabor: {'id': 22, 'code': 'KGCB-0023', 'name': 'MUAYTHAI'},
        headName: 'Djaka umaran',
        phone: '089630325024',
        email: 'bajafight@gmail.com',
        since: '2022',
        noSk: 'SK-029/2022',
        status: 1,
        statusLabel: 'Aktif',
        secretariat: {
          'address': 'Jl. A. Yani, Kp. Ciwalen',
          'subdistrict_id': 1728,
          'subdistrict_name': 'Garut Kota',
          'district_id': 126,
          'district_name': 'Kabupaten Garut',
        },
        totalAthleteInClub: 15,
        training: {
          'address': 'GOR Ciateul',
          'subdistrict_id': 1729,
          'subdistrict_name': 'Tarogong Kidul',
          'district_id': 126,
          'district_name': 'Kabupaten Garut',
        },
        fileSk: 'https://sicabor.test/files/sk-029.pdf',
        officials: {'data_available': false, 'reason': 'NOT_RECORDED'},
        coaches: {'data_available': false, 'reason': 'NOT_RECORDED'},
        management: {'data_available': true, 'partial': true, 'source': 'head'},
      );

      final json = item1.toJson();
      final item2 = SicaborClubDetailItem.fromJson(json);

      expect(item1, equals(item2));
      expect(item1.hashCode, equals(item2.hashCode));
    });
  });

  group('SicaborListEnvelope & SicaborDetailEnvelope with Club DTOs', () {
    test('SicaborListEnvelope parses Club items list', () {
      final json = {
        'success': true,
        'message': 'Berhasil mengambil daftar club.',
        'scope': {
          'subdistrict_id': 1728,
          'subdistrict_name': 'Garut Kota',
          'district_id': 126,
          'district_name': 'Garut',
        },
        'meta': {'limit': 25, 'offset': 0, 'total': 1},
        'data': [
          {
            'id': 29,
            'code': 'KGCL-0029',
            'name': 'BAJA FIGHT ACADEMY',
            'logo': null,
            'cabor': {'id': 22, 'code': 'KGCB-0023', 'name': 'MUAYTHAI'},
            'head_name': 'Djaka umaran',
            'phone': '089630325024',
            'email': 'bajafight@gmail.com',
            'since': '2022',
            'no_sk': '',
            'status': 0,
            'status_label': 'Belum Aktif',
            'secretariat': {
              'address': 'Jl. A. Yani, Kp. Ciwalen',
              'subdistrict_id': 1728,
              'subdistrict_name': 'Garut Kota',
              'district_id': 126,
              'district_name': 'Kabupaten Garut',
            },
            'total_athlete_in_club': 0,
          },
        ],
      };

      final envelope = SicaborListEnvelope<SicaborClubItem>.fromJson(
        json,
        SicaborClubItem.fromJson,
      );

      expect(envelope.success, isTrue);
      expect(envelope.data.length, equals(1));
      expect(envelope.data.first.name, equals('BAJA FIGHT ACADEMY'));
    });

    test('SicaborDetailEnvelope parses ClubDetail item', () {
      final json = {
        'success': true,
        'message': 'Berhasil mengambil detail club.',
        'scope': {
          'subdistrict_id': 1728,
          'subdistrict_name': 'Garut Kota',
          'district_id': 126,
          'district_name': 'Garut',
        },
        'data': {
          'id': 29,
          'code': 'KGCL-0029',
          'name': 'BAJA FIGHT ACADEMY',
          'logo': 'https://sicabor.test/logo/baja.png',
          'cabor': {'id': 22, 'code': 'KGCB-0023', 'name': 'MUAYTHAI'},
          'head_name': 'Djaka umaran',
          'phone': '089630325024',
          'email': 'bajafight@gmail.com',
          'since': '2022',
          'no_sk': 'SK-029/2022',
          'status': 1,
          'status_label': 'Aktif',
          'secretariat': {
            'address': 'Jl. A. Yani, Kp. Ciwalen',
            'subdistrict_id': 1728,
            'subdistrict_name': 'Garut Kota',
            'district_id': 126,
            'district_name': 'Kabupaten Garut',
          },
          'total_athlete_in_club': 15,
          'training': null,
          'file_sk': null,
          'officials': {'data_available': false, 'items': []},
          'coaches': {'data_available': false, 'items': []},
          'management': {'data_available': true, 'partial': true, 'items': []},
        },
      };

      final envelope = SicaborDetailEnvelope<SicaborClubDetailItem>.fromJson(
        json,
        SicaborClubDetailItem.fromJson,
      );

      expect(envelope.success, isTrue);
      expect(envelope.data.id, equals(29));
      expect(envelope.data.name, equals('BAJA FIGHT ACADEMY'));
    });
  });
}
