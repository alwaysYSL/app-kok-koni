import 'package:flutter_test/flutter_test.dart';
import 'package:kok_app/core/auth/data/dto/sicabor_profile_response.dart';
import 'package:kok_app/data/dto/sicabor_cabor_item.dart';
import 'package:kok_app/data/dto/sicabor_list_envelope.dart';
import 'package:kok_app/data/mapper/sicabor_data_mapper.dart';
import 'package:kok_app/data/models/cabor.dart';
import 'package:kok_app/data/models/profile_summary.dart';

void main() {
  group('SicaborCaborItem', () {
    test('fromJson correctly parses complete JSON', () {
      final json = {
        'id': 9,
        'code': 'KGCB-0010',
        'name': 'ARUNG JERAM',
        'group_name': 'FAJI',
        'logo': 'https://sicabor.test/logo.png',
        'status': 1,
        'status_label': 'Aktif',
        'total_club': 2,
        'total_athlete': 15,
      };

      final item = SicaborCaborItem.fromJson(json);

      expect(item.id, equals(9));
      expect(item.code, equals('KGCB-0010'));
      expect(item.name, equals('ARUNG JERAM'));
      expect(item.groupName, equals('FAJI'));
      expect(item.logo, equals('https://sicabor.test/logo.png'));
      expect(item.status, equals(1));
      expect(item.statusLabel, equals('Aktif'));
      expect(item.totalClub, equals(2));
      expect(item.totalAthlete, equals(15));
    });

    test('fromJson handles string numbers and nullable fields', () {
      final json = {
        'id': '9',
        'code': 'KGCB-0010',
        'name': 'ARUNG JERAM',
        'group_name': null,
        'logo': null,
        'status': '1',
        'status_label': 'Aktif',
        'total_club': '0',
        'total_athlete': '25',
      };

      final item = SicaborCaborItem.fromJson(json);

      expect(item.id, equals(9));
      expect(item.groupName, isNull);
      expect(item.logo, isNull);
      expect(item.status, equals(1));
      expect(item.totalClub, equals(0));
      expect(item.totalAthlete, equals(25));
    });

    test('toJson and equality work as expected', () {
      const item1 = SicaborCaborItem(
        id: 9,
        code: 'KGCB-0010',
        name: 'ARUNG JERAM',
        groupName: 'FAJI',
        logo: 'https://sicabor.test/logo.png',
        status: 1,
        statusLabel: 'Aktif',
        totalClub: 2,
        totalAthlete: 15,
      );

      final json = item1.toJson();
      final item2 = SicaborCaborItem.fromJson(json);

      expect(item1, equals(item2));
      expect(item1.hashCode, equals(item2.hashCode));
    });
  });

  group('SicaborPaginationMeta', () {
    test('fromJson parses full metadata including extra properties', () {
      final json = {
        'limit': 20,
        'offset': 40,
        'total': 100,
        'sort': 'name_asc',
      };

      final meta = SicaborPaginationMeta.fromJson(json);

      expect(meta.limit, equals(20));
      expect(meta.offset, equals(40));
      expect(meta.total, equals(100));
      expect(meta.extra['sort'], equals('name_asc'));
    });

    test('fromJson applies defaults for missing fields', () {
      final meta = SicaborPaginationMeta.fromJson(const {});

      expect(meta.limit, equals(25));
      expect(meta.offset, equals(0));
      expect(meta.total, equals(0));
      expect(meta.extra, isEmpty);
    });

    test('fromJson parses string numbers correctly', () {
      final json = {'limit': '15', 'offset': '30', 'total': '75'};

      final meta = SicaborPaginationMeta.fromJson(json);

      expect(meta.limit, equals(15));
      expect(meta.offset, equals(30));
      expect(meta.total, equals(75));
    });

    test('toJson and equality work as expected', () {
      const meta1 = SicaborPaginationMeta(
        limit: 10,
        offset: 20,
        total: 50,
        extra: {'query': 'karate'},
      );

      final json = meta1.toJson();
      final meta2 = SicaborPaginationMeta.fromJson(json);

      expect(meta1, equals(meta2));
      expect(meta1.hashCode, equals(meta2.hashCode));
    });
  });

  group('SicaborListEnvelope', () {
    test('fromJson parses generic list response with scope and meta', () {
      final json = {
        'success': true,
        'message': 'Berhasil mengambil daftar cabor.',
        'scope': {
          'subdistrict_id': 1728,
          'subdistrict_name': 'Garut Kota',
          'district_id': 126,
          'district_name': 'Garut',
        },
        'meta': {'limit': 25, 'offset': 0, 'total': 2},
        'data': [
          {
            'id': 1,
            'code': 'KGCB-0001',
            'name': 'ATLETIK',
            'group_name': 'PASI',
            'logo': null,
            'status': 1,
            'status_label': 'Aktif',
            'total_club': 3,
            'total_athlete': 20,
          },
          {
            'id': 2,
            'code': 'KGCB-0002',
            'name': 'BULUTANGKIS',
            'group_name': 'PBSI',
            'logo': 'https://sicabor.test/pbsi.png',
            'status': 1,
            'status_label': 'Aktif',
            'total_club': 5,
            'total_athlete': 42,
          },
        ],
      };

      final envelope = SicaborListEnvelope<SicaborCaborItem>.fromJson(
        json,
        SicaborCaborItem.fromJson,
      );

      expect(envelope.success, isTrue);
      expect(envelope.message, equals('Berhasil mengambil daftar cabor.'));
      expect(envelope.scope.subdistrictId, equals(1728));
      expect(envelope.scope.subdistrictName, equals('Garut Kota'));
      expect(envelope.meta.limit, equals(25));
      expect(envelope.meta.offset, equals(0));
      expect(envelope.meta.total, equals(2));
      expect(envelope.data.length, equals(2));
      expect(envelope.data.first.code, equals('KGCB-0001'));
      expect(envelope.data.last.code, equals('KGCB-0002'));
    });

    test('fromJson handles null or empty data gracefully', () {
      final json = {
        'success': true,
        'message': 'Data kosong',
        'scope': null,
        'meta': null,
        'data': null,
      };

      final envelope = SicaborListEnvelope<SicaborCaborItem>.fromJson(
        json,
        SicaborCaborItem.fromJson,
      );

      expect(envelope.success, isTrue);
      expect(envelope.data, isEmpty);
      expect(envelope.meta.limit, equals(25));
      expect(envelope.meta.offset, equals(0));
      expect(envelope.meta.total, equals(0));
      expect(envelope.scope.subdistrictId, equals(0));
    });
  });

  group('SicaborDataMapper', () {
    const mapper = SicaborDataMapper();

    test('mapCabor correctly maps SicaborCaborItem to domain Cabor model', () {
      const dto = SicaborCaborItem(
        id: 9,
        code: 'KGCB-0010',
        name: 'ARUNG JERAM',
        groupName: 'FAJI',
        logo: 'https://sicabor.test/logo.png',
        status: 1,
        statusLabel: 'Aktif',
        totalClub: 0,
        totalAthlete: 15,
      );

      final domain = mapper.mapCabor(dto);

      expect(
        domain,
        equals(
          const Cabor(
            id: 9,
            code: 'KGCB-0010',
            name: 'ARUNG JERAM',
            groupName: 'FAJI',
            logoUrl: 'https://sicabor.test/logo.png',
            status: 1,
            statusLabel: 'Aktif',
            totalClub: 0,
            totalAthlete: 15,
          ),
        ),
      );
    });

    test(
      'mapProfileSummary correctly maps SicaborProfileResponse to ProfileSummary model',
      () {
        const profileResponse = SicaborProfileResponse(
          success: true,
          message: 'Berhasil mengambil data.',
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
              email: 'admin@garutkota.id',
              type: 'admin_kok',
              status: 1,
              statusLabel: 'Aktif',
            ),
            kontingen: SicaborKontingen(
              id: 1,
              code: 'KGPK-0001',
              name: 'Garut Kota',
            ),
            summary: SicaborSummary(
              totalCabor: 32,
              totalCaborFromClub: 5,
              totalCaborFromAthlete: 31,
              totalClub: 10,
              totalAthlete: 361,
              totalAthleteWithoutClub: 320,
            ),
            dataNotes: ['Catatan batasan 1', 'Catatan batasan 2'],
          ),
        );

        final summary = mapper.mapProfileSummary(profileResponse);

        expect(
          summary,
          equals(
            const ProfileSummary(
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
                email: 'admin@garutkota.id',
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
              dataNotes: ['Catatan batasan 1', 'Catatan batasan 2'],
            ),
          ),
        );
      },
    );
  });
}
