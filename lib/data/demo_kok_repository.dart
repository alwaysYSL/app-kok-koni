import '../core/auth/domain/user_principal.dart';
import 'kok_repository.dart';
import 'models.dart';
import 'request_cancellation.dart';

class DemoKokRepository implements KokRepository {
  final bool simulateLatency;

  DemoKokRepository({this.simulateLatency = true});

  Future<void> _maybeDelay() async {
    if (simulateLatency) {
      await Future<void>.delayed(const Duration(milliseconds: 300));
    }
  }

  @override
  Future<KokSnapshot> fetchScope(
    AccessScope scope, {
    RequestCancellation? cancellation,
  }) async {
    cancellation?.throwIfCancelled();
    await _maybeDelay();
    cancellation?.throwIfCancelled();

    if (scope.type == AccessScopeType.district && scope.id == 'garut_kota') {
      return _buildGarutKotaSnapshot();
    }
    if (scope.type == AccessScopeType.district &&
        scope.id == 'tarogong_kidul') {
      return _buildTarogongKidulSnapshot();
    }
    if (scope.type == AccessScopeType.county && scope.id == 'koni_kab') {
      return _buildCountySnapshot();
    }

    throw UnsupportedScopeException(scope);
  }

  KokSnapshot _buildGarutKotaSnapshot() {
    const clubs = [
      Club(
        id: 'garuda',
        name: 'Klub Garuda Muda',
        sport: 'Sepak Bola',
        village: 'Pakuwon',
        brandPrimaryHex: '#5B566E',
        brandSecondaryHex: '#11294B',
      ),
      Club(
        id: 'pb',
        name: 'PB Citra Garut',
        sport: 'Bulu Tangkis',
        village: 'Paminggir',
        brandPrimaryHex: '#A51D2A',
        brandSecondaryHex: '#670A13',
      ),
      Club(
        id: 'silat',
        name: 'Silat Panglipur',
        sport: 'Pencak Silat',
        village: 'Regol',
      ),
      Club(
        id: 'voli',
        name: 'Voli Bina Muda',
        sport: 'Bola Voli',
        village: 'Pakuwon',
        brandPrimaryHex: '#F3B51B',
        brandSecondaryHex: '#8F6100',
      ),
      Club(
        id: 'tirta',
        name: 'Tirta Kencana',
        sport: 'Renang',
        village: 'Paminggir',
        active: false,
      ),
    ];

    final people = <SportPerson>[];
    final athleteCounts = [34, 21, 44, 18, 8];
    for (var c = 0; c < clubs.length; c++) {
      for (var i = 0; i < athleteCounts[c]; i++) {
        people.add(
          SportPerson(
            id: '${clubs[c].id}-atlet-$i',
            name: 'Atlet ${i + 1} · ${clubs[c].name.replaceFirst('Klub ', '')}',
            clubId: clubs[c].id,
            role: 'Atlet',
            group: i.isEven ? 'U-18' : 'U-16',
            gender: i.isEven ? 'L' : 'P',
            age: 15 + (i % 4),
            verified: !(c == 0 && i < 8),
            missingDocuments: c == 0 && i < 8
                ? ['Kartu Keluarga', 'Akta kelahiran']
                : [],
          ),
        );
      }
      for (var i = 0; i < 2; i++) {
        people.add(
          SportPerson(
            id: '${clubs[c].id}-pelatih-$i',
            name: 'Pelatih ${i + 1} · ${clubs[c].name}',
            clubId: clubs[c].id,
            role: 'Pelatih',
            group: 'Lisensi C',
            expiredLicense: i == 0,
          ),
        );
      }
      people.add(
        SportPerson(
          id: '${clubs[c].id}-official',
          name: 'Official · ${clubs[c].name}',
          clubId: clubs[c].id,
          role: 'Official',
          group: 'Manajer tim',
        ),
      );
    }

    return KokSnapshot(
      scope: const AccessScope(
        type: AccessScopeType.district,
        id: 'garut_kota',
        name: 'Kecamatan Garut Kota',
      ),
      clubs: clubs,
      people: people,
      loadedAt: DateTime.now(),
      committee: const [
        CommitteeMember(
          id: 'ketua',
          name: 'Asep (contoh)',
          position: 'Ketua KOK',
          division: 'Pengurus inti',
        ),
        CommitteeMember(
          id: 'wakil',
          name: 'Dedi (contoh)',
          position: 'Wakil Ketua',
          division: 'Pengurus inti',
        ),
        CommitteeMember(
          id: 'sekretaris',
          name: 'Rina (contoh)',
          position: 'Sekretaris',
          division: 'Pengurus inti',
        ),
        CommitteeMember(
          id: 'bendahara',
          name: 'Siti (contoh)',
          position: 'Bendahara',
          division: 'Pengurus inti',
        ),
        CommitteeMember(
          id: 'pembinaan',
          name: 'Hendra (contoh)',
          position: 'Koordinator Pembinaan',
          division: 'Pembinaan prestasi',
        ),
      ],
    );
  }

  KokSnapshot _buildTarogongKidulSnapshot() {
    const tkClubs = [
      Club(
        id: 'club-tk-1',
        name: 'Tarogong Kidul Utama FC',
        sport: 'Sepak Bola',
        village: 'Sukagalih',
        brandPrimaryHex: '#1E3A8A',
        brandSecondaryHex: '#172554',
      ),
      Club(
        id: 'club-tk-2',
        name: 'PB Surya Tarogong',
        sport: 'Bulu Tangkis',
        village: 'Haurpanggung',
        brandPrimaryHex: '#047857',
        brandSecondaryHex: '#064E3B',
      ),
      Club(
        id: 'club-tk-3',
        name: 'Putra Tarogong Silat',
        sport: 'Pencak Silat',
        village: 'Jayawaras',
        brandPrimaryHex: '#B45309',
        brandSecondaryHex: '#78350F',
      ),
      Club(
        id: 'club-tk-4',
        name: 'Voli Gemilang Tarogong',
        sport: 'Bola Voli',
        village: 'Patarruman',
        brandPrimaryHex: '#7C3AED',
        brandSecondaryHex: '#4C1D95',
      ),
    ];

    final tkPeople = <SportPerson>[];
    final tkAthleteCounts = [26, 22, 24, 16];
    for (var c = 0; c < tkClubs.length; c++) {
      for (var i = 0; i < tkAthleteCounts[c]; i++) {
        tkPeople.add(
          SportPerson(
            id: '${tkClubs[c].id}-atlet-$i',
            name:
                'Atlet ${i + 1} · ${tkClubs[c].name.replaceFirst('Klub ', '')}',
            clubId: tkClubs[c].id,
            role: 'Atlet',
            group: i.isEven ? 'U-18' : 'U-16',
            gender: i.isEven ? 'L' : 'P',
            age: 15 + (i % 4),
            verified: true,
            missingDocuments: const [],
          ),
        );
      }
      for (var i = 0; i < 2; i++) {
        tkPeople.add(
          SportPerson(
            id: '${tkClubs[c].id}-pelatih-$i',
            name: 'Pelatih ${i + 1} · ${tkClubs[c].name}',
            clubId: tkClubs[c].id,
            role: 'Pelatih',
            group: 'Lisensi C',
            expiredLicense: false,
          ),
        );
      }
      tkPeople.add(
        SportPerson(
          id: '${tkClubs[c].id}-official',
          name: 'Official · ${tkClubs[c].name}',
          clubId: tkClubs[c].id,
          role: 'Official',
          group: 'Manajer tim',
        ),
      );
    }

    return KokSnapshot(
      scope: const AccessScope(
        type: AccessScopeType.district,
        id: 'tarogong_kidul',
        name: 'Kecamatan Tarogong Kidul',
      ),
      clubs: tkClubs,
      people: tkPeople,
      loadedAt: DateTime.now(),
      committee: const [
        CommitteeMember(
          id: 'ketua-tk',
          name: 'Cecep (contoh)',
          position: 'Ketua KOK',
          division: 'Pengurus inti',
        ),
        CommitteeMember(
          id: 'sekretaris-tk',
          name: 'Dewi (contoh)',
          position: 'Sekretaris',
          division: 'Pengurus inti',
        ),
      ],
    );
  }

  KokSnapshot _buildCountySnapshot() {
    final gk = _buildGarutKotaSnapshot();
    final tk = _buildTarogongKidulSnapshot();

    return KokSnapshot(
      scope: const AccessScope(
        type: AccessScopeType.county,
        id: 'koni_kab',
        name: 'KONI Kabupaten Garut',
      ),
      clubs: [...gk.clubs, ...tk.clubs],
      people: [...gk.people, ...tk.people],
      committee: [...gk.committee, ...tk.committee],
      loadedAt: DateTime.now(),
    );
  }
}
