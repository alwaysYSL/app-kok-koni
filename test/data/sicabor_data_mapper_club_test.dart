import 'package:flutter_test/flutter_test.dart';
import 'package:kok_app/data/dto/sicabor_club_detail_item.dart';
import 'package:kok_app/data/dto/sicabor_club_item.dart';
import 'package:kok_app/data/mapper/sicabor_data_mapper.dart';
import 'package:kok_app/data/models/club.dart';
import 'package:kok_app/data/models/club_detail.dart';

void main() {
  group('SicaborDataMapper Club Tests', () {
    const mapper = SicaborDataMapper();

    test(
      'mapClub correctly maps complete SicaborClubItem to Club domain model',
      () {
        const dto = SicaborClubItem(
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
            'address': 'Jl. A. Yani, Kp. Ciwalen Gg. Sulaeman',
            'subdistrict_id': 1728,
            'subdistrict_name': 'Garut Kota',
            'district_id': 126,
            'district_name': 'Kabupaten Garut',
          },
          totalAthleteInClub: 15,
        );

        final domain = mapper.mapClub(dto);

        expect(
          domain,
          equals(
            const Club(
              id: 29,
              code: 'KGCL-0029',
              name: 'BAJA FIGHT ACADEMY',
              logoUrl: 'https://sicabor.test/logo/baja.png',
              cabor: ClubCabor(id: 22, code: 'KGCB-0023', name: 'MUAYTHAI'),
              headName: 'Djaka umaran',
              phone: '089630325024',
              email: 'bajafight@gmail.com',
              since: '2022',
              noSk: 'SK-029/2022',
              status: 1,
              statusLabel: 'Aktif',
              secretariat: ClubAddress(
                address: 'Jl. A. Yani, Kp. Ciwalen Gg. Sulaeman',
                subdistrictId: 1728,
                subdistrictName: 'Garut Kota',
                districtId: 126,
                districtName: 'Kabupaten Garut',
              ),
              totalAthleteInClub: 15,
            ),
          ),
        );
      },
    );

    test(
      'mapClub correctly maps SicaborClubItem with null optional fields',
      () {
        const dto = SicaborClubItem(
          id: 30,
          code: 'KGCL-0030',
          name: 'GARUT RUNNERS',
          logo: null,
          cabor: {'id': 10, 'code': 'KGCB-0010', 'name': 'ATLETIK'},
          headName: null,
          phone: null,
          email: null,
          since: null,
          noSk: null,
          status: 0,
          statusLabel: 'Belum Aktif',
          secretariat: {
            'address': null,
            'subdistrict_id': 1728,
            'subdistrict_name': 'Garut Kota',
            'district_id': 126,
            'district_name': 'Kabupaten Garut',
          },
          totalAthleteInClub: 0,
        );

        final domain = mapper.mapClub(dto);

        expect(domain.id, equals(30));
        expect(domain.logoUrl, isNull);
        expect(domain.headName, isNull);
        expect(domain.phone, isNull);
        expect(domain.email, isNull);
        expect(domain.since, isNull);
        expect(domain.noSk, isNull);
        expect(domain.secretariat.address, isNull);
        expect(domain.status, equals(0));
        expect(domain.totalAthleteInClub, equals(0));
      },
    );

    test('mapClub handles string numbers inside nested maps', () {
      const dto = SicaborClubItem(
        id: 31,
        code: 'KGCL-0031',
        name: 'KLUB RENANG',
        cabor: {'id': '15', 'code': 'KGCB-0015', 'name': 'RENANG'},
        status: 1,
        statusLabel: 'Aktif',
        secretariat: {
          'subdistrict_id': '1728',
          'subdistrict_name': 'Garut Kota',
          'district_id': '126',
          'district_name': 'Garut',
        },
        totalAthleteInClub: 8,
      );

      final domain = mapper.mapClub(dto);

      expect(domain.cabor.id, equals(15));
      expect(domain.secretariat.subdistrictId, equals(1728));
      expect(domain.secretariat.districtId, equals(126));
    });

    test(
      'mapClubDetail correctly maps complete SicaborClubDetailItem with all blocks',
      () {
        const dto = SicaborClubDetailItem(
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
            'address': 'Jl. A. Yani, Kp. Ciwalen Gg. Sulaeman',
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
          officials: {
            'data_available': false,
            'reason': 'NOT_RECORDED_IN_SYSTEM',
            'data': [],
          },
          coaches: {
            'data_available': false,
            'reason': 'NOT_RECORDED_IN_SYSTEM',
            'data': [],
          },
          management: {
            'data_available': true,
            'partial': true,
            'source': 'club.head_name',
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
        );

        final domain = mapper.mapClubDetail(dto);

        expect(
          domain,
          equals(
            const ClubDetail(
              id: 29,
              code: 'KGCL-0029',
              name: 'BAJA FIGHT ACADEMY',
              logoUrl: 'https://sicabor.test/logo/baja.png',
              cabor: ClubCabor(id: 22, code: 'KGCB-0023', name: 'MUAYTHAI'),
              headName: 'Djaka umaran',
              phone: '089630325024',
              email: 'bajafight@gmail.com',
              since: '2022',
              noSk: 'SK-029/2022',
              status: 1,
              statusLabel: 'Aktif',
              secretariat: ClubAddress(
                address: 'Jl. A. Yani, Kp. Ciwalen Gg. Sulaeman',
                subdistrictId: 1728,
                subdistrictName: 'Garut Kota',
                districtId: 126,
                districtName: 'Kabupaten Garut',
              ),
              totalAthleteInClub: 15,
              training: ClubAddress(
                address: 'GOR Ciateul',
                subdistrictId: 1729,
                subdistrictName: 'Tarogong Kidul',
                districtId: 126,
                districtName: 'Kabupaten Garut',
              ),
              fileSkUrl: 'https://sicabor.test/files/sk-029.pdf',
              officials: ClubPersonnelBlock(
                dataAvailable: false,
                reason: 'NOT_RECORDED_IN_SYSTEM',
                items: [],
              ),
              coaches: ClubPersonnelBlock(
                dataAvailable: false,
                reason: 'NOT_RECORDED_IN_SYSTEM',
                items: [],
              ),
              management: ClubManagementBlock(
                dataAvailable: true,
                partial: true,
                source: 'club.head_name',
                items: [
                  ClubPersonnelItem(
                    id: null,
                    name: 'Djaka umaran',
                    role: 'Ketua',
                    phone: '089630325024',
                    email: 'bajafight@gmail.com',
                    photoUrl: null,
                    source: 'club.head_name',
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    test(
      'mapClubDetail correctly maps SicaborClubDetailItem with null training and fileSk',
      () {
        const dto = SicaborClubDetailItem(
          id: 30,
          code: 'KGCL-0030',
          name: 'GARUT RUNNERS',
          cabor: {'id': 10, 'code': 'KGCB-0010', 'name': 'ATLETIK'},
          status: 0,
          statusLabel: 'Belum Aktif',
          secretariat: {
            'subdistrict_id': 1728,
            'subdistrict_name': 'Garut Kota',
            'district_id': 126,
            'district_name': 'Kabupaten Garut',
          },
          totalAthleteInClub: 0,
          training: null,
          fileSk: null,
          officials: {'data_available': false, 'items': []},
          coaches: {'data_available': false, 'items': []},
          management: {'data_available': false, 'partial': false, 'items': []},
        );

        final domain = mapper.mapClubDetail(dto);

        expect(domain.id, equals(30));
        expect(domain.training, isNull);
        expect(domain.fileSkUrl, isNull);
        expect(domain.officials.dataAvailable, isFalse);
        expect(domain.coaches.dataAvailable, isFalse);
        expect(domain.management.dataAvailable, isFalse);
        expect(domain.management.partial, isFalse);
      },
    );

    test('mapClubDetail handles items key and populated personnel blocks', () {
      const dto = SicaborClubDetailItem(
        id: 32,
        code: 'KGCL-0032',
        name: 'KLUB PERSATUAN',
        cabor: {'id': 1, 'code': 'C1', 'name': 'CABOR 1'},
        status: 1,
        statusLabel: 'Aktif',
        secretariat: {
          'subdistrict_id': 1728,
          'subdistrict_name': 'Garut Kota',
          'district_id': 126,
          'district_name': 'Garut',
        },
        totalAthleteInClub: 5,
        officials: {
          'data_available': true,
          'items': [
            {
              'id': 101,
              'name': 'Official A',
              'role': 'Manajer',
              'phone': '08123',
              'email': 'a@test.com',
              'photo_url': 'https://sicabor.test/photos/a.png',
              'source': 'cabor',
            },
          ],
        },
        coaches: {
          'data_available': true,
          'items': [
            {
              'id': '102',
              'name': 'Pelatih B',
              'role': 'Pelatih Fisik',
              'photo': 'https://sicabor.test/photos/b.png',
            },
          ],
        },
        management: {
          'data_available': true,
          'partial': false,
          'source': 'manual',
          'items': [
            {'id': 103, 'name': 'Pengurus C', 'role': 'Sekretaris'},
          ],
        },
      );

      final domain = mapper.mapClubDetail(dto);

      expect(domain.officials.dataAvailable, isTrue);
      expect(domain.officials.items.length, equals(1));
      expect(domain.officials.items.first.id, equals(101));
      expect(
        domain.officials.items.first.photoUrl,
        equals('https://sicabor.test/photos/a.png'),
      );

      expect(domain.coaches.dataAvailable, isTrue);
      expect(domain.coaches.items.length, equals(1));
      expect(domain.coaches.items.first.id, equals(102));
      expect(
        domain.coaches.items.first.photoUrl,
        equals('https://sicabor.test/photos/b.png'),
      );

      expect(domain.management.dataAvailable, isTrue);
      expect(domain.management.partial, isFalse);
      expect(domain.management.items.length, equals(1));
      expect(domain.management.items.first.id, equals(103));
    });
  });
}
