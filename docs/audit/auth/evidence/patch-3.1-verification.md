# Patch 3.1 verification evidence

This is a reproducible local evidence bundle. No hosted CI run URL is claimed because the repository remote/CI run was not verified in this worktree.

## Environment

- Repository: `alwaysYSL/app-kok-koni`
- Branch: `codex/patch-3-1-auth-audit`
- Flutter: 3.44.4
- Dart: 3.12.2
- Expected generated-source step: `flutter pub run build_runner build`

## Commands

Run from the repository root:

```powershell
flutter pub get
flutter pub run build_runner build
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
flutter build apk --debug
git grep -nEi "ID SICABOR|Data milik SICABOR|SINKRONISASI DATA SICABOR|tersinkronisasi dengan SICABOR|data SICABOR aktif" -- lib
```

The final `git grep` command is expected to return no matches. The committed CI equivalent is [.github/workflows/auth-hardening-patch-3-1.yml](../../../.github/workflows/auth-hardening-patch-3-1.yml).

## Focused acceptance commands

```powershell
flutter test test/auth_controller_test.dart test/auth_token_storage_test.dart test/auth_repository_test.dart
flutter test test/app_environment_test.dart test/session_scope_test.dart
flutter test test/profile_page_test.dart test/sport_detail_test.dart test/login_page_test.dart
```

These commands cover B1–B3, composition/scope migration, Q1–Q4, and SC-30 directly. The full `flutter test` run remains the authoritative suite after the evidence bundle is regenerated.

## Artifacts

- Android debug APK: `build/app/outputs/flutter-apk/app-debug.apk`
- CI artifact name: `kok-app-patch-3-1-debug-apk`
- Acceptance manifest: [acceptance-manifest-patch-3.1.md](../acceptance-manifest-patch-3.1.md)
