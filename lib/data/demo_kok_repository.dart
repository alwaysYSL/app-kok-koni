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

  KokSnapshot _snapshotForScope(AccessScope scope) {
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

  List<KokSnapshot> _detailSnapshots() => [
    _buildGarutKotaSnapshot(),
    _buildTarogongKidulSnapshot(),
  ];

  String _normalized(String value) => value.trim().toLowerCase();

  @override
  Future<List<Club>> fetchClubs(
    AccessScope scope, {
    String? sport,
    String? query,
    RequestCancellation? cancellation,
  }) async {
    cancellation?.throwIfCancelled();
    await _maybeDelay();
    cancellation?.throwIfCancelled();

    final normalizedSport = sport == null ? null : _normalized(sport);
    final normalizedQuery = query == null ? null : _normalized(query);
    final clubs = _snapshotForScope(scope).clubs.where((club) {
      final sportMatches =
          normalizedSport == null || _normalized(club.sport) == normalizedSport;
      if (!sportMatches) return false;
      if (normalizedQuery == null || normalizedQuery.isEmpty) return true;

      final haystack = [
        club.name,
        club.sport,
        club.village,
      ].map(_normalized).join(' ');
      return haystack.contains(normalizedQuery);
    }).toList();

    return List<Club>.of(clubs);
  }

  @override
  Future<Club> fetchClubDetail(
    String clubId, {
    RequestCancellation? cancellation,
  }) async {
    cancellation?.throwIfCancelled();
    await _maybeDelay();
    cancellation?.throwIfCancelled();

    for (final snapshot in _detailSnapshots()) {
      for (final club in snapshot.clubs) {
        if (club.id == clubId) return club;
      }
    }
    throw KokResourceNotFoundException('club', clubId);
  }

  @override
  Future<List<SportPerson>> fetchClubMembers(
    String clubId, {
    String? role,
    RequestCancellation? cancellation,
  }) async {
    cancellation?.throwIfCancelled();
    await _maybeDelay();
    cancellation?.throwIfCancelled();

    final people = <SportPerson>[];
    var clubFound = false;
    for (final snapshot in _detailSnapshots()) {
      if (snapshot.clubs.any((club) => club.id == clubId)) {
        clubFound = true;
        people.addAll(
          snapshot.people.where((person) => person.clubId == clubId),
        );
      }
    }
    if (!clubFound) {
      throw KokResourceNotFoundException('club', clubId);
    }

    final normalizedRole = role == null ? null : _normalized(role);
    final filtered = normalizedRole == null || normalizedRole.isEmpty
        ? people
        : people
              .where((person) => _normalized(person.role) == normalizedRole)
              .toList();
    return List<SportPerson>.of(filtered);
  }

  @override
  Future<SportPerson> fetchPersonDetail(
    String personId, {
    RequestCancellation? cancellation,
  }) async {
    cancellation?.throwIfCancelled();
    await _maybeDelay();
    cancellation?.throwIfCancelled();

    for (final snapshot in _detailSnapshots()) {
      for (final person in snapshot.people) {
        if (person.id == personId) return person;
      }
    }
    throw KokResourceNotFoundException('person', personId);
  }

  @override
  Future<List<CommitteeMember>> fetchCommittee(
    AccessScope scope, {
    RequestCancellation? cancellation,
  }) async {
    cancellation?.throwIfCancelled();
    await _maybeDelay();
    cancellation?.throwIfCancelled();

    return List<CommitteeMember>.of(_snapshotForScope(scope).committee);
  }

  @override
  Future<HelpdeskContact?> fetchHelpdesk({
    RequestCancellation? cancellation,
  }) async {
    cancellation?.throwIfCancelled();
    await _maybeDelay();
    cancellation?.throwIfCancelled();

    return _buildGarutKotaSnapshot().helpdesk;
  }

  @override
  Future<KokSnapshot> fetchScope(
    AccessScope scope, {
    RequestCancellation? cancellation,
  }) async {
    cancellation?.throwIfCancelled();
    await _maybeDelay();
    cancellation?.throwIfCancelled();

    return _snapshotForScope(scope);
  }

  KokSnapshot _buildGarutKotaSnapshot() {
    final clubs = [
      Club(
        id: 'garuda',
        name: 'Klub Garuda Muda',
        sport: 'Sepak Bola',
        village: 'Pakuwon',
        brandPrimaryHex: '#5B566E',
        brandSecondaryHex: '#11294B',
        phone: '081234567890',
        email: 'garuda@example.test',
        address: 'Jl. Pakuwon No. 10, Kecamatan Garut Kota',
        documents: [
          ClubDocument(
            id: 'garuda-sk-klub',
            name: 'SK Klub',
            status: 'verified',
            fileUrl: 'https://demo.invalid/documents/garuda-sk-klub.pdf',
            uploadedAt: DateTime(2026, 1, 10),
            verifiedAt: DateTime(2026, 1, 11),
          ),
          ClubDocument(
            id: 'garuda-kepengurusan',
            name: 'Kepengurusan',
            status: 'pending-review',
          ),
        ],
      ),
      Club(
        id: 'pb',
        name: 'PB Citra Garut',
        sport: 'Bulu Tangkis',
        village: 'Paminggir',
        brandPrimaryHex: '#A51D2A',
        brandSecondaryHex: '#670A13',
        phone: '081298765432',
        email: 'citra@example.test',
        address: 'Jl. Paminggir No. 4, Kecamatan Garut Kota',
      ),
      Club(
        id: 'silat',
        name: 'Silat Panglipur',
        sport: 'Pencak Silat',
        village: 'Regol',
        address: 'Jl. Regol No. 7, Kecamatan Garut Kota',
      ),
      Club(
        id: 'voli',
        name: 'Voli Bina Muda',
        sport: 'Bola Voli',
        village: 'Pakuwon',
        brandPrimaryHex: '#F3B51B',
        brandSecondaryHex: '#8F6100',
        phone: '081211223344',
      ),
      Club(
        id: 'tirta',
        name: 'Tirta Kencana',
        sport: 'Renang',
        village: 'Paminggir',
        active: false,
        email: 'tirta@example.test',
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
            nik: c == 0 && i == 0 ? '3205010101010001' : null,
            birthPlace: c == 0 && i == 0 ? 'Garut' : null,
            birthDate: c == 0 && i == 0 ? DateTime(2008, 5, 1) : null,
            address: c == 0 && i == 0 ? 'Jl. Cikuray No. 5, Garut' : null,
            verified: !(c == 0 && i < 8),
            missingDocuments: c == 0 && i < 8
                ? ['Kartu Keluarga', 'Akta kelahiran']
                : [],
            milestones: c == 0 && i == 0
                ? const [
                    Milestone(
                      year: '2025',
                      title: 'Kejuaraan Antar Klub',
                      description: 'Juara dua tingkat kabupaten.',
                    ),
                  ]
                : const [],
            requiredDocuments: c == 0 && i == 0
                ? const ['KTP', 'Kartu Keluarga', 'Akta kelahiran']
                : const [],
            completedDocuments: c == 0 && i == 0
                ? const ['KTP', 'Kartu Keluarga']
                : const [],
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
          phone: '081200000001',
          email: 'asep@example.test',
        ),
        CommitteeMember(
          id: 'wakil',
          name: 'Dedi (contoh)',
          position: 'Wakil Ketua',
          division: 'Pengurus inti',
          phone: '081200000002',
          email: 'dedi@example.test',
        ),
        CommitteeMember(
          id: 'sekretaris',
          name: 'Rina (contoh)',
          position: 'Sekretaris',
          division: 'Pengurus inti',
          phone: '081200000003',
          email: 'rina@example.test',
        ),
        CommitteeMember(
          id: 'bendahara',
          name: 'Siti (contoh)',
          position: 'Bendahara',
          division: 'Pengurus inti',
          phone: '081200000004',
          email: 'siti@example.test',
        ),
        CommitteeMember(
          id: 'pembinaan',
          name: 'Hendra (contoh)',
          position: 'Koordinator Pembinaan',
          division: 'Pembinaan prestasi',
          phone: '081200000005',
          email: 'hendra@example.test',
        ),
      ],
      helpdesk: const HelpdeskContact(
        whatsapp: '081299999999',
        phone: '0262234567',
        email: 'helpdesk@koni-garut.example.test',
        address: 'Sekretariat KONI Kabupaten Garut',
        operationalHours: 'Senin–Jumat, 08.00–16.00',
      ),
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
        phone: '081300000001',
        email: 'utama@example.test',
        address: 'Jl. Sukagalih No. 1, Tarogong Kidul',
      ),
      Club(
        id: 'club-tk-2',
        name: 'PB Surya Tarogong',
        sport: 'Bulu Tangkis',
        village: 'Haurpanggung',
        brandPrimaryHex: '#047857',
        brandSecondaryHex: '#064E3B',
        phone: '081300000002',
      ),
      Club(
        id: 'club-tk-3',
        name: 'Putra Tarogong Silat',
        sport: 'Pencak Silat',
        village: 'Jayawaras',
        brandPrimaryHex: '#B45309',
        brandSecondaryHex: '#78350F',
        address: 'Jl. Jayawaras No. 3, Tarogong Kidul',
      ),
      Club(
        id: 'club-tk-4',
        name: 'Voli Gemilang Tarogong',
        sport: 'Bola Voli',
        village: 'Patarruman',
        brandPrimaryHex: '#7C3AED',
        brandSecondaryHex: '#4C1D95',
        email: 'gemilang@example.test',
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
            nik: c == 0 && i == 0 ? '3205010202020001' : null,
            birthPlace: c == 0 && i == 0 ? 'Garut' : null,
            birthDate: c == 0 && i == 0 ? DateTime(2007, 8, 17) : null,
            address: c == 0 && i == 0 ? 'Jl. Sukagalih No. 2, Garut' : null,
            verified: true,
            missingDocuments: const [],
            milestones: c == 0 && i == 0
                ? const [Milestone(year: '2024', title: 'Liga Pelajar')]
                : const [],
            requiredDocuments: c == 0 && i == 0
                ? const ['KTP', 'Kartu Keluarga']
                : const [],
            completedDocuments: c == 0 && i == 0 ? const ['KTP'] : const [],
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
          phone: '081300000010',
          email: 'cecep@example.test',
        ),
        CommitteeMember(
          id: 'sekretaris-tk',
          name: 'Dewi (contoh)',
          position: 'Sekretaris',
          division: 'Pengurus inti',
          phone: '081300000011',
          email: 'dewi@example.test',
        ),
      ],
      helpdesk: const HelpdeskContact(
        whatsapp: '081299999999',
        phone: '0262234567',
        email: 'helpdesk@koni-garut.example.test',
        address: 'Sekretariat KONI Kabupaten Garut',
        operationalHours: 'Senin–Jumat, 08.00–16.00',
      ),
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
      helpdesk: gk.helpdesk,
    );
  }
}
