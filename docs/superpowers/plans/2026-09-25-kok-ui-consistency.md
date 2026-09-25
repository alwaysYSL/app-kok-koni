# KOK UI Consistency Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Bring SICABOR mode back to the approved KOK visual language while preserving the current API data, tabs, statistics, and navigation behavior.

**Architecture:** Keep the existing Riverpod providers and GoRouter routes. Reuse shared visual primitives for cards and detail headers, and change presentation widgets in place. Separate logo color extraction from network loading so detail pages always render with KOK blue first.

**Tech Stack:** Flutter, Dart, Riverpod 3, GoRouter 17, Flutter widget tests.

**Spec:** `docs/superpowers/specs/2026-09-25-kok-ui-consistency-design.md`

## Global Constraints

- Retain SICABOR API contracts, scope, statistics, data meaning, search, and pagination.
- Preserve existing tab switch animation and demo-only data/features.
- Use KOK blue for Sport and Athlete details; Club detail uses a readable logo-derived color with KOK-blue fallback.
- The three directory lists keep white cards with one shared radius, shadow, padding, and spacing.
- Check layouts at 320 and 390 dp, especially long names, filtering, and sticky detail tabs.

---

### Task 1: Navigation and directory foundation

**Files:** `lib/app.dart`, `lib/features/athlete_list/athlete_list_page.dart`, `lib/features/profile_page.dart`, `lib/shared/widgets.dart`, `test/app_test.dart`, `test/athlete_list_page_test.dart`, `test/profile_page_test.dart`

**Interfaces:** `/athletes` becomes the fourth shell branch. `/committee` remains a reachable route from Profile. `Surface` remains the directory-card primitive.

- [ ] Write widget tests that tap the fourth destination and observe `Atlet`, and open Kepengurusan from Profile. They should fail while the fourth branch is Anggota.
- [ ] Run the focused tests and confirm the expected failures.
- [ ] Move `/athletes` into the fourth shell branch, retain `/committee` as a non-shell route, and make AthleteListPage show a root title without a back button. Add Profile access to Kepengurusan for both modes and the remote availability label.
- [ ] Run the focused tests and `flutter analyze` on changed files; commit.

### Task 2: Athlete list presentation

**Files:** `lib/features/athlete_list/athlete_list_page.dart`, `lib/data/providers/athlete_providers.dart`, `test/athlete_list_page_test.dart`

**Interfaces:** Existing provider search, gender, status, and page-size behavior stays. A single filter action stages both choices until `Terapkan`; `Reset` clears the draft before application.

- [ ] Write widget tests for the staged filter sheet, apply/reset, long-name card, and load-more retry using existing provider overrides.
- [ ] Run tests to see the filter/card failures.
- [ ] Replace horizontal chips with a modal bottom sheet, use `Surface` for cards, and show loading/retry/end states for infinite scroll.
- [ ] Run focused tests and format/analyze; commit.

### Task 3: Directory lists and shared surface

**Files:** `lib/features/sports_page.dart`, `lib/features/clubs_page.dart`, `lib/shared/widgets.dart`, `test/sports_page_test.dart`, `test/clubs_page_test.dart`

**Interfaces:** Existing list controllers, filters, sort values, card navigation, and data stay. Cards use the same white Surface treatment; Cabor logo URL falls back to a same-size icon.

- [ ] Write focused widget tests that exercise result cards and no-image fallback; confirm they fail where presentation differs.
- [ ] Align Cabor and Klub card hierarchy, spacing and controls with the spec, keeping API values and semantic status color.
- [ ] Run focused tests and analysis; commit.

### Task 4: Detail brand colors

**Files:** `lib/features/sport_detail/sport_brand_palette.dart`, `lib/features/club_detail/club_brand_palette.dart`, `lib/features/club_detail/club_detail_page.dart`, `lib/features/athlete_detail/athlete_detail_page.dart`, `test/sport_brand_palette_test.dart`, `test/club_brand_palette_test.dart`

**Interfaces:** SportBrandPaletteResolver returns KOK blue for every sport. ClubBrandPaletteResolver accepts a color sample from logo bytes, rejects transparent/near-white pixels, and produces readable hero/tab colors; failures produce KOK blue.

- [ ] Write palette tests with literal expected KOK colors, a red logo fixture, a transparent/white fixture, and an invalid-image fixture; run for expected failures.
- [ ] Implement image color sampling off the UI build path and apply it to remote Club detail. Keep demo explicit brand colors. Use KOK palette for Athlete detail.
- [ ] Run focused tests, format/analyze, and commit.

### Task 5: Detail scroll and sticky compact headers

**Files:** `lib/features/club_detail/club_detail_page.dart`, `lib/features/sport_detail/sport_detail_page.dart`, `lib/shared/detail_header_lip.dart`, `test/club_detail_test.dart`, `test/sport_detail_test.dart`

**Interfaces:** Hero and white content move together; compact back/title/actions header and tabs remain pinned. Search and filters scroll away. TabBarView animation remains the current one.

- [ ] Write widget scroll tests for Cabor and Klub that drag from the body and verify compact title plus tabs remain visible and the hero moves away; run for expected failures.
- [ ] Move both remote details to a consistent nested sliver structure, adding a smoothly revealed compact header with one-line ellipsis.
- [ ] Run focused tests and analysis; commit.

### Task 6: Athlete physical data and detail polish

**Files:** `lib/features/athlete_detail/athlete_detail_page.dart`, optional focused painter file under `lib/features/athlete_detail/`, `test/athlete_detail_test.dart`

**Interfaces:** Keep v2 hero and identity content. Data Fisik is one white card with blue neutral silhouette, three illustration lines, and height/weight/blood-type values; missing values use `—`.

- [ ] Write widget tests for all three present/missing values and 320 dp overflow; run for expected failures.
- [ ] Build the silhouette as code-native vector painting and replace inner stat boxes. Refine detail spacing and text wraps without changing data.
- [ ] Run focused tests, format/analyze, and commit.

### Task 7: Beranda and Profile composition

**Files:** `lib/features/home_page.dart`, `lib/features/profile_page.dart`, `lib/features/login_page.dart`, `lib/data/providers/club_providers.dart`, `test/home_page_test.dart`, `test/profile_page_test.dart`, `test/login_page_test.dart`

**Interfaces:** Profile summary remains the stats source. A separate first-page `/club` request supplies up to three real club previews in remote mode; its failure stays local to that section. `data_notes` retains server order and wording.

- [ ] Write widget tests for preview success/empty/error and Profile's remote unavailable/demo committee states; run for expected failures.
- [ ] Shorten the home hero, remove remote directory shortcuts, place club preview before notes, tidy Profile sections, and adjust Login spacing for 320 dp without changing username or demo-picker semantics. Keep demo-only attention items in demo mode.
- [ ] Run focused tests, full test suite, format/analyze, and commit.

### Task 8: Visual verification and completion

**Files:** Only files with concrete findings from visual review.

- [ ] Render the remote mock flow at 320 and 390 dp and inspect Home, Cabor/Club/Athlete lists, all three details, Profile, and Login.
- [ ] Check long names, logo network failure, filter sheet, pagination, scroll headers, tab animation, and accessibility labels.
- [ ] Fix concrete defects with a failing test when behavior changes, then rerun focused tests, full suite, `flutter analyze`, and `git diff --check`.
- [ ] Review the final diff and report remaining platform/API limits accurately.
