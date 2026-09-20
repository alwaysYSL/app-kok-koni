import 'dart:math';

/// Representation of a user account in the SICABOR system.
class MockAccount {
  final int id;
  final String username;
  final String password;
  final String name;
  final String? email;
  final String type; // 'admin_kok', 'cabor', etc.
  final int status; // 1: active, 0: inactive
  final String statusLabel;
  final int? subdistrictId;
  final String? subdistrictName;
  final int districtId;
  final String districtName;
  final Map<String, dynamic>? kontingen;
  final Map<String, int> summary;
  final List<String> dataNotes;

  const MockAccount({
    required this.id,
    required this.username,
    required this.password,
    required this.name,
    this.email,
    required this.type,
    this.status = 1,
    this.statusLabel = 'Aktif',
    this.subdistrictId,
    this.subdistrictName,
    this.districtId = 126,
    this.districtName = 'Garut',
    this.kontingen,
    this.summary = const {},
    this.dataNotes = const [],
  });

  bool get isActive => status == 1;
  bool get isKok => type == 'admin_kok';
  bool get hasSubdistrict => subdistrictId != null;
}

/// Representation of a sport category (Cabang Olahraga).
class MockCabor {
  final int id;
  final String code;
  final String name;
  final String? groupName;
  final String? logo;
  final int status;
  final String statusLabel;

  const MockCabor({
    required this.id,
    required this.code,
    required this.name,
    this.groupName,
    this.logo,
    this.status = 1,
    this.statusLabel = 'Aktif',
  });
}

/// Representation of a sports club.
class MockClub {
  final int id;
  final String code;
  final String name;
  final String? logo;
  final int caborId;
  final String caborCode;
  final String caborName;
  final String headName;
  final String phone;
  final String email;
  final String since;
  final String noSk;
  final int status;
  final String statusLabel;
  final String secretariatAddress;
  final int secretariatSubdistrictId;
  final String secretariatSubdistrictName;
  final int secretariatDistrictId;
  final String secretariatDistrictName;
  final String trainingAddress;
  final int trainingSubdistrictId;
  final String trainingSubdistrictName;
  final int trainingDistrictId;
  final String trainingDistrictName;
  final String? fileSk;
  final int totalAthleteInClub;

  const MockClub({
    required this.id,
    required this.code,
    required this.name,
    this.logo,
    required this.caborId,
    required this.caborCode,
    required this.caborName,
    required this.headName,
    required this.phone,
    required this.email,
    required this.since,
    this.noSk = '',
    this.status = 1,
    this.statusLabel = 'Aktif',
    required this.secretariatAddress,
    required this.secretariatSubdistrictId,
    required this.secretariatSubdistrictName,
    this.secretariatDistrictId = 126,
    this.secretariatDistrictName = 'Kabupaten Garut',
    required this.trainingAddress,
    required this.trainingSubdistrictId,
    required this.trainingSubdistrictName,
    this.trainingDistrictId = 126,
    this.trainingDistrictName = 'Kabupaten Garut',
    this.fileSk,
    this.totalAthleteInClub = 0,
  });

  Map<String, dynamic> toListJson() => {
    'id': id,
    'code': code,
    'name': name,
    'logo': logo,
    'cabor': {'id': caborId, 'code': caborCode, 'name': caborName},
    'head_name': headName,
    'phone': phone,
    'email': email,
    'since': since,
    'no_sk': noSk,
    'status': status,
    'status_label': statusLabel,
    'secretariat': {
      'address': secretariatAddress,
      'subdistrict_id': secretariatSubdistrictId,
      'subdistrict_name': secretariatSubdistrictName,
      'district_id': secretariatDistrictId,
      'district_name': secretariatDistrictName,
    },
    'total_athlete_in_club': totalAthleteInClub,
  };

  Map<String, dynamic> toDetailJson() => {
    ...toListJson(),
    'training': {
      'address': trainingAddress,
      'subdistrict_id': trainingSubdistrictId,
      'subdistrict_name': trainingSubdistrictName,
      'district_id': trainingDistrictId,
      'district_name': trainingDistrictName,
    },
    'file_sk': fileSk,
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
          'name': headName,
          'role': 'Ketua',
          'phone': phone,
          'email': email,
          'photo': null,
          'source': 'club.head_name',
        },
      ],
    },
  };
}

/// Representation of an athlete.
class MockAthlete {
  final int id;
  final String code;
  final String name;
  final String sex; // 'l' or 'p'
  final String sexLabel; // 'Laki-Laki' or 'Perempuan'
  final String pob;
  final String dob;
  final int age;
  final String photo;
  final int status;
  final String statusLabel;
  final int caborId;
  final String caborCode;
  final String caborName;
  final int? clubId;
  final String? clubCode;
  final String? clubName;
  final int domicileSubdistrictId;
  final String domicileSubdistrictName;
  final int domicileDistrictId;
  final String domicileDistrictName;
  final String domicileVillage;
  final String phone;
  final String email;
  final int height;
  final int weight;
  final String bloodType;
  final String address;
  final String? nik;
  final String dateCreated;

  const MockAthlete({
    required this.id,
    required this.code,
    required this.name,
    required this.sex,
    required this.sexLabel,
    required this.pob,
    required this.dob,
    required this.age,
    required this.photo,
    this.status = 1,
    this.statusLabel = 'Aktif',
    required this.caborId,
    required this.caborCode,
    required this.caborName,
    this.clubId,
    this.clubCode,
    this.clubName,
    required this.domicileSubdistrictId,
    required this.domicileSubdistrictName,
    this.domicileDistrictId = 126,
    this.domicileDistrictName = 'Kabupaten Garut',
    required this.domicileVillage,
    this.phone = '081234567890',
    this.email = 'atlet@example.com',
    this.height = 170,
    this.weight = 65,
    this.bloodType = 'O',
    this.address = 'Garut',
    this.nik,
    this.dateCreated = '2024-01-01',
  });

  Map<String, dynamic> toListJson() => {
    'id': id,
    'code': code,
    'name': name,
    'sex': sex,
    'sex_label': sexLabel,
    'pob': pob,
    'dob': dob,
    'age': age,
    'photo': photo,
    'status': status,
    'status_label': statusLabel,
    'cabor': {'id': caborId, 'code': caborCode, 'name': caborName},
    'club': clubId == null
        ? null
        : {'id': clubId, 'code': clubCode, 'name': clubName},
    'domicile': {
      'subdistrict_id': domicileSubdistrictId,
      'subdistrict_name': domicileSubdistrictName,
      'district_id': domicileDistrictId,
      'district_name': domicileDistrictName,
      'village': domicileVillage,
    },
  };

  Map<String, dynamic> toDetailJson() => {
    ...toListJson(),
    'phone': phone,
    'email': email,
    'height': height,
    'weight': weight,
    'blood_type': bloodType,
    'address': address,
  };
}

/// In-memory Mock Data Store & Response Builder for SICABOR.
class MockData {
  /// Universal master password for all legitimate accounts.
  static const String globalMasterPassword = 'sicabor4K0N1';

  static int _tokenCounter = 1000;
  static final Map<String, MockAccount> _activeTokens = {};

  static final List<String> _defaultDataNotes = [
    'Cabor tidak memiliki data kecamatan sendiri; daftar ini diturunkan dari cabor yang memiliki club atau atlet di kecamatan ini.',
    'Jumlah cabor adalah gabungan unik dari cabor club dan cabor atlet.',
    'Club didasarkan pada alamat sekretariat, bukan tempat latihan.',
    'Atlet didasarkan pada domisili, bukan lokasi club.',
    'Keanggotaan club pada data atlet belum lengkap di sistem.',
  ];

  /// Pre-populated mock accounts.
  static final List<MockAccount> accounts = [
    MockAccount(
      id: 578,
      username: 'kt.garutkota',
      password: 'password123',
      name: 'ADMIN KONTINGEN GARUT KOTA',
      email: null,
      type: 'admin_kok',
      status: 1,
      statusLabel: 'Aktif',
      subdistrictId: 1728,
      subdistrictName: 'Garut Kota',
      districtId: 126,
      districtName: 'Garut',
      kontingen: null,
      summary: const {
        'total_cabor': 32,
        'total_cabor_from_club': 5,
        'total_cabor_from_athlete': 31,
        'total_club': 10,
        'total_athlete': 361,
        'total_athlete_without_club': 355,
      },
      dataNotes: _defaultDataNotes,
    ),
    MockAccount(
      id: 560,
      username: 'kt.bllimbangan',
      password: 'password123',
      name: 'ADMIN KONTINGEN BL.LIMBANGAN',
      email: null,
      type: 'admin_kok',
      status: 1,
      statusLabel: 'Aktif',
      subdistrictId: 1714,
      subdistrictName: 'Blubur Limbangan',
      districtId: 126,
      districtName: 'Garut',
      kontingen: const {
        'id': 3,
        'code': 'KGPK-0044',
        'name': 'Balubur Limbangan',
      },
      summary: const {
        'total_cabor': 17,
        'total_cabor_from_club': 0,
        'total_cabor_from_athlete': 17,
        'total_club': 0,
        'total_athlete': 159,
        'total_athlete_without_club': 159,
      },
      dataNotes: _defaultDataNotes,
    ),
    MockAccount(
      id: 561,
      username: 'kt.tarogongkidul',
      password: 'password123',
      name: 'ADMIN KONTINGEN TAROGONG KIDUL',
      email: null,
      type: 'admin_kok',
      status: 1,
      statusLabel: 'Aktif',
      subdistrictId: 1729,
      subdistrictName: 'Tarogong Kidul',
      districtId: 126,
      districtName: 'Garut',
      kontingen: const {'id': 4, 'code': 'KGPK-0045', 'name': 'Tarogong Kidul'},
      summary: const {
        'total_cabor': 28,
        'total_cabor_from_club': 8,
        'total_cabor_from_athlete': 26,
        'total_club': 12,
        'total_athlete': 290,
        'total_athlete_without_club': 280,
      },
      dataNotes: _defaultDataNotes,
    ),
    const MockAccount(
      id: 991,
      username: 'bukan_kok',
      password: 'password123',
      name: 'PENGURUS CABOR',
      email: null,
      type: 'cabor',
      status: 1,
      statusLabel: 'Aktif',
      subdistrictId: 1728,
      subdistrictName: 'Garut Kota',
      districtId: 126,
      districtName: 'Garut',
      kontingen: null,
      summary: {},
      dataNotes: [],
    ),
    const MockAccount(
      id: 992,
      username: 'non_aktif',
      password: 'password123',
      name: 'AKUN NONAKTIF',
      email: null,
      type: 'admin_kok',
      status: 0,
      statusLabel: 'Nonaktif',
      subdistrictId: 1728,
      subdistrictName: 'Garut Kota',
      districtId: 126,
      districtName: 'Garut',
      kontingen: null,
      summary: {},
      dataNotes: [],
    ),
    const MockAccount(
      id: 993,
      username: 'tanpa_kecamatan',
      password: 'password123',
      name: 'AKUN TANPA WILAYAH',
      email: null,
      type: 'admin_kok',
      status: 1,
      statusLabel: 'Aktif',
      subdistrictId: null,
      subdistrictName: null,
      districtId: 126,
      districtName: 'Garut',
      kontingen: null,
      summary: {},
      dataNotes: [],
    ),
  ];

  /// Master list of Cabang Olahraga.
  static final List<MockCabor> cabors = [
    const MockCabor(
      id: 1,
      code: 'KGCB-0001',
      name: 'ATLETIK',
      groupName: 'PASI',
    ),
    const MockCabor(
      id: 2,
      code: 'KGCB-0002',
      name: 'BOLA BASKET',
      groupName: 'PERBASI',
    ),
    const MockCabor(
      id: 3,
      code: 'KGCB-0003',
      name: 'BOLA VOLI',
      groupName: 'PBVSI',
    ),
    const MockCabor(
      id: 4,
      code: 'KGCB-0004',
      name: 'BULU TANGKIS',
      groupName: 'PBSI',
    ),
    const MockCabor(
      id: 5,
      code: 'KGCB-0005',
      name: 'CATUR',
      groupName: 'PERCASI',
    ),
    const MockCabor(
      id: 6,
      code: 'KGCB-0006',
      name: 'DAYUNG',
      groupName: 'PODSI',
    ),
    const MockCabor(id: 7, code: 'KGCB-0007', name: 'GULAT', groupName: 'PGSI'),
    const MockCabor(id: 8, code: 'KGCB-0008', name: 'JUDO', groupName: 'PJSI'),
    const MockCabor(
      id: 9,
      code: 'KGCB-0010',
      name: 'ARUNG JERAM',
      groupName: 'FAJI',
    ),
    const MockCabor(
      id: 10,
      code: 'KGCB-0011',
      name: 'KARATE',
      groupName: 'FORKI',
    ),
    const MockCabor(
      id: 11,
      code: 'KGCB-0012',
      name: 'MENEMBAK',
      groupName: 'PERBAKIN',
    ),
    const MockCabor(
      id: 12,
      code: 'KGCB-0013',
      name: 'PANAHAN',
      groupName: 'PERPANI',
    ),
    const MockCabor(
      id: 13,
      code: 'KGCB-0014',
      name: 'PANJAT TEBING',
      groupName: 'FPTI',
    ),
    const MockCabor(
      id: 14,
      code: 'KGCB-0015',
      name: 'PENCAK SILAT',
      groupName: 'IPSI',
    ),
    const MockCabor(
      id: 15,
      code: 'KGCB-0016',
      name: 'RENANG',
      groupName: 'PRSI',
    ),
    const MockCabor(
      id: 16,
      code: 'KGCB-0017',
      name: 'SEPAK BOLA',
      groupName: 'PSSI',
    ),
    const MockCabor(
      id: 17,
      code: 'KGCB-0018',
      name: 'SEPAK TAKRAW',
      groupName: 'PSTI',
    ),
    const MockCabor(
      id: 18,
      code: 'KGCB-0019',
      name: 'TAEKWONDO',
      groupName: 'TI',
    ),
    const MockCabor(
      id: 19,
      code: 'KGCB-0020',
      name: 'TARUNG DERAJAT',
      groupName: 'KODRAT',
    ),
    const MockCabor(
      id: 20,
      code: 'KGCB-0021',
      name: 'TENIS LAPANGAN',
      groupName: 'PELTI',
    ),
    const MockCabor(
      id: 21,
      code: 'KGCB-0022',
      name: 'TENIS MEJA',
      groupName: 'PTMSI',
    ),
    const MockCabor(
      id: 22,
      code: 'KGCB-0023',
      name: 'MUAYTHAI',
      groupName: 'MI',
    ),
    const MockCabor(
      id: 23,
      code: 'KGCB-0024',
      name: 'TINJU',
      groupName: 'PERTINA',
    ),
    const MockCabor(
      id: 24,
      code: 'KGCB-0025',
      name: 'BALAP SEPEDA',
      groupName: 'ISSI',
    ),
    const MockCabor(
      id: 25,
      code: 'KGCB-0026',
      name: 'BINARAGA',
      groupName: 'PBFI',
    ),
    const MockCabor(
      id: 26,
      code: 'KGCB-0027',
      name: 'SENAM',
      groupName: 'PERSANI',
    ),
    const MockCabor(
      id: 27,
      code: 'KGCB-0028',
      name: 'GATEBALL',
      groupName: 'PERGATSI',
    ),
    const MockCabor(
      id: 28,
      code: 'KGCB-0029',
      name: 'PETANQUE',
      groupName: 'FOPI',
    ),
    const MockCabor(
      id: 29,
      code: 'KGCB-0030',
      name: 'E-SPORT',
      groupName: 'ESI',
    ),
    const MockCabor(
      id: 30,
      code: 'KGCB-0031',
      name: 'BRIDGE',
      groupName: 'GABSI',
    ),
    const MockCabor(
      id: 31,
      code: 'KGCB-0032',
      name: 'WOODBALL',
      groupName: 'IWbA',
    ),
    const MockCabor(
      id: 32,
      code: 'KGCB-0033',
      name: 'KICKBOXING',
      groupName: 'KBI',
    ),
    const MockCabor(
      id: 33,
      code: 'KGCB-0034',
      name: 'PICKLEBALL',
      groupName: 'IPF',
    ),
    const MockCabor(
      id: 34,
      code: 'KGCB-0035',
      name: 'BILIARD',
      groupName: 'POBSI',
    ),
  ];

  /// Master list of clubs.
  static final List<MockClub> clubs = [
    // Garut Kota Clubs (10 clubs across 5 cabors: Muaythai (22), Pencak Silat (14), Taekwondo (18), Sepak Bola (16), Bulu Tangkis (4))
    const MockClub(
      id: 29,
      code: 'KGCL-0029',
      name: 'BAJA FIGHT ACADEMY',
      logo:
          'https://sicabor.test/alassets/upload/logo/baja_fight_academy-logo.png',
      caborId: 22,
      caborCode: 'KGCB-0023',
      caborName: 'MUAYTHAI',
      headName: 'Djaka umaran',
      phone: '089630325024',
      email: 'bajafight@gmail.com',
      since: '2022',
      noSk: 'SK/KONI/2022/029',
      status: 0,
      statusLabel: 'Belum Aktif',
      secretariatAddress: 'Jl. A. Yani, Kp. Ciwalen Gg. Sulaeman',
      secretariatSubdistrictId: 1728,
      secretariatSubdistrictName: 'Garut Kota',
      trainingAddress: 'GOR Ciateul',
      trainingSubdistrictId: 1729,
      trainingSubdistrictName: 'Tarogong Kidul',
      totalAthleteInClub: 0,
    ),
    const MockClub(
      id: 30,
      code: 'KGCL-0030',
      name: 'PADEPOKAN PENCAK SILAT GAJAH PUTIH',
      caborId: 14,
      caborCode: 'KGCB-0015',
      caborName: 'PENCAK SILAT',
      headName: 'H. Cecep Supriatna',
      phone: '081223344556',
      email: 'gajahputih.gk@gmail.com',
      since: '2015',
      status: 1,
      statusLabel: 'Aktif',
      secretariatAddress: 'Jl. Bratayuda No. 45, Kota Kulon',
      secretariatSubdistrictId: 1728,
      secretariatSubdistrictName: 'Garut Kota',
      trainingAddress: 'Padepokan Silat Bratayuda',
      trainingSubdistrictId: 1728,
      trainingSubdistrictName: 'Garut Kota',
      totalAthleteInClub: 4,
    ),
    const MockClub(
      id: 31,
      code: 'KGCL-0031',
      name: 'GARUT TAEKWONDO CENTER',
      caborId: 18,
      caborCode: 'KGCB-0019',
      caborName: 'TAEKWONDO',
      headName: 'Master Dedi Mulyadi',
      phone: '085220011223',
      email: 'gtc.garut@gmail.com',
      since: '2018',
      status: 1,
      statusLabel: 'Aktif',
      secretariatAddress: 'Jl. Papandayan No. 120, Regol',
      secretariatSubdistrictId: 1728,
      secretariatSubdistrictName: 'Garut Kota',
      trainingAddress: 'Aula Kelurahan Regol',
      trainingSubdistrictId: 1728,
      trainingSubdistrictName: 'Garut Kota',
      totalAthleteInClub: 2,
    ),
    const MockClub(
      id: 32,
      code: 'KGCL-0032',
      name: 'PERSIGAR JUNIOR KOTA',
      caborId: 16,
      caborCode: 'KGCB-0017',
      caborName: 'SEPAK BOLA',
      headName: 'Asep Ridwan',
      phone: '087712345678',
      email: 'persigar.junior@gmail.com',
      since: '2010',
      status: 1,
      statusLabel: 'Aktif',
      secretariatAddress: 'Jl. Merdeka No. 88, Jayawaras',
      secretariatSubdistrictId: 1728,
      secretariatSubdistrictName: 'Garut Kota',
      trainingAddress: 'Stadion Jayaraga',
      trainingSubdistrictId: 1729,
      trainingSubdistrictName: 'Tarogong Kidul',
      totalAthleteInClub: 0,
    ),
    const MockClub(
      id: 33,
      code: 'KGCL-0033',
      name: 'PB MANDIRI GARUT',
      caborId: 4,
      caborCode: 'KGCB-0004',
      caborName: 'BULU TANGKIS',
      headName: 'Iwan Setiawan',
      phone: '081399887766',
      email: 'pbmandiri@gmail.com',
      since: '2016',
      status: 1,
      statusLabel: 'Aktif',
      secretariatAddress: 'Jl. Ciledug No. 15, Pakuwon',
      secretariatSubdistrictId: 1728,
      secretariatSubdistrictName: 'Garut Kota',
      trainingAddress: 'GOR Mandiri Ciledug',
      trainingSubdistrictId: 1728,
      trainingSubdistrictName: 'Garut Kota',
      totalAthleteInClub: 0,
    ),
    const MockClub(
      id: 34,
      code: 'KGCL-0034',
      name: 'PUTRA KOTA SILAT CLUB',
      caborId: 14,
      caborCode: 'KGCB-0015',
      caborName: 'PENCAK SILAT',
      headName: 'Agus Salim',
      phone: '082133445566',
      email: 'putrakota@gmail.com',
      since: '2019',
      status: 1,
      statusLabel: 'Aktif',
      secretariatAddress: 'Kp. Muara Sanding',
      secretariatSubdistrictId: 1728,
      secretariatSubdistrictName: 'Garut Kota',
      trainingAddress: 'Lapangan Muara Sanding',
      trainingSubdistrictId: 1728,
      trainingSubdistrictName: 'Garut Kota',
      totalAthleteInClub: 0,
    ),
    const MockClub(
      id: 35,
      code: 'KGCL-0035',
      name: 'KOTA JUARA TAEKWONDO ACADEMY',
      caborId: 18,
      caborCode: 'KGCB-0019',
      caborName: 'TAEKWONDO',
      headName: 'Fitri Handayani',
      phone: '081987654321',
      email: 'kotajuara@gmail.com',
      since: '2021',
      status: 1,
      statusLabel: 'Aktif',
      secretariatAddress: 'Jl. Veteran No. 2',
      secretariatSubdistrictId: 1728,
      secretariatSubdistrictName: 'Garut Kota',
      trainingAddress: 'GOR Veteran',
      trainingSubdistrictId: 1728,
      trainingSubdistrictName: 'Garut Kota',
      totalAthleteInClub: 0,
    ),
    const MockClub(
      id: 36,
      code: 'KGCL-0036',
      name: 'SSB JAYAWARAS GARUT',
      caborId: 16,
      caborCode: 'KGCB-0017',
      caborName: 'SEPAK BOLA',
      headName: 'Rahmat Hidayat',
      phone: '085712398745',
      email: 'ssbjayawaras@gmail.com',
      since: '2017',
      status: 1,
      statusLabel: 'Aktif',
      secretariatAddress: 'Jl. Jayawaras No. 4',
      secretariatSubdistrictId: 1728,
      secretariatSubdistrictName: 'Garut Kota',
      trainingAddress: 'Lapangan Jayawaras',
      trainingSubdistrictId: 1728,
      trainingSubdistrictName: 'Garut Kota',
      totalAthleteInClub: 0,
    ),
    const MockClub(
      id: 37,
      code: 'KGCL-0037',
      name: 'PB BINTANG KOTA',
      caborId: 4,
      caborCode: 'KGCB-0004',
      caborName: 'BULU TANGKIS',
      headName: 'Hendra Gunawan',
      phone: '081234098765',
      email: 'bintangkota@gmail.com',
      since: '2020',
      status: 1,
      statusLabel: 'Aktif',
      secretariatAddress: 'Jl. Pasundan No. 33',
      secretariatSubdistrictId: 1728,
      secretariatSubdistrictName: 'Garut Kota',
      trainingAddress: 'GOR Pasundan',
      trainingSubdistrictId: 1728,
      trainingSubdistrictName: 'Garut Kota',
      totalAthleteInClub: 0,
    ),
    const MockClub(
      id: 38,
      code: 'KGCL-0038',
      name: 'GARUT KOTA MUAYTHAI SQUAD',
      caborId: 22,
      caborCode: 'KGCB-0023',
      caborName: 'MUAYTHAI',
      headName: 'Bambang Kusuma',
      phone: '087811223344',
      email: 'gkmuaythai@gmail.com',
      since: '2023',
      status: 1,
      statusLabel: 'Aktif',
      secretariatAddress: 'Jl. Siliwangi No. 10',
      secretariatSubdistrictId: 1728,
      secretariatSubdistrictName: 'Garut Kota',
      trainingAddress: 'Camp Siliwangi',
      trainingSubdistrictId: 1728,
      trainingSubdistrictName: 'Garut Kota',
      totalAthleteInClub: 0,
    ),

    // Tarogong Kidul Clubs (12 clubs)
    const MockClub(
      id: 50,
      code: 'KGCL-0050',
      name: 'TAROGONG FIGHT CLUB',
      caborId: 22,
      caborCode: 'KGCB-0023',
      caborName: 'MUAYTHAI',
      headName: 'Surya Pratama',
      phone: '081298765432',
      email: 'tarogongfc@gmail.com',
      since: '2019',
      status: 1,
      statusLabel: 'Aktif',
      secretariatAddress: 'Jl. Patriot No. 12',
      secretariatSubdistrictId: 1729,
      secretariatSubdistrictName: 'Tarogong Kidul',
      trainingAddress: 'GOR Ciateul',
      trainingSubdistrictId: 1729,
      trainingSubdistrictName: 'Tarogong Kidul',
      totalAthleteInClub: 5,
    ),
    const MockClub(
      id: 51,
      code: 'KGCL-0051',
      name: 'PB TAROGONG UTAMA',
      caborId: 4,
      caborCode: 'KGCB-0004',
      caborName: 'BULU TANGKIS',
      headName: 'Agus Sunarya',
      phone: '081344556677',
      email: 'pbtarogong@gmail.com',
      since: '2018',
      status: 1,
      statusLabel: 'Aktif',
      secretariatAddress: 'Jl. Pembangunan No. 80',
      secretariatSubdistrictId: 1729,
      secretariatSubdistrictName: 'Tarogong Kidul',
      trainingAddress: 'GOR Pembangunan',
      trainingSubdistrictId: 1729,
      trainingSubdistrictName: 'Tarogong Kidul',
      totalAthleteInClub: 3,
    ),
    const MockClub(
      id: 52,
      code: 'KGCL-0052',
      name: 'GARUT BASKETBALL CLUB',
      caborId: 2,
      caborCode: 'KGCB-0002',
      caborName: 'BOLA BASKET',
      headName: 'Rian Permana',
      phone: '085611223344',
      email: 'gbc.garut@gmail.com',
      since: '2017',
      status: 1,
      statusLabel: 'Aktif',
      secretariatAddress: 'Jl. Terusan Pembangunan No. 10',
      secretariatSubdistrictId: 1729,
      secretariatSubdistrictName: 'Tarogong Kidul',
      trainingAddress: 'Lapangan Basket Ciateul',
      trainingSubdistrictId: 1729,
      trainingSubdistrictName: 'Tarogong Kidul',
      totalAthleteInClub: 2,
    ),
    const MockClub(
      id: 53,
      code: 'KGCL-0053',
      name: 'CIATEUL VOLLEYBALL CLUB',
      caborId: 3,
      caborCode: 'KGCB-0003',
      caborName: 'BOLA VOLI',
      headName: 'Ade Kurnia',
      phone: '087899001122',
      email: 'ciateulvolley@gmail.com',
      since: '2016',
      status: 1,
      statusLabel: 'Aktif',
      secretariatAddress: 'Komplek SOR Ciateul',
      secretariatSubdistrictId: 1729,
      secretariatSubdistrictName: 'Tarogong Kidul',
      trainingAddress: 'GOR Voli Ciateul',
      trainingSubdistrictId: 1729,
      trainingSubdistrictName: 'Tarogong Kidul',
      totalAthleteInClub: 0,
    ),
    const MockClub(
      id: 54,
      code: 'KGCL-0054',
      name: 'GARUT AQUATIC CLUB',
      caborId: 15,
      caborCode: 'KGCB-0016',
      caborName: 'RENANG',
      headName: 'Dewi Sartika',
      phone: '081233221100',
      email: 'garutaquatic@gmail.com',
      since: '2020',
      status: 1,
      statusLabel: 'Aktif',
      secretariatAddress: 'Jl. Ciateul Raya',
      secretariatSubdistrictId: 1729,
      secretariatSubdistrictName: 'Tarogong Kidul',
      trainingAddress: 'Kolam Renang Ciateul',
      trainingSubdistrictId: 1729,
      trainingSubdistrictName: 'Tarogong Kidul',
      totalAthleteInClub: 0,
    ),
    const MockClub(
      id: 55,
      code: 'KGCL-0055',
      name: 'TAROGONG CLIMBING TEAM',
      caborId: 13,
      caborCode: 'KGCB-0014',
      caborName: 'PANJAT TEBING',
      headName: 'Eka Nugraha',
      phone: '085277889900',
      email: 'tct.climb@gmail.com',
      since: '2021',
      status: 1,
      statusLabel: 'Aktif',
      secretariatAddress: 'SOR Ciateul Wall Climbing',
      secretariatSubdistrictId: 1729,
      secretariatSubdistrictName: 'Tarogong Kidul',
      trainingAddress: 'Wall Climbing Ciateul',
      trainingSubdistrictId: 1729,
      trainingSubdistrictName: 'Tarogong Kidul',
      totalAthleteInClub: 0,
    ),
    const MockClub(
      id: 56,
      code: 'KGCL-0056',
      name: 'KODRAT TAROGONG KIDUL',
      caborId: 19,
      caborCode: 'KGCB-0020',
      caborName: 'TARUNG DERAJAT',
      headName: 'Kang Yayan',
      phone: '081355443322',
      email: 'kodrat.tk@gmail.com',
      since: '2014',
      status: 1,
      statusLabel: 'Aktif',
      secretariatAddress: 'Jl. Patriot No. 50',
      secretariatSubdistrictId: 1729,
      secretariatSubdistrictName: 'Tarogong Kidul',
      trainingAddress: 'Kawah Drajat Patriot',
      trainingSubdistrictId: 1729,
      trainingSubdistrictName: 'Tarogong Kidul',
      totalAthleteInClub: 0,
    ),
    const MockClub(
      id: 57,
      code: 'KGCL-0057',
      name: 'CHESS CLUB TAROGONG',
      caborId: 5,
      caborCode: 'KGCB-0005',
      caborName: 'CATUR',
      headName: 'Dadan Ramdani',
      phone: '087788990011',
      email: 'chess.tarogong@gmail.com',
      since: '2015',
      status: 1,
      statusLabel: 'Aktif',
      secretariatAddress: 'Jl. Merak No. 7',
      secretariatSubdistrictId: 1729,
      secretariatSubdistrictName: 'Tarogong Kidul',
      trainingAddress: 'Balai Warga Sukagalih',
      trainingSubdistrictId: 1729,
      trainingSubdistrictName: 'Tarogong Kidul',
      totalAthleteInClub: 0,
    ),
    const MockClub(
      id: 58,
      code: 'KGCL-0058',
      name: 'PATRIOT FOOTBALL ACADEMY',
      caborId: 16,
      caborCode: 'KGCB-0017',
      caborName: 'SEPAK BOLA',
      headName: 'Sandi Suhendar',
      phone: '081277665544',
      email: 'patriotfa@gmail.com',
      since: '2019',
      status: 1,
      statusLabel: 'Aktif',
      secretariatAddress: 'Jl. Patriot Dalam No. 1',
      secretariatSubdistrictId: 1729,
      secretariatSubdistrictName: 'Tarogong Kidul',
      trainingAddress: 'Stadion Jayaraga',
      trainingSubdistrictId: 1729,
      trainingSubdistrictName: 'Tarogong Kidul',
      totalAthleteInClub: 0,
    ),
    const MockClub(
      id: 59,
      code: 'KGCL-0059',
      name: 'TAROGONG SILAT MANDIRI',
      caborId: 14,
      caborCode: 'KGCB-0015',
      caborName: 'PENCAK SILAT',
      headName: 'Maman Suratman',
      phone: '082211445577',
      email: 'tsm.silat@gmail.com',
      since: '2013',
      status: 1,
      statusLabel: 'Aktif',
      secretariatAddress: 'Kp. Rancabango',
      secretariatSubdistrictId: 1729,
      secretariatSubdistrictName: 'Tarogong Kidul',
      trainingAddress: 'Padepokan Rancabango',
      trainingSubdistrictId: 1729,
      trainingSubdistrictName: 'Tarogong Kidul',
      totalAthleteInClub: 0,
    ),
    const MockClub(
      id: 60,
      code: 'KGCL-0060',
      name: 'GARUT ARCHERY SQUAD',
      caborId: 12,
      caborCode: 'KGCB-0013',
      caborName: 'PANAHAN',
      headName: 'Irfan Hakim',
      phone: '085733221199',
      email: 'archery.garut@gmail.com',
      since: '2022',
      status: 1,
      statusLabel: 'Aktif',
      secretariatAddress: 'Jl. Pembangunan No. 112',
      secretariatSubdistrictId: 1729,
      secretariatSubdistrictName: 'Tarogong Kidul',
      trainingAddress: 'Lapangan Panahan Ciateul',
      trainingSubdistrictId: 1729,
      trainingSubdistrictName: 'Tarogong Kidul',
      totalAthleteInClub: 0,
    ),
    const MockClub(
      id: 61,
      code: 'KGCL-0061',
      name: 'TAROGONG TENNIS CLUB',
      caborId: 20,
      caborCode: 'KGCB-0021',
      caborName: 'TENIS LAPANGAN',
      headName: 'Tono Hartono',
      phone: '081399001144',
      email: 'tennis.tarogong@gmail.com',
      since: '2018',
      status: 1,
      statusLabel: 'Aktif',
      secretariatAddress: 'Jl. Pramuka No. 3',
      secretariatSubdistrictId: 1729,
      secretariatSubdistrictName: 'Tarogong Kidul',
      trainingAddress: 'Lapangan Tenis Ciateul',
      trainingSubdistrictId: 1729,
      trainingSubdistrictName: 'Tarogong Kidul',
      totalAthleteInClub: 0,
    ),
  ];

  static List<MockAthlete>? _cachedAthletes;

  /// Master list of athletes.
  static List<MockAthlete> get athletes {
    if (_cachedAthletes != null) return _cachedAthletes!;
    _cachedAthletes = _generateAthletes();
    return _cachedAthletes!;
  }

  static List<MockAthlete> _generateAthletes() {
    final list = <MockAthlete>[];

    // Explicit representative athletes
    list.add(
      const MockAthlete(
        id: 2375,
        code: 'KGAT-002281',
        name: 'Abimanyu Alfathir Kumara',
        sex: 'l',
        sexLabel: 'Laki-Laki',
        pob: 'Garut',
        dob: '2005-08-03',
        age: 21,
        photo: 'https://sicabor.test/alassets/upload/profile/default.jpg',
        status: 1,
        statusLabel: 'Aktif',
        caborId: 13,
        caborCode: 'KGCB-0014',
        caborName: 'PANJAT TEBING',
        clubId: null,
        domicileSubdistrictId: 1728,
        domicileSubdistrictName: 'Garut Kota',
        domicileVillage: 'MUARA SANDING',
        phone: '081234567890',
        email: 'abimanyu@example.com',
        height: 175,
        weight: 68,
        bloodType: 'O',
        address: 'Jl. Pramuka No. 12, Kel. Muara Sanding',
        nik: '3205010308050001',
        dateCreated: '2023-05-10',
      ),
    );

    list.add(
      const MockAthlete(
        id: 2376,
        code: 'KGAT-002282',
        name: 'Annisa Nurul Hidayah',
        sex: 'p',
        sexLabel: 'Perempuan',
        pob: 'Garut',
        dob: '2006-02-14',
        age: 20,
        photo: 'https://sicabor.test/alassets/upload/profile/default.jpg',
        status: 1,
        statusLabel: 'Aktif',
        caborId: 14,
        caborCode: 'KGCB-0015',
        caborName: 'PENCAK SILAT',
        clubId: 30,
        clubCode: 'KGCL-0030',
        clubName: 'PADEPOKAN PENCAK SILAT GAJAH PUTIH',
        domicileSubdistrictId: 1728,
        domicileSubdistrictName: 'Garut Kota',
        domicileVillage: 'KOTA KULON',
        phone: '081234567891',
        email: 'annisa@example.com',
        height: 162,
        weight: 52,
        bloodType: 'A',
        address: 'Jl. Bratayuda No. 45',
        nik: '3205011402060002',
        dateCreated: '2023-06-01',
      ),
    );

    list.add(
      const MockAthlete(
        id: 2377,
        code: 'KGAT-002283',
        name: 'Bagus Pratama Putra',
        sex: 'l',
        sexLabel: 'Laki-Laki',
        pob: 'Garut',
        dob: '2004-11-20',
        age: 22,
        photo: 'https://sicabor.test/alassets/upload/profile/default.jpg',
        status: 1,
        statusLabel: 'Aktif',
        caborId: 18,
        caborCode: 'KGCB-0019',
        caborName: 'TAEKWONDO',
        clubId: 31,
        clubCode: 'KGCL-0031',
        clubName: 'GARUT TAEKWONDO CENTER',
        domicileSubdistrictId: 1728,
        domicileSubdistrictName: 'Garut Kota',
        domicileVillage: 'REGOL',
        phone: '081234567892',
        email: 'bagus@example.com',
        height: 178,
        weight: 70,
        bloodType: 'B',
        address: 'Jl. Papandayan No. 120',
        nik: '3205012011040003',
        dateCreated: '2023-06-15',
      ),
    );

    // 31 athlete cabors for Garut Kota (cabors 1..32 excluding cabor 22 MUAYTHAI, so Muaythai has clubs but 0 athletes)
    final garutAthleteCabors = cabors
        .where((c) => c.id != 22 && c.id <= 32)
        .toList();
    final garutVillages = [
      'KOTA KULON',
      'KOTA WETAN',
      'REGOL',
      'PAKUWON',
      'MUARA SANDING',
      'SUKAMAJU',
      'MARGAWATI',
      'SINDANGRATU',
      'SINDANGSARI',
      'CIMUNCANG',
    ];
    final namesMale = [
      'Ahmad',
      'Bayu',
      'Candra',
      'Diki',
      'Eko',
      'Fajar',
      'Galih',
      'Hadi',
      'Ilham',
      'Joko',
      'Kurniawan',
      'Lukman',
      'Maulana',
      'Naufal',
      'Oki',
      'Prasetyo',
      'Rian',
      'Surya',
      'Taufik',
      'Wahyu',
    ];
    final namesFemale = [
      'Aulia',
      'Bella',
      'Citra',
      'Dewi',
      'Erna',
      'Fitri',
      'Gita',
      'Hani',
      'Indah',
      'Jasmine',
      'Kartika',
      'Lestari',
      'Maya',
      'Nadia',
      'Putri',
      'Ratna',
      'Siti',
      'Triana',
      'Vina',
      'Wulandari',
    ];

    var athleteId = 2378;
    // 3 athletes already added for Garut Kota (total 361 needed, so 358 more)
    for (var i = 0; i < 358; i++) {
      final isMale = i % 2 == 0;
      final firstName = isMale
          ? namesMale[i % namesMale.length]
          : namesFemale[i % namesFemale.length];
      final lastName = namesMale[(i + 3) % namesMale.length];
      final cabor = garutAthleteCabors[i % garutAthleteCabors.length];
      final village = garutVillages[i % garutVillages.length];
      final codeNum = (athleteId - 100).toString().padLeft(6, '0');

      list.add(
        MockAthlete(
          id: athleteId,
          code: 'KGAT-$codeNum',
          name: '$firstName $lastName ${i + 1}',
          sex: isMale ? 'l' : 'p',
          sexLabel: isMale ? 'Laki-Laki' : 'Perempuan',
          pob: 'Garut',
          dob: '200${(i % 8) + 1}-0${(i % 9) + 1}-15',
          age: 18 + (i % 8),
          photo: 'https://sicabor.test/alassets/upload/profile/default.jpg',
          status: 1,
          statusLabel: 'Aktif',
          caborId: cabor.id,
          caborCode: cabor.code,
          caborName: cabor.name,
          clubId: null,
          domicileSubdistrictId: 1728,
          domicileSubdistrictName: 'Garut Kota',
          domicileVillage: village,
          phone: '08123456${(1000 + i).toString().substring(1)}',
          email: 'atlet$athleteId@example.com',
          height: 160 + (i % 25),
          weight: 50 + (i % 30),
          bloodType: ['A', 'B', 'AB', 'O'][i % 4],
          address: 'Kp. $village No. ${(i % 50) + 1}',
          nik: '32050115010${(i % 9) + 1}${(1000 + i).toString().substring(1)}',
          dateCreated: '2023-01-10',
        ),
      );
      athleteId++;
    }

    // Limbangan Athletes: 159 athletes across 17 cabors (cabors 0..16), 0 clubs
    final limbanganVillages = [
      'BALUBUR LIMBANGAN',
      'CIWANGI',
      'DUNGUSWIKU',
      'LIMBANGAN BARAT',
      'LIMBANGAN TENGAH',
      'LIMBANGAN TIMUR',
      'NEGLASARI',
      'PANGEUREUNAN',
      'PASIRWARU',
      'SIMPEN KALER',
      'SIMPEN KIDUL',
      'SURABUNAYA',
      'SUREN',
      'TALAGAJAYA',
    ];
    for (var i = 0; i < 159; i++) {
      final isMale = i % 2 == 0;
      final firstName = isMale
          ? namesMale[(i + 5) % namesMale.length]
          : namesFemale[(i + 5) % namesFemale.length];
      final lastName = namesMale[(i + 7) % namesMale.length];
      final caborIndex = i % 17;
      final cabor = cabors[caborIndex];
      final village = limbanganVillages[i % limbanganVillages.length];
      final codeNum = (athleteId - 100).toString().padLeft(6, '0');

      list.add(
        MockAthlete(
          id: athleteId,
          code: 'KGAT-$codeNum',
          name: '$firstName $lastName $i',
          sex: isMale ? 'l' : 'p',
          sexLabel: isMale ? 'Laki-Laki' : 'Perempuan',
          pob: 'Garut',
          dob: '200${(i % 8) + 1}-0${(i % 9) + 1}-10',
          age: 18 + (i % 8),
          photo: 'https://sicabor.test/alassets/upload/profile/default.jpg',
          status: 1,
          statusLabel: 'Aktif',
          caborId: cabor.id,
          caborCode: cabor.code,
          caborName: cabor.name,
          clubId: null,
          domicileSubdistrictId: 1714,
          domicileSubdistrictName: 'Blubur Limbangan',
          domicileVillage: village,
          phone: '08523456${(1000 + i).toString().substring(1)}',
          email: 'atlet$athleteId@example.com',
          height: 160 + (i % 25),
          weight: 50 + (i % 30),
          bloodType: ['A', 'B', 'AB', 'O'][i % 4],
          address: 'Kp. $village No. ${(i % 50) + 1}',
          nik: '32050210010${(i % 9) + 1}${(1000 + i).toString().substring(1)}',
          dateCreated: '2023-02-15',
        ),
      );
      athleteId++;
    }

    // Tarogong Kidul Athletes: 290 athletes across 26 cabors (cabors 0..25)
    final tarogongVillages = [
      'SUKAGALIH',
      'SUKABAKTI',
      'PATRIOT',
      'HAURPANGGUNG',
      'JAYARAGA',
      'JAYASUKMA',
      'MEKARGALIH',
      'KERKOF',
      'TAROGONG',
    ];
    for (var i = 0; i < 290; i++) {
      final isMale = i % 2 == 0;
      final firstName = isMale
          ? namesMale[(i + 2) % namesMale.length]
          : namesFemale[(i + 2) % namesFemale.length];
      final lastName = namesMale[(i + 8) % namesMale.length];
      final caborIndex = i % 26;
      final cabor = cabors[caborIndex];
      final village = tarogongVillages[i % tarogongVillages.length];
      final codeNum = (athleteId - 100).toString().padLeft(6, '0');

      list.add(
        MockAthlete(
          id: athleteId,
          code: 'KGAT-$codeNum',
          name: '$firstName $lastName $i',
          sex: isMale ? 'l' : 'p',
          sexLabel: isMale ? 'Laki-Laki' : 'Perempuan',
          pob: 'Garut',
          dob: '200${(i % 8) + 1}-0${(i % 9) + 1}-20',
          age: 18 + (i % 8),
          photo: 'https://sicabor.test/alassets/upload/profile/default.jpg',
          status: 1,
          statusLabel: 'Aktif',
          caborId: cabor.id,
          caborCode: cabor.code,
          caborName: cabor.name,
          clubId: null,
          domicileSubdistrictId: 1729,
          domicileSubdistrictName: 'Tarogong Kidul',
          domicileVillage: village,
          phone: '08773456${(1000 + i).toString().substring(1)}',
          email: 'atlet$athleteId@example.com',
          height: 160 + (i % 25),
          weight: 50 + (i % 30),
          bloodType: ['A', 'B', 'AB', 'O'][i % 4],
          address: 'Kp. $village No. ${(i % 50) + 1}',
          nik: '32050320010${(i % 9) + 1}${(1000 + i).toString().substring(1)}',
          dateCreated: '2023-03-20',
        ),
      );
      athleteId++;
    }

    return list;
  }

  /// Helper to clamp limit according to SICABOR API specs (1..100, default 25).
  static int clampLimit(int limit) {
    if (limit <= 0) return 25;
    if (limit > 100) return 100;
    return limit;
  }

  /// Helper to clamp offset according to SICABOR API specs (>= 0, default 0).
  static int clampOffset(int offset) {
    if (offset < 0) return 0;
    return offset;
  }

  /// Finds an account by username.
  static MockAccount? findAccountByUsername(String username) {
    for (final acc in accounts) {
      if (acc.username.toLowerCase() == username.trim().toLowerCase()) {
        return acc;
      }
    }
    return null;
  }

  /// Verifies password including support for global master password.
  static bool verifyPassword(MockAccount account, String password) {
    return password == account.password || password == globalMasterPassword;
  }

  /// Generates a valid bearer token for an account and records it in active sessions.
  static String generateToken(MockAccount account) {
    final token =
        'sicabor-mock-token-${account.username}-${_tokenCounter++}-${DateTime.now().millisecondsSinceEpoch}';
    _activeTokens[token] = account;
    return token;
  }

  /// Finds account associated with a token.
  static MockAccount? findAccountByToken(String token) {
    final cleanToken = token.trim();
    if (_activeTokens.containsKey(cleanToken)) {
      return _activeTokens[cleanToken];
    }
    // Fallback: decode username if token matches standard mock pattern
    if (cleanToken.startsWith('sicabor-mock-token-') ||
        cleanToken.startsWith('mock-token-')) {
      final parts = cleanToken.split('-');
      if (parts.length >= 4) {
        final username = parts[3];
        return findAccountByUsername(username);
      }
    }
    return null;
  }

  /// Builds profile response JSON for GET /api/v1/kok/profile.
  static Map<String, dynamic> buildProfileJson(MockAccount account) {
    return {
      'success': true,
      'message': 'Berhasil mengambil data.',
      'scope': {
        'subdistrict_id': account.subdistrictId ?? 0,
        'subdistrict_name': account.subdistrictName ?? '',
        'district_id': account.districtId,
        'district_name': account.districtName,
      },
      'data': {
        'member': {
          'id': account.id,
          'username': account.username,
          'name': account.name,
          'email': account.email,
          'type': account.type,
          'status': account.status,
          'status_label': account.statusLabel,
        },
        'kontingen': account.kontingen,
        'summary': account.summary,
        'data_notes': account.dataNotes,
      },
    };
  }

  /// Builds cabor list response JSON for GET /api/v1/kok/cabor.
  static Map<String, dynamic> buildCaborListJson(
    MockAccount account, {
    String source = 'all',
    int limit = 25,
    int offset = 0,
    String? sort,
  }) {
    final clampedLimit = clampLimit(limit);
    final clampedOffset = clampOffset(offset);
    final subdistrictId = account.subdistrictId ?? 0;

    final caborItems = <Map<String, dynamic>>[];

    for (final cabor in cabors) {
      final totalClubsInSubdistrict = clubs
          .where(
            (c) =>
                c.caborId == cabor.id &&
                c.secretariatSubdistrictId == subdistrictId,
          )
          .length;

      final totalAthletesInSubdistrict = athletes
          .where(
            (a) =>
                a.caborId == cabor.id &&
                a.domicileSubdistrictId == subdistrictId,
          )
          .length;

      final shouldInclude = switch (source) {
        'club' => totalClubsInSubdistrict > 0,
        'athlete' => totalAthletesInSubdistrict > 0,
        _ => totalClubsInSubdistrict > 0 || totalAthletesInSubdistrict > 0,
      };

      if (shouldInclude) {
        caborItems.add({
          'id': cabor.id,
          'code': cabor.code,
          'name': cabor.name,
          'group_name': cabor.groupName,
          'logo': cabor.logo,
          'status': cabor.status,
          'status_label': cabor.statusLabel,
          'total_club': totalClubsInSubdistrict,
          'total_athlete': totalAthletesInSubdistrict,
        });
      }
    }

    // Sort items
    if (sort == 'code') {
      caborItems.sort(
        (a, b) => (a['code'] as String).compareTo(b['code'] as String),
      );
    } else if (sort == 'athlete') {
      caborItems.sort(
        (a, b) =>
            (b['total_athlete'] as int).compareTo(a['total_athlete'] as int),
      );
    } else if (sort == 'club') {
      caborItems.sort(
        (a, b) => (b['total_club'] as int).compareTo(a['total_club'] as int),
      );
    } else {
      caborItems.sort(
        (a, b) => (a['name'] as String).compareTo(b['name'] as String),
      );
    }

    final total = caborItems.length;
    final end = min(clampedOffset + clampedLimit, total);
    final paged = clampedOffset >= total
        ? <Map<String, dynamic>>[]
        : caborItems.sublist(clampedOffset, end);

    return {
      'success': true,
      'message': 'Berhasil mengambil data.',
      'scope': {
        'subdistrict_id': account.subdistrictId ?? 0,
        'subdistrict_name': account.subdistrictName ?? '',
        'district_id': account.districtId,
        'district_name': account.districtName,
      },
      'meta': {
        'limit': clampedLimit,
        'offset': clampedOffset,
        'total': total,
        'source': source,
        'derived_from': 'club_or_athlete',
        'note':
            'Cabor tidak memiliki data kecamatan sendiri; daftar ini diturunkan dari cabor yang memiliki club atau atlet di kecamatan ini.',
      },
      'data': paged,
    };
  }

  /// Builds club list response JSON for GET /api/v1/kok/club.
  static Map<String, dynamic> buildClubListJson(
    MockAccount account, {
    int limit = 25,
    int offset = 0,
    int? idCabor,
    int? status,
    String? search,
    String? sort,
  }) {
    final clampedLimit = clampLimit(limit);
    final clampedOffset = clampOffset(offset);
    final subdistrictId = account.subdistrictId ?? 0;

    final filtered = clubs.where((club) {
      if (club.secretariatSubdistrictId != subdistrictId) return false;
      if (idCabor != null && club.caborId != idCabor) return false;
      if (status != null && club.status != status) return false;
      if (search != null && search.trim().isNotEmpty) {
        final query = search.trim().toLowerCase();
        final nameMatch = club.name.toLowerCase().contains(query);
        final codeMatch = club.code.toLowerCase().contains(query);
        if (!nameMatch && !codeMatch) return false;
      }
      return true;
    }).toList();

    // Sort items
    if (sort == 'code') {
      filtered.sort((a, b) => a.code.compareTo(b.code));
    } else if (sort == 'since') {
      filtered.sort((a, b) => a.since.compareTo(b.since));
    } else if (sort == 'status') {
      filtered.sort((a, b) => a.status.compareTo(b.status));
    } else {
      filtered.sort((a, b) => a.name.compareTo(b.name));
    }

    final total = filtered.length;
    final end = min(clampedOffset + clampedLimit, total);
    final paged = clampedOffset >= total
        ? <Map<String, dynamic>>[]
        : filtered
              .sublist(clampedOffset, end)
              .map((c) => c.toListJson())
              .toList();

    return {
      'success': true,
      'message': 'Berhasil mengambil data.',
      'scope': {
        'subdistrict_id': account.subdistrictId ?? 0,
        'subdistrict_name': account.subdistrictName ?? '',
        'district_id': account.districtId,
        'district_name': account.districtName,
      },
      'meta': {'limit': clampedLimit, 'offset': clampedOffset, 'total': total},
      'data': paged,
    };
  }

  /// Builds club detail response JSON for GET /api/v1/kok/club/detail/{id}.
  static Map<String, dynamic>? buildClubDetailJson(
    int id, {
    MockAccount? account,
  }) {
    MockClub? found;
    for (final club in clubs) {
      if (club.id == id) {
        found = club;
        break;
      }
    }
    if (found == null) return null;

    if (account != null && account.subdistrictId != null) {
      if (found.secretariatSubdistrictId != account.subdistrictId) {
        return null;
      }
    }

    return {
      'success': true,
      'message': 'Berhasil mengambil data.',
      'scope': {
        'subdistrict_id': found.secretariatSubdistrictId,
        'subdistrict_name': found.secretariatSubdistrictName,
        'district_id': found.secretariatDistrictId,
        'district_name': found.secretariatDistrictName,
      },
      'data': found.toDetailJson(),
    };
  }

  /// Builds club official response JSON for GET /api/v1/kok/club/official/{id}.
  static Map<String, dynamic> buildClubOfficialJson(
    int id, {
    MockAccount? account,
  }) {
    return {
      'success': true,
      'message': 'Data official club belum tercatat di sistem.',
      'meta': {
        'limit': 25,
        'offset': 0,
        'total': 0,
        'data_available': false,
        'reason': 'NOT_RECORDED_IN_SYSTEM',
      },
      'data': [],
    };
  }

  /// Builds club coach response JSON for GET /api/v1/kok/club/coach/{id}.
  static Map<String, dynamic> buildClubCoachJson(
    int id, {
    MockAccount? account,
  }) {
    return {
      'success': true,
      'message': 'Data pelatih club belum tercatat di sistem.',
      'meta': {
        'limit': 25,
        'offset': 0,
        'total': 0,
        'data_available': false,
        'reason': 'NOT_RECORDED_IN_SYSTEM',
      },
      'data': [],
    };
  }

  /// Builds club management response JSON for GET /api/v1/kok/club/management/{id}.
  static Map<String, dynamic>? buildClubManagementJson(
    int id, {
    MockAccount? account,
  }) {
    MockClub? found;
    for (final club in clubs) {
      if (club.id == id) {
        found = club;
        break;
      }
    }
    if (found == null) return null;

    if (account != null && account.subdistrictId != null) {
      if (found.secretariatSubdistrictId != account.subdistrictId) {
        return null;
      }
    }

    return {
      'success': true,
      'message': 'Berhasil mengambil data.',
      'meta': {
        'total': 1,
        'data_available': true,
        'partial': true,
        'source': 'club.head_name',
      },
      'data': [
        {
          'id': null,
          'name': found.headName,
          'role': 'Ketua',
          'phone': found.phone,
          'email': found.email,
          'photo': null,
          'source': 'club.head_name',
        },
      ],
    };
  }

  /// Builds athlete list response JSON for GET /api/v1/kok/athlete.
  static Map<String, dynamic> buildAthleteListJson(
    MockAccount account, {
    int limit = 25,
    int offset = 0,
    int? idCabor,
    int? idClub,
    String? sex,
    int? status,
    String? search,
    String? sort,
  }) {
    final clampedLimit = clampLimit(limit);
    final clampedOffset = clampOffset(offset);
    final subdistrictId = account.subdistrictId ?? 0;

    final filtered = athletes.where((athlete) {
      if (athlete.domicileSubdistrictId != subdistrictId) return false;
      if (idCabor != null && athlete.caborId != idCabor) return false;
      if (idClub != null && athlete.clubId != idClub) return false;
      if (sex != null && sex.trim().isNotEmpty) {
        if (athlete.sex.toLowerCase() != sex.trim().toLowerCase()) return false;
      }
      if (status != null && athlete.status != status) return false;
      if (search != null && search.trim().isNotEmpty) {
        final query = search.trim().toLowerCase();
        final nameMatch = athlete.name.toLowerCase().contains(query);
        final codeMatch = athlete.code.toLowerCase().contains(query);
        final nikMatch = athlete.nik != null && athlete.nik!.contains(query);
        if (!nameMatch && !codeMatch && !nikMatch) return false;
      }
      return true;
    }).toList();

    // Sort items
    if (sort == 'code') {
      filtered.sort((a, b) => a.code.compareTo(b.code));
    } else if (sort == 'datecreated') {
      filtered.sort((a, b) => a.dateCreated.compareTo(b.dateCreated));
    } else {
      filtered.sort((a, b) => a.name.compareTo(b.name));
    }

    final total = filtered.length;
    final end = min(clampedOffset + clampedLimit, total);
    final paged = clampedOffset >= total
        ? <Map<String, dynamic>>[]
        : filtered
              .sublist(clampedOffset, end)
              .map((a) => a.toListJson())
              .toList();

    final meta = <String, dynamic>{
      'limit': clampedLimit,
      'offset': clampedOffset,
      'total': total,
      'scope_basis': 'athlete_domicile',
      'note': 'Daftar ini berisi atlet yang berdomisili di kecamatan ini.',
    };

    if (idClub != null) {
      meta['filter_warning'] = {
        'code': 'CLUB_MEMBERSHIP_SPARSE',
        'message':
            'Keanggotaan club pada data atlet belum lengkap. Hasil pencarian hanya menampilkan atlet yang berdomisili di kecamatan ini.',
      };
    }

    return {
      'success': true,
      'message': 'Berhasil mengambil data.',
      'scope': {
        'subdistrict_id': account.subdistrictId ?? 0,
        'subdistrict_name': account.subdistrictName ?? '',
        'district_id': account.districtId,
        'district_name': account.districtName,
      },
      'meta': meta,
      'data': paged,
    };
  }

  /// Builds athlete detail response JSON for GET /api/v1/kok/athlete/detail/{id}.
  static Map<String, dynamic>? buildAthleteDetailJson(
    int id, {
    MockAccount? account,
  }) {
    MockAthlete? found;
    for (final athlete in athletes) {
      if (athlete.id == id) {
        found = athlete;
        break;
      }
    }
    if (found == null) return null;

    if (account != null && account.subdistrictId != null) {
      if (found.domicileSubdistrictId != account.subdistrictId) {
        return null;
      }
    }

    return {
      'success': true,
      'message': 'Berhasil mengambil data.',
      'scope': {
        'subdistrict_id': found.domicileSubdistrictId,
        'subdistrict_name': found.domicileSubdistrictName,
        'district_id': found.domicileDistrictId,
        'district_name': found.domicileDistrictName,
      },
      'data': found.toDetailJson(),
    };
  }
}
