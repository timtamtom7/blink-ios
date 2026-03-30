# AUDIT2 — Phase 2: Cross-Pollination Report

**Auditor:** Accessibility Guardian (Subagent)
**Date:** 2026-03-30
**Sources:** ARCHITECT, ACCESSIBILITY, BRAND, SWIFTUI, PLATFORM
**Goal:** Identify cross-cutting issues spanning 2+ audit dimensions

---

## Methodology

Cross-cutting = confirmed by **2 or more independent auditors**, or issues spanning **multiple technical dimensions** (e.g., accessibility + architecture + brand simultaneously). Purely single-domain issues are excluded.

---

## TOP 10 PRIORITIES

### 1. [CRITICAL] — Theme Font Tokens Exist But Are Completely Unused — Dynamic Type Non-Functional

**Confirmed by:** ACCESSIBILITY, ARCHITECT, BRAND (3 agents)

`Theme.swift` defines `ThemeFontStyle` and `Font.blinkText(_:)` but **zero view files consume it**. Every view uses `.font(.system(size: N))` instead. The tokens are dead code.

Worse: `Font.blinkText(_:)` itself uses `.system(size:)` without `@ScaledMetric` — even full adoption would NOT enable Dynamic Type. This is both an **architectural failure** (tokens unused) and a **technical failure** (adoption wouldn't fix it anyway).

**Files affected (partial):** PrivacyLockView, CalendarView, RecordView, OnboardingView, DeepAnalysisView, MonthBrowserView, PlaybackView, TrimView, FreemiumEnforcementView, SocialShareSheet, CustomGraphics — **~20+ views**

**Fix requires:** (a) Update `Font.blinkText(_:)` to use `.scaledFont(_:for)` or `@ScaledMetric`, (b) Audit all views and replace hardcoded `.font(.system(size:))` calls with Theme tokens, (c) Test with accessibility text size at maximum.

---

### 2. [CRITICAL] — Accessibility Labels Missing on 40+ Interactive Elements Across 8+ Views

**Confirmed by:** ACCESSIBILITY, BRAND (2 agents)

VoiceOver users encounter **completely unlabeled interactive elements** across major views:

| View | Elements | Severity |
|------|----------|----------|
| PrivacyLockView | 11 keypad buttons (digits 0-9, backspace) | CRITICAL |
| PasscodeSetupView | 11 keypad buttons | CRITICAL |
| OnboardingView | 5+ buttons (Back, Next, Open Settings, Enable Camera, Start Your Year) | CRITICAL |
| ErrorStatesView | 10 buttons across 6 error state views | HIGH |
| CommunityView | Category filter chips | HIGH |
| MonthBrowserView | Year picker buttons + month grid buttons + thumbnail tap gesture | HIGH |
| DeepAnalysisView | Toolbar refresh + empty state + Done button | HIGH |
| PricingView | Dismiss button + subscribe button | HIGH |
| FreemiumEnforcementView | X button (accessibilityHint generic, not descriptive) | LOW (but flagged) |

BRAND audit independently confirmed the FreemiumEnforcementView accessibilityHint issue.

**Fix:** Systematic `.accessibilityLabel()` pass on all interactive elements. Priority: keypad views → onboarding → error states → remaining.

---

### 3. [CRITICAL] — Periodic Time Observer Never Removed in TrimView (Memory Leak)

**Confirmed by:** SWIFTUI (primary), referenced by ARCHITECT actor isolation analysis

**Line:** TrimView.swift 270–275

`AVPlayer.addPeriodicTimeObserver()` returns an `Any` token that must be retained and passed to `removeTimeObserver()`. The current code never stores or removes the token. When the view disappears, the observer leaks — memory grows, and a callback can fire after the view is deallocated causing a crash.

```swift
player.addPeriodicTimeObserver(forInterval: ..., queue: .main) { time in
    // ... never removed
}
```

This is a **use-after-free crash risk**, not just a memory leak.

**Also in TrimView:** `saveTask?.cancel()` missing in `onDisappear` — task can continue after view dismissal.

---

### 4. [CRITICAL] — Notification Observer Never Removed in PlaybackView (Memory Leak)

**Confirmed by:** SWIFTUI (primary)

**Lines:** PlaybackView.swift 253–258

Classic `NotificationCenter` observer leak — `addObserver(forName:object:queue:)` returns a token that is never stored or removed. The observer lives in `NotificationCenter.default` permanently even after the view deallocates.

```swift
NotificationCenter.default.addObserver(
    forName: .AVPlayerItemDidPlayToEndTime,
    object: player.currentItem,
    ...
) { ... }
```

This is the same class of bug as the TrimView time observer — **actors hold references to deallocated views**.

**Also in PlaybackView:** `exportTask` cancellation only cancels the Task wrapper, not the underlying `videoStore.exportToCameraRoll` operation.

---

### 5. [CRITICAL] — Deep Link Infrastructure Dead-End — URL Scheme Unregistered + No AppShortcutsProvider + No Consumer

**Confirmed by:** PLATFORM (primary), referenced by ARCHITECT

Three compounding failures:

1. **`blink://` URL scheme not registered** — `CFBundleURLTypes` absent from Info.plist. iOS will never deliver `blink://` URLs to the app.
2. **DeepLinkHandler has no consumer** — `onOpenURL` correctly sets `pendingDeepLink`, but `ContentView.swift` has zero reference to `deepLinkHandler` or routing logic.
3. **Siri Shortcuts defined but not exposed** — `RecordBlinkIntent`, `ShowHighlightsIntent`, `OnThisDayIntent` exist but no `AppShortcutsProvider` exists in `BlinkApp`. `NSUserActivityTypes` absent from Info.plist. "Hey Siri, Record a Blink" does nothing.

**Also missing (CRITICAL for App Store):** `PrivacyInfo.xcprivacy` — required for privacy nutrition labels since 2020. App cannot be submitted without it.

---

### 6. [HIGH] — Shimmer Skeleton Animation Without reduceMotion Check (CommunityView)

**Confirmed by:** ACCESSIBILITY (primary), referenced by BRAND

**Line:** CommunityView.swift 283–289

`SkeletonMomentCard` shimmer animation runs with `.linear(duration: 1.5).repeatForever(autoreverses: false)` — no `@Environment(\.accessibilityReduceMotion)` guard. Users with vestibular motion sensitivity get a permanently looping animation. This is a **WCAG violation**.

BRAND audit also flagged `ApertureGraphic` `.repeatForever` animation (CustomGraphics.swift:361) — same pattern, though it has a `reduceMotion` check on `isOpen`, the `.repeatForever` still applies conditionally.

**Also:** PrivacyLockView has `shakeAnimation()` function that is **empty** — no actual shake effect on wrong passcode, only text feedback.

---

### 7. [HIGH] — Hardcoded Hex Colors in 15+ Files — Theme Token Inconsistency

**Confirmed by:** ARCHITECT, BRAND (2 agents)

Theme.swift defines tokens but is inconsistently adopted. Brand audit identifies **partial adoption creating visual inconsistency** — CalendarView uses Theme but RecordView uses raw hex, producing different shades for the same semantic colors.

Hardcoded `Color(hex:)` still present in:
- RecordView.swift: `0a0a0a`, `ff3b30`, `333333`
- SocialShareSheet.swift: `ff6b60`, `1a1a1a`, `666666`
- TrimView.swift: `1e1e1e`, `ff3b30`, `444444`
- PlaybackView.swift: `ff3b30`, `666666`
- FreemiumEnforcementView.swift: `0a0a0a`, `141414`, `2a2a2a`
- CustomGraphics.swift: `444444`, `ff6b60`, `1a1a1a` + macOS traffic light colors
- SubscriptionsView.swift: `ffd700`, `34c759`
- DeepAnalysisView.swift: `34c759`, `ff9500`, `ffcc00`

ARCHITECT notes: `Theme.success (34c759)` and `Theme.warning (ffcc00)` are **defined but never consumed** — dead code confirming no view is using Theme for these colors.

---

### 8. [HIGH] — Task/Observer Leaks in 4 Views — No Cancellation on Disappear

**Confirmed by:** SWIFTUI (primary), ARCHITECT (partial)

| View | Leak | Status |
|------|------|--------|
| TrimView.swift | PeriodicTimeObserver never removed | Not fixed |
| PlaybackView.swift | NotificationCenter observer never removed | Not fixed |
| CalendarView.swift | `exportTask` not cancelled on view dismiss | Not fixed |
| PrivacyLockView.swift | `biometricTask` (raw `Task`) not cancelled on disappear | Not fixed (pre-existing) |

ARCHITECT confirmed: CalendarView `exportTask` created in `exportThisMonth()` but never cancelled when CalendarView disappears — could set `showExportedAlert = true` on a dismissed view.

SWIFTUI confirmed: PrivacyLockView `biometricTask` is a raw `Task` (not `.task {}`), so SwiftUI won't auto-cancel it on disappear.

---

### 9. [HIGH] — i18n Broken — 15+ Hardcoded Strings Not in Localizable.strings

**Confirmed by:** PLATFORM (primary)

User-facing strings present in code but absent from `Localizable.strings`:

| File | Line | String |
|------|------|--------|
| MonthBrowserView.swift | 144 | `"No clips"` |
| StorageDashboardView.swift | 319 | `"No clips yet"` |
| OnThisDayView.swift | 165 | `"No clips on this date in past years"` |
| OnThisDayView.swift | 178 | `"Analyze clips to discover similar moments"` |
| CollaborativeAlbumView.swift | 151 | `"No clips yet"` |
| DeepAnalysisView.swift | 418 | `"No clips found"` |
| SocialShareSheet.swift | 66 | `"Add to today's most meaningful moments (anonymous)"` |
| CustomGraphics.swift | 536 | `"Your year in Blink"` |
| CustomGraphics.swift | 834 | `"Your year, compiled."` |
| CommunityView.swift | 36 | `"Coming Soon"` |
| ErrorStatesView.swift | 445 | `"No clips yet"` |
| OnboardingView.swift | 106 | `"Your year, one moment"` |
| PricingView.swift | 135 | `"Your year deserves more"` |
| CrossDeviceSyncView.swift | 38 | `"Coming Soon"` |
| CrossDeviceSyncView.swift | 107 | `"Syncing your memories…"` |
| SettingsView.swift | 469 | `"Your year, one moment at a time."` |

**Also:** Platform audit flagged `"Coming Soon"` labels on **functional features** — CrossDeviceSyncView and SettingsView iCloud Backup section show "Coming Soon" but have fully functional UIs beneath. Misleading copy.

---

### 10. [HIGH] — YearInReviewGraphic Hardcodes "83 Clips" in OnboardingScreen1

**Confirmed by:** BRAND (primary), referenced by ACCESSIBILITY

**Line:** CustomGraphics.swift:310

`OnboardingScreen1` uses `YearInReviewGraphic()` with no parameters. The graphic has `Text("83")` hardcoded — new users with 0 clips see "83 clips" during onboarding. This is a **broken onboarding experience** confirmed by Brand audit as the #1 remaining CRITICAL issue.

BRAND audit notes this was previously flagged in Phase 1 #30, partially fixed in YearInReviewView but **NOT in OnboardingScreen1**.

The graphic also uses `Color(hex: "f5f5f5")` directly instead of `Theme.textPrimary`.

---

## CROSS-CUTTING THEME MAP

```
Theme/Dynamic Type Failure
├── ACCESSIBILITY: Font tokens unused + Dynamic Type broken
├── ARCHITECT: Theme.success/warning dead code
└── BRAND: Visual inconsistency from partial Theme adoption

Accessibility Labels Missing
├── ACCESSIBILITY: 12 CRITICAL/HIGH elements in 8 views
├── BRAND: FreemiumEnforcementView accessibilityHint generic
└── ARCHITECT: privacyLockView keypad uses raw hex instead of Theme

Resource Leaks (Observers/Tasks)
├── SWIFTUI: TrimView PeriodicTimeObserver
├── SWIFTUI: PlaybackView NotificationCenter observer
├── ARCHITECT: CalendarView exportTask not cancelled
└── ARCHITECT: PrivacyLockView biometricTask not cancelled

Deep Link / Platform Infrastructure
├── PLATFORM: URL scheme unregistered
├── PLATFORM: DeepLinkHandler has no consumer
├── PLATFORM: AppShortcutsProvider missing
└── PLATFORM: PrivacyInfo.xcprivacy missing

i18n / Hardcoded Strings
├── PLATFORM: 15+ hardcoded strings not in Localizable.strings
└── BRAND: "Coming Soon" on functional features (misleading)

Hardcoded Colors (Partial Theme Adoption)
├── ARCHITECT: 15+ files with hardcoded hex
├── BRAND: Same 15+ files (visual inconsistency)
└── ACCESSIBILITY: Raw hex prevents light-mode/accessibility color inversion
```

---

## WHAT IS NOT CROSS-CUTTING (Single-Domain, Excluded)

- SWIFTUI-only: `DispatchQueue.main.asyncAfter` modernization (SocialShareSheet, RecordView, ContentView) — consistent but single-domain
- SWIFTUI-only: VideoStore file I/O on main thread — architectural concern but single-service
- SWIFTUI-only: StorageDashboardView computed property without memoization — single view
- SWIFTUI-only: AIHighlightsView recomputes on every body evaluation — single view
- ARCHITECT-only: CalendarView calendar math in views — service extraction, single domain
- BRAND-only: No undo after PlaybackView delete — UX pattern, single view
- BRAND-only: ApertureGraphic infinite animation — single graphic
- BRAND-only: Freemium "Maybe Later" copy expectations — single view
- PLATFORM-only: NWPathMonitor not used — single network concern
- PLATFORM-only: CommunityService fake data — single service

---

*End of Phase 2 Cross-Pollination Report*
*Accessibility Guardian — 2026-03-30*
