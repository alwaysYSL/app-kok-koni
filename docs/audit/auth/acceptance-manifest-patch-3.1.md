# Patch 3.1 acceptance manifest

Tanggal implementasi: 2026-09-12
Branch: `codex/patch-3-1-auth-audit`

Manifest ini memisahkan acceptance scenario dari bukti eksekusi. Bukti lokal yang dapat direproduksi dicatat di [evidence bundle](evidence/patch-3.1-verification.md); workflow CI yang dapat dijalankan host dicatat di `.github/workflows/auth-hardening-patch-3-1.yml`.

| Scenario | Area | Evidence / assertion | Status |
|---|---|---|---|
| SC-01 | Login UI | `test/login_page_test.dart` form and demo-picker tests | Covered |
| SC-02 | Demo account | `test/auth_repository_test.dart` canonical DEMO-001/002/003 mapping | Covered |
| SC-03 | Invalid credentials | `test/auth_repository_test.dart` generic failure test | Covered |
| SC-04 | Persistent login | `test/auth_controller_test.dart` two-phase persistent commit | Covered |
| SC-05 | Non-persistent login | `test/auth_controller_test.dart` nonpersistent storage boundary | Covered |
| SC-06 | Logout single-flight | `test/auth_controller_test.dart` identical future and one cleanup cycle | Covered |
| SC-07 | Cleanup gate | `test/auth_controller_test.dart` rejected login during failed/pending cleanup | Covered |
| SC-08 | Bootstrap empty state | `test/auth_controller_test.dart` truth-table Row 1 | Covered |
| SC-09 | Orphan credential recovery | `test/auth_controller_test.dart` truth-table Rows 2/6 | Covered |
| SC-10 | Corrupt metadata/credential | `test/auth_controller_test.dart` truth-table Rows 3/4 | Covered |
| SC-11 | Restore enabled | `test/auth_controller_test.dart` truth-table Rows 7–9 | Covered |
| SC-12 | Restore expiry | `test/auth_controller_test.dart` truth-table Row 10 | Covered |
| SC-13 | Stale login ticket | `test/auth_controller_test.dart` mutation barrier test | Covered |
| SC-14 | Sign-in cancellation | `test/auth_controller_test.dart` cancellation tests | Covered |
| SC-15 | Logout cleanup result | `test/auth_controller_test.dart` `LogoutResult` assertions | Covered |
| SC-16 | Cancel while committing | `test/auth_controller_test.dart` operation-in-progress rejection | Covered |
| SC-17 | Storage fault mapping | `test/auth_token_storage_test.dart` secure-store fault injection | Covered |
| SC-18 | Remembered SK boundary | `test/auth_token_storage_test.dart` `RememberedSkStore` tests | Covered |
| SC-19 | Principal permissions | `test/user_principal_test.dart` immutable permissions and equality | Covered |
| SC-20 | Route auth guard | `test/auth_hardening_test.dart` router guard scenario | Covered |
| SC-21 | Dynamic profile role/scope | `test/profile_page_test.dart` district/county profile tests | Covered |
| SC-22 | Scope-bound data | `test/session_scope_test.dart` `DataRequestContext` mapping | Covered |
| SC-23 | Cancellation token | `test/session_scope_test.dart` disposal cancellation | Covered |
| SC-24 | Stale data response | `test/session_scope_test.dart` cross-session stale guard | Covered |
| SC-25 | Snapshot scope mismatch | `test/session_scope_test.dart` non-retry `StateError` guard | Covered |
| SC-26 | Demo labels | `test/profile_page_test.dart`, `test/club_detail_widgets_test.dart`, `test/athlete_detail_test.dart` | Covered |
| SC-27 | Dynamic cabor scope | `test/sport_detail_test.dart` dynamic summary assertion | Covered |
| SC-28 | Profile export permission | `test/profile_page_test.dart` DEMO-002 rekap action disabled | Covered |
| SC-29 | Namespace isolation | `test/app_environment_test.dart` composition key isolation | Covered |
| SC-30 | Detail cabor export guard | `test/sport_detail_test.dart` header and bottom button disabled for DEMO-002 | Covered |
| SC-31 | No active SICABOR claim | source sweep plus page/widget label tests | Covered |
| B1 | Logout A/B race | `test/auth_controller_test.dart` held revocation, independent B future, one revoke per handle | Fixed |
| B2 | Repeated failed logout | `test/auth_controller_test.dart` FT-05 repeat logout and explicit recovery path | Fixed |
| B3 | Persistent credential precondition | `test/auth_controller_test.dart` null/blank/overlong token, invalid ID, generator exception; zero writes | Fixed |
| Q1 | Profile clipboard order | delayed and failing clipboard tests in `test/profile_page_test.dart` | Fixed |
| Q2 | Profile permission TOCTOU | active-principal re-check test in `test/profile_page_test.dart` | Fixed |
| Q3 | Bottom export assertion | `test/sport_detail_test.dart` `FilledButton.onPressed == null` for DEMO-002 | Fixed |
| Q4 | Demo role wording | `test/login_page_test.dart` exact `Tim Verifikator` assertion | Fixed |

## Acceptance note

“Covered” means a deterministic source/test assertion exists. It does not claim a hosted CI run; the executed local commands and their results are recorded separately.
