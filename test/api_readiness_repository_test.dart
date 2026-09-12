import 'package:flutter_test/flutter_test.dart';
import 'package:kok_app/core/auth/domain/user_principal.dart';
import 'package:kok_app/data/demo_kok_repository.dart';
import 'package:kok_app/data/kok_repository.dart';
import 'package:kok_app/data/request_cancellation.dart';

void main() {
  const garutKotaScope = AccessScope(
    type: AccessScopeType.district,
    id: 'garut_kota',
    name: 'Kecamatan Garut Kota',
  );

  group('DemoKokRepository granular API-ready queries', () {
    test('fetchClubs menerapkan scope, filter cabor, dan query', () async {
      final repo = DemoKokRepository(simulateLatency: false);

      final clubs = await repo.fetchClubs(
        garutKotaScope,
        sport: 'Sepak Bola',
        query: ' GARUDA ',
      );

      expect(clubs.map((club) => club.id), ['garuda']);
      expect(clubs.single.phone, isNotNull);
    });

    test(
      'fetchClubs memperlakukan sport yang hanya berisi spasi sebagai tanpa filter',
      () async {
        final clubs = await DemoKokRepository(
          simulateLatency: false,
        ).fetchClubs(garutKotaScope, sport: '   ');

        expect(clubs.map((club) => club.id), [
          'garuda',
          'pb',
          'silat',
          'voli',
          'tirta',
        ]);
      },
    );

    test('fetchClubs mengembalikan defensive copy', () async {
      final repo = DemoKokRepository(simulateLatency: false);

      final clubs = await repo.fetchClubs(garutKotaScope);
      clubs.clear();

      expect((await repo.fetchClubs(garutKotaScope)), hasLength(5));
    });

    test(
      'detail query melempar not-found untuk ID yang tidak dikenal',
      () async {
        final repo = DemoKokRepository(simulateLatency: false);

        expect(
          () => repo.fetchClubDetail('missing-club'),
          throwsA(isA<KokResourceNotFoundException>()),
        );
        expect(
          () => repo.fetchPersonDetail('missing-person'),
          throwsA(isA<KokResourceNotFoundException>()),
        );
      },
    );

    test(
      'detail query mengembalikan field kontak dan dokumen fixture',
      () async {
        final repo = DemoKokRepository(simulateLatency: false);
        final club = await repo.fetchClubDetail('garuda');
        final person = await repo.fetchPersonDetail('garuda-atlet-0');

        expect(club.email, 'garuda@example.test');
        expect(club.address, isNotNull);
        expect(club.documents, hasLength(2));
        expect(person.nik, isNotNull);
        expect(person.completedDocuments, contains('KTP'));
        expect(person.milestones.single.year, '2025');
      },
    );

    test('fetchClubMembers dapat difilter berdasarkan role', () async {
      final members = await DemoKokRepository(
        simulateLatency: false,
      ).fetchClubMembers('garuda', role: 'Pelatih');

      expect(members, isNotEmpty);
      expect(members.every((person) => person.role == 'Pelatih'), isTrue);
      expect(members, hasLength(2));
      expect(members.first.id, 'garuda-pelatih-0');
    });

    test('fetchPersonDetail mengembalikan detail orang dari fixture', () async {
      final person = await DemoKokRepository(
        simulateLatency: false,
      ).fetchPersonDetail('garuda-atlet-0');

      expect(person.clubId, 'garuda');
      expect(person.birthDate, isNotNull);
      expect(person.milestones, isNotEmpty);
      expect(person.requiredDocuments, isNotEmpty);
    });

    test('committee mengikuti scope dan helpdesk tersedia', () async {
      final repo = DemoKokRepository(simulateLatency: false);

      final committee = await repo.fetchCommittee(garutKotaScope);
      final countyCommittee = await repo.fetchCommittee(
        const AccessScope(
          type: AccessScopeType.county,
          id: 'koni_kab',
          name: 'KONI Kabupaten Garut',
        ),
      );
      final helpdesk = await repo.fetchHelpdesk();

      expect(committee, isNotEmpty);
      expect(countyCommittee.length, greaterThan(committee.length));
      expect(committee.first.phone, isNotNull);
      expect(helpdesk, isNotNull);
      expect(helpdesk?.whatsapp, isNotNull);

      expect(
        () => repo.fetchCommittee(
          const AccessScope(
            type: AccessScopeType.district,
            id: 'unknown',
            name: 'Unknown',
          ),
        ),
        throwsA(isA<UnsupportedScopeException>()),
      );
    });

    test('query granular menghormati cancellation sebelum request', () async {
      final controller = RequestCancellationController()..cancel('dibatalkan');

      expect(
        () => DemoKokRepository(
          simulateLatency: false,
        ).fetchClubs(garutKotaScope, cancellation: controller.token),
        throwsA(isA<RequestCancelledException>()),
      );
    });

    test('query granular menghormati cancellation setelah latency', () async {
      final controller = RequestCancellationController();
      final future = DemoKokRepository(
        simulateLatency: true,
      ).fetchClubs(garutKotaScope, cancellation: controller.token);
      controller.cancel('dibatalkan saat request berjalan');

      expect(future, throwsA(isA<RequestCancelledException>()));
    });
  });
}
