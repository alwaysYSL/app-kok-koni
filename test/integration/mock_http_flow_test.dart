import 'dart:io';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kok_app/core/auth/data/secure_key_val_store.dart';
import 'package:kok_app/core/auth/domain/auth_failure.dart';
import 'package:kok_app/core/composition/app_composition.dart';
import 'package:kok_app/core/config/deployment_profile.dart';
import 'package:kok_app/core/network/api_exceptions.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../scripts/mock_server/sicabor_mock_server.dart';

class _InMemorySecureStore implements SecureKeyValStore {
  final Map<String, String> _storage = {};

  @override
  Future<String?> read({required String key}) async => _storage[key];

  @override
  Future<void> write({required String key, required String value}) async {
    _storage[key] = value;
  }

  @override
  Future<void> delete({required String key}) async {
    _storage.remove(key);
  }

  @override
  Future<bool> containsKey({required String key}) async =>
      _storage.containsKey(key);
}

void main() {
  group('Real HTTP Integration Tests against SicaborMockServer', () {
    late SicaborMockServer server;
    late int serverPort;
    late AppComposition composition;
    late SharedPreferences prefs;
    late _InMemorySecureStore secureStore;

    setUp(() async {
      server = SicaborMockServer();
      final httpServer = await server.start(
        host: '127.0.0.1',
        port: 0,
        verbose: false,
      );
      serverPort = httpServer.port;
      addTearDown(() async {
        await server.stop();
      });

      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      secureStore = _InMemorySecureStore();

      final profile = DeploymentProfile(
        environment: AppEnv.staging,
        authMode: AuthMode.remote,
        dataMode: DataMode.remote,
        apiBaseUrl: 'http://127.0.0.1:$serverPort/api/v1/kok',
      );

      composition = AppComposition.fromProfile(
        profile,
        preferences: prefs,
        secureStore: secureStore,
      );
    });

    test(
      'mock image URLs load from the requested host and keep fallbacks',
      () async {
        final login = await composition.authRepository.login(
          username: 'kt.garutkota',
          password: 'password123',
          staySignedIn: true,
        );
        final client = HttpClient();
        addTearDown(client.close);

        Future<Map<String, dynamic>> fetch(String path) async {
          final request = await client.get('127.0.0.1', serverPort, path);
          request.headers.set('Authorization', 'Bearer ${login.accessToken}');
          final response = await request.close();
          expect(response.statusCode, HttpStatus.ok);
          return jsonDecode(await utf8.decodeStream(response))
              as Map<String, dynamic>;
        }

        Future<void> expectPng(String url) async {
          final uri = Uri.parse(url);
          expect(uri.host, '127.0.0.1');
          expect(uri.port, serverPort);
          final response = await (await client.getUrl(uri)).close();
          expect(response.statusCode, HttpStatus.ok);
          expect(response.headers.contentType?.mimeType, 'image/png');
          final bytes = await response.fold<List<int>>(
            <int>[],
            (out, chunk) => out..addAll(chunk),
          );
          expect(bytes.take(8).toList(), [137, 80, 78, 71, 13, 10, 26, 10]);
        }

        final cabor = await fetch('/api/v1/kok/cabor?limit=100');
        final cabors = cabor['data'] as List;
        await expectPng(
          (cabors.firstWhere((c) => c['id'] == 1) as Map)['logo'] as String,
        );
        expect(cabors.any((c) => c['logo'] == null), isTrue);

        final club = await fetch('/api/v1/kok/club/detail/30');
        await expectPng(club['data']['logo'] as String);
        final failedClub = await fetch('/api/v1/kok/club/detail/29');
        expect(failedClub['data']['logo'], contains('sicabor.test'));

        final athlete = await fetch('/api/v1/kok/athlete/detail/2375');
        await expectPng(athlete['data']['photo'] as String);
      },
    );

    test(
      'Login & retrieve profile summary for kt.garutkota over real HTTP',
      () async {
        final loginResult = await composition.authRepository.login(
          username: 'kt.garutkota',
          password: 'password123',
          staySignedIn: true,
        );

        expect(loginResult.isSuccess, isTrue);
        final user = loginResult.user;
        expect(user, isNotNull);
        expect(user!.username, 'kt.garutkota');
        expect(user.fullName, 'ADMIN KONTINGEN GARUT KOTA');
        expect(user.scope.id, '1728');
        expect(user.scope.name, 'Garut Kota');
        expect(loginResult.accessToken, isNotEmpty);

        // Update active session tokens in composition
        composition.sessionTokens.replace(
          accessToken: loginResult.accessToken,
          sessionToken: loginResult.sessionToken,
        );

        final profileSummary = await composition.profileService
            .fetchProfileSummary();
        expect(profileSummary.scope.subdistrictId, 1728);
        expect(profileSummary.scope.subdistrictName, 'Garut Kota');
        expect(profileSummary.member.username, 'kt.garutkota');
        expect(profileSummary.member.name, 'ADMIN KONTINGEN GARUT KOTA');
        expect(profileSummary.totalCabor, 32);
        expect(profileSummary.totalClub, 10);
        expect(profileSummary.totalAthlete, 361);
        expect(profileSummary.dataNotes, isNotEmpty);
      },
    );

    test(
      'Fetch Cabor list with pagination (> 25 items across page 1 and page 2)',
      () async {
        // Authenticate as Garut Kota
        final loginResult = await composition.authRepository.login(
          username: 'kt.garutkota',
          password: 'password123',
          staySignedIn: true,
        );
        composition.sessionTokens.replace(
          accessToken: loginResult.accessToken,
          sessionToken: loginResult.sessionToken,
        );

        // Fetch Page 1 (limit: 25, offset: 0)
        final page1 = await composition.caborService.fetchCaborList(
          limit: 25,
          offset: 0,
        );
        expect(page1.limit, 25);
        expect(page1.offset, 0);
        expect(page1.total, 32);
        expect(page1.items.length, 25);
        expect(page1.hasMore, isTrue);

        // Fetch Page 2 (limit: 25, offset: 25)
        final page2 = await composition.caborService.fetchCaborList(
          limit: 25,
          offset: 25,
        );
        expect(page2.limit, 25);
        expect(page2.offset, 25);
        expect(page2.total, 32);
        expect(page2.items.length, 7);
        expect(page2.hasMore, isFalse);

        // Verify all 32 items are unique and non-overlapping across pages
        final page1Ids = page1.items.map((c) => c.id).toSet();
        final page2Ids = page2.items.map((c) => c.id).toSet();
        expect(page1Ids.length, 25);
        expect(page2Ids.length, 7);
        expect(page1Ids.intersection(page2Ids), isEmpty);
        expect({...page1Ids, ...page2Ids}.length, 32);

        // Verify filtering by source
        final clubCabors = await composition.caborService.fetchCaborList(
          source: 'club',
        );
        expect(clubCabors.total, 5);
        expect(clubCabors.items.length, 5);

        final athleteCabors = await composition.caborService.fetchCaborList(
          source: 'athlete',
        );
        expect(athleteCabors.total, 31);
        expect(athleteCabors.items.length, 25);
      },
    );

    test('Fetch Athlete list and detail with filters', () async {
      final loginResult = await composition.authRepository.login(
        username: 'kt.garutkota',
        password: 'password123',
        staySignedIn: true,
      );
      composition.sessionTokens.replace(
        accessToken: loginResult.accessToken,
        sessionToken: loginResult.sessionToken,
      );

      final athleteList = await composition.athleteService.fetchAthleteList(
        limit: 10,
        offset: 0,
      );
      expect(athleteList.total, 361);
      expect(athleteList.items.length, 10);

      final firstAthlete = athleteList.items.first;
      expect(firstAthlete.id, isPositive);
      expect(firstAthlete.name, isNotEmpty);
      expect(firstAthlete.cabor.name, isNotEmpty);
      expect(firstAthlete.domicile.subdistrictName, 'Garut Kota');

      // Fetch detail for the first athlete
      final athleteDetail = await composition.athleteService.fetchAthleteDetail(
        firstAthlete.id,
      );
      expect(athleteDetail.id, firstAthlete.id);
      expect(athleteDetail.name, firstAthlete.name);
      expect(athleteDetail.cabor.name, firstAthlete.cabor.name);
      expect(athleteDetail.domicile.subdistrictName, 'Garut Kota');
      expect(athleteDetail.phone, isNotNull);
      expect(athleteDetail.email, isNotNull);

      // Filter athletes by gender
      final maleAthletes = await composition.athleteService.fetchAthleteList(
        sex: 'l',
      );
      expect(maleAthletes.total, isPositive);
      for (final a in maleAthletes.items) {
        expect(a.sex, 'l');
      }

      final femaleAthletes = await composition.athleteService.fetchAthleteList(
        sex: 'p',
      );
      expect(femaleAthletes.total, isPositive);
      for (final a in femaleAthletes.items) {
        expect(a.sex, 'p');
      }
    });

    test('Fetch Club list and detail with management structure', () async {
      final loginResult = await composition.authRepository.login(
        username: 'kt.garutkota',
        password: 'password123',
        staySignedIn: true,
      );
      composition.sessionTokens.replace(
        accessToken: loginResult.accessToken,
        sessionToken: loginResult.sessionToken,
      );

      final clubList = await composition.clubService.fetchClubList(
        limit: 10,
        offset: 0,
      );
      expect(clubList.total, 10);
      expect(clubList.items.length, 10);

      final firstClub = clubList.items.first;
      expect(firstClub.id, isPositive);
      expect(firstClub.name, isNotEmpty);
      expect(firstClub.cabor.name, isNotEmpty);
      expect(firstClub.secretariat.subdistrictName, 'Garut Kota');

      // Fetch detail for the first club
      final clubDetail = await composition.clubService.fetchClubDetail(
        firstClub.id,
      );
      expect(clubDetail.id, firstClub.id);
      expect(clubDetail.name, firstClub.name);
      expect(clubDetail.cabor.name, firstClub.cabor.name);
      expect(clubDetail.secretariat.subdistrictName, 'Garut Kota');
      expect(clubDetail.management.items, isNotEmpty);
      expect(clubDetail.management.items.first.role, 'Ketua');
    });

    test(
      'Account switching & scope isolation (kt.tarogongkidul returns Tarogong Kidul data only)',
      () async {
        // Log in as Tarogong Kidul
        final tkLogin = await composition.authRepository.login(
          username: 'kt.tarogongkidul',
          password: 'password123',
          staySignedIn: true,
        );
        expect(tkLogin.isSuccess, isTrue);
        final tkUser = tkLogin.user!;
        expect(tkUser.username, 'kt.tarogongkidul');
        expect(tkUser.scope.id, '1729');
        expect(tkUser.scope.name, 'Tarogong Kidul');

        composition.sessionTokens.replace(
          accessToken: tkLogin.accessToken,
          sessionToken: tkLogin.sessionToken,
        );

        // Verify profile summary for Tarogong Kidul
        final tkProfile = await composition.profileService
            .fetchProfileSummary();
        expect(tkProfile.scope.subdistrictId, 1729);
        expect(tkProfile.scope.subdistrictName, 'Tarogong Kidul');
        expect(tkProfile.totalCabor, 28);
        expect(tkProfile.totalClub, 12);
        expect(tkProfile.totalAthlete, 290);

        // Verify Cabor list isolation
        final tkCabors = await composition.caborService.fetchCaborList();
        expect(tkCabors.total, 28);

        // Verify Club list isolation
        final tkClubs = await composition.clubService.fetchClubList();
        expect(tkClubs.total, 12);
        for (final club in tkClubs.items) {
          expect(club.secretariat.subdistrictName, 'Tarogong Kidul');
        }

        // Verify Athlete list isolation
        final tkAthletes = await composition.athleteService.fetchAthleteList();
        expect(tkAthletes.total, 290);
        for (final athlete in tkAthletes.items) {
          expect(athlete.domicile.subdistrictName, 'Tarogong Kidul');
        }
      },
    );

    test(
      'Invalid or expired token returns 401 UnauthorizedException',
      () async {
        composition.sessionTokens.replace(
          accessToken: 'invalid_expired_token_xyz',
        );

        expect(
          () => composition.profileService.fetchProfileSummary(),
          throwsA(isA<UnauthorizedException>()),
        );

        expect(
          () => composition.caborService.fetchCaborList(),
          throwsA(isA<UnauthorizedException>()),
        );

        expect(
          () => composition.clubService.fetchClubList(),
          throwsA(isA<UnauthorizedException>()),
        );

        expect(
          () => composition.athleteService.fetchAthleteList(),
          throwsA(isA<UnauthorizedException>()),
        );
      },
    );

    test(
      'Negative accounts return mapped domain failures (403 Forbidden)',
      () async {
        // Account without subdistrict
        final tanpaKecamatanResult = await composition.authRepository.login(
          username: 'tanpa_kecamatan',
          password: 'password123',
          staySignedIn: false,
        );
        expect(tanpaKecamatanResult.isSuccess, isFalse);
        expect(tanpaKecamatanResult.failure, isA<NoSubdistrictFailure>());

        // Inactive account
        final inactiveResult = await composition.authRepository.login(
          username: 'non_aktif',
          password: 'password123',
          staySignedIn: false,
        );
        expect(inactiveResult.isSuccess, isFalse);
        expect(inactiveResult.failure, isA<AccountInactiveFailure>());

        // Non-KOK member type (cabor)
        final nonKokResult = await composition.authRepository.login(
          username: 'bukan_kok',
          password: 'password123',
          staySignedIn: false,
        );
        expect(nonKokResult.isSuccess, isFalse);
        expect(nonKokResult.failure, isA<AccountNotKokFailure>());

        // Wrong password
        final wrongPassResult = await composition.authRepository.login(
          username: 'kt.garutkota',
          password: 'wrong_password_123',
          staySignedIn: false,
        );
        expect(wrongPassResult.isSuccess, isFalse);
        expect(wrongPassResult.failure, isA<InvalidCredentialsFailure>());
      },
    );

    test('README and AndroidManifest compliance verification', () {
      final readmeFile = File('scripts/mock_server/README.md');
      expect(readmeFile.existsSync(), isTrue);
      final readmeContent = readmeFile.readAsStringSync();

      // Assert README uses DATA_MODE=remote and NOT DATA_MODE=demo
      expect(readmeContent, contains('--dart-define=DATA_MODE=remote'));
      expect(readmeContent.contains('--dart-define=DATA_MODE=demo'), isFalse);
      expect(readmeContent, contains('--host=0.0.0.0'));
      expect(readmeContent, contains('8088'));
      expect(readmeContent, contains('android:usesCleartextTraffic="true"'));

      // Assert debug AndroidManifest allows cleartext
      final debugManifest = File('android/app/src/debug/AndroidManifest.xml');
      expect(debugManifest.existsSync(), isTrue);
      final debugManifestContent = debugManifest.readAsStringSync();
      expect(
        debugManifestContent,
        contains('android:usesCleartextTraffic="true"'),
      );

      // Assert main AndroidManifest stays unmodified (no cleartext)
      final mainManifest = File('android/app/src/main/AndroidManifest.xml');
      expect(mainManifest.existsSync(), isTrue);
      final mainManifestContent = mainManifest.readAsStringSync();
      expect(
        mainManifestContent.contains('android:usesCleartextTraffic="true"'),
        isFalse,
      );
    });
  });
}
