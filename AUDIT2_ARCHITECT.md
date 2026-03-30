# Blink iOS — Architecture Audit Report (Phase 4)

**Date:** 2026-03-30
**Phase:** Post-Phase 4 Review
**Previous Issues:** 346
**Scope:** Architecture, design tokens, spacing, corner radii, MVVM violations, `@MainActor` isolation, force-unwraps

---

## Summary

Phase 4 made significant progress on VideoStore actor isolation, Keychain security (SHA256 hashing), and Theme token migration for CalendarView. However, **substantial token migration debt remains** across ~15 views, and **new issues were introduced** in the compression and sync pipelines.

---

## REMAINING ISSUES (from original 346)

### Token Migration — Incomplete (HIGH priority)

The Theme.swift design system exists but is inconsistently adopted across the codebase.

| File | Line | Issue |
|------|------|-------|
| `TrimView.swift` | 168 | Hardcoded `Color(hex: "1a1a1a")` — should be `Theme.backgroundSecondary` |
| `OnThisDayView.swift` | 414 | Hardcoded `Color(hex: "666666")` — no Theme equivalent exists |
| `DeepAnalysisView.swift` | 288 | `Color(hex: "34c759")` / `"ff9500"` — success/warning colors should use `Theme.success` / `Theme.warning` |
| `DeepAnalysisView.swift` | 289 | `Color(hex: "ffcc00")` — should use `Theme.warning` |
| `SocialShareSheet.swift` | 54 | `Color(hex: "ff6b60")` — brand-adjacent red, not in Theme |
| `SocialShareSheet.swift` | 200 | `Color(hex: "666666")` — no Theme equivalent |
| `SocialShareSheet.swift` | 347 | `Color(hex: "1a1a1a")` — should be `Theme.backgroundSecondary` |
| `SubscriptionsView.swift` | 91 | `Color(hex: "ffd700")` — gold accent not in Theme |
| `SubscriptionsView.swift` | 143 | `Color(hex: "34c759")` — should use `Theme.success` |
| `SubscriptionsView.swift` | 146 | `Color(hex: "34c759")` — should use `Theme.success` |
| `SubscriptionsView.swift` | 160 | `Color(hex: "34c759")` — should use `Theme.success` |
| `SubscriptionsView.swift` | 174 | `Color(hex: "34c759")` — should use `Theme.success` |
| `PlaybackView.swift` | 256 | `Color(hex: "666666")` — no Theme equivalent |
| `PlaybackView.swift` | 265 | `Color(hex: "666666")` — no Theme equivalent |
| `CrossDeviceSyncView.swift` | 184 | `Color(hex: "34c759")` — should use `Theme.success` |
| `CustomGraphics.swift` | 326 | `Color(hex: "444444")` — hardcoded gray not in Theme |
| `CustomGraphics.swift` | 384 | `Color(hex: "1a1a1a")` — should be `Theme.backgroundSecondary` |
| `CustomGraphics.swift` | 397 | `Color(hex: "ff6b60")` — brand-adjacent red not in Theme |
| `CustomGraphics.swift` | 642-644 | `ff5f57`, `ffbd2e`, `28c840` — macOS-style traffic light colors, no Theme equivalent |

**[MEDIUM] Theme.swift:43,46** — `success` (`34c759`) and `warning` (`ffcc00`) are defined in Theme but **never consumed** by the views that have matching hardcoded hex values. The Theme tokens exist but are dead code.

---

### Spacing Inconsistencies

| File | Line | Issue |
|------|------|-------|
| `RecordView.swift` | 30 | `.padding(.top, 20)` hardcoded — Theme.spacing20 is 20 but Theme.spacing20 (16) and Theme.spacing24 (24) also exist. No systematic use. |
| `RecordView.swift` | 189 | `.padding(.bottom, 24)` — Theme.spacing24 = 24, but spacing here is part of a 2-column layout with no Theme reference |
| `RecordView.swift` | 191 | `.padding(.bottom, 40)` — Theme.spacing40 = 40, correctly used |
| `CalendarView.swift` | 48 | `.padding(.horizontal, 16)` / `.padding(.top, 16)` — Theme.spacing16 correctly used |
| `MonthCard` | N/A | Uses hardcoded `spacing: 8`, `spacing: 2` in LazyVGrid — not using Theme.spacing8 or Theme.spacing4 |

---

### Corner Radius Inconsistencies

| File | Line | Issue |
|------|------|-------|
| `CustomGraphics.swift` | 28 | `cornerRadius: 6` — Theme.cornerRadiusSmall = 8. This is a graphic preview, so exact radius matters for accuracy. But it's inconsistent with the design system. |
| `TrimView.swift` | N/A | Check for any `cornerRadius` usage not via Theme |
| `PlaybackView.swift` | N/A | Check for any `cornerRadius` usage not via Theme |

---

### Typography Hierarchy — Font Sizes Not Using Theme

Multiple views hardcode `.system(size: X)` instead of using `Theme.font*` tokens:

| File | Line | Issue |
|------|------|-------|
| `CalendarView.swift` | 103 | `.font(.system(size: 14, weight: .medium))` — toolbar icons should use Theme.icon sizes but labels can use Theme.fontCallout |
| `PrivacyLockView.swift` | 62 | `.font(.system(size: 22, weight: .bold))` — should use Theme.fontTitle1 |
| `PrivacyLockView.swift` | 65 | `.font(.system(size: 15))` — should use Theme.fontBody |
| `PrivacyLockView.swift` | 87 | `.font(.system(size: 12))` — should use Theme.fontCaption1 |
| `PrivacyLockView.swift` | 137 | `.font(.system(size: 28, weight: .medium, design: .rounded))` — keypad number, should be Theme.fontLargeTitle or custom |
| `RecordView.swift` | 122 | `.font(.system(size: 14))` — "Setting up camera..." should use Theme.fontCallout |
| `RecordView.swift` | 162 | `.font(.system(size: 12, weight: .bold, design: .monospaced))` — "REC" should use Theme.fontCaption2Bold with monospace |

---

### MVVM Violations

| File | Line | Issue |
|------|------|-------|
| `CalendarView.swift` | 40-41 | `daysElapsedThisYear` computed property calls `calendar.dateComponents([.day], from: startOfYear, to: now).day ?? 1` — this is a Date calculation that belongs in a ViewModel or service, not directly in the View |
| `CalendarView.swift` | 420-435 | `MonthCard` computes `monthName`, `daysInMonth`, `firstWeekday`, `entryMap` all as computed properties — these calendar calculations should be in a `CalendarService` |
| `CalendarView.swift` | 450-460 | `clipsThisMonth` computed property filters entries every time — should be pre-computed or memoized |
| `VideoStore.swift` | 240-260 | `onThisDayEntries()` called twice (`onThisDayCount` and passed to `OnThisDayView`) — duplicate computation of the same filtered+sorted array |

---

### @MainActor Isolation — Remaining Issues

| File | Line | Issue |
|------|------|-------|
| `AdaptiveCompressionService.swift` | 55-56 | `compressEligibleEntries` is `@MainActor` but iterates with `for (index, entry) in candidates.enumerated()` calling `await compressEntry(entry)` — `compressEntry` is NOT `@MainActor`, so this is correct, but the `await MainActor.run { totalSavedBytes += saved }` at line 49 is awkward. The entire loop could be structured better. |
| `PrivacyService.swift` | 198 | `unlockWithBiometrics()` is `@MainActor` — correct. The `authenticateWithBiometrics()` call is `async` but runs on whatever actor it belongs to (LAContext is actor-isolated). This is correct. |
| `VideoStore.swift` | 54 | `addVideo(at:)` is `@MainActor` and calls `await ThumbnailGenerator.shared.generateThumbnail(...)` — need to verify ThumbnailGenerator is also `@MainActor` or actor-safe |
| `VideoStore.swift` | 141 | `deleteEntry` is `@MainActor` but the `saveEntries()` call inside is synchronous and touching `entries` from the main actor — correct |

**[LOW] AdaptiveCompressionService.swift:49** — `await MainActor.run { totalSavedBytes += saved }` is correct but could be avoided by making `totalSavedBytes` a `@MainActor` property and the whole function being `@MainActor`.

---

### Force-Unwraps and Implicitly Unwrapped Optionals

| File | Line | Issue |
|------|------|-------|
| `CalendarView.swift` | 42 | `calendar.dateComponents([.day], from: startOfYear, to: now).day ?? 1` — safe, has fallback |
| `VideoStore.swift` | 35 | `entries = try JSONDecoder().decode([VideoEntry].self, from: data)` — if this fails, entries = []. Swallows error silently. Should log. |
| `VideoStore.swift` | 40 | `entries = []` on catch — same silent failure issue |
| `ExportService.swift` | 238 | `throw ExportError.exportFailed(exportSession.error?.localizedDescription ?? "Unknown error")` — `exportSession.error` can be nil, handled with ?? |
| `AdaptiveCompressionService.swift` | 69, 94, 115 | `(try? FileManager.default.attributesOfItem(...)[.size] as? Int64) ?? 0` — safe but silently fails |

**[LOW] VideoStore.swift:35,40** — Silent catch blocks. Should log errors for debugging. Not critical but poor for maintainability.

---

## NEW ISSUES Introduced by Phase 4 Fixes

### [HIGH] AdaptiveCompressionService.swift — Race Condition in Progress Tracking

The loop in `compressEligibleEntries` at line 43-56:

```swift
for (index, entry) in candidates.enumerated() {
    let saved = await compressEntry(entry)
    await MainActor.run {
        totalSavedBytes += saved  // ✅ Correct
    }
    if saved > 0 {
        compressedEntries.insert(entry.id)  // ⚠️ NOT on main actor
    }
    compressionProgress = Double(index + 1) / Double(candidates.count)  // ⚠️ NOT on main actor
}
```

`compressedEntries` and `compressionProgress` are `@Published` properties accessed from a `for` loop running in an async context. While the loop is `for ... in candidates.enumerated()` (sequential, not concurrent), the writes to `@Published` properties happen outside `@MainActor` context. `Set.insert()` on a non-isolated actor property from a concurrent context is unsafe.

**Fix:** Wrap `compressedEntries.insert()` and `compressionProgress =` in `await MainActor.run { }`.

### [MEDIUM] CalendarView.swift — exportTask Not Cancelled on View Dismiss

Line 20: `@State private var exportTask: Task<Void, Never>?`

This task is created in `exportThisMonth()` at line 376 but **never cancelled** when CalendarView disappears. If the user navigates away during export, the task continues running, potentially calling `showExportedAlert = true` on a dismissed view (SwiftUI will discard the update but it's still a logic bug).

### [MEDIUM] CalendarView.swift — Task Leak in Navigation

When `selectedEntry` is set via `selectedEntry = entry` (line 58 in `MonthCard.onTap`), `videoStore.deleteEntry(entry)` is called in the `fullScreenCover` dismissal handler (line 146). This is fine. However, the `fullScreenCover(isPresented: $showYearCompilation)` at line 158 passes `videoStore.entriesForYear(selectedYear)` — this is a computed property that returns the full filtered array every time it's accessed. Not a leak, but inefficient if the array is large.

### [LOW] RecordView.swift — DispatchQueue.main.asyncAfter on Line 174

```swift
DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
    isCameraSettingUp = false
}
```

This predates Phase 4 but uses `DispatchQueue` (legacy GCD) instead of Swift's structured `Task.sleep` or `@MainActor` continuation. Not a regression, but worth noting as modernization debt.

### [LOW] PrivacyLockView.swift — biometricTask Not Structured

Line 42: `@State private var biometricTask: Task<Void, Never>?`

The `attemptBiometric()` function creates a raw `Task` that captures `self`. When the view disappears, the task is not cancelled. SwiftUI will cancel child tasks in `.task { }` modifiers, but raw `Task` created in a function is not automatically cancelled. This is a latent issue, not introduced by Phase 4.

---

## Architecture Issues (Pre-existing, Not Fixed)

### VideoStore — Singleton with Shared State

`VideoStore` is a `final class` with `static let shared = VideoStore()`. This is a global singleton. While convenient, it makes testing difficult and creates hidden coupling. All `@Published` properties are main-actor isolated which is correct, but the singleton pattern itself is an architectural smell.

### CalendarView — Services Injected via @StateObject vs Environment

`@ObservedObject private var videoStore = VideoStore.shared` — directly instantiating the singleton instead of using `@EnvironmentObject`. This means the view can't be previewed with a custom VideoStore mock. Views like `OnThisDayView`, `MonthBrowserView`, `SearchView` also likely have the same pattern.

### Missing Architecture Layer

There is no `CalendarService`, `DateCalculationService`, or `ThumbnailService`. Calendar math (`daysInMonth`, `firstWeekday`, `monthName`) is duplicated in `MonthCard` and possibly elsewhere. These calculations should be in a testable service.

---

## What Was Fixed Well (Phase 4)

1. **VideoStore `@MainActor` on `deleteEntry`** — correct
2. **PrivacyService SHA256 hashing** — excellent security fix, proper constant-time comparison with `Data ==`
3. **CalendarView Theme token migration** — most hardcoded hex values replaced with Theme equivalents
4. **Accessibility labels on CalendarView navigation** — improved
5. **AdaptiveCompressionService MainActor.run** — `totalSavedBytes += saved` properly isolated
6. **CustomGraphics reduceMotion** — proper `@Environment(\.accessibilityReduceMotion)` checks added

---

## Priority Recommendations

### P0 (Critical)
- None identified — no crashers or data corruption risks

### P1 (High)
- Fix `compressedEntries.insert()` and `compressionProgress` writes in `AdaptiveCompressionService` to be `@MainActor`
- Add `Theme.success` and `Theme.warning` consumption in views that hardcode matching hex values (subscriptions, sync views)
- Add `Theme.textSecondary` for text that uses `Color(hex: "c0c0c0")` if not already using Theme

### P2 (Medium)
- Cancel `exportTask` in `CalendarView.onDisappear`
- Create `CalendarService` to extract calendar math from views
- Add logging to VideoStore silent catch blocks
- Migrate remaining `Color(hex:)` calls to Theme tokens
- Refactor `@StateObject var videoStore = VideoStore.shared` to `@EnvironmentObject`

### P3 (Low)
- Replace `DispatchQueue.main.asyncAfter` in RecordView with `Task.sleep`
- Cancel `biometricTask` in PrivacyLockView on disappear
- Add `Theme.textSecondary` token for `666666` and similar grays

---

## Files Not Audited (Out of Scope)

The following files were changed in Phase 4 but not deep-audited in this session:
- `Blink/App/ContentView.swift` — new file, needs separate review
- `Blink/Views/FreemiumEnforcementView.swift` — new file, needs separate review
- `Blink/Views/ErrorStatesView.swift` — partial Theme adoption
- `Blink/Services/DeepLinkHandler.swift` — new file, needs separate review
- `Blink/Services/NotificationService.swift` — new file, needs separate review
- `Blink/Strings/Localizable.strings` — localization only

---

*End of Audit Report*
