# Blink iOS — Round 2 Phase 2: Cross-Pollination Brand/UX Audit

**Auditor:** Brand/UX Auditor (Subagent)
**Date:** 2026-03-30
**Sources:** ARCHITECT, ACCESSIBILITY, BRAND, SWIFTUI, PLATFORM

---

## Methodology

All 5 Phase 2 audit files were read in full. Cross-cutting issues are issues confirmed by **2 or more independent auditors**, or issues that span multiple architectural layers (e.g., a Brand issue also being an Accessibility issue, or a Platform issue also being an Architecture issue).

---

## TOP 10 PRIORITIES

### 1. CRITICAL — PrivacyInfo.xcprivacy missing — App Store submission blocked
**File:** `Blink/PrivacyInfo.xcprivacy` (does not exist)
**Confirmed by:** PLATFORM, ARCHITECT (privacy consent gap)
**Cross-layer:** Platform + Privacy compliance + App Store readiness

No `PrivacyInfo.xcprivacy` manifest exists. Required for App Store privacy nutrition labels since 2020. No privacy consent onboarding flow. Users enable biometrics without informed consent. This is the single most blocking item for TestFlight/App Store release.

---

### 2. CRITICAL — DeepLinkHandler is wired but never consumed; `blink://` URL scheme unregistered
**Files:** `Blink/App/BlinkApp.swift:133`, `Blink/Info.plist` (missing CFBundleURLTypes), `Blink/Views/ContentView.swift` (zero reference to `pendingDeepLink`)
**Confirmed by:** PLATFORM
**Cross-layer:** Platform + Architecture (unwired infrastructure)

`onOpenURL` correctly calls `DeepLinkHandler.shared.handle(url)` and sets `pendingDeepLink`, but `ContentView` never observes this state. iOS will not route `blink://` URLs to the app because `CFBundleURLTypes` is absent from Info.plist. The entire deep link system is inert.

---

### 3. CRITICAL — Siri Shortcuts defined but never exposed — no AppShortcutsProvider
**Files:** `Blink/AppIntents/RecordBlinkIntent.swift`, `ShowHighlightsIntent.swift`, `OnThisDayIntent.swift` + `Blink/App/BlinkApp.swift` (no AppShortcutsProvider), `Blink/Info.plist` (missing NSUserActivityTypes)
**Confirmed by:** PLATFORM
**Cross-layer:** Platform + Accessibility (voice access)

Intents set `openAppWhenRun = true` and update `pendingDeepLink`, but without an `AppShortcutsProvider` in `BlinkApp`, the system cannot discover shortcuts. "Hey Siri, Record a Blink" does nothing. No shortcuts appear in Settings > Siri & Search.

---

### 4. CRITICAL — Theme font tokens exist but are NEVER used — Dynamic Type completely broken
**Files:** `Blink/App/Theme.swift:370–390` (tokens defined) + ALL 30+ view files (zero consumption)
**Confirmed by:** ACCESSIBILITY, ARCHITECT, BRAND
**Cross-layer:** Accessibility + Architecture + Brand (design system fail)

`enum ThemeFontStyle` and `Font.blinkText(_:)` are defined but no view uses them. All views use hardcoded `.font(.system(size: N))`. Beyond non-adoption, `Font.blinkText()` itself does NOT use `.scaledFont()` or `@ScaledMetric` — even if adopted, text would NOT scale with accessibility text size. Dynamic Type is architecturally impossible to achieve in the current state.

---

### 5. CRITICAL — PrivacyLockView + PasscodeSetupView — all 11 keypad buttons unlabeled for VoiceOver
**Files:** `Blink/Views/PrivacyLockView.swift:130–154`, `Blink/Views/PasscodeSetupView.swift:93–110`
**Confirmed by:** ACCESSIBILITY, ARCHITECT (typography/Theme partial)
**Cross-layer:** Accessibility + Security (app completely inaccessible to VoiceOver users)

All digit keys (0–9), backspace, and confirm buttons have zero `accessibilityLabel`. VoiceOver reads "button, button, button" with no way to identify digits. A locked app with an inaccessible passcode is both a security and usability failure — users cannot access their own app.

---

### 6. CRITICAL — YearInReviewGraphic hardcodes "83 clips" in OnboardingScreen1 — new users see fake data
**Files:** `Blink/Views/CustomGraphics.swift:310` (hardcoded Text("83")), `Blink/Views/OnboardingView.swift` (OnboardingScreen1 uses parameterless YearInReviewGraphic)
**Confirmed by:** BRAND, SWIFTUI (partial — YearInReviewView was fixed, OnboardingScreen1 was not)
**Cross-layer:** Brand + Onboarding (trust damage on first launch)

`YearInReviewGraphic` accepts no `clipsThisYear` parameter. New users with 0 clips see "83 clips" during onboarding. This was flagged in Phase 1 and marked "FIXED" — but only `YearInReviewView` was fixed, not `OnboardingScreen1`. The same issue persists through Round 2.

---

### 7. CRITICAL — PlaybackView delete has zero undo mechanism — permanent data loss
**File:** `Blink/Views/PlaybackView.swift:84–87`
**Confirmed by:** BRAND, SWIFTUI
**Cross-layer:** Brand + UX (no safety net for accidental deletion)

`confirmationDialog` calls `onDelete()` which invokes `videoStore.deleteEntry(entry)` with no recovery path. The clip is permanently deleted on confirm. No Snackbar/Toast with "Clip deleted — Undo" action. Listed in TOP 10 since Phase 1 and still unresolved.

---

### 8. CRITICAL — TrimView addPeriodicTimeObserver never removed — memory leak + crash risk
**Files:** `Blink/Views/TrimView.swift:270–275`, `Blink/Views/PlaybackView.swift:253–258` (notification observer same pattern)
**Confirmed by:** SWIFTUI, ARCHITECT (actor isolation partial)
**Cross-layer:** SwiftUI + Architecture (resource management fail)

`AVPlayer.addPeriodicTimeObserver` returns an `Any` token that must be retained and passed to `removeTimeObserver` on cleanup. The code never stores or removes the token. When the view disappears, the observer outlives the view — memory leak and potential crash if the callback fires on a deallocated view. Same pattern for `NotificationCenter.default.addObserver` in PlaybackView.

---

### 9. HIGH — ApertureGraphic uses `.repeatForever` spring animation — distracting and motion-unsafe
**Files:** `Blink/Views/CustomGraphics.swift:361–365` (ApertureGraphic), `Blink/Views/CommunityView.swift:283–289` (SkeletonMomentCard shimmer)
**Confirmed by:** BRAND, ACCESSIBILITY, ARCHITECT (reduceMotion partial fix)
**Cross-layer:** Brand + Accessibility + Animation

ApertureGraphic uses `.repeatForever(autoreverses: true)` — the aperture blades pulse open/closed continuously for the entire duration of the permission onboarding screen. This is distracting in normal use and potentially harmful for motion-sensitive users even with `reduceMotion = true` (the spring overshoots continuously). SkeletonMomentCard shimmer also runs with `repeatForever` with no `reduceMotion` check (NEW issue introduced in Phase 4).

---

### 10. HIGH — NWPathMonitor imported but never instantiated — sync/backup proceeds blindly offline
**Files:** `Blink/Services/AppleEcosystemService.swift:3` (import Network), `Blink/Services/CloudBackupService.swift`, `Blink/Services/CrossDeviceSyncService.swift`
**Confirmed by:** PLATFORM, ARCHITECT (architecture gap)
**Cross-layer:** Platform + Architecture (reliability fail)

`import Network` is present but `NWPathMonitor` is never instantiated anywhere in the codebase. CloudBackupService and CrossDeviceSyncService have zero network reachability awareness. Sync and backup operations attempt to proceed even when offline or on cellular — no retry logic, no offline queuing, no user indication of failure state.

---

## Honorable Mention (Cross-Cutting Issues #11–15)

These didn't make the top 10 but span multiple audits and should not be ignored:

**11. HIGH — 18+ hardcoded user-facing strings not in Localizable.strings** (PLATFORM) — i18n broken for: `"No clips"`, `"Coming Soon"`, `"Your year in Blink"`, `"Syncing your memories…"`, and 14+ more across MonthBrowserView, OnThisDayView, SocialShareSheet, CustomGraphics, CommunityView, SettingsView, CrossDeviceSyncView.

**12. HIGH — AdaptiveCompressionService race condition** (ARCHITECT, SWIFTUI) — `compressedEntries.insert()` and `compressionProgress =` write to `@Published` properties from outside `@MainActor` context. Non-sequential writes to a Set from concurrent context is unsafe.

**13. MEDIUM — FreemiumEnforcementView "Maybe Later" copy sets no expectations** (BRAND, ACCESSIBILITY partial) — "Maybe Later" implies "ask again in 5 minutes" rather than "suppress for 24 hours." No offline edge case distinction. Button copy should clarify behavior.

**14. MEDIUM — VideoStore.loadEntries() does file I/O on main thread** (SWIFTUI, ARCHITECT) — `Data(contentsOf:)` is synchronous blocking I/O in `init()`. On large entry files, causes UI jank at launch. Should be `Task.detached`.

**15. MEDIUM — isSubmittingToFeed + isLoadingContacts tracked but no UI feedback** (BRAND, SWIFTUI) — SocialShareSheet sets these states but the UI never reads them. User taps "Share to Public Feed" and the button appears to do nothing for several seconds. No spinner, no disabled state.

---

## Pattern Analysis

| Pattern | Audits Confirming | Severity Range |
|---------|-------------------|---------------|
| Theme tokens unused / inconsistent | ACCESSIBILITY, ARCHITECT, BRAND | CRITICAL → MEDIUM |
| Accessibility labels missing | ACCESSIBILITY, ARCHITECT | CRITICAL → LOW |
| Deep link / URL scheme unwired | PLATFORM, ARCHITECT | CRITICAL |
| Network monitoring absent | PLATFORM, ARCHITECT | HIGH |
| Animation without reduceMotion guard | BRAND, ACCESSIBILITY, ARCHITECT | HIGH → CRITICAL |
| Task/observer leaks | SWIFTUI, ARCHITECT | CRITICAL |
| i18n / hardcoded strings | PLATFORM | HIGH |
| Freemium UX copy unclear | BRAND | HIGH |
| Hardcoded delays / fake data | BRAND, PLATFORM, SWIFTUI | MEDIUM |

---

*End of Cross-Pollination Report*
