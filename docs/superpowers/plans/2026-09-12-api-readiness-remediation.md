# API Readiness Remediation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix 5 key defects and polish edge cases discovered during the API readiness audit across Auth, Network, Providers, and UI layers.

**Architecture:** Maintain strict layered architecture: Domain entities must uphold value equality; Network exceptions must clearly map HTTP 4xx client errors without name collisions; Granular providers must cleanly pass validated context and protect against cross-session race conditions; UI components must dynamically format document status and person roles without hardcoded assumptions.

**Tech Stack:** Flutter 3.44.4 / Dart 3.12.2, Riverpod 3, Dio 5.9, Freezed 3, GoRouter 17.

## Global Constraints

- No regressions: all 382+ tests must pass at every step.
- Zero static analysis issues (`flutter analyze`).
- Maintain fail-closed architecture for remote profiles.
- Keep in-memory access token separate from persisted refresh token.

---

### Task 1: AuthSignedIn Equality & Token Parity Fix

**Files:**
- Modify: `lib/core/auth/domain/auth_state.dart:44-59`
- Test: `test/api_readiness_auth_test.dart`

**Interfaces:**
- Consumes: `AuthSignedIn` class in `lib/core/auth/domain/auth_state.dart`
- Produces: Updated `operator ==` and `hashCode` in `AuthSignedIn` comparing `accessToken`.

- [ ] **Step 1: Write failing test in `test/api_readiness_auth_test.dart`**
- [ ] **Step 2: Run test to verify it fails**
- [ ] **Step 3: Update `AuthSignedIn` in `lib/core/auth/domain/auth_state.dart`**
- [ ] **Step 4: Run test to verify it passes**
- [ ] **Step 5: Commit**

---

### Task 2: API Exceptions & Dio Error Mapping Fix

**Files:**
- Modify: `lib/core/network/api_exceptions.dart`
- Modify: `lib/core/network/api_client.dart`
- Test: `test/api_client_test.dart`

**Interfaces:**
- Consumes: `ApiException` hierarchy
- Produces: `ApiTimeoutException`, `BadRequestException`, updated `_mapException()` handling 400/422/409 and wire-level `CancelToken`.

- [ ] **Step 1: Write failing tests in `test/api_client_test.dart`**
- [ ] **Step 2: Run test to verify it fails**
- [ ] **Step 3: Implement `BadRequestException`, rename `TimeoutException` to `ApiTimeoutException`, and bind Dio `CancelToken`**
- [ ] **Step 4: Run tests to verify they pass**
- [ ] **Step 5: Commit**

---

### Task 3: Granular Provider Cleanup & Provider Test Coverage

**Files:**
- Modify: `lib/data/providers/club_providers.dart:8-28, 78-85`
- Test: `test/api_readiness_providers_test.dart`

**Interfaces:**
- Consumes: `_runGranularRequest`
- Produces: Context passed directly to request callback; new test cases covering stale response rejection and auto-cancellation on provider disposal.

- [ ] **Step 1: Write failing tests in `test/api_readiness_providers_test.dart`**
- [ ] **Step 2: Run test to verify it fails**
- [ ] **Step 3: Refactor `_runGranularRequest` and `committeeProvider`**
- [ ] **Step 4: Run test to verify it passes**
- [ ] **Step 5: Commit**

---

### Task 4: UI Bug Fixes & Dynamic Polish

**Files:**
- Modify: `lib/features/club_detail/club_document_tab.dart`
- Modify: `lib/features/athlete_detail/athlete_detail_page.dart`
- Modify: `lib/features/sports_page.dart`
- Modify: `lib/features/committee_page.dart`
- Modify: `lib/features/profile_page.dart`
- Test: `test/club_detail_widgets_test.dart`
- Test: `test/athlete_detail_test.dart`
- Test: `test/sports_page_test.dart`
- Test: `test/profile_page_test.dart`

**Interfaces:**
- Consumes: `ClubDocument.status`, `SportPerson.role`, `KokSnapshot.scope.name`, `DeploymentProfile.dataMode`
- Produces: Correct status colors, role-aware ID badges, dynamic scope labels.

- [ ] **Step 1: Write/update tests for UI changes**
- [ ] **Step 2: Run tests to verify failures**
- [ ] **Step 3: Implement UI Fixes**
- [ ] **Step 4: Run all tests to verify they pass**
- [ ] **Step 5: Run static analysis**
- [ ] **Step 6: Commit**
