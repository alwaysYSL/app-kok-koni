# SICABOR Mock Server Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create a standalone, dependency-free Dart mock HTTP server that implements the official SICABOR API specification (`POST /api/auth`, `GET /api/v1/kok/profile`, cabor, club, athlete) to enable live network testing from emulators and physical mobile devices.

**Architecture:** A lightweight Dart HTTP server using `dart:io` and `dart:convert`. Listens on `0.0.0.0:8080` (customizable via CLI arguments), decodes `application/x-www-form-urlencoded` and JSON requests, manages token sessions in-memory, enforces Bearer token authentication, filters data by kecamatan scope, and produces structured terminal request logs.

**Tech Stack:** Dart (`dart:io`, `dart:convert`, `dart:async`), `package:test`.

## Global Constraints

- **Zero Third-Party Dependencies:** Written purely in standard Dart library (`dart:io`, `dart:convert`) so it can be run instantly via `dart run` on any machine with Dart/Flutter installed.
- **Contract Fidelity:** Must match the exact response envelope schemas in `docs/api/api-kok-sicabor.md` (`status` on login, `success` & `scope` on KOK endpoints).
- **Network Accessibility:** Default binding host `0.0.0.0` allows physical phones on the same Wi-Fi and emulators (`10.0.2.2`) to connect directly.

---

### Task 1: Mock Data & In-Memory Store (`scripts/mock_server/mock_data.dart`)

**Files:**
- Create: `scripts/mock_server/mock_data.dart`
- Create: `test/scripts/mock_data_test.dart`

**Interfaces:**
- Produces:
  - `MockAccount` model & database: `kt.garutkota` (id: 578, subdistrict: 1728 Garut Kota), `kt.bllimbangan` (id: 560, subdistrict: 1714 Blubur Limbangan), `kt.tarogongkidul` (id: 561, subdistrict: 1729 Tarogong Kidul), `bukan_kok` (type: cabor), `non_aktif` (status: 0), `tanpa_kecamatan` (subdistrict: null).
  - Mock Cabor dataset for Garut Kota and Blubur Limbangan.
  - Mock Club dataset with secretariat, training, management data.
  - Mock Athlete dataset with domicile and cabor mappings.

- [ ] **Step 1: Write failing test for mock data store**

```dart
// test/scripts/mock_data_test.dart
import 'package:flutter_test/flutter_test.dart';
import '../../scripts/mock_server/mock_data.dart';

void main() {
  group('MockData', () {
    test('contains valid accounts for garut kota and limbangan', () {
      final garut = MockData.findAccountByUsername('kt.garutkota');
      expect(garut, isNotNull);
      expect(garut?.type, equals('admin_kok'));
      expect(garut?.subdistrictId, equals(1728));

      final limbangan = MockData.findAccountByUsername('kt.bllimbangan');
      expect(limbangan, isNotNull);
      expect(limbangan?.subdistrictId, equals(1714));
    });
  });
}
```

- [ ] **Step 2: Run test to verify failure**

Run: `flutter test test/scripts/mock_data_test.dart`
Expected: FAIL (file not found).

- [ ] **Step 3: Implement `scripts/mock_server/mock_data.dart`**

Implement `MockData` class containing account definitions, tokens, cabor, club, and athlete models with JSON builders according to `docs/api/api-kok-sicabor.md`.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/scripts/mock_data_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit changes**

```bash
git add scripts/mock_server/mock_data.dart test/scripts/mock_data_test.dart
git commit -m "feat(mock): add mock data definitions matching SICABOR API contract"
```

---

### Task 2: HTTP Server Router & Handlers (`scripts/mock_server/sicabor_mock_server.dart`)

**Files:**
- Create: `scripts/mock_server/sicabor_mock_server.dart`
- Create: `test/scripts/sicabor_mock_server_test.dart`

**Interfaces:**
- Produces:
  - `SicaborMockServer` class with `start({String host = '0.0.0.0', int port = 8080})` and `stop()`.
  - Routes:
    - `POST /api/auth` (parses form-urlencoded body, returns token).
    - `GET /api/v1/kok/profile` (validates Bearer token, returns scope & summary).
    - `GET /api/v1/kok/cabor` (returns cabor list for account's subdistrict).
    - `GET /api/v1/kok/club` & `GET /api/v1/kok/club/detail/{id}`.
    - `GET /api/v1/kok/club/official/{id}`, `GET /api/v1/kok/club/coach/{id}`, `GET /api/v1/kok/club/management/{id}`.
    - `GET /api/v1/kok/athlete` & `GET /api/v1/kok/athlete/detail/{id}`.
  - `main(List<String> args)` CLI entrypoint supporting `--port=8080` and `--host=0.0.0.0`.

- [ ] **Step 1: Write integration tests for `SicaborMockServer`**

```dart
// test/scripts/sicabor_mock_server_test.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import '../../scripts/mock_server/sicabor_mock_server.dart';

void main() {
  group('SicaborMockServer Integration', () {
    late SicaborMockServer server;
    late int port;
    late HttpClient client;

    setUp(() async {
      server = SicaborMockServer();
      final httpServer = await server.start(host: '127.0.0.1', port: 0);
      port = httpServer.port;
      client = HttpClient();
    });

    tearDown(() async {
      client.close();
      await server.stop();
    });

    test('POST /api/auth succeeds for kt.garutkota', () async {
      final req = await client.post('127.0.0.1', port, '/api/auth');
      req.headers.contentType = ContentType('application', 'x-www-form-urlencoded');
      req.write('username=kt.garutkota&password=password123');
      final res = await req.close();
      expect(res.statusCode, equals(200));

      final body = await utf8.decodeStream(res);
      final json = jsonDecode(body) as Map<String, dynamic>;
      expect(json['status'], isTrue);
      expect(json['token'], isNotEmpty);
      expect(json['data']['type'], equals('admin_kok'));
    });

    test('GET /api/v1/kok/profile returns 401 without Bearer token', () async {
      final req = await client.get('127.0.0.1', port, '/api/v1/kok/profile');
      final res = await req.close();
      expect(res.statusCode, equals(401));
    });
  });
}
```

- [ ] **Step 2: Run test to verify failure**

Run: `flutter test test/scripts/sicabor_mock_server_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement `SicaborMockServer` and CLI entrypoint**

Create `scripts/mock_server/sicabor_mock_server.dart` with complete route handling, auth verification, CORS support, error handling, and colored terminal logger.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/scripts/sicabor_mock_server_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit changes**

```bash
git add scripts/mock_server/sicabor_mock_server.dart test/scripts/sicabor_mock_server_test.dart
git commit -m "feat(mock): implement standalone SICABOR mock server with full API routes"
```

---

### Task 3: Full Verification & Documentation

**Files:**
- Create: `scripts/mock_server/README.md`
- Entire codebase

- [ ] **Step 1: Write user guide in `scripts/mock_server/README.md`**
- [ ] **Step 2: Run `flutter analyze` and `flutter test` across all suites**
- [ ] **Step 3: Commit and verify git status**

```bash
git add scripts/mock_server/README.md
git commit -m "docs: add user guide for running local SICABOR mock server"
```
