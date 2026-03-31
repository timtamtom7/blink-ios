# AUDIT4 — Architecture, Design Tokens & Swift 6 Round 4

**Auditor:** Architect Agent
**Date:** 2026-03-31
**Scope:** Full Blink iOS codebase — post-Round 3 fixes
**Focus:** Architecture patterns, design token adoption, Swift 6 concurrency

---

## Executive Summary

Round 3 made real progress (BlinkFontStyle migration begun, cache invalidation added, trimClip UUID fixed). However, **BlinkFontStyle migration is only ~15% complete**, and several Swift 6 concurrency issues remain that would block a Swift 6 migration. Design token coverage is the weakest area — hardcoded colors and corner radii are pervasive.

---

## CRITICAL

### 1. `VideoEntry.swift:23,28` — Struct accessing `@Observable` singleton unsafely
**File:** `Blink/Models/VideoEntry.swift`
```swift
var videoURL: URL {
    VideoStore.shared.videosDirectory.appendingPathComponent(filename)
}
var thumbnailURL: URL? {
    guard let thumb = thumbnailFilename else { return nil }
    return VideoStore.shared.videosDirectory.appendingPathComponent(thumb)
}
```
`VideoEntry` is a plain `struct` (not isolated to any actor) conforming to `Codable`. It is passed across concurrency boundaries — into SwiftUI views, async services (DeepAnalysisService, CloudBackupService, SmartSkipService, AdaptiveCompressionService), and `AVPlayer`/`AVURLAsset` initializers. Its `videoURL`/`thumbnailURL` computed properties synchronously call `VideoStore.shared`, which is not isolated to `@MainActor`.

In Swift 6 strict concurrency, accessing a shared mutable state (`VideoStore`) from a non-isolated struct is a data-race violation. Every usage of `entry.videoURL` in services (DeepAnalysisService:112, CloudBackupService:114, SmartSkipService:29, AdaptiveCompressionService:67, etc.) and views (PlaybackView:286, TrimView:364, AIHighlightsView:512) becomes a potential data race.

**Fix:** Make `videosDirectory` a static constant, or pass `videosDirectory` as a parameter, or make `VideoEntry` hold a `videosDirectory` reference.

---

## HIGH

### 2. `BlinkFontStyle` migration ~15% complete — 60+ `.font(.system(size:))` calls remain
**Files:** Theme.swift (button styles), TrimView.swift, SettingsView.swift, SearchView.swift, StorageDashboardView.swift, RecordView.swift, OnThisDayView.swift, DeepAnalysisView.swift, AIHighlightsView.swift, SocialShareSheet.swift, SubscriptionsView.swift, PlaybackView.swift, FreemiumEnforcementView.swift, PasscodeSetupView.swift, CustomGraphics.swift, YearInReviewCompilationView.swift, CommunityView.swift, PublicFeedView.swift, ErrorStatesView.swift, PrivacyLockView.swift

The R3 commit migrated 4 files (CalendarView, MonthBrowserView, OnThisDayView, PlaybackView) but ~40 other files still use raw `.font(.system(size:))`.

Notable high-traffic files NOT migrated:
- **PlaybackView.swift:256** — `.font(.system(size: 13, design: .monospaced))` (date label, monospaced clock)
- **PlaybackView.swift:320** — `.font(.system(size: 14, weight: .bold, design: .monospaced))` (speed label)
- **TrimView.swift:262,274** — `.font(.system(size: 12, weight: .medium, design: .monospaced))` (time displays)
- **RecordView.swift:159,217,279,294** — Timer/duration fonts
- **OnThisDayView.swift:139,162,175,405** — Large title dates and timestamps
- **Theme.swift button styles (lines 222, 242, 264, 293)** — BlinkPrimaryButtonStyle, BlinkSecondaryButtonStyle, BlinkTertiaryButtonStyle, BlinkPillButtonStyle all use `.font(.system())` instead of BlinkFontStyle — this is the most ironic gap since Theme.swift defines BlinkFontStyle.

### 3. `VideoStore.swift:6` — Class not isolated to `@MainActor` but mixes `@MainActor` mutations and non-isolated reads
**File:** `Blink/Services/VideoStore.swift`

`entries` is `@Published private(set)` — mutations happen only in `@MainActor` methods (`addVideo`, `deleteEntry`, `trimClip`, `updateTitle`, `updateEntry`, `restoreEntry`, `toggleLock`). But `entriesForYear`, `entryForDate`, `todayHasClip`, `clipCountThisYear`, `monthsWithEntries`, `clipCount`, `onThisDayEntries`, and the computed property `onThisDayCount` are all **non-isolated** and read `entries`.

In Swift 6 strict concurrency, the compiler will flag that non-isolated members cannot safely access `@Published` state that is mutated on `@MainActor`. The non-isolated `onThisDayEntries()` is called from `OnThisDayView` (a SwiftUI view running on MainActor) but the method itself is not isolated — this works today but would fail Swift 6 isolation checking.

**Fix:** Mark the entire class `@MainActor` or make all read methods `@MainActor`.

### 4. `SubscriptionService.swift:8` — Not `@MainActor` but used as `@StateObject`/`@ObservedObject` in SwiftUI views
**File:** `Blink/Services/SubscriptionService.swift`

`SubscriptionService` is used as:
- `@ObservedObject private var subscription = SubscriptionService.shared` (ContentView, RecordView, CalendarView)
- `@StateObject private var subscriptionService = SubscriptionService.shared` (SubscriptionsView)

All SwiftUI views run on `@MainActor`. In Swift 6, an `@Observable` class used from SwiftUI must either be `@MainActor` or explicitly `nonisolated(unsafe)`. The `recordClipRecorded()` method on line 227 of CameraService.swift calls `SubscriptionService.shared.recordClipRecorded()` from a non-isolated context — potential violation.

### 5. `PrivacyService.swift:1` — Not `@MainActor` but `@Published` properties read/set from SwiftUI
**File:** `Blink/Services/PrivacyService.swift`

`isAppLocked`, `lockReason`, and keychain/UserDefaults accessors are not `@MainActor`. PrivacyService is used as `@ObservedObject` in ContentView and SettingsView. Properties are mutated in `lockApp`/`unlockApp` which may be called from non-isolated contexts.

---

## MEDIUM

### 6. Hardcoded `Color(hex:)` values everywhere — Theme tokens not used
**Severity:** ~150+ hardcoded hex strings found across the codebase. Representative samples:

| File | Hardcoded Colors |
|------|-----------------|
| TrimView.swift | `"1a1a1a"`, `"1e1e1e"` → should be `Theme.backgroundTertiary` |
| MonthBrowserView.swift | `"333333"`, `"555555"` → no Theme mapping |
| SettingsView.swift | `"555555"`, `"1e1e1e"` → no Theme mapping |
| SearchView.swift | `"333333"`, `"555555"`, `"1e1e1e"` → no Theme mapping |
| OnThisDayView.swift | `"2a2a2a"`, `"333333"`, `"666666"` → no Theme mapping |
| DeepAnalysisView.swift | `"1e1e1e"`, `"555555"` → no Theme mapping |

These are shades of gray (`333333`, `555555`, `666666`, `1e1e1e`) that have no Theme equivalent. Either they should map to existing Theme tokens (e.g., `Theme.backgroundTertiary`, `Theme.separator`) or new tokens should be added.

### 7. Hardcoded corner radii in CustomGraphics.swift and elsewhere
**File:** `Blink/Views/CustomGraphics.swift`

CustomGraphics is a library of static preview/generator views. It has 20+ hardcoded corner radii:
- Line 15, 20, 81: `RoundedRectangle(cornerRadius: 6)` — no Theme equivalent
- Line 114, 116: `RoundedRectangle(cornerRadius: 10)` — no Theme equivalent
- Line 162, 164: `RoundedRectangle(cornerRadius: 8)` — close to `Theme.cornerRadiusSmall (8)` ✓
- Line 324, 330: `RoundedRectangle(cornerRadius: 4)` — no Theme equivalent
- Line 246, 564, 606, 748, 750: `RoundedRectangle(cornerRadius: 12)` — matches `Theme.cornerRadiusMedium (12)` ✓
- Line 783: `RoundedRectangle(cornerRadius: 16)` — matches `Theme.cornerRadiusLarge (16)` ✓

The 6, 10, 4pt radii have no Theme token. The 8, 12, 16pt values already match Theme tokens but are hardcoded anyway.

### 8. `ContentView.swift:12-14` — Singleton `@ObservedObject` instead of `@StateObject`
```swift
@ObservedObject private var videoStore = VideoStore.shared       // ← singleton store of record
@ObservedObject private var privacy = PrivacyService.shared      // ← singleton
@ObservedObject private var subscription = SubscriptionService.shared  // ← singleton
```
Apple's guidance: use `@StateObject` for store-of-record dependencies you create, `@ObservedObject` for injected dependencies. Since these are `static let shared` singletons owned by the app, `@StateObject` is more correct and prevents potential deallocation issues.

Contrast with `StorageDashboardView.swift` which correctly uses `@StateObject` for `dashboardService`, `compressionService`, `deduplicationService`.

### 9. Hardcoded `.frame(height:)` values — no Theme spacing
**Files:** TrimView, CustomGraphics, StorageDashboardView

Many `.frame(height:)` calls use magic numbers (56, 52, 44, etc.) with no Theme token equivalent. Theme.swift has no `height` tokens. This is a gap — either Theme needs height tokens or these are acceptable as one-off layout values.

---

## LOW

### 10. `PlaybackView.swift:256` — Monospaced font not using BlinkFontStyle
```swift
.font(.system(size: 13, design: .monospaced))
```
`Theme.fontMonoCaption` is `Font.system(size: 11, weight: .medium, design: .monospaced)` — close but not identical. A new `Theme.fontMonoBody` (size 13) exists but the PlaybackView uses size 13 directly. Minor, but inconsistent.

### 11. Theme.swift button styles use raw `.font(.system())` instead of BlinkFontStyle
**File:** `Blink/App/Theme.swift` lines 222, 242, 264, 293

`BlinkPrimaryButtonStyle`, `BlinkSecondaryButtonStyle`, `BlinkTertiaryButtonStyle`, `BlinkPillButtonStyle` all define `.font(.system(size:))` directly rather than using `BlinkFontStyle.headline` or a custom button font style. Since BlinkFontStyle uses the Dynamic Type system (`Font.headline`, etc.) which is correct for accessibility, the button styles should ideally also use Dynamic Type fonts, or a new `BlinkFontStyle` case for `.button` should be added.

### 12. `VideoEntry` lacks `Sendable` conformance
`VideoEntry` is a plain struct with value types (UUID, Date, String, TimeInterval, Bool) — all Sendable. It should be explicitly annotated `struct VideoEntry: Sendable` to satisfy Swift 6 and prevent future accidental non-Sendable additions.

---

## Architectural Observations (Non-Fixing)

### A. VideoEntry ↔ VideoStore circular dependency
`VideoEntry.videoURL` calls `VideoStore.shared.videosDirectory`. This makes VideoEntry implicitly coupled to VideoStore. A cleaner architecture would pass `videosDirectory` as a parameter or make it a static property on VideoEntry.

### B. Services directory has no architecture document
With ~15 services (VideoStore, PrivacyService, AdaptiveCompressionService, CloudBackupService, DeepAnalysisService, AIHighlightsService, DeduplicationService, ExportService, SocialShareService, CaptionService, CrossDeviceSyncService, StorageDashboardService, SmartSkipService, SubscriptionService, ThumbnailGenerator), there's no architecture diagram or ownership hierarchy. Some are `@MainActor`, some aren't, some are singletons, some are injected. A MARK document would help.

### C. BlinkFontStyle enum uses `.largeTitle`, `.title`, etc. (Dynamic Type) but hardcoded sizes in Theme
`Theme.fontLargeTitle` is `Font.system(size: 28, weight: .bold)` while `BlinkFontStyle.largeTitle` returns `.largeTitle` (iOS Dynamic Type). These are semantically different — Theme's fonts are fixed-size, BlinkFontStyle fonts are accessibility-scaling. The button styles mixing `.font(.system(size:))` with fixed sizes is the inconsistency.

---

## Priority Recommendations

| Priority | Issue | Est. Effort |
|----------|-------|-------------|
| P0 | Fix VideoEntry videoURL/thumbnailURL actor isolation | Medium |
| P0 | Mark VideoStore `@MainActor` (or annotate all read methods) | Low |
| P1 | BlinkFontStyle migration — remaining 20 files | High |
| P1 | Add missing Theme tokens for hardcoded colors (333333, 555555, 666666, etc.) | Medium |
| P2 | Fix SubscriptionService / PrivacyService actor isolation | Medium |
| P2 | CustomGraphics hardcoded radii → Theme.cornerRadius tokens | Medium |
| P3 | Add `Sendable` to VideoEntry | Low |
| P3 | `@ObservedObject` → `@StateObject` for singleton stores in ContentView | Low |
