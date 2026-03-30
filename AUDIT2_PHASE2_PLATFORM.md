# AUDIT2 — Phase 2: Cross-Pollination Report

**Auditor:** Platform Guardian (Subagent)  
**Date:** 2026-03-30  
**Sources:** AUDIT2_ARCHITECT.md, AUDIT2_ACCESSIBILITY.md, AUDIT2_BRAND.md, AUDIT2_SWIFTUI.md, AUDIT2_PLATFORM.md  
**Method:** Cross-reference findings across all 5 Phase 2 audits to identify themes confirmed by multiple agents.

---

## TOP 10 CROSS-CUTTING PRIORITIES

### 1. [CRITICAL] PrivacyInfo.xcprivacy still missing
**File:** `Blink/PrivacyInfo.xcprivacy` (does not exist)  
**Description:** Required for App Store privacy nutrition labels since 2020. Without it, the app cannot be submitted to TestFlight or the App Store. Listed as Priority 6 in PLAN_PLATFORM.md but never created. No privacy manifest = automatic rejection.  
**Confirmed by:** PLATFORM (Platform Guardian)

---

### 2. [CRITICAL] Siri Shortcuts are dead — no AppShortcutsProvider
**File:** `Blink/App/BlinkApp.swift` (missing AppShortcutsProvider)  
**Description:** `RecordBlinkIntent`, `ShowHighlightsIntent`, and `OnThisDayIntent` are defined in `Blink/AppIntents/` with `openAppWhenRun = true`, but without an `AppShortcutsProvider` in `BlinkApp`, the system cannot discover these shortcuts. `NSUserActivityTypes` is also missing from Info.plist. "Hey Siri, Record a Blink" does nothing.  
**Confirmed by:** PLATFORM (Platform Guardian)

---

### 3. [CRITICAL] `blink://` URL scheme is NOT registered in Info.plist
**File:** `Blink/Info.plist` (and `BlinkMac/Info.plist`)  
**Description:** `CFBundleURLTypes` is absent. Even though `DeepLinkHandler` parses `blink://` URLs correctly and sets `pendingDeepLink`, iOS will never deliver those URLs to the app because the scheme is not declared. The entire deep-link system is dead on arrival.  
**Confirmed by:** PLATFORM (Platform Guardian)

---

### 4. [CRITICAL] DeepLinkHandler has no consumer in ContentView
**Files:** `Blink/App/DeepLinkHandler.swift`, `Blink/App/ContentView.swift`  
**Description:** `onOpenURL` correctly calls `DeepLinkHandler.shared.handle(url)`, setting `pendingDeepLink`. However, `ContentView.swift` has zero reference to `deepLinkHandler`, `pendingDeepLink`, or any routing logic based on deep links. The wiring between the URL handler and the view layer is completely absent.  
**Confirmed by:** PLATFORM (Platform Guardian)

---

### 5. [CRITICAL] PrivacyLockView & PasscodeSetupView — all 22 keypad buttons unlabeled
**Files:** `PrivacyLockView.swift:130–154`, `PasscodeSetupView.swift:93–110`  
**Description:** All 11 keypad buttons (digits 0–9 + backspace) in both views have no `accessibilityLabel`. VoiceOver users hear "button, button, button" with no way to identify which digit they are pressing. Users are completely locked out of their own app's passcode via VoiceOver.  
**Confirmed by:** ACCESSIBILITY (Accessibility Guardian), BRAND (Brand/UX Auditor — implicit via passcode UX failure)

---

### 6. [HIGH] Theme font tokens exist but are never consumed — Dynamic Type is non-functional
**Files:** `Theme.swift` (defines tokens), ALL views (consume nothing)  
**Description:** `Theme.swift:370–390` defines `enum ThemeFontStyle` and `Font.blinkText(_:)`, but zero view files reference these tokens. All views use hardcoded `.font(.system(size: N, ...))`. Additionally, `Font.blinkText()` uses `.system(size:)` without Dynamic Type scaling wrappers (`@ScaledMetric`, `Font.preferredFont(forTextStyle:)`), so even if adopted, text would NOT scale with accessibility text size preferences. This was flagged as a CRITICAL architecture issue in Phase 2 that remains unresolved.  
**Confirmed by:** ACCESSIBILITY (Theme tokens dead code), BRAND (Theme token inconsistency across views), ARCHITECT (partial Theme adoption creates visual inconsistency)

---

### 7. [HIGH] CommunityView skeleton shimmer animation — no reduceMotion guard (NEW issue)
**File:** `CommunityView.swift:283–289`  
**Description:** `SkeletonMomentCard` shimmer animation runs with `.animation(.linear(duration: 1.5).repeatForever(autoreverses: false), value: isAnimating)` triggered in `onAppear` with NO `@Environment(\.accessibilityReduceMotion)` check. This is a NEW issue introduced (or unfixed) in Phase 4. Loading skeletons shimmer continuously for all users, including those who prefer reduced motion.  
**Confirmed by:** ACCESSIBILITY (Accessibility Guardian — NEW issue), BRAND (Brand/UX Auditor — confirmed as HIGH issue introduced by Phase 4)

---

### 8. [HIGH] TrimView — AVPlayer addPeriodicTimeObserver token never removed
**File:** `TrimView.swift:270–275`  
**Description:** `AVPlayer.addPeriodicTimeObserver` returns an `Any` token that must be retained and passed to `removeTimeObserver` on view disappear. The code adds the observer but never stores the token. When the view disappears, the player retains the observer and the closure captures `self` — causing a memory leak and potential crash if the callback fires after deallocation.  
**Confirmed by:** SWIFTUI (SwiftUI Pedant Agent)

---

### 9. [HIGH] PlaybackView — AVPlayerItem notification observer and export task never cleaned up
**Files:** `PlaybackView.swift:253–258` (notification observer), `PlaybackView.swift:29–30` (export task)  
**Description:** (a) `NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, ...)` is added but the returned token is never stored or removed in `onDisappear`. The observer lives in NotificationCenter forever. (b) `exportTask` is cancelled but not set to `nil` on disappear, and the underlying `videoStore.exportToCameraRoll` async work is not interrupted — only the Task wrapper is cancelled.  
**Confirmed by:** SWIFTUI (SwiftUI Pedant Agent)

---

### 10. [HIGH] Clip deletion in PlaybackView has no undo mechanism
**File:** `PlaybackView.swift:84–87`  
**Description:** The delete confirmation dialog permanently removes the clip via `onDelete()` → `videoStore.deleteEntry(entry)` with no recovery path. No Snackbar/Toast with "Clip deleted — Undo" action appears. Once confirmed, the clip is gone. This was flagged in Phase 1 and remains unfixed.  
**Confirmed by:** BRAND (Brand/UX Auditor — CRITICAL #2 in remaining issues), ARCHITECT (no deletion recovery noted in architecture review)

---

## BONUS — Cross-Cutting Themes (Not Top 10 but Noted)

| Theme | Description | Confirmed By |
|-------|-------------|--------------|
| **Fake/simulated data in production** | `CommunityService.loadPublicFeed()` returns hardcoded fake users; `CrossDeviceSyncService` uses `Task.sleep` placeholders | PLATFORM |
| **"Coming Soon" on working features** | `SettingsView.swift:173` labels functional iCloud Backup as "Coming Soon"; `CrossDeviceSyncView` overlays partial sync UI | PLATFORM, BRAND |
| **Legacy GCD usage** | `RecordView.swift:174` uses `DispatchQueue.main.asyncAfter` instead of `Task.sleep` | ARCHITECT, SWIFTUI |
| **Theme color migration incomplete** | ~20 `Color(hex:)` calls in TrimView, PlaybackView, SocialShareSheet, SubscriptionsView not using Theme tokens | ARCHITECT, BRAND |
| **Silent catch blocks** | `VideoStore.swift:35,40` swallows decode errors silently — should log | ARCHITECT, SWIFTUI |
| **ApertureGraphic infinite animation** | `.repeatForever` spring animation on ApertureGraphic — distracting, potentially harmful for motion-sensitive users | BRAND |
| **Onboarding missing celebration** | OnboardingScreen4 transitions directly to main app with no "You're all set!" moment | BRAND |
| **SocialShareSheet loading states tracked but not shown** | `isSubmittingToFeed` and `isLoadingContacts` are set but no loading UI appears | BRAND |
| **YearInReviewGraphic "83 clips" hardcoded in OnboardingScreen1** | OnboardingScreen1 uses `YearInReviewGraphic()` with no parameters — new user with 0 clips sees "83" | BRAND |

---

*Platform Guardian — Phase 2 Cross-Pollination — 2026-03-30*
