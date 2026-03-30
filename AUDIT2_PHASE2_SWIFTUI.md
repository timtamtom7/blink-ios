# AUDIT2 PHASE 2 — Cross-Pollination: TOP 10 PRIORITIES

**Auditor:** SwiftUI Pedant (cross-pollinating from 5 Round 2 audit agents)  
**Date:** 2026-03-30  
**Input:** AUDIT2_ARCHITECT, AUDIT2_ACCESSIBILITY, AUDIT2_BRAND, AUDIT2_SWIFTUI, AUDIT2_PLATFORM

---

## Methodology

Cross-cutting issues are those that appear in **two or more** audit scopes simultaneously, or span multiple layers (UI → Services → Platform). Severity is assessed by compounding impact: an issue that blocks App Store readiness AND breaks accessibility AND causes crashes wins over a single-layer issue.

---

## TOP 10 PRIORITIES

---

### 1. [CRITICAL/Platform] — `PrivacyInfo.xcprivacy` missing — blocks App Store submission
**Confirmed by:** Platform Guardian  
**Files:** `Blink/` (absent from project entirely)  
**Description:** Privacy manifest required by App Store since 2020. Without it, TestFlight/App Store upload is blocked. Also the root cause of the missing privacy consent onboarding flow — no `NSPrivacyTracking` declarations exist.

> ⚠️ This is the single most blocking item for App Store readiness. All other work is moot until this exists.

---

### 2. [CRITICAL/Platform] — Deep link system is wired but completely inert
**Confirmed by:** Platform Guardian  
**Files:** `BlinkApp.swift:133` (handler sets `pendingDeepLink`), `ContentView.swift` (zero routing logic), `Info.plist` (no `CFBundleURLTypes` for `blink://`), `AppShortcutsProvider` (absent — Siri shortcuts undiscoverable)  
**Description:** `DeepLinkHandler.shared.handle(url)` is called correctly on `onOpenURL`, but **no view ever reads `pendingDeepLink`**. The URL scheme `blink://` is not registered in `Info.plist`. `AppShortcutsProvider` is absent so "Hey Siri, Record a Blink" has no discovery path. Three separate platform features are dead on arrival due to zero wiring.

---

### 3. [CRITICAL/Accessibility] — PrivacyLockView + PasscodeSetupView keypad buttons completely unlabeled
**Confirmed by:** Accessibility Guardian  
**Files:** `PrivacyLockView.swift:130–154`, `PasscodeSetupView.swift:93–110`  
**Description:** All 11 keypad buttons (digits 0–9 + backspace) have zero `accessibilityLabel`. VoiceOver reads "button, button, button" — users cannot enter their passcode by voice. This is a **security and accessibility failure**: users who rely on VoiceOver are locked out of their own app. Must be fixed before any beta/release.

---

### 4. [CRITICAL/SwiftUI] — AVPlayer observer leaks causing memory crashes
**Confirmed by:** SwiftUI Pedant  
**Files:** `TrimView.swift:270–275` (periodic time observer never removed), `PlaybackView.swift:253–258` (notification observer never removed)  
**Description:** `AVPlayer.addPeriodicTimeObserver` returns a token that must be retained and passed to `removeTimeObserver`. The current code adds the observer but never removes it. When the view is dismissed and the player is deallocated, the observer callback can still fire — causing memory corruption or crashes. `NotificationCenter.default.addObserver` has the same problem. These are memory safety bugs.

---

### 5. [HIGH/Accessibility] — CommunityView skeleton shimmer ignores `reduceMotion`
**Confirmed by:** Accessibility Guardian  
**File:** `CommunityView.swift:283–289` (`SkeletonMomentCard`)  
**Description:** Loading skeleton animation uses `.animation(.linear(duration: 1.5).repeatForever(autoreverses: false), value: isAnimating)` with **no** `@Environment(\.accessibilityReduceMotion)` check. This is a NEW issue introduced in Phase 4. Users with vestibular disorders get continuous perpetual motion in a loading placeholder. Contrast: all 7 previously flagged animation instances in CustomGraphics and PrivacyLockView were fixed correctly.

---

### 6. [HIGH/Architecture] — Theme tokens exist but Dynamic Type is architecturally broken
**Confirmed by:** Accessibility Guardian, Architecture Auditor, Brand Auditor  
**Files:** `Theme.swift:370–390` (token definitions), **zero view files** consuming them  
**Description:** `ThemeFontStyle` enum and `Font.blinkText(_:)` are defined but **never referenced** by any view. Additionally, `Font.blinkText` uses `.system(size: N, ...)` without any `@ScaledMetric` or `Font.preferredFont(forTextStyle:)` — so even if adopted, text would NOT scale with accessibility text size. The Phase 4 accessibility work claimed Dynamic Type support, but it is architecturally impossible with the current implementation.

---

### 7. [HIGH/SwiftUI] — Multiple Task/observer leaks across views
**Confirmed by:** SwiftUI Pedant  
**Files:** `PlaybackView.swift:29–30` (export task not nil'd on disappear), `CalendarView.swift:20` (exportTask not cancelled on view dismiss), `PrivacyLockView.swift:42` (biometricTask raw Task not cancelled)  
**Description:** `.task {}` modifiers auto-cancel child tasks when the view disappears. Raw `Task` variables created in functions do NOT auto-cancel. `exportTask?.cancel()` is called but the task reference is not cleared. These are latent leaks that can cause state updates on deallocated views.

---

### 8. [HIGH/Brand+Architecture] — Hardcoded hex colors across ~16 files; Theme adoption creates visual inconsistency
**Confirmed by:** Architecture Auditor, Brand Auditor  
**Files:** `TrimView.swift:168`, `SocialShareSheet.swift:54,200,347`, `SubscriptionsView.swift:91,143,146,160,174`, `PlaybackView.swift:256,265`, `DeepAnalysisView.swift:288–289`, `RecordView.swift` (throughout), `CustomGraphics.swift:326,384,397,642–644`, `CrossDeviceSyncView.swift:184`, `OnThisDayView.swift:414`, and others  
**Description:** Phase 4 partially migrated CalendarView and OnThisDayView to Theme tokens, but 15+ other views still use raw `Color(hex:)` literals. This creates **visual inconsistency**: Calendar uses `Theme.background` while RecordView uses `Color(hex: "0a0a0a")` — slightly different shades on what should be the same background. `Theme.success (34c759)` and `Theme.warning (ffcc00)` are defined but are dead code — no view consumes them, even while identical hardcoded values exist in other files.

---

### 9. [HIGH/Platform+i18n] — Hardcoded strings in 16+ files break localization
**Confirmed by:** Platform Guardian  
**Files:** `MonthBrowserView.swift:144`, `StorageDashboardView.swift:319`, `OnThisDayView.swift:165,178`, `CommunityView.swift:36`, `DeepAnalysisView.swift:418`, `SocialShareSheet.swift:66`, `CustomGraphics.swift:536,834`, `OnboardingView.swift:106`, `PricingView.swift:135`, `CrossDeviceSyncView.swift:38,107`, `SettingsView.swift:469`, `ErrorStatesView.swift:445`, `CollaborativeAlbumView.swift:151`, and more  
**Description:** User-facing strings like `"No clips"`, `"Coming Soon"`, `"Your year in Blink"`, `"Syncing your memories…"` are hardcoded throughout. Localizable.strings exists and has good core coverage, but edge-case view strings are absent. This blocks localization and is a code quality anti-pattern.

---

### 10. [HIGH/Architecture+Platform] — `NWPathMonitor` imported but never used; network-blind services
**Confirmed by:** Platform Guardian  
**Files:** `AppleEcosystemService.swift:3` (`import Network` but no `NWPathMonitor`), `CloudBackupService.swift` (proceeds blindly on cellular/offline), `CrossDeviceSyncService.swift` (proceeds blindly offline)  
**Description:** `NWPathMonitor` is suggested in `AppleEcosystemService` but never instantiated. `CloudBackupService` and `CrossDeviceSyncService` have no network reachability awareness — they attempt CloudKit operations and sync without checking connectivity. On slow/offline networks, these fail silently or show fake progress. This is a foundational missing piece for a cloud-connected app.

---

## Honorable Mentions (P1/P2 but not in top 10)

| Priority | Issue | Files | Agent |
|----------|-------|-------|-------|
| HIGH | YearInReviewGraphic "83 clips" hardcoded in OnboardingScreen1 | CustomGraphics.swift:310 | Brand |
| HIGH | PlaybackView delete — no undo/snackbar | PlaybackView.swift:84–87 | Brand |
| HIGH | ApertureGraphic `.repeatForever` animation distracting/motion-risk | CustomGraphics.swift:361 | Brand |
| HIGH | VideoStore `loadEntries()` does blocking file I/O on main thread | VideoStore.swift:30–31 | SwiftUI |
| HIGH | FreemiumEnforcementView — "Maybe Later" copy doesn't set 24h expectations | FreemiumEnforcementView.swift | Brand |
| MEDIUM | `Theme.textSecondary` token missing for `666666` gray text | Multiple files | Architecture |
| MEDIUM | OnboardingView + ErrorStatesView — 15+ buttons unlabeled | OnboardingView.swift, ErrorStatesView.swift | Accessibility |
| MEDIUM | CalendarView — calendar math duplicated in MonthCard, should be CalendarService | CalendarView.swift:420–460 | Architecture |
| MEDIUM | `@ObservedObject var videoStore = VideoStore.shared` instead of EnvironmentObject | Multiple views | Architecture |
| MEDIUM | iOS 26 "Liquid Glass" comments with zero iOS 26 API implementation | Theme.swift:4,347 | Platform |
| MEDIUM | CommunityService fake data will appear if "Coming Soon" overlay removed | CommunityService.swift:68–76 | Platform |
| MEDIUM | SocialShareSheet — isSubmittingToFeed + isLoadingContacts tracked but no UI | SocialShareSheet.swift | Brand |

---

## Root Cause Themes

Three systemic problems underpin most of the top 10:

1. **Incomplete migrations**: Phase migrations (Theme, Dynamic Type, VoiceOver) were partial — tokens added to Theme.swift but not consumed, accessibility labels added to some views but not others, observers added but not cleaned up.
2. **Wiring gaps**: Platform features (deep links, Siri, NWPathMonitor) were scaffolded but never connected to consumers — the handler exists but nobody calls it.
3. **No lint rules**: Hardcoded hex colors, hardcoded strings, and `.accessibilityLabel` omissions have no static check preventing them from entering the codebase.

---

*SwiftUI Pedant — Round 2 Phase 2 Cross-Pollination*
