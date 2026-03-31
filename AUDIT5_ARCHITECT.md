# AUDIT5_ARCHITECT.md — Blink iOS Round 5 Architecture Audit

**Date:** 2026-03-31
**Auditor:** Architect Agent
**Scope:** Full codebase line-by-line review (81 Swift files)
**Lens:** Architecture, design tokens, spacing, corner radii, materials, typography hierarchy, architecture patterns

---

## Executive Summary

The R4 fixes were **well-executed**. BlinkFontStyle migration is complete. VideoStore race condition is resolved. `@MainActor` annotations are properly placed on services. However, there remain **structural inconsistencies** in design token usage and some minor architectural debt.

---

## ✅ What Was Fixed (R4 — Verified)

| Issue | Status |
|---|---|
| BlinkFontStyle migration incomplete | ✅ FIXED — No remaining `.font(.system(size:))` outside Theme.swift |
| VideoStore concurrent entry modification race | ✅ FIXED — `@MainActor` on all mutating methods |
| Missing `@MainActor` on PrivacyService | ✅ FIXED — Class now marked `@MainActor` |
| Missing `@MainActor` on SubscriptionService | ✅ FIXED — Class now marked `@MainActor` |
| Hardcoded fonts in TrimView (lines 262, 274) | ✅ FIXED — Now uses `BlinkFontStyle.monospacedSmall.font` |
| BlinkFontStyle missing cases (R4 additions) | ✅ FIXED — All 35+ cases present in Theme.swift |

---

## CRITICAL Issues

*None found.*

---

## HIGH Issues

**[HIGH] Blink/Services/PrivacyService.swift:199** — Redundant `@MainActor` annotation on `unlockWithBiometrics()` method. The class itself is marked `@MainActor` (line 8), making the method-level annotation redundant. While not a Swift 6 violation, it creates noise and suggests the annotator wasn't certain about actor isolation. Remove the redundant annotation.

```swift
// CURRENT (redundant)
@MainActor
func unlockWithBiometrics() async -> Bool {

// CORRECT
func unlockWithBiometrics() async -> Bool {
```

---

## MEDIUM Issues

**[MEDIUM] Blink/Views/CommunityView.swift:64** — Hardcoded `cornerRadius: 14` for category filter chips. Blink's design system has corner radii of 8, 12, 16, and 9999. `cornerRadius: 14` is an outlier that breaks the 4pt grid rhythm. Replace with `Theme.cornerRadiusMedium` (12pt) or `Theme.cornerRadiusLarge` (16pt), or add a new token if 14pt is truly a different size needed for these chips.

```swift
// CURRENT
RoundedRectangle(cornerRadius: 14)

// RECOMMENDATION
RoundedRectangle(cornerRadius: Theme.cornerRadiusMedium) // 12pt
// OR add Theme.cornerRadiusChip: CGFloat = 14 to Theme
```

**[MEDIUM] Blink/Views/TrimView.swift:501** — Hardcoded `cornerRadius: 1` for waveform bar segments. While this is intentionally razor-thin (a 1pt divider between waveform bars), it's worth verifying this is intentional rather than a typo. If the waveform needs 1pt gaps, this is correct but undocumented. If it should be 2pt, fix to `Theme.spacing2`.

```swift
// REVIEW: Is 1pt intentional for waveform bar gaps?
RoundedRectangle(cornerRadius: 1)
```

**[MEDIUM] Blink/Views/SubscriptionsView.swift:91** — Hardcoded `Color(hex: "ffd700")` for gold accent. This is a new color not defined in the Theme palette. If gold is used for subscription/premium UI, it should be added to Theme (e.g., `Theme.gold = Color(hex: "ffd700")`).

**[MEDIUM] Blink/Views/DeepAnalysisView.swift:289** — Hardcoded `Color(hex: "ff9500")` for warning orange. This color exists in the warning palette but Theme.warning is `ffcc00` (yellow). Either use `Theme.warning` (if the intent is yellow-amber) or define a new `Theme.warningOrange` if amber-orange is the intended color for analysis warnings.

**[MEDIUM] Blink/Views/SocialShareSheet.swift:54** — Hardcoded `Color(hex: "ff6b60")` for social icon accent. Not defined in Theme. Should be added as a brand secondary color if used in multiple places.

**[MEDIUM] Blink/Views/DeepAnalysisView.swift:288** — Uses `Color(hex: "34c759")` (iOS system green) for quality indicator. `Theme.success` is already `Color(hex: "34c759")`. Use `Theme.success` instead for consistency.

**[MEDIUM] Blink/Services/DeepAnalysisService.swift** — Not marked `@MainActor` at class level (only on `analyzeAll`). The `@Published` properties (`isAnalyzing`, `analysisProgress`, `analyzedEntries`, `insights`) are accessed from SwiftUI views via `DeepAnalysisService.shared` observed objects. In Swift 6 strict concurrency, a non-`@MainActor` class with `@Published` properties accessed from the main actor needs scrutiny. The class-level annotation should be added for consistency with other services:

```swift
@MainActor
final class DeepAnalysisService: ObservableObject {
```

---

## LOW Issues

**[LOW] Blink/Views/RecordView.swift** — Multiple hardcoded `.padding(12)`, `.padding(16)` values throughout. While these are common spacing values, they should use `Theme.spacing12` / `Theme.spacing16` for consistency. The following hardcoded padding sites should migrate to Theme tokens:

- Line 169: `.padding(12)` → `.padding(Theme.spacing12)`
- Line 221: padding values throughout bottomInfo

**[LOW] Blink/Views/StorageDashboardView.swift** — Hardcoded `.padding(16)`, `.padding(20)`, `.padding(10)`, `.padding(12)` throughout. Use Theme.spacing12/16/20.

**[LOW] Blink/Views/DeepAnalysisView.swift** — Hardcoded `.padding(40)`, `.padding(14)` throughout. Use Theme.spacing40, Theme.spacing14.

**[LOW] Blink/Views/AIHighlightsView.swift** — Hardcoded `.padding(40)`, `.padding(16)`, `.padding(14)`, `.padding(10)`. Use Theme tokens.

**[LOW] Blink/Views/SocialShareSheet.swift** — Hardcoded `.padding(24)`, `.padding(14)`, `.padding(12)`. Use Theme tokens.

**[LOW] Blink/Views/OnThisDayView.swift** — Hardcoded `.padding(12)`, `.padding(10)`. Use Theme tokens.

**[LOW] Blink/Views/SearchView.swift** — `.padding(12)`. Use Theme.spacing12.

**[LOW] Blink/Views/CustomGraphics.swift** — Raw corner radii (6, 10, 12, 16, 4) throughout the file. This is **acceptable** for a graphics primitives file that defines raw geometric shapes (avatars, rings, progress indicators), but should be noted that CustomGraphics is the exception — all other view files should use Theme tokens.

**[LOW] Blink/Views/PlaybackView.swift** — Uses `Theme.background` for the app background but hardcodes `Color.black` for the video player background. This is intentional (video player should always be black), but worth noting the inconsistency.

**[LOW] Blink/Views/PlaybackView.swift** — `currentEntry` computed property accesses `videoStore.entries` which is a `@Published` property on a `@MainActor` VideoStore. The property is accessed from a View (which runs on main actor), so this is safe, but it could be annotated for clarity.

**[LOW] Blink/Services/StorageDashboardService.swift:88,91** — Force-unwrapping `oldest!` and `newest!` after `guard oldest == nil || entry.date < oldest!` check. Technically safe but uses force unwrap. Prefer:

```swift
// CURRENT
if oldest == nil || entry.date < oldest! {
    oldest = entry.date
}

// PREFERRED (avoids force-unwrap)
if oldest == nil || entry.date < oldest! {  // first comparison short-circuits safely
    oldest = entry.date
}
// Actually this is fine — the nil check protects it. Consider suppressing the warning.
```

**[LOW] Blink/Services/DeepAnalysisService.swift:204,259,279,328** — Multiple `guard let cgImage = image.cgImage else { return ... }` in private methods. These are fine (proper guard pattern), but worth noting they return fallback values rather than propagating errors.

**[LOW] Blink/Services/DeepAnalysisService.swift:215** — `guard let observations = request.results as? [VNClassificationObservation] else` — uses `as?` optional cast. This is correct for Vision framework's unreliable results.

---

## Design Token Analysis

### Corner Radii — Usage Correctness

| Token | Value | Usage |
|---|---|---|
| `Theme.cornerRadiusSmall` | 8pt | TrimView timeline, MonthBrowserView days, SearchView chips ✅ |
| `Theme.cornerRadiusMedium` | 12pt | Standard cards, buttons ✅, BlinkCardButtonStyle ✅ |
| `Theme.cornerRadiusLarge` | 16pt | Modals, sheets, viewfinder frames ✅ |
| `Theme.cornerRadiusPill` | 9999pt | Pill buttons/chips ✅ |
| **Outlier: 14pt** | CommunityView.swift:64 | Category filter chips ❌ |
| **Outlier: 6pt** | CustomGraphics.swift | Avatar rings, geometric primitives ✅ (acceptable exception) |

### Typography Hierarchy — BlinkFontStyle Coverage

**Status: COMPLETE** — All 35+ BlinkFontStyle cases present. No `.font(.system(size:))` outside Theme.swift source tokens. ✅

The following categories are covered:
- Dynamic Type: `.largeTitle` through `.caption2` ✅
- Display sizes: `.displayGigantic` (80pt) through `.displaySmall` ✅
- Specialized: `.countdown` (120pt), `.speedLabel`, `.monospaced*`, `.rounded*`, `.recLabel`, `.timerText`, `.micro*`, `.badge` ✅
- Buttons: `.buttonTextMedium`, `.pillButtonText` ✅

### Color Palette — Inconsistencies

| Token | Hex | Usage | Non-Token Usage |
|---|---|---|---|
| `Theme.accent` | `ff3b30` | ✅ Primary brand | ✅ Used consistently |
| `Theme.textPrimary` | `f5f5f5` | ✅ Primary text | ✅ Used |
| `Theme.textSecondary` | `AAAAAA` | ⚠️ Underused | Many views use `Color(hex: "8a8a8a")` instead |
| `Theme.textTertiary` | `888888` | ⚠️ Underused | Many views use `Color(hex: "8a8a8a")` instead |
| `Theme.background` | `0a0a0a` | ✅ Used correctly | ✅ |
| `Theme.backgroundSecondary` | `141414` | ✅ Used correctly | ✅ |
| `Theme.backgroundTertiary` | `1e1e1e` | ✅ Used correctly | ✅ |
| `Theme.success` | `34c759` | ⚠️ Defined but unused | `Color(hex: "34c759")` used directly in DeepAnalysisView |
| `Theme.warning` | `ffcc00` | ⚠️ Defined but unused | `Color(hex: "ff9500")` used instead in DeepAnalysisView |
| `Theme.destructive` | `ff3b30` | ⚠️ Defined but unused | `Color(hex: "ff3b30")` used directly |
| **Undefined** | `ffd700` | — | SubscriptionsView gold ❌ |
| **Undefined** | `ff6b60` | — | SocialShareSheet ❌ |
| **Undefined** | `ff9500` | — | DeepAnalysisView warning orange ❌ |
| **Undefined** | `c0c0c0` | — | Multiple views (light gray) ❌ |

**Issue:** Theme defines `textSecondary` as `AAAAAA` but views frequently use `Color(hex: "8a8a8a")` which is actually `textTertiary` (888888). The discrepancy: "8a8a8a" ≠ "AAAAAA". Many caption/subheadline text uses "8a8a8a" (mid-gray) which maps closer to textTertiary than textSecondary.

---

## Architecture Patterns

### MainActor Isolation — Overall Assessment: GOOD

All `@MainActor` services properly annotated:
- `VideoStore` — `@MainActor` on class ✅
- `SubscriptionService` — `@MainActor` on class ✅
- `PrivacyService` — `@MainActor` on class ✅
- `DeepAnalysisService` — `@MainActor` only on `analyzeAll()` (MEDIUM issue — see above)
- `CloudBackupService` — `@MainActor` on methods, class not marked ✅
- `CrossDeviceSyncService` — `@MainActor` on methods, class not marked ✅
- `AIHighlightsService` — `@MainActor` on methods, class not marked ✅
- `DeduplicationService` — `@MainActor` on methods, class not marked ✅
- `CommunityService` — `@MainActor` on `loadPublicFeed()` only ✅

**Note:** Services that aren't marked `@MainActor` at class level but have some `@MainActor` methods (CloudBackupService, CrossDeviceSyncService, etc.) — this is correct. Not every method needs to be on MainActor; only those that access/mutate ObservableObject published state.

### VideoEntry — Clean Value Type ✅

`VideoEntry` is a pure value type (struct) with no isolation concerns. Its `videoURL` computed property reads from `VideoStore.shared.videosDirectory` (thread-safe, immutable after init).

### Data Flow — VideoStore ✅

All mutating methods properly marked `@MainActor`:
- `addVideo` ✅
- `deleteEntry` ✅
- `trimClip` ✅
- `exportToCameraRoll` ✅
- `updateTitle` ✅
- `updateEntry` ✅
- `restoreEntry` ✅
- `toggleLock` ✅

### Privacy/Security — SHA256 Constant-Time Comparison ✅

`PrivacyService.verifyPasscode()` uses `Data == Data` which performs constant-time comparison in Swift standard library. Well-implemented.

---

## Spacing Token Usage

Theme defines: spacing2, 4, 6, 8, 12, 14, 16, 20, 24, 28, 32, 40, 48.

Most views use hardcoded integer values for `.padding()`. The following views have the most non-token padding and should be migrated:

| File | Hardcoded Padding Sites |
|---|---|
| `DeepAnalysisView.swift` | 40, 14, 12, 16, 14, 16 |
| `AIHighlightsView.swift` | 40, 16, 14, 10, 16 |
| `SocialShareSheet.swift` | 24, 14, 12 |
| `StorageDashboardView.swift` | 16, 20, 16, 10, 16, 16, 12, 16 |
| `RecordView.swift` | 16, 20, 12, 16, 12 |
| `OnThisDayView.swift` | 12, 10, 12 |
| `SearchView.swift` | 12 |
| `PlaybackView.swift` | None (uses spacing correctly) ✅ |
| `TrimView.swift` | None (uses spacing correctly) ✅ |
| `SettingsView.swift` | None (uses spacing correctly) ✅ |

---

## R4 Commit Verification

**Commit:** `03a58b5` — "Blink R4: Architect fixes (BlinkFontStyle completion, VideoEntry race, MainActor annotations)"

| Change | Verified |
|---|---|
| `PrivacyService` got `@MainActor` | ✅ Present in diff |
| `SubscriptionService` got `@MainActor` | ✅ Present in diff |
| TrimView font fixes (lines 262, 274) | ✅ `monospacedSmall.font` in diff |
| 24 files changed | ✅ Matches stat output |
| +138/-62 lines | ✅ Consistent with additions |

---

## Recommendations (Priority Order)

1. **[HIGH]** Remove redundant `@MainActor` from `PrivacyService.unlockWithBiometrics()` line 199
2. **[HIGH]** Add `@MainActor` to `DeepAnalysisService` class declaration
3. **[MEDIUM]** Replace `cornerRadius: 14` in `CommunityView.swift:64` with Theme token (add `cornerRadiusChip: 14` if truly needed, or use 12/16)
4. **[MEDIUM]** Add undefined colors to Theme: `gold` (ffd700), `coralAccent` (ff6b60), `warningOrange` (ff9500), `lightGray` (c0c0c0)
5. **[MEDIUM]** Audit `Color(hex: "8a8a8a")` usage — does it represent secondary or tertiary text? Align with Theme.textSecondary (AAAAAA) or textTertiary (888888)
6. **[LOW]** Migrate hardcoded `.padding()` values in DeepAnalysisView, AIHighlightsView, SocialShareSheet, StorageDashboardView to Theme.spacing tokens
7. **[LOW]** Use `Theme.success` in DeepAnalysisView instead of raw hex
8. **[LOW]** Verify `cornerRadius: 1` in TrimView waveform is intentional (document if so)

---

## Conclusion

**Blink R4 was well-executed.** The critical issues from R3 were properly resolved. The codebase is in good shape architecturally. Remaining issues are primarily design token hygiene — undefined colors, hardcoded spacing in some views, and one redundant MainActor annotation. None of these are blockers; all are refinements.

**Architecture grade: A-** (deducted for the DeepAnalysisService MainActor gap and design token inconsistencies)

**Swift 6 readiness: GOOD** — MainActor isolation is properly applied to all services that mutate shared state.
