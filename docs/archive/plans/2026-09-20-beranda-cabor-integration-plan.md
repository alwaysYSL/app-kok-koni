# Integrasi Data Beranda + Cabor — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Mengintegrasikan data operasional Beranda (Dashboard Summary via `GET /profile`) dan Cabang Olahraga (Daftar Cabor via `GET /cabor` dengan pagination infinite scroll) dari API SICABOR ke dalam aplikasi mobile KOK dengan arsitektur multi-layer (Service, DTO, Mapper, Riverpod Providers, UI).

**Architecture:** Menggunakan arsitektur bertahap (*gradual migration*). Lapisan data dibagi menjadi Service Interfaces (`ProfileService`, `CaborService`), DTO parsing (`SicaborCaborItem`, `SicaborListEnvelope`), Mapper domain (`SicaborDataMapper`), serta Provider granular dengan session guard (`profileSummaryProvider`, `caborPaginationController`). `AppComposition` menginjeksi adapter remote/demo sesuai `DataMode`. Halaman Beranda (`HomePage`) dan Cabor (`SportsPage`) dimigrasikan dari `DataView`/`KokSnapshot` ke provider granular baru, sedangkan halaman lain tetap aman pada demo repository hingga gilirannya.

**Tech Stack:** Flutter, Dart, Riverpod, Dio, Flutter Test, Mockito / Custom HTTP Mock Adapters.

## Global Constraints

- **Single Session Token**: Sesi aktif menggunakan Bearer Token 24 jam tanpa refresh token.
- **Granular Envelope**: Seluruh endpoint data KOK SICABOR menggunakan amplop `{ success: true, message: ..., scope: ..., meta: ..., data: ... }`.
- **Derivasi Cabor**: Daftar cabor berasal dari server (`GET /cabor`) dengan parameter `source` (`all` default) dan `sort` (`name` default). Jangan menghitung ulang `total_cabor` di frontend.
- **Session Lifecycle Guards**: Setiap request granular memverifikasi `dataRequestContextProvider` sebelum dan sesudah eksekusi untuk mencegah kebocoran state antar-sesi.
- **Fail-Closed on 401**: Respon 401 langsung melempar `UnauthorizedException` dan memicu logout bersih.
- **Location Rules**: Seluruh file spesifikasi dan rencana implementasi HARUS disimpan di `docs/archive/specs/` dan `docs/archive/plans/`.
- **Remotes**: Commit dipusatkan pada branch `feat/sicabor-auth` dan di-push ke `gitlab` dan `origin`.

---

### Task 1: Domain Models & Generic Pagination Result

**Files:**
- Create: `lib/data/models/cabor.dart`
- Create: `lib/data/models/profile_summary.dart`
- Create: `lib/data/models/paginated_result.dart`
- Test: `test/data/domain_models_test.dart`

**Interfaces:**
- Produces:
  - `class Cabor`: `{ int id, String code, String name, String? groupName, String? logoUrl, int status, String statusLabel, int totalClub, int totalAthlete }`
  - `class ProfileSummary`: `{ SicaborScope scope, SicaborMember member, SicaborKontingen? kontingen, int totalCabor, int totalCaborFromClub, int totalCaborFromAthlete, int totalClub, int totalAthlete, int totalAthleteWithoutClub, List<String> dataNotes }`
  - `class PaginatedResult<T>`: `{ List<T> items, int limit, int offset, int total, bool hasMore, int nextOffset }`

- [ ] **Step 1: Write failing tests for domain models**

```dart
// test/data/domain_models_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:kok_app/core/auth/data/dto/sicabor_login_response.dart';
import 'package:kok_app/core/auth/data/dto/sicabor_profile_response.dart';
import 'package:kok_app/data/models/cabor.dart';
import 'package:kok_app/data/models/profile_summary.dart';
import 'package:kok_app/data/models/paginated_result.dart';

void main() {
  group('Domain Models Tests', () {
    test('Cabor model instantiates correctly with equality and copy', () {
      const cabor = Cabor(
        id: 9,
        code: 'KGCB-0010',
        name: 'ARUNG JERAM',
        groupName: 'FAJI',
        logoUrl: 'https://sicabor.test/logo.png',
        status: 1,
        statusLabel: 'Aktif',
        totalClub: 0,
        totalAthlete: 15,
      );

      expect(cabor.id, equals(9));
      expect(cabor.code, equals('KGCB-0010'));
      expect(cabor.name, equals('ARUNG JERAM'));
      expect(cabor.groupName, equals('FAJI'));
      expect(cabor.logoUrl, equals('https://sicabor.test/logo.png'));
      expect(cabor.status, equals(1));
      expect(cabor.statusLabel, equals('Aktif'));
      expect(cabor.totalClub, equals(0));
      expect(cabor.totalAthlete, equals(15));
    });

    test('ProfileSummary model instantiates with nested scope, member, summary', () {
      final summary = ProfileSummary(
        scope: const SicaborScope(
          subdistrictId: 1728,
          subdistrictName: 'Garut Kota',
          districtId: 126,
          districtName: 'Garut',
        ),
        member: const SicaborMember(
          id: 578,
          username: 'kt.garutkota',
          name: 'ADMIN KONTINGEN GARUT KOTA',
          email: null,
          type: 'admin_kok',
          status: 1,
          statusLabel: 'Aktif',
        ),
        kontingen: const SicaborKontingen(
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
        dataNotes: const ['Catatan 1', 'Catatan 2'],
      );

      expect(summary.scope.subdistrictName, equals('Garut Kota'));
      expect(summary.totalCabor, equals(32));
      expect(summary.totalClub, equals(10));
      expect(summary.totalAthlete, equals(361));
      expect(summary.dataNotes.length, equals(2));
    });

    test('PaginatedResult correctly calculates hasMore and nextOffset', () {
      final result1 = PaginatedResult<String>(
        items: ['a', 'b', 'c'],
        limit: 3,
        offset: 0,
        total: 10,
      );
      expect(result1.hasMore, isTrue);
      expect(result1.nextOffset, equals(3));

      final result2 = PaginatedResult<String>(
        items: ['d', 'e'],
        limit: 3,
        offset: 8,
        total: 10,
      );
      expect(result2.hasMore, isFalse);
      expect(result2.nextOffset, equals(10));
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/data/domain_models_test.dart`
Expected: Compilation failure (files not found).

- [ ] **Step 3: Implement domain models**

Create `lib/data/models/cabor.dart`:
```dart
final class Cabor {
  const Cabor({
    required this.id,
    required this.code,
    required this.name,
    this.groupName,
    this.logoUrl,
    required this.status,
    required this.statusLabel,
    required this.totalClub,
    required this.totalAthlete,
  });

  final int id;
  final String code;
  final String name;
  final String? groupName;
  final String? logoUrl;
  final int status;
  final String statusLabel;
  final int totalClub;
  final int totalAthlete;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Cabor &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          code == other.code &&
          name == other.name &&
          groupName == other.groupName &&
          logoUrl == other.logoUrl &&
          status == other.status &&
          statusLabel == other.statusLabel &&
          totalClub == other.totalClub &&
          totalAthlete == other.totalAthlete;

  @override
  int get hashCode => Object.hash(
        id,
        code,
        name,
        groupName,
        logoUrl,
        status,
        statusLabel,
        totalClub,
        totalAthlete,
      );
}
```

Create `lib/data/models/profile_summary.dart`:
```dart
import '../../core/auth/data/dto/sicabor_login_response.dart';
import '../../core/auth/data/dto/sicabor_profile_response.dart';

final class ProfileSummary {
  const ProfileSummary({
    required this.scope,
    required this.member,
    this.kontingen,
    required this.totalCabor,
    required this.totalCaborFromClub,
    required this.totalCaborFromAthlete,
    required this.totalClub,
    required this.totalAthlete,
    required this.totalAthleteWithoutClub,
    this.dataNotes = const [],
  });

  final SicaborScope scope;
  final SicaborMember member;
  final SicaborKontingen? kontingen;
  final int totalCabor;
  final int totalCaborFromClub;
  final int totalCaborFromAthlete;
  final int totalClub;
  final int totalAthlete;
  final int totalAthleteWithoutClub;
  final List<String> dataNotes;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProfileSummary &&
          runtimeType == other.runtimeType &&
          scope == other.scope &&
          member == other.member &&
          kontingen == other.kontingen &&
          totalCabor == other.totalCabor &&
          totalCaborFromClub == other.totalCaborFromClub &&
          totalCaborFromAthlete == other.totalCaborFromAthlete &&
          totalClub == other.totalClub &&
          totalAthlete == other.totalAthlete &&
          totalAthleteWithoutClub == other.totalAthleteWithoutClub;

  @override
  int get hashCode => Object.hash(
        scope,
        member,
        kontingen,
        totalCabor,
        totalCaborFromClub,
        totalCaborFromAthlete,
        totalClub,
        totalAthlete,
        totalAthleteWithoutClub,
      );
}
```

Create `lib/data/models/paginated_result.dart`:
```dart
final class PaginatedResult<T> {
  const PaginatedResult({
    required this.items,
    required this.limit,
    required this.offset,
    required this.total,
  });

  final List<T> items;
  final int limit;
  final int offset;
  final int total;

  bool get hasMore => offset + items.length < total;
  int get nextOffset => offset + items.length;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PaginatedResult<T> &&
          runtimeType == other.runtimeType &&
          limit == other.limit &&
          offset == other.offset &&
          total == other.total;

  @override
  int get hashCode => Object.hash(limit, offset, total);
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/data/domain_models_test.dart`
Expected: All tests pass.

- [ ] **Step 5: Commit changes**

```bash
git add lib/data/models/ test/data/domain_models_test.dart
git commit -m "feat(data): implement Cabor, ProfileSummary, and PaginatedResult domain models"
```

---

### Task 2: DTOs, Generic List Envelope & Data Mapper

**Files:**
- Create: `lib/data/dto/sicabor_cabor_item.dart`
- Create: `lib/data/dto/sicabor_list_envelope.dart`
- Create: `lib/data/mapper/sicabor_data_mapper.dart`
- Test: `test/data/sicabor_data_mapper_test.dart`

**Interfaces:**
- Produces:
  - `class SicaborCaborItem`: `fromJson(Map<String, dynamic>)`
  - `class SicaborListEnvelope<T>`: `fromJson(Map<String, dynamic>, T Function(Map<String, dynamic>))`
  - `class SicaborPaginationMeta`: `fromJson(Map<String, dynamic>)`
  - `class SicaborDataMapper`: `Cabor mapCabor(SicaborCaborItem)`, `ProfileSummary mapProfileSummary(SicaborProfileResponse)`

- [ ] **Step 1: Write failing tests for DTOs and Data Mapper**

```dart
// test/data/sicabor_data_mapper_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:kok_app/core/auth/data/dto/sicabor_profile_response.dart';
import 'package:kok_app/data/dto/sicabor_cabor_item.dart';
import 'package:kok_app/data/dto/sicabor_list_envelope.dart';
import 'package:kok_app/data/mapper/sicabor_data_mapper.dart';

void main() {
  group('SicaborDataMapper & DTO Tests', () {
    test('SicaborCaborItem parses JSON correctly', () {
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

    test('SicaborListEnvelope parses generic list response with meta and scope', () {
      final json = {
        'success': true,
        'message': 'Berhasil mengambil data.',
        'scope': {
          'subdistrict_id': 1728,
          'subdistrict_name': 'Garut Kota',
          'district_id': 126,
          'district_name': 'Garut',
        },
        'meta': {
          'limit': 25,
          'offset': 0,
          'total': 32,
          'source': 'all',
        },
        'data': [
          {
            'id': 9,
            'code': 'KGCB-0010',
            'name': 'ARUNG JERAM',
            'group_name': 'FAJI',
            'logo': null,
            'status': 1,
            'status_label': 'Aktif',
            'total_club': 0,
            'total_athlete': 15,
          }
        ]
      };

      final envelope = SicaborListEnvelope<SicaborCaborItem>.fromJson(
        json,
        SicaborCaborItem.fromJson,
      );

      expect(envelope.success, isTrue);
      expect(envelope.message, equals('Berhasil mengambil data.'));
      expect(envelope.scope.subdistrictName, equals('Garut Kota'));
      expect(envelope.meta.total, equals(32));
      expect(envelope.meta.limit, equals(25));
      expect(envelope.meta.offset, equals(0));
      expect(envelope.data.length, equals(1));
      expect(envelope.data.first.name, equals('ARUNG JERAM'));
    });

    test('SicaborDataMapper maps DTOs to Domain Models', () {
      final caborItem = SicaborCaborItem(
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

      final cabor = SicaborDataMapper.mapCabor(caborItem);
      expect(cabor.id, equals(9));
      expect(cabor.name, equals('ARUNG JERAM'));
      expect(cabor.groupName, equals('FAJI'));
      expect(cabor.logoUrl, equals('https://sicabor.test/logo.png'));
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/data/sicabor_data_mapper_test.dart`
Expected: Compilation failure.

- [ ] **Step 3: Implement DTOs and Data Mapper**

Create `lib/data/dto/sicabor_cabor_item.dart`:
```dart
final class SicaborCaborItem {
  const SicaborCaborItem({
    required this.id,
    required this.code,
    required this.name,
    this.groupName,
    this.logo,
    required this.status,
    required this.statusLabel,
    required this.totalClub,
    required this.totalAthlete,
  });

  final int id;
  final String code;
  final String name;
  final String? groupName;
  final String? logo;
  final int status;
  final String statusLabel;
  final int totalClub;
  final int totalAthlete;

  factory SicaborCaborItem.fromJson(Map<String, dynamic> json) {
    return SicaborCaborItem(
      id: json['id'] is int ? json['id'] as int : int.tryParse(json['id']?.toString() ?? '') ?? 0,
      code: json['code']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      groupName: json['group_name']?.toString(),
      logo: json['logo']?.toString(),
      status: json['status'] is int ? json['status'] as int : int.tryParse(json['status']?.toString() ?? '') ?? 0,
      statusLabel: json['status_label']?.toString() ?? '',
      totalClub: json['total_club'] is int ? json['total_club'] as int : int.tryParse(json['total_club']?.toString() ?? '') ?? 0,
      totalAthlete: json['total_athlete'] is int ? json['total_athlete'] as int : int.tryParse(json['total_athlete']?.toString() ?? '') ?? 0,
    );
  }
}
```

Create `lib/data/dto/sicabor_list_envelope.dart`:
```dart
import '../../core/auth/data/dto/sicabor_profile_response.dart';

final class SicaborPaginationMeta {
  const SicaborPaginationMeta({
    required this.limit,
    required this.offset,
    required this.total,
    this.extra = const {},
  });

  final int limit;
  final int offset;
  final int total;
  final Map<String, dynamic> extra;

  factory SicaborPaginationMeta.fromJson(Map<String, dynamic> json) {
    final limit = json['limit'] is int ? json['limit'] as int : int.tryParse(json['limit']?.toString() ?? '') ?? 25;
    final offset = json['offset'] is int ? json['offset'] as int : int.tryParse(json['offset']?.toString() ?? '') ?? 0;
    final total = json['total'] is int ? json['total'] as int : int.tryParse(json['total']?.toString() ?? '') ?? 0;
    
    final extra = Map<String, dynamic>.from(json)..remove('limit')..remove('offset')..remove('total');

    return SicaborPaginationMeta(
      limit: limit,
      offset: offset,
      total: total,
      extra: extra,
    );
  }
}

final class SicaborListEnvelope<T> {
  const SicaborListEnvelope({
    required this.success,
    required this.message,
    required this.scope,
    required this.meta,
    required this.data,
  });

  final bool success;
  final String message;
  final SicaborScope scope;
  final SicaborPaginationMeta meta;
  final List<T> data;

  factory SicaborListEnvelope.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) itemParser,
  ) {
    final rawData = json['data'];
    final items = <T>[];
    if (rawData is List) {
      for (final element in rawData) {
        if (element is Map<String, dynamic>) {
          items.add(itemParser(element));
        }
      }
    }

    return SicaborListEnvelope<T>(
      success: json['success'] == true,
      message: json['message']?.toString() ?? '',
      scope: json['scope'] is Map<String, dynamic>
          ? SicaborScope.fromJson(json['scope'] as Map<String, dynamic>)
          : const SicaborScope(subdistrictId: 0, subdistrictName: '', districtId: 0, districtName: ''),
      meta: json['meta'] is Map<String, dynamic>
          ? SicaborPaginationMeta.fromJson(json['meta'] as Map<String, dynamic>)
          : const SicaborPaginationMeta(limit: 25, offset: 0, total: 0),
      data: items,
    );
  }
}
```

Create `lib/data/mapper/sicabor_data_mapper.dart`:
```dart
import '../../core/auth/data/dto/sicabor_profile_response.dart';
import '../dto/sicabor_cabor_item.dart';
import '../models/cabor.dart';
import '../models/profile_summary.dart';

abstract final class SicaborDataMapper {
  static Cabor mapCabor(SicaborCaborItem item) => Cabor(
        id: item.id,
        code: item.code,
        name: item.name,
        groupName: item.groupName,
        logoUrl: item.logo,
        status: item.status,
        statusLabel: item.statusLabel,
        totalClub: item.totalClub,
        totalAthlete: item.totalAthlete,
      );

  static ProfileSummary mapProfileSummary(SicaborProfileResponse dto) =>
      ProfileSummary(
        scope: dto.scope,
        member: dto.data.member,
        kontingen: dto.data.kontingen,
        totalCabor: dto.data.summary.totalCabor,
        totalCaborFromClub: dto.data.summary.totalCaborFromClub,
        totalCaborFromAthlete: dto.data.summary.totalCaborFromAthlete,
        totalClub: dto.data.summary.totalClub,
        totalAthlete: dto.data.summary.totalAthlete,
        totalAthleteWithoutClub: dto.data.summary.totalAthleteWithoutClub,
        dataNotes: dto.data.dataNotes,
      );
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/data/sicabor_data_mapper_test.dart`
Expected: All tests pass.

- [ ] **Step 5: Commit changes**

```bash
git add lib/data/dto/ lib/data/mapper/ test/data/sicabor_data_mapper_test.dart
git commit -m "feat(data): implement SICABOR Cabor DTO, generic list envelope, and domain mapper"
```

---

### Task 3: Service Interfaces & Remote Implementations

**Files:**
- Create: `lib/data/services/profile_service.dart`
- Create: `lib/data/services/cabor_service.dart`
- Create: `lib/data/services/remote/remote_profile_service.dart`
- Create: `lib/data/services/remote/remote_cabor_service.dart`
- Test: `test/data/remote_services_test.dart`

**Interfaces:**
- Produces:
  - `abstract interface class ProfileService`: `Future<ProfileSummary> fetchProfileSummary({RequestCancellation? cancellation})`
  - `abstract interface class CaborService`: `Future<PaginatedResult<Cabor>> fetchCaborList({int limit = 25, int offset = 0, String source = 'all', String sort = 'name', RequestCancellation? cancellation})`
  - `class RemoteProfileService implements ProfileService`
  - `class RemoteCaborService implements CaborService`

- [ ] **Step 1: Write failing tests for Remote Services**

```dart
// test/data/remote_services_test.dart
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kok_app/core/config/deployment_profile.dart';
import 'package:kok_app/core/network/api_client.dart';
import 'package:kok_app/core/network/auth_session_tokens.dart';
import 'package:kok_app/data/services/remote/remote_cabor_service.dart';
import 'package:kok_app/data/services/remote/remote_profile_service.dart';

void main() {
  group('Remote Services Tests', () {
    late Dio dio;
    late ApiClient apiClient;
    late AuthSessionTokens tokens;

    setUp(() {
      dio = Dio();
      tokens = AuthSessionTokens();
      tokens.setTokens(accessToken: 'mock_token', sessionToken: 'mock_token');
      const profile = DeploymentProfile(
        environment: AppEnv.staging,
        authMode: AuthMode.remote,
        dataMode: DataMode.remote,
        apiBaseUrl: 'https://sicabor.test/api/v1/kok',
      );
      apiClient = ApiClient(profile: profile, tokens: tokens, dio: dio);
    });

    test('RemoteProfileService fetches and maps ProfileSummary', () async {
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            if (options.path.endsWith('/profile')) {
              return handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 200,
                  data: {
                    'success': true,
                    'message': 'OK',
                    'scope': {
                      'subdistrict_id': 1728,
                      'subdistrict_name': 'Garut Kota',
                      'district_id': 126,
                      'district_name': 'Garut',
                    },
                    'data': {
                      'member': {
                        'id': 578,
                        'username': 'kt.garutkota',
                        'name': 'ADMIN KONTINGEN GARUT KOTA',
                        'type': 'admin_kok',
                        'status': 1,
                        'status_label': 'Aktif',
                      },
                      'summary': {
                        'total_cabor': 32,
                        'total_cabor_from_club': 5,
                        'total_cabor_from_athlete': 31,
                        'total_club': 10,
                        'total_athlete': 361,
                        'total_athlete_without_club': 320,
                      },
                      'data_notes': ['Catatan'],
                    }
                  },
                ),
              );
            }
            return handler.next(options);
          },
        ),
      );

      final service = RemoteProfileService(apiClient);
      final summary = await service.fetchProfileSummary();
      expect(summary.totalCabor, equals(32));
      expect(summary.scope.subdistrictName, equals('Garut Kota'));
    });

    test('RemoteCaborService fetches and maps PaginatedResult<Cabor>', () async {
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            if (options.path.endsWith('/cabor')) {
              return handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 200,
                  data: {
                    'success': true,
                    'message': 'OK',
                    'scope': {
                      'subdistrict_id': 1728,
                      'subdistrict_name': 'Garut Kota',
                      'district_id': 126,
                      'district_name': 'Garut',
                    },
                    'meta': {
                      'limit': 25,
                      'offset': 0,
                      'total': 1,
                    },
                    'data': [
                      {
                        'id': 9,
                        'code': 'KGCB-0010',
                        'name': 'ARUNG JERAM',
                        'group_name': 'FAJI',
                        'status': 1,
                        'status_label': 'Aktif',
                        'total_club': 0,
                        'total_athlete': 15,
                      }
                    ]
                  },
                ),
              );
            }
            return handler.next(options);
          },
        ),
      );

      final service = RemoteCaborService(apiClient);
      final result = await service.fetchCaborList(limit: 25, offset: 0);
      expect(result.total, equals(1));
      expect(result.items.first.name, equals('ARUNG JERAM'));
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/data/remote_services_test.dart`
Expected: Compilation failure.

- [ ] **Step 3: Implement Service Interfaces and Remote Classes**

Create `lib/data/services/profile_service.dart`:
```dart
import '../models/profile_summary.dart';
import '../request_cancellation.dart';

abstract interface class ProfileService {
  Future<ProfileSummary> fetchProfileSummary({
    RequestCancellation? cancellation,
  });
}
```

Create `lib/data/services/cabor_service.dart`:
```dart
import '../models/cabor.dart';
import '../models/paginated_result.dart';
import '../request_cancellation.dart';

abstract interface class CaborService {
  Future<PaginatedResult<Cabor>> fetchCaborList({
    int limit = 25,
    int offset = 0,
    String source = 'all',
    String sort = 'name',
    RequestCancellation? cancellation,
  });
}
```

Create `lib/data/services/remote/remote_profile_service.dart`:
```dart
import '../../../core/auth/data/dto/sicabor_profile_response.dart';
import '../../../core/network/api_client.dart';
import '../../mapper/sicabor_data_mapper.dart';
import '../../models/profile_summary.dart';
import '../../request_cancellation.dart';
import '../profile_service.dart';

final class RemoteProfileService implements ProfileService {
  const RemoteProfileService(this._client);

  final ApiClient _client;

  @override
  Future<ProfileSummary> fetchProfileSummary({
    RequestCancellation? cancellation,
  }) async {
    final response = await _client.request(
      '/profile',
      method: 'GET',
      cancellation: cancellation,
    );
    final json = response.data as Map<String, dynamic>;
    final dto = SicaborProfileResponse.fromJson(json);
    return SicaborDataMapper.mapProfileSummary(dto);
  }
}
```

Create `lib/data/services/remote/remote_cabor_service.dart`:
```dart
import '../../../core/network/api_client.dart';
import '../../dto/sicabor_cabor_item.dart';
import '../../dto/sicabor_list_envelope.dart';
import '../../mapper/sicabor_data_mapper.dart';
import '../../models/cabor.dart';
import '../../models/paginated_result.dart';
import '../../request_cancellation.dart';
import '../cabor_service.dart';

final class RemoteCaborService implements CaborService {
  const RemoteCaborService(this._client);

  final ApiClient _client;

  @override
  Future<PaginatedResult<Cabor>> fetchCaborList({
    int limit = 25,
    int offset = 0,
    String source = 'all',
    String sort = 'name',
    RequestCancellation? cancellation,
  }) async {
    final response = await _client.request(
      '/cabor',
      method: 'GET',
      queryParameters: {
        'limit': limit,
        'offset': offset,
        'source': source,
        'sort': sort,
      },
      cancellation: cancellation,
    );
    final json = response.data as Map<String, dynamic>;
    final envelope = SicaborListEnvelope<SicaborCaborItem>.fromJson(
      json,
      SicaborCaborItem.fromJson,
    );
    final caborItems = envelope.data.map(SicaborDataMapper.mapCabor).toList();
    return PaginatedResult<Cabor>(
      items: caborItems,
      limit: envelope.meta.limit,
      offset: envelope.meta.offset,
      total: envelope.meta.total,
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/data/remote_services_test.dart`
Expected: All tests pass.

- [ ] **Step 5: Commit changes**

```bash
git add lib/data/services/ test/data/remote_services_test.dart
git commit -m "feat(data): implement ProfileService and CaborService remote implementations"
```

---

### Task 4: Demo Service Adapters

**Files:**
- Create: `lib/data/services/demo/demo_profile_service.dart`
- Create: `lib/data/services/demo/demo_cabor_service.dart`
- Test: `test/data/demo_services_test.dart`

**Interfaces:**
- Produces:
  - `class DemoProfileService implements ProfileService`
  - `class DemoCaborService implements CaborService`

- [ ] **Step 1: Write failing tests for Demo Services**

```dart
// test/data/demo_services_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:kok_app/core/auth/domain/user_principal.dart';
import 'package:kok_app/data/demo_kok_repository.dart';
import 'package:kok_app/data/services/demo/demo_cabor_service.dart';
import 'package:kok_app/data/services/demo/demo_profile_service.dart';

void main() {
  group('Demo Services Tests', () {
    late DemoKokRepository demoRepo;
    const scope = AccessScope(
      type: AccessScopeType.district,
      id: '1728',
      name: 'Garut Kota',
    );

    setUp(() {
      demoRepo = DemoKokRepository(simulateLatency: false);
    });

    test('DemoProfileService adapts snapshot into ProfileSummary', () async {
      final service = DemoProfileService(
        demoRepo: demoRepo,
        currentScopeProvider: () => scope,
      );
      final summary = await service.fetchProfileSummary();
      expect(summary.totalCabor, equals(5));
      expect(summary.totalClub, equals(5));
      expect(summary.totalAthlete, equals(125));
    });

    test('DemoCaborService adapts snapshot into PaginatedResult<Cabor>', () async {
      final service = DemoCaborService(
        demoRepo: demoRepo,
        currentScopeProvider: () => scope,
      );
      final result = await service.fetchCaborList(limit: 2, offset: 0);
      expect(result.total, equals(5));
      expect(result.items.length, equals(2));
      expect(result.hasMore, isTrue);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/data/demo_services_test.dart`
Expected: Compilation failure.

- [ ] **Step 3: Implement Demo Services**

Create `lib/data/services/demo/demo_profile_service.dart`:
```dart
import '../../../core/auth/data/dto/sicabor_login_response.dart';
import '../../../core/auth/data/dto/sicabor_profile_response.dart';
import '../../../core/auth/domain/user_principal.dart';
import '../../demo_kok_repository.dart';
import '../../models/profile_summary.dart';
import '../../request_cancellation.dart';
import '../profile_service.dart';

final class DemoProfileService implements ProfileService {
  DemoProfileService({
    required DemoKokRepository demoRepo,
    required AccessScope Function() currentScopeProvider,
  })  : _demoRepo = demoRepo,
        _currentScopeProvider = currentScopeProvider;

  final DemoKokRepository _demoRepo;
  final AccessScope Function() _currentScopeProvider;

  @override
  Future<ProfileSummary> fetchProfileSummary({
    RequestCancellation? cancellation,
  }) async {
    final scope = _currentScopeProvider();
    final snapshot = await _demoRepo.fetchScope(scope, cancellation: cancellation);
    final athletes = snapshot.people.where((p) => p.role == 'Atlet').toList();
    final sports = snapshot.clubs.map((c) => c.sport).toSet();

    return ProfileSummary(
      scope: SicaborScope(
        subdistrictId: int.tryParse(scope.id) ?? 1728,
        subdistrictName: scope.name,
        districtId: 126,
        districtName: 'Kabupaten Garut',
      ),
      member: const SicaborMember(
        id: 578,
        username: 'kt.garutkota',
        name: 'ADMIN KONTINGEN GARUT KOTA',
        type: 'admin_kok',
        status: 1,
        statusLabel: 'Aktif',
      ),
      kontingen: SicaborKontingen(
        id: 1,
        code: 'KGPK-0001',
        name: scope.name,
      ),
      totalCabor: sports.length,
      totalCaborFromClub: sports.length,
      totalCaborFromAthlete: sports.length,
      totalClub: snapshot.clubs.length,
      totalAthlete: athletes.length,
      totalAthleteWithoutClub: 0,
      dataNotes: const ['Mode Demo: Menampilkan dataset simulasi lokal KOK.'],
    );
  }
}
```

Create `lib/data/services/demo/demo_cabor_service.dart`:
```dart
import '../../../core/auth/domain/user_principal.dart';
import '../../demo_kok_repository.dart';
import '../../models/cabor.dart';
import '../../models/paginated_result.dart';
import '../../request_cancellation.dart';
import '../cabor_service.dart';

final class DemoCaborService implements CaborService {
  DemoCaborService({
    required DemoKokRepository demoRepo,
    required AccessScope Function() currentScopeProvider,
  })  : _demoRepo = demoRepo,
        _currentScopeProvider = currentScopeProvider;

  final DemoKokRepository _demoRepo;
  final AccessScope Function() _currentScopeProvider;

  @override
  Future<PaginatedResult<Cabor>> fetchCaborList({
    int limit = 25,
    int offset = 0,
    String source = 'all',
    String sort = 'name',
    RequestCancellation? cancellation,
  }) async {
    final scope = _currentScopeProvider();
    final snapshot = await _demoRepo.fetchScope(scope, cancellation: cancellation);
    final sports = snapshot.clubs.map((c) => c.sport).toSet().toList()..sort();

    final caborList = <Cabor>[];
    for (var i = 0; i < sports.length; i++) {
      final sportName = sports[i];
      final clubsWithSport = snapshot.clubs.where((c) => c.sport == sportName).toList();
      final athletesCount = snapshot.people.where(
        (p) => p.role == 'Atlet' && snapshot.clubs.any((c) => c.id == p.clubId && c.sport == sportName),
      ).length;

      caborList.add(
        Cabor(
          id: i + 1,
          code: 'DEMO-CB-${(i + 1).toString().padLeft(3, '0')}',
          name: sportName.toUpperCase(),
          status: 1,
          statusLabel: 'Aktif',
          totalClub: clubsWithSport.length,
          totalAthlete: athletesCount,
        ),
      );
    }

    final pageItems = caborList.skip(offset).take(limit).toList();
    return PaginatedResult<Cabor>(
      items: pageItems,
      limit: limit,
      offset: offset,
      total: caborList.length,
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/data/demo_services_test.dart`
Expected: All tests pass.

- [ ] **Step 5: Commit changes**

```bash
git add lib/data/services/demo/ test/data/demo_services_test.dart
git commit -m "feat(data): implement DemoProfileService and DemoCaborService adapters"
```

---

### Task 5: Riverpod Providers & Pagination Controller

**Files:**
- Create: `lib/data/providers/profile_providers.dart`
- Create: `lib/data/providers/cabor_providers.dart`
- Test: `test/data/cabor_providers_test.dart`

**Interfaces:**
- Produces:
  - `profileServiceProvider`: `Provider<ProfileService>`
  - `caborServiceProvider`: `Provider<CaborService>`
  - `profileSummaryProvider`: `FutureProvider<ProfileSummary>`
  - `caborListProvider`: `FutureProvider.family<PaginatedResult<Cabor>, CaborListParams>`
  - `caborPaginationProvider`: `NotifierProvider<CaborPaginationController, CaborPaginationState>`

- [ ] **Step 1: Write failing tests for Providers & Pagination Controller**

```dart
// test/data/cabor_providers_test.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kok_app/core/auth/data/dto/sicabor_login_response.dart';
import 'package:kok_app/core/auth/data/dto/sicabor_profile_response.dart';
import 'package:kok_app/core/auth/domain/user_principal.dart';
import 'package:kok_app/core/auth/presentation/auth_controller.dart';
import 'package:kok_app/data/api_readiness/data_request_context.dart';
import 'package:kok_app/data/models/cabor.dart';
import 'package:kok_app/data/models/paginated_result.dart';
import 'package:kok_app/data/models/profile_summary.dart';
import 'package:kok_app/data/providers/cabor_providers.dart';
import 'package:kok_app/data/providers/profile_providers.dart';
import 'package:kok_app/data/request_cancellation.dart';
import 'package:kok_app/data/services/cabor_service.dart';
import 'package:kok_app/data/services/profile_service.dart';

class MockProfileService implements ProfileService {
  @override
  Future<ProfileSummary> fetchProfileSummary({RequestCancellation? cancellation}) async {
    return const ProfileSummary(
      scope: SicaborScope(subdistrictId: 1728, subdistrictName: 'Garut Kota', districtId: 126, districtName: 'Garut'),
      member: SicaborMember(id: 1, username: 'user', name: 'User', type: 'admin_kok', status: 1, statusLabel: 'Aktif'),
      totalCabor: 5,
      totalCaborFromClub: 5,
      totalCaborFromAthlete: 5,
      totalClub: 10,
      totalAthlete: 50,
      totalAthleteWithoutClub: 0,
    );
  }
}

class MockCaborService implements CaborService {
  @override
  Future<PaginatedResult<Cabor>> fetchCaborList({
    int limit = 25,
    int offset = 0,
    String source = 'all',
    String sort = 'name',
    RequestCancellation? cancellation,
  }) async {
    final items = List.generate(
      limit,
      (i) => Cabor(
        id: offset + i + 1,
        code: 'CB-${offset + i + 1}',
        name: 'Cabor ${offset + i + 1}',
        status: 1,
        statusLabel: 'Aktif',
        totalClub: 1,
        totalAthlete: 10,
      ),
    );
    return PaginatedResult(items: items, limit: limit, offset: offset, total: 50);
  }
}

void main() {
  group('Cabor & Profile Providers Tests', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer(
        overrides: [
          profileServiceProvider.overrideWithValue(MockProfileService()),
          caborServiceProvider.overrideWithValue(MockCaborService()),
          dataRequestContextProvider.overrideWithValue(
            const DataRequestContext(
              userId: '1',
              scope: AccessScope(type: AccessScopeType.district, id: '1728', name: 'Garut Kota'),
              generation: 1,
            ),
          ),
        ],
      );
    });

    tearDown(() => container.dispose());

    test('profileSummaryProvider loads data successfully', () async {
      final summary = await container.read(profileSummaryProvider.future);
      expect(summary.totalCabor, equals(5));
      expect(summary.totalClub, equals(10));
    });

    test('CaborPaginationController loads first page and loads more', () async {
      final controller = container.read(caborPaginationProvider.notifier);
      await controller.loadFirstPage();

      final state1 = container.read(caborPaginationProvider);
      expect(state1.items.length, equals(25));
      expect(state1.hasMore, isTrue);

      await controller.loadMore();
      final state2 = container.read(caborPaginationProvider);
      expect(state2.items.length, equals(50));
      expect(state2.hasMore, isFalse);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/data/cabor_providers_test.dart`
Expected: Compilation failure.

- [ ] **Step 3: Implement Providers & Pagination State/Controller**

Create `lib/data/providers/profile_providers.dart`:
```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/composition/app_composition.dart';
import '../api_readiness/data_request_context.dart';
import '../models/profile_summary.dart';
import '../request_cancellation.dart';
import '../services/profile_service.dart';

final profileServiceProvider = Provider<ProfileService>((ref) {
  return ref.watch(appCompositionProvider).profileService;
});

final profileSummaryProvider = FutureProvider<ProfileSummary>((ref) async {
  final context = ref.watch(dataRequestContextProvider);
  if (context == null) {
    throw const RequestCancelledException('Sesi tidak aktif atau telah berakhir.');
  }

  final service = ref.watch(profileServiceProvider);
  final cancellationController = RequestCancellationController();
  ref.onDispose(() => cancellationController.cancel());

  final summary = await service.fetchProfileSummary(
    cancellation: cancellationController.token,
  );

  final currentContext = ref.read(dataRequestContextProvider);
  if (currentContext != context) {
    throw const RequestCancelledException('Konteks sesi berubah saat memuat ringkasan.');
  }

  return summary;
});
```

Create `lib/data/providers/cabor_providers.dart`:
```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/composition/app_composition.dart';
import '../api_readiness/data_request_context.dart';
import '../models/cabor.dart';
import '../models/paginated_result.dart';
import '../request_cancellation.dart';
import '../services/cabor_service.dart';

final caborServiceProvider = Provider<CaborService>((ref) {
  return ref.watch(appCompositionProvider).caborService;
});

typedef CaborListParams = ({
  int offset,
  int limit,
  String source,
  String sort,
});

final caborListProvider = FutureProvider.family<PaginatedResult<Cabor>, CaborListParams>(
  (ref, params) async {
    final context = ref.watch(dataRequestContextProvider);
    if (context == null) {
      throw const RequestCancelledException('Sesi tidak aktif atau telah berakhir.');
    }

    final service = ref.watch(caborServiceProvider);
    final cancellationController = RequestCancellationController();
    ref.onDispose(() => cancellationController.cancel());

    final result = await service.fetchCaborList(
      limit: params.limit,
      offset: params.offset,
      source: params.source,
      sort: params.sort,
      cancellation: cancellationController.token,
    );

    final currentContext = ref.read(dataRequestContextProvider);
    if (currentContext != context) {
      throw const RequestCancelledException('Konteks sesi berubah saat memuat daftar cabor.');
    }

    return result;
  },
);

final class CaborPaginationState {
  const CaborPaginationState({
    this.items = const [],
    this.total = 0,
    this.hasMore = false,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.error,
    this.loadMoreError,
    this.source = 'all',
    this.sort = 'name',
  });

  final List<Cabor> items;
  final int total;
  final bool hasMore;
  final bool isLoading;
  final bool isLoadingMore;
  final Object? error;
  final Object? loadMoreError;
  final String source;
  final String sort;

  CaborPaginationState copyWith({
    List<Cabor>? items,
    int? total,
    bool? hasMore,
    bool? isLoading,
    bool? isLoadingMore,
    Object? error,
    Object? loadMoreError,
    String? source,
    String? sort,
  }) {
    return CaborPaginationState(
      items: items ?? this.items,
      total: total ?? this.total,
      hasMore: hasMore ?? this.hasMore,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      error: error,
      loadMoreError: loadMoreError,
      source: source ?? this.source,
      sort: sort ?? this.sort,
    );
  }
}

class CaborPaginationController extends Notifier<CaborPaginationState> {
  static const int pageSize = 25;

  @override
  CaborPaginationState build() {
    return const CaborPaginationState();
  }

  Future<void> loadFirstPage({String source = 'all', String sort = 'name'}) async {
    state = state.copyWith(isLoading: true, error: null, source: source, sort: sort);
    try {
      final result = await ref.read(
        caborListProvider((offset: 0, limit: pageSize, source: source, sort: sort)).future,
      );
      state = state.copyWith(
        items: result.items,
        total: result.total,
        hasMore: result.hasMore,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e);
    }
  }

  Future<void> loadMore() async {
    if (state.isLoading || state.isLoadingMore || !state.hasMore) return;
    state = state.copyWith(isLoadingMore: true, loadMoreError: null);
    try {
      final result = await ref.read(
        caborListProvider((
          offset: state.items.length,
          limit: pageSize,
          source: state.source,
          sort: state.sort,
        )).future,
      );
      state = state.copyWith(
        items: [...state.items, ...result.items],
        total: result.total,
        hasMore: result.hasMore,
        isLoadingMore: false,
      );
    } catch (e) {
      state = state.copyWith(isLoadingMore: false, loadMoreError: e);
    }
  }

  Future<void> refresh() => loadFirstPage(source: state.source, sort: state.sort);
}

final caborPaginationProvider = NotifierProvider<CaborPaginationController, CaborPaginationState>(
  CaborPaginationController.new,
);
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/data/cabor_providers_test.dart`
Expected: All tests pass.

- [ ] **Step 5: Commit changes**

```bash
git add lib/data/providers/ test/data/cabor_providers_test.dart
git commit -m "feat(data): implement profileSummaryProvider, caborListProvider, and caborPaginationController"
```

---

### Task 6: AppComposition & DI Wiring

**Files:**
- Modify: `lib/core/composition/app_composition.dart`
- Test: `test/app_environment_test.dart`

**Interfaces:**
- Produces:
  - `AppComposition`: fields `ProfileService profileService`, `CaborService caborService`

- [ ] **Step 1: Update AppComposition fields and factory**

Modify `lib/core/composition/app_composition.dart` to inject `profileService` and `caborService` based on `profile.dataMode`:
- In `DataMode.demo`:
  ```dart
  final demoProfileService = DemoProfileService(
    demoRepo: demoRepo,
    currentScopeProvider: () => const AccessScope(type: AccessScopeType.district, id: '1728', name: 'Garut Kota'),
  );
  final demoCaborService = DemoCaborService(
    demoRepo: demoRepo,
    currentScopeProvider: () => const AccessScope(type: AccessScopeType.district, id: '1728', name: 'Garut Kota'),
  );
  ```
- In `DataMode.remote`:
  ```dart
  final remoteProfileService = RemoteProfileService(apiClient!);
  final remoteCaborService = RemoteCaborService(apiClient!);
  ```

- [ ] **Step 2: Run app_environment_test to verify composition**

Run: `flutter test test/app_environment_test.dart`
Expected: All tests pass.

- [ ] **Step 3: Commit changes**

```bash
git add lib/core/composition/app_composition.dart test/app_environment_test.dart
git commit -m "feat(composition): wire ProfileService and CaborService into AppComposition"
```

---

### Task 7: UI Beranda (`HomePage`) Migration

**Files:**
- Modify: `lib/features/home_page.dart`
- Test: `test/home_page_test.dart`

**Interfaces:**
- Consumes: `profileSummaryProvider`, `appCompositionProvider`

- [ ] **Step 1: Update `home_page_test.dart` to test `profileSummaryProvider` states**

Ensure tests verify:
- Displays dynamic subdistrict name from `summary.scope.subdistrictName`.
- Displays Total Cabor, Total Klub, Total Atlet, Atlet Tanpa Klub.
- Displays `dataNotes` cards when present.
- In remote mode, hides demo-only metrics (verified %, missing docs, expired license).

- [ ] **Step 2: Update `HomePage` implementation**

Replace `DataView` on `snapshotProvider` with `ref.watch(profileSummaryProvider).when(...)`.
Conditionally hide unpopulated demo tiles when `profile.dataMode == DataMode.remote`.
Add pull-to-refresh (`ref.refresh(profileSummaryProvider)`).

- [ ] **Step 3: Run home_page_test to verify**

Run: `flutter test test/home_page_test.dart`
Expected: All tests pass.

- [ ] **Step 4: Commit changes**

```bash
git add lib/features/home_page.dart test/home_page_test.dart
git commit -m "feat(ui): migrate HomePage to profileSummaryProvider with server metrics and data notes"
```

---

### Task 8: UI Cabor (`SportsPage`) & Detail Navigation Migration

**Files:**
- Modify: `lib/features/sports_page.dart`
- Modify: `lib/features/sport_detail/sport_detail_page.dart`
- Modify: `lib/app.dart`
- Test: `test/sports_page_test.dart`
- Test: `test/sport_detail_test.dart`

**Interfaces:**
- Consumes: `caborPaginationProvider`, `CaborPaginationController`

- [ ] **Step 1: Update `sports_page_test.dart` and `sport_detail_test.dart`**

Verify infinite scrolling, logo loading with fallback, `groupName` subtitle, cabor total athletes & clubs, and navigation using `cabor.id`.

- [ ] **Step 2: Update `SportsPage` to use `caborPaginationProvider`**

- Initialize with `loadFirstPage()` in `initState` or `ConsumerState`.
- Render `NotificationListener<ScrollNotification>` for infinite scroll `loadMore()`.
- Display Cabor list item with `cabor.name`, `cabor.groupName`, `cabor.totalClub`, `cabor.totalAthlete`, and `cabor.logoUrl`.
- Tapping item navigates to `/sport/${cabor.id}`.

- [ ] **Step 3: Update `AppRouter` and `SportDetailPage` for Cabor ID**

Route `/sport/:id` accepts `int caborId`. Detail page displays Cabor summary and tabs with "Dalam Pengembangan" placeholder.

- [ ] **Step 4: Run tests to verify**

Run: `flutter test test/sports_page_test.dart test/sport_detail_test.dart`
Expected: All tests pass.

- [ ] **Step 5: Commit changes**

```bash
git add lib/features/sports_page.dart lib/features/sport_detail/ lib/app.dart test/sports_page_test.dart test/sport_detail_test.dart
git commit -m "feat(ui): migrate SportsPage to caborPaginationProvider with infinite scroll and dynamic cabor details"
```

---

### Task 9: End-to-End Verification & Documentation Update

**Files:**
- Modify: `docs/project-status.md`
- Test: All tests (`flutter test`, `flutter analyze`)

- [ ] **Step 1: Run full test suite and static analysis**

Run:
```bash
flutter analyze
flutter test
```
Expected: 0 issues, all tests pass.

- [ ] **Step 2: Update project status document**

Update `docs/project-status.md` indicating Milestone 2 (Data Beranda & Cabor) is completed and verified.

- [ ] **Step 3: Commit and push changes**

```bash
git add docs/project-status.md
git commit -m "docs: update project status for Milestone 2 Beranda and Cabor integration"
git push gitlab feat/sicabor-auth
git push origin feat/sicabor-auth
```
