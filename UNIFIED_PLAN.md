# Blink iOS — Unified Action Plan
**Synthesized from:** Architect + Accessibility + Brand + SwiftUI + Platform (Phase 3 plans)
**Date:** 2026-03-30

---

## How to Read This Plan

- Each priority has: **what** to do, **where**, **who owns it**, and **why it matters**
- Items are ordered: CRITICAL → HIGH → MEDIUM
- "Owner" = which agent's specialty leads the fix
- All agents execute in Phase 4

---

## CRITICAL

### 1. FreemiumEnforcementView — User Trap + No A11y Labels
**Owner:** Accessibility + Brand (shared)

**Problem:** Free users are architecturally trapped. `ContentView.onAppear` re-triggers enforcement on EVERY appear. FreemiumEnforcementView has no dismiss. All 7 buttons lack accessibility labels.

**Fix:**
- `ContentView.swift:49-51` — Add `@AppStorage("hasAcknowledgedFreemiumToday") var hasAcknowledgedFreemiumToday: Bool`. Only show enforcement once per day: `if !hasAcknowledgedFreemiumToday && subscriptionTier == .free { showFreemium = true }`
- `FreemiumEnforcementView.swift` — Add dismiss `X` button top-right with `accessibilityLabel: "Dismiss"` + "Maybe Later" secondary action that sets `hasAcknowledgedFreemiumToday = true` and dismisses
- `FreemiumEnforcementView.swift:35,44,52,57,75,84,93` — Add `accessibilityLabel` to all 7 buttons (label each button's action semantically)
- `ContentView.swift` — Add `onAppear { hasAcknowledgedFreemiumToday = false }` at midnight to reset daily

**Confirmed by:** Accessibility (#1), Brand (#1 CRITICAL), SwiftUI (HIGH), Architect (HIGH)

---

### 2. VideoStore Actor Isolation — Data Race on Every Entry
**Owner:** Architect + SwiftUI (shared)

**Problem:** `VideoStore+Operations.swift` mutates `@Published entries` from background Tasks without `MainActor.run`. ~30 fire-and-forget Tasks read/write the store concurrently. Every view displaying `videoStore.entries` is reading potentially racy state.

**Fix:**
- `VideoStore+Operations.swift:10-22` — Wrap every `self.entries = ...` mutation in `await MainActor.run { self.entries = ... }`
- `VideoStore.swift` — `loadEntries()` should populate entries via `await MainActor.run { self.entries = loaded }`
- `VideoStore.swift:40` — Remove `@MainActor` from class OR keep it and ensure all external callers use `await MainActor.run { }`
- `AdaptiveCompressionService.swift:50-80` — `totalSavedBytes += saved` mutate — wrap in `await MainActor.run { }`
- `ExportService.swift:60-80` — callback mutates VideoStore — wrap in `await MainActor.run { }`

**Confirmed by:** Architect (#1 CRITICAL), SwiftUI (#1 CRITICAL), Platform (HIGH)

---

### 3. Passcode Security — Plaintext UserDefaults + Timing Attack
**Owner:** Architect + Platform (shared)

**Problem:** Passcode stored in plaintext `UserDefaults`. Direct string comparison in `verifyPasscode()` enables timing attacks. Force-unwrap on encode/decode crashes on corruption.

**Fix:**
- `PrivacyService.swift:12-18` — Replace `@AppStorage("privacyPasscode")` with Keychain storage (use `KeychainSwift` or custom `KeychainManager`)
- `PrivacyService.swift:55` — Replace string comparison with `CryptoKit` HMAC constant-time compare
- `PrivacyService.swift:38` — Remove `JSONEncoder().encode(privacy)!` force-unwrap → `try?` with graceful fallback
- `PrivacyService.swift:56` — Remove `JSONDecoder().decode(...from: data)!` force-unwrap → `try?` with graceful fallback
- `PrivacyService.swift:77-101` — `unlockWithBiometrics()` uses `withCheckedContinuation` blocking main thread → refactor to async/await with `LAContext.evaluatePolicy` async variant

**Confirmed by:** Architect (#2 CRITICAL), SwiftUI (#2 CRITICAL), Platform (HIGH), Brand (HIGH)

---

### 4. Deep Link Handler — `blink://` URLs Built But Never Received
**Owner:** Platform

**Problem:** `SocialShareService.swift:18` constructs `blink://share?...` URLs. But `BlinkApp.swift` has NO `onOpenURL` modifier and `Info.plist` has NO `CFBundleURLTypes` registering the `blink` scheme. Shared links can't open the app.

**Fix:**
- `BlinkApp.swift` — Add `.onOpenURL { url in DeepLinkHandler.shared.handle(url) }` modifier
- Create `Blink/Services/DeepLinkHandler.swift` with `handle(_ url: URL)` that routes `blink://share?...` → opens specific clip, `blink://home` → root
- `Blink/Info.plist` — Add `CFBundleURLTypes` entry for `blink` scheme

**Confirmed by:** Platform (#1 CRITICAL), Architect, Brand

---

### 5. Notification Infrastructure — Partially Wired, Non-Functional
**Owner:** Platform

**Problem:** `SettingsView.swift:369-391` calls `UNUserNotificationCenter.add/remove` but: no categories, no delegate, no deep-link routing for notification taps.

**Fix:**
- Create `NotificationService.swift` with: `requestAuthorization()`, `scheduleOnThisDay()`, `scheduleDailyReminder()`, `scheduleWeeklyHighlights()`
- `UNUserNotificationCenter.current().setNotificationCategories([...])` with action buttons: "View", "Remind Me Later"
- Implement `UNUserNotificationCenterDelegate` — `userNotificationCenter(_:didReceive:withCompletionHandler:)` routes tap to deep link
- Add deep-link routing: tap "On This Day" notification → `blink://onthisday?date=...`

**Confirmed by:** Platform (#2 CRITICAL)

---

### 6. App Intents / Siri Shortcuts — Zero Defined
**Owner:** Platform

**Problem:** No `AppIntents` defined. Siri can't interact with Blink at all despite the app being a daily recording tool.

**Fix:**
- Create `Blink/AppIntents/RecordBlinkIntent.swift` — "Record a blink" → opens RecordView
- Create `Blink/AppIntents/ShowHighlightsIntent.swift` — "Show my highlights" → opens AIHighlightsView
- Create `Blink/AppIntents/OnThisDayIntent.swift` — "Show this day last year" → opens OnThisDayView
- Register in `BlinkApp.swift` via `appIntents` property

**Confirmed by:** Platform (#3 CRITICAL)

---

## HIGH

### 7. 119 Missing Accessibility Labels — VoiceOver Broken App-Wide
**Owner:** Accessibility (pure additive, no risk)

**Problem:** Every interactive element across 30+ views lacks `accessibilityLabel`. VoiceOver users experience a completely non-functional UI.

**Fix — batch per file** (in priority order):
1. `RecordView.swift` — record button, flip camera, flash, timer
2. `PlaybackView.swift` — play/pause, delete, share, trim controls
3. `CalendarView.swift` — day cells, month nav arrows, today button
4. `SettingsView.swift` — each settings row, toggle switches
5. `ContentView.swift` — tab bar items: Record, Calendar, Search, Settings
6. `TrimView.swift` — handles, confirm/cancel
7. `FreemiumEnforcementView.swift` — all 7 buttons (see Priority 1)
8. All remaining views: `AIHighlightsView`, `PrivacyLockView`, `PasscodeSetupView`, `OnboardingView`, `SearchView`, `CommunityView`, `PublicFeedView`, `PricingView`, `SubscriptionsView`, `SocialShareSheet`, `CameraPreview`, `MonthBrowserView`, `CloseCircleView`, `CollaborativeAlbumView`, `DeepAnalysisView`, `OnThisDayView`, `YearInReviewCompilationView`, `StorageDashboardView`

**Confirmed by:** Accessibility (#1, 119 instances), all 5 agents

---

### 8. Localization Pipeline — Zero `String(localized:)`
**Owner:** Platform + Accessibility + Brand

**Problem:** Every string in every view is a raw Swift literal. Zero localization possible. Accessibility strings can't be audited. Brand copy can't be refined.

**Fix:**
- Create `Blink/Strings/Localizable.strings` (English base) and `Localizable.stringsdict` for pluralization
- Add `blondeStrings()` computed property to each ViewModel that returns `LocalizedStringKey` strings
- In views: replace `"Submit"` → `Text("submit")`, `"Something went wrong"` → `Text("error.generic")`
- Use `String(localized:)` for dynamically constructed strings

**Confirmed by:** Platform (#4 HIGH), Accessibility (#4 HIGH), Brand (#4 HIGH)

---

### 9. Theme.swift Token Adoption — Defined But Completely Unused
**Owner:** Architect + Brand + Accessibility (highest leverage)

**Problem:** `Theme.swift` defines a complete design token system. Zero views use it. Every view uses `Color(hex: "0a0a0a")` instead of `Theme.background`. `.font(.system(size:))` breaks Dynamic Type everywhere.

**Fix (single migration, multiple wins):**
- `Theme.swift` — Verify all tokens exist: `background`, `surface`, `primary`, `secondary`, `cornerRadiusSmall/Medium/Large`, `spacingSmall/Medium/Large`
- Across 40+ view files: `Color(hex: "...")` → `Theme.*` semantic token
- Across 19+ view files: `.font(.system(size: N))` → `Font.TextStyle` via `Font.theme(.body)` extension
- Add `CornerRadius` semantic tokens to `Theme.swift`
- Add SwiftLint rule to ban `Color(hex:)` (except in `Theme.swift` itself)

**Confirmed by:** All 5 agents (highest cross-agent agreement)

---

### 10. Fire-and-Forget Task Leaks + Timer Memory Leaks
**Owner:** SwiftUI

**Problem:** ~30 `Task { }` closures in views that outlive their views. `Timer.scheduledTimer` that never gets invalidated.

**Fix:**
- Replace `Task { ... }` with SwiftUI's `.task { }` modifier (auto-cancels on view disappear)
- `YearInReviewCompilationView.swift:226` — `Timer.scheduledTimer` stored in `@State private var progressTimer: Timer?`; invalidate in `.onDisappear { progressTimer?.invalidate() }`
- `RecordView.swift:303` — `startCountdown()` Task stored and cancelled
- `CalendarView.swift:376,382` — export Tasks stored, cancelled
- `DeepAnalysisView.swift` — `Task { }` for AI analysis stored and cancelled
- All services: `AIHighlightsService`, `DeepAnalysisService` marked `@MainActor`

**Confirmed by:** SwiftUI (#2 HIGH), Architect (#1 CRITICAL — same root cause as VideoStore)

---

### 11. Force-Unwrap Crash Paths
**Owner:** SwiftUI + Architect

**Problem:** 20+ `!` and implicitly unwrapped optionals that cause runtime crashes.

**Fix:**
- `ContentView.swift:41` — `try! JSONDecoder()` → `try? JSONDecoder().decode(...).flatMap { $0 } ?? []`
- `PrivacyLockView.swift:37,40` — `UIApplication.shared!` and `viewContext!` → optional binding with error state
- `PrivacySettingsView.swift:37,40` — Same fix
- `CalendarView.swift:106,118,126,139` — `first!` on arrays that could be empty → `first ??`

**Confirmed by:** SwiftUI (#1 CRITICAL), Architect (#4 CRITICAL)

---

## MEDIUM

### 12. Humanized Error Copy
**Owner:** Brand

**Problem:** Clinical errors like "Something went wrong. Please try again." throughout.

**Fix:**
- `ErrorStatesView.swift` — Rewrite all error messages with actionable, humanized copy
- `PlaybackView.swift` — After delete: show snackbar "Clip deleted" with "Undo" for 4 seconds before committing

---

### 13. Loading States — Zero Feedback for Async Operations
**Owner:** Brand + SwiftUI

**Problem:** Camera setup, social share, community view — all async with no loading indicator.

**Fix:**
- `RecordView.swift` — Add camera setup loading state (spinner or skeleton)
- `SocialShareSheet.swift` — Loading indicator while generating share link
- `CommunityView.swift` — Skeleton screens for feed loading

---

### 14. Reduce Motion — 7 Animations Not Checked
**Owner:** Accessibility

**Fix:**
- `CustomGraphics.swift` — Wrap all `repeatForever` animations in `if !accessibilityReduceMotion { }`
- `PrivacyLockView.swift` — `accessibilityReduceMotion` check on unlock animation
- `YearInReviewCompilationView.swift` — `accessibilityReduceMotion` check on progress animation
- `RecordView.swift:254` — Countdown animation reduce motion check
- `OnboardingView.swift` — ApertureGraphic: `if !accessibilityReduceMotion { isOpen = true }` on `.onAppear`

**Confirmed by:** Accessibility (#2 HIGH), Brand (#10)

---

### 15. Stub Services — Fake Data Shown as Real
**Owner:** Platform

**Problem:** `CloudBackupService`, `CrossDeviceSyncService`, `CommunityService` are non-functional stubs with convincing placeholder data. Users think features work that don't exist.

**Fix:**
- Show "Coming Soon" state OR hide these features behind feature flags until functional
- If shown: use `EmptyStateView` with "This feature is in development" copy
- Do NOT show functional-looking UI for non-existent features

**Confirmed by:** Platform (#4 HIGH), Brand (#5)

---

## Phase 4 Execution

**Who does what:**

| Agent | Owns |
|-------|------|
| **Accessibility** | Priorities 1 (a11y parts), 7, 8 (strings), 14 |
| **Architect** | Priorities 2, 3, 9 (design system), 11 (architectural) |
| **Brand** | Priorities 1 (UX parts), 12, 13 |
| **SwiftUI** | Priorities 2, 10, 11 |
| **Platform** | Priorities 4, 5, 6, 8 (pipeline), 15 |

All agents execute in parallel. Coordinate through this session.
