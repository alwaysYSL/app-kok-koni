# Auth Hardening Patch 3.1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Menutup blocker B1–B3 dan temuan P2/Q pada audit autentikasi Patch 3, kemudian menyediakan manifest acceptance SC-01–SC-31 dan bukti verifikasi yang dapat diulang.

**Architecture:** Logout memiliki flight record yang terikat pada generation sesi sumber dan tetap dapat melakukan revocation remote secara paralel setelah lifecycle lokal sesi ditutup. Jalur lokal yang gagal tetap menjadi cleanup gate; hanya recovery eksplisit dengan `forceClearForRecovery()` yang boleh mengubahnya menjadi clean. Composition root menjadi dependency wajib, seluruh provider turunan fail-fast, dan compatibility barrel/API lama dihapus setelah semua consumer dimigrasikan.

**Tech Stack:** Flutter 3.44.4, Dart 3.12.2, Riverpod 3.4.3, `flutter_secure_storage`, `shared_preferences`, Freezed, Flutter widget/unit tests.

**Spec:** `docs/audit/auth/audit-auth-review-tahap1-ketiga.md` dan `docs/superpowers/specs/2026-09-10-auth-hardening-patch-3-design.md`.

## Global Constraints

- Seluruh teks pada komponen antarmuka memiliki ukuran font >= 12px.
- Tombol kembali memakai `Icons.chevron_left` ukuran 28 dan warna kontras sesuai surface.
- Struktur lima tab navigasi bawah tidak diubah.
- `flutter analyze` harus 0 issues dan `flutter test` harus lulus.
- `README.md` tidak boleh diformat dengan `dart format`.
- Token refresh/revocation tidak boleh diekspos melalui getter publik pada controller atau handle.
- Tidak ada fallback demo, storage in-memory production provider, atau compatibility import setelah migrasi selesai.

---

### Task 1: Reproduce and lock the three blocker regressions

**Files:**
- Modify: `test/auth_controller_test.dart`
- Modify: `test/auth_token_storage_test.dart`

**Interfaces:**
- Consumes: `AuthController.logout()`, `AuthController.login()`, `StoredCredential`, `AuthCommandResult`.
- Produces: deterministic regression tests for B1, B2, and B3 that fail against the current Patch 3 implementation.

- [ ] **Step 1: Add B1 session-generation regression test**

Use a sequenced fake repository with distinct A/B handles. Hold A revocation with a `Completer<void>`, wait for A's local clean state, login B, call logout B, and assert the two futures differ, B storage is cleared, and two distinct handles are captured.

- [ ] **Step 2: Run only the B1 test and verify the expected failure**

Run: `flutter test test/auth_controller_test.dart --plain-name "logout B"`

Expected: FAIL because the second call returns A's active logout Future and B remains signed in.

- [ ] **Step 3: Add B2 repeated-logout regression test**

Extend the FT-05 foreign-credential scenario: after the first failed cleanup, call `logout()` again and assert the result keeps `credentialCleared == false`, `metadataClean == false`, the foreign credential remains stored, and the final metadata is not `signedOutClean`.

- [ ] **Step 4: Run only the B2 test and verify the expected failure**

Run: `flutter test test/auth_controller_test.dart --plain-name "logout kedua"`

Expected: FAIL because the current second logout treats null in-memory ownership as already cleared and writes clean metadata.

- [ ] **Step 5: Add B3 persistent precondition tests**

Add four tests: successful repository result with null refresh token, blank refresh token, generator exception, and invalid generated credential ID. Assert no metadata pending write and no credential write; each returns `AuthCommandStatus.failed`, `AuthSignedOut(clean)`, and a typed `AuthCommandFailure` value.

- [ ] **Step 6: Run only the B3 tests and verify the expected failures**

Run: `flutter test test/auth_controller_test.dart --plain-name "persistent credential precondition"`

Expected: FAIL because the current controller writes pending before validating the token, calls `!`, and lets generator/constructor failures escape.

---

### Task 2: Fix logout lifecycle and persistent credential invariants

**Files:**
- Modify: `lib/core/auth/presentation/auth_controller.dart`
- Modify: `lib/core/auth/data/auth_token_storage.dart`
- Modify: `lib/core/auth/data/auth_repository.dart`
- Modify: `test/auth_controller_test.dart`
- Modify: `test/auth_token_storage_test.dart`
- Modify: `test/auth_repository_test.dart`

**Interfaces:**
- Consumes: the failing tests from Task 1 and existing mutation queue/recovery APIs.
- Produces: generation-bound logout single-flight, cleanup-failed protection, `AuthCommandFailure`, validated `StoredCredential`, and opaque `RemoteSessionHandle`.

- [ ] **Step 1: Add typed command failure and generation-bound flight record**

Add `AuthCommandFailure { invalidPersistentCredential, credentialIdGenerationFailed }`. Replace `_activeLogoutFuture` with a private record containing the source generation, post-local generation, and Future. Reuse the Future only while the current generation equals that flight's post-local generation and no newer session has been committed.

- [ ] **Step 2: Run the B1 test and confirm it now passes**

Run: `flutter test test/auth_controller_test.dart --plain-name "logout B"`

Expected: PASS with separate B cleanup/revocation and two captured handles.

- [ ] **Step 3: Guard logout from failed/pending cleanup state**

Before mutating anything in `logout()`, return a completed `LogoutResult` with `credentialCleared: false` and `metadataClean: false` when `state` is `AuthSignedOut` with non-clean cleanup status. Leave the state and metadata unchanged; `retryLocalCredentialCleanup()` remains the only force-clear path.

- [ ] **Step 4: Run the B2 test and confirm it now passes**

Run: `flutter test test/auth_controller_test.dart --plain-name "logout kedua"`

Expected: PASS with foreign/orphan credential preserved and no clean metadata.

- [ ] **Step 5: Make `StoredCredential` validate at construction**

Use a validating public factory and private constructor. Reject blank or overlong IDs and refresh tokens with `CorruptCredentialException`; make `fromJson` call that same factory. Update direct test fixtures from `const StoredCredential(...)` to `StoredCredential(...)` where runtime validation is required.

- [ ] **Step 6: Make `RemoteSessionHandle` opaque**

Rename its token field to private, remove `revocationToken`, retain validation in the public factory, and implement equality/hashCode inside `auth_repository.dart`. Update tests to verify redacted string/equality and repository observable revocation behavior instead of reading the raw token.

- [ ] **Step 7: Validate persistent login prerequisites before the first mutation**

After a successful repository result and before `metadataStore.write(cleanupPending())`, validate `result.refreshToken` by constructing the credential in memory. Catch generator exceptions as `AuthCommandFailure.credentialIdGenerationFailed`; catch token/ID invariant errors as `AuthCommandFailure.invalidPersistentCredential`; restore `AuthSignedOut(clean)` and leave both stores untouched.

- [ ] **Step 8: Run focused auth tests and then the full auth suite**

Run: `flutter test test/auth_controller_test.dart test/auth_token_storage_test.dart test/auth_repository_test.dart`

Expected: PASS with all old lifecycle/fault-injection tests plus B1–B3 regressions.

---

### Task 3: Require composition and remove compatibility surfaces

**Files:**
- Modify: `lib/core/composition/app_composition.dart`
- Modify: `lib/core/auth/presentation/auth_controller.dart`
- Modify: `lib/data/providers/snapshot_provider.dart`
- Create: `lib/data/club_filters.dart`
- Modify: `lib/shared/widgets.dart`
- Modify: `lib/features/clubs_page.dart`
- Modify: `lib/features/committee_page.dart`
- Modify: `lib/features/club_detail/club_detail_page.dart`
- Modify: `lib/features/home_page.dart`
- Modify: `lib/features/profile_page.dart`
- Modify: `lib/features/*.dart` and affected tests to import canonical modules
- Delete: `lib/data/repository.dart`
- Delete: `lib/core/config/app_environment.dart`
- Modify: `lib/core/auth/data/remembered_sk_store.dart`
- Modify: `lib/core/auth/domain/user_principal.dart`
- Modify: `lib/data/models.dart`
- Modify: `test/app_environment_test.dart`, `test/session_scope_test.dart`, and all affected tests

**Interfaces:**
- Consumes: canonical `AppComposition`, `DataRequestContext`, `KokRepository`, `snapshotProvider`, and `club_filters.dart`.
- Produces: non-null fail-fast composition provider, no fallback providers, no `SessionScope`/district compatibility getters, and no `data/repository.dart` barrel.

- [ ] **Step 1: Add fail-fast provider test**

Replace the fallback test with assertions that reading `appCompositionProvider`, `authTokenStorageProvider`, `authRepositoryProvider`, and `repositoryProvider` without an explicit composition/override throws `StateError`.

- [ ] **Step 2: Run the fail-fast test and verify it fails against nullable fallback wiring**

Run: `flutter test test/app_environment_test.dart --plain-name "fail-fast"`

Expected: FAIL because the current provider returns null/fallback demo objects.

- [ ] **Step 3: Make composition and derived providers required**

Change `Provider<AppComposition?>` to `Provider<AppComposition>` that throws `StateError('AppComposition must be injected at startup.')`. Remove fallback secure storage, metadata in-memory, remembered-SK in-memory, demo repository, and environment-derived fallback branches. Require `SharedPreferences` in `RememberedSkStore`.

- [ ] **Step 4: Run the fail-fast test and confirm it passes**

Run: `flutter test test/app_environment_test.dart --plain-name "fail-fast"`

Expected: PASS.

- [ ] **Step 5: Move filtering helpers to a canonical module**

Create `lib/data/club_filters.dart` containing `clubPeople`, `ClubSortOption`, and `filterClubs`; move the Dio provider to `lib/data/providers/dio_provider.dart` only if a consumer exists, otherwise remove it. Migrate imports to direct modules.

- [ ] **Step 6: Replace `SessionScope` with `DataRequestContext` in tests and consumers**

Update session tests to assert `dataRequestContextProvider`, `scope.id`, `scope.name`, and generation. Remove `SessionScope`, `sessionScopeProvider`, and `DistrictSnapshot` from the deleted barrel.

- [ ] **Step 7: Remove deprecated district compatibility getters**

Update production/test references from `user.districtName`/`districtId` and `snapshot.districtName`/`districtId` to `user.scope.name`/`scope.id` and `snapshot.scope.name`/`scope.id`; remove `KokSnapshotDistrictExt` and the deprecated getters from `UserPrincipal`.

- [ ] **Step 8: Migrate configuration imports and delete the old barrel**

Import `deployment_profile.dart` directly, replace `validateAppConfiguration` tests with `DeploymentProfile(...).validate()`, migrate every `data/repository.dart` import to direct files, then delete both compatibility barrel files.

- [ ] **Step 9: Run migration sweeps**

Run: `rg -n "app_environment.dart|data/repository.dart|SessionScope|sessionScopeProvider|KokSnapshotDistrictExt|\.district(Name|Id)|readRefreshToken|getRefreshToken|saveRefreshToken|Future<void> logout\(\)" lib test`

Expected: no production/test matches except intentional audit/plan prose.

---

### Task 4: Fix UI action ordering, permission re-checks, and exact demo copy

**Files:**
- Modify: `lib/features/profile_page.dart`
- Modify: `lib/features/sport_detail/sport_detail_page.dart`
- Modify: `lib/features/login_page.dart`
- Modify: `test/profile_page_test.dart`
- Modify: `test/sport_detail_test.dart`
- Modify: `test/login_page_test.dart`

**Interfaces:**
- Consumes: `currentUserProvider`, `snapshot.scope`, canonical demo credentials, and Clipboard platform channel.
- Produces: honest success feedback after awaited clipboard write, TOCTOU permission checks, explicit bottom export assertion, and `Tim Verifikator` wording.

- [ ] **Step 1: Add failing ProfilePage clipboard/permission tests**

Make the clipboard test delay `Clipboard.setData`, assert no success snackbar before completion, complete the call, then assert the snackbar. Add a callback re-check test that changes the active principal before pressing copy and asserts no clipboard write.

- [ ] **Step 2: Run the focused UI tests and verify failures**

Run: `flutter test test/profile_page_test.dart --plain-name "clipboard" test/profile_page_test.dart --plain-name "permission"`

Expected: FAIL because the snackbar is currently shown before `await` and the callback trusts the sheet-open principal.

- [ ] **Step 3: Move ProfilePage snackbar after awaited clipboard and re-check principal**

In the copy callback, read `currentUserProvider` again immediately before copying, return when `reports:export` is absent, await `Clipboard.setData`, catch platform exceptions, and show success only after the await succeeds.

- [ ] **Step 4: Add explicit DEMO-002 bottom-button assertion**

Find the `FilledButton` labeled `Salin Rekapitulasi Cabor`, cast its `ButtonStyleButton`, and assert `onPressed == null` for the no-export principal while retaining the existing header assertion.

- [ ] **Step 5: Run focused UI tests and confirm they pass**

Run: `flutter test test/profile_page_test.dart test/sport_detail_test.dart test/login_page_test.dart`

Expected: PASS, including both SportDetail export controls and exact `Tim Verifikator` picker copy.

---

### Task 5: Scope guard, documentation, acceptance manifest, and evidence

**Files:**
- Modify: `lib/data/providers/snapshot_provider.dart`
- Modify: `test/session_scope_test.dart`
- Modify: `README.md`
- Create: `docs/audit/auth/acceptance-manifest-patch-3.1.md`
- Create: `docs/audit/auth/evidence/patch-3.1-verification.md`
- Create: `.github/workflows/auth-hardening-patch-3-1.yml`

**Interfaces:**
- Consumes: canonical scope context, current README/demo contracts, and final test/build commands.
- Produces: non-retryable snapshot scope mismatch, synchronized docs, SC-01–SC-31 matrix, reproducible local evidence instructions, and CI workflow source.

- [ ] **Step 1: Add failing snapshot mismatch test**

Override `repositoryProvider` with a repository returning a snapshot for a different scope and assert `snapshotProvider.future` throws `StateError` without retry.

- [ ] **Step 2: Run the mismatch test and verify failure**

Run: `flutter test test/session_scope_test.dart --plain-name "scope mismatch"`

Expected: FAIL if the provider returns the mismatched snapshot.

- [ ] **Step 3: Add the scope equality guard**

After `fetchScope` and cancellation validation, throw `StateError` when `snapshot.scope != initialContext.scope`; preserve the existing retry exclusion for `StateError`.

- [ ] **Step 4: Synchronize README without formatting it**

Use repository-relative commands, state that Android debug build is validated by the provided command/CI, describe remembered SK as a non-secret local preference in ordinary `SharedPreferences`, use `fetchScope()`, and keep exact canonical IDs/passwords/permissions.

- [ ] **Step 5: Write the acceptance manifest**

List every SC-01 through SC-31 with the corresponding test name/file or documented manual evidence command, plus explicit B1/B2/B3 and Q1–Q4 rows.

- [ ] **Step 6: Write the evidence bundle and CI workflow**

Document the exact Flutter/Dart versions, resolved dependency check, analyzer/test/APK commands, forbidden-API and honest-label grep commands, and artifact upload paths. The workflow runs `flutter pub get`, code generation, format check, analyzer, full tests, Android debug build, and publishes logs/APK.

- [ ] **Step 7: Run final verification and record results**

Run:

```powershell
dart run build_runner build --delete-conflicting-outputs
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
flutter build apk --debug
rg -n "fetchDistrict|class CancelToken|readRefreshToken|getRefreshToken|saveRefreshToken|Future<void> logout\(\)" lib test
rg -n -i "ID SICABOR|Data milik SICABOR|SINKRONISASI DATA SICABOR|tersinkronisasi dengan SICABOR|data SICABOR aktif" lib
```

Expected: generation/format/analyzer/tests/build succeed; forbidden API and active-claim searches return no matches.

---

## Self-review

- B1 is covered by Task 1/2 with a blocked A revocation and a real B login/logout.
- B2 is covered by Task 1/2 with FT-05 repeated logout and explicit metadata preservation.
- B3 is covered by Task 1/2 with four pre-mutation validation cases and a runtime-validating credential factory.
- P2-02 is covered by Task 3 through required composition, fallback removal, direct imports, and barrel deletion.
- P2-03 is covered by Task 2 through controller getter removal and opaque handle storage.
- Q1–Q4 are covered by Task 4.
- P2-07, P2-05, the acceptance manifest, and reproducible evidence are covered by Task 5.
