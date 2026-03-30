# AUDIT2 — Phase 2 Cross-Pollination Report

**Agent:** Architect (Cross-Pollination)  
**Date:** 2026-03-30  
**Input:** AUDIT2_ARCHITECT.md, AUDIT2_ACCESSIBILITY.md, AUDIT2_BRAND.md, AUDIT2_SWIFTUI.md, AUDIT2_PLATFORM.md  
**Goal:** Identify cross-cutting issues confirmed by multiple agents, flag Phase4 regressions, produce TOP 10 consolidated priorities.

---

## Cross-Cutting Issue Mapping

### Issue 1: Theme Tokens Exist But Are Unused (4 agents confirm)

| Agent | Finding |
|-------|---------|
| Architect | Theme.success/warning are dead code — defined but never consumed. ~15 views still use hardcoded `Color(hex:)` |
| Accessibility | `Font.blinkText(_:)` uses fixed `.system(size:)` with no Dynamic Type scaling — even if adopted, text won't scale with accessibility preferences |
| Brand | Phase4 partial adoption creates visual inconsistency — CalendarView uses Theme tokens, RecordView uses raw hex, producing different shades for the same semantic colors |
| SwiftUI | All views use hardcoded `.font(.system(size: N))` instead of Theme font tokens |

**Confirmed:** Theme design system exists but is architecturally incomplete — tokens are defined but consumption is optional and unenforced. Dynamic Type will not work even if views adopt tokens without architectural fix to `Font.blinkText(_:)`.

---

### Issue 2: AVPlayer Observer Leaks (2 agents confirm)

| Agent | Finding |
|-------|---------|
| SwiftUI | TrimView.swift:270 — `addPeriodicTimeObserver` returns token never stored or removed. Memory leak + potential post-deallocation crash |
| SwiftUI | PlaybackView.swift:253 — `addObserver(forName: .AVPlayerItemDidPlayToEndTime)` never removed. Observer lives in NotificationCenter forever |
| Architect | RecordView.swift — `DispatchQueue.main.asyncAfter` predates Phase4 (not observer-related but same leak pattern) |

**Confirmed:** Two distinct AVPlayer/KVO observer leaks. Both will cause memory growth and potential crashes after extended use.

---

### Issue 3: Animation Accessibility — Skeleton Shimmer (2 agents confirm)

| Agent | Finding |
|-------|---------|
| Accessibility | CommunityView.swift:283–289 — SkeletonMomentCard shimmer with `repeatForever`, no `@Environment(\.accessibilityReduceMotion)` check. NEW issue introduced in Phase 4 or previously unfixed |
| Brand | CommunityView shimmer listed as HIGH — accessibility needs check |

**Confirmed:** Loading skeleton animation introduced without reduceMotion guard. Affects motion-sensitive users.

---

### Issue 4: @MainActor Isolation in AdaptiveCompressionService (2 agents confirm)

| Agent | Finding |
|-------|---------|
| Architect | `compressEligibleEntries` loop writes `compressedEntries.insert()` and `compressionProgress =` outside @MainActor context. `totalSavedBytes += saved` IS correctly wrapped, but sibling writes are not |
| SwiftUI | AdaptiveCompressionService noted as "Non-isolated ObservableObject" — acceptable for read-only but the write isolation problem confirms this |

**Confirmed:** Race condition in Phase4 code. `@Published` properties written from async context outside MainActor.

---

### Issue 5: Hardcoded Strings Outside Localizable (2 agents confirm)

| Agent | Finding |
|-------|---------|
| Platform | 19+ hardcoded strings identified across MonthBrowserView, OnThisDayView, DeepAnalysisView, SocialShareSheet, CustomGraphics, CommunityView, ErrorStatesView, OnboardingView, PricingView, CrossDeviceSyncView, SettingsView |
| Brand | FreemiumEnforcementView copy doesn't set expectations (partially related) |

**Confirmed:** i18n is systematically broken across ~12 view files. User-facing strings exist only as Swift literals.

---

### Issue 6: Loading State UI Missing (2 agents confirm)

| Agent | Finding |
|-------|---------|
| Brand | SocialShareSheet.swift — `isSubmittingToFeed` set but no loading UI shown; `isLoadingContacts` set but contacts option remains clickable during fetch |
| Brand | SocialShareSheet.swift — `createAndShowPrivateLink` is synchronous (10ms) but shows 2-second loading overlay — naming and UX mismatch |

**Confirmed:** Boolean flags track async state but UI doesn't reflect them. Users see no feedback during multi-second operations.

---

### Issue 7: Tasks Not Cancelled on View Dismiss (2 agents confirm)

| Agent | Finding |
|-------|---------|
| Architect | CalendarView.swift:20 — `exportTask` created but never cancelled on view disappear |
| Architect | PrivacyLockView.swift:42 — `biometricTask` raw Task not cancelled on disappear |
| SwiftUI | PlaybackView.swift:29-30 — `exportTask?.cancel()` only cancels Task wrapper, not underlying in-flight operation |

**Confirmed:** Three view dismissal patterns with incomplete cleanup. Tasks continue running post-dismiss.

---

### Issue 8: Hardcoded 1-Second Timer for Camera Init (2 agents confirm)

| Agent | Finding |
|-------|---------|
| Brand | RecordView.swift:174 — `DispatchQueue.main.asyncAfter(deadline: .now() + 1.0)` hardcoded delay to hide camera loading overlay |
| SwiftUI | Same issue confirmed |

**Confirmed:** Fixed timer instead of session-ready signal. Slow devices show black viewfinder after spinner disappears; fast devices see spinner after camera ready.

---

### Issue 9: Phase4 New Issues That Regressed Other Fixes

| Issue | Introduced By | Confirmed By |
|-------|--------------|--------------|
| `compressedEntries` race condition | Phase4 AdaptiveCompressionService refactor | Architect + SwiftUI |
| Skeleton shimmer no reduceMotion | Phase4 CommunityView skeleton addition | Accessibility + Brand |
| `exportTask` not cancelled | Phase4 CalendarView exportTask addition | Architect |
| `biometricTask` not structured | Phase4 PrivacyLockView changes | Architect |

---

### Issue 10: Deep Link System Entirely Non-Functional (2 agents confirm)

| Agent | Finding |
|-------|---------|
| Platform | `pendingDeepLink` set by DeepLinkHandler but ContentView has zero reference to it |
| Platform | `blink://` URL scheme not registered in Info.plist — iOS won't route URLs to app |

**Confirmed:** Deep link plumbing exists but no consumer and no system registration. Dead code.

---

## TOP 10 PRIORITIES

```
TOP 10 PRIORITIES:
1. CRITICAL — PrivacyLockView.swift, PasscodeSetupView.swift — All 11 keypad buttons (0-9, ⌫) have NO accessibilityLabel. VoiceOver users hear "button, button, button" and cannot enter passcode. Confirmed by: Accessibility + Brand
2. CRITICAL — TrimView.swift:270 — AVPlayer addPeriodicTimeObserver token never stored or removed. Memory leak + post-deallocation crash. Confirmed by: SwiftUI + Architect
3. CRITICAL — PlaybackView.swift:253 — NotificationCenter addObserver for AVPlayerItemDidPlayToEndTime never removed. Observer lives in NotificationCenter forever after view dealloc. Confirmed by: SwiftUI
4. CRITICAL — CommunityView.swift:283 — SkeletonMomentCard shimmer animation uses repeatForever with no @Environment(\.accessibilityReduceMotion) check. NEW regression from Phase4. Confirmed by: Accessibility + Brand
5. CRITICAL — AdaptiveCompressionService.swift:43-56 — compressedEntries.insert() and compressionProgress = written outside @MainActor from async loop. Race condition on @Published properties. Introduced by Phase4. Confirmed by: Architect + SwiftUI
6. CRITICAL — BlinkApp.swift + ContentView.swift — DeepLinkHandler sets pendingDeepLink but ContentView never reads it. Deep link system is dead code. Confirmed by: Platform
7. CRITICAL — Info.plist — CFBundleURLTypes missing. blink:// scheme not registered. iOS will not route any deep links to the app regardless of code fixes. Confirmed by: Platform
8. HIGH — Theme.swift (architecture) — Font.blinkText(_:) uses fixed .system(size:) with no Dynamic Type scaling. Tokens defined but unusable. Also: Theme.success/warning are dead code — defined but zero view consumption. Confirmed by: Architect + Accessibility + Brand + SwiftUI
9. HIGH — VideoStore.swift:240 — onThisDayEntries() computed twice (onThisDayCount getter + passed to OnThisDayView). Duplicate filtering/sorting of same array. Confirmed by: Architect
10. HIGH — 19+ hardcoded strings not in Localizable.strings — i18n systematically broken across ~12 view files. Confirmed by: Platform + Brand
```

---

## Phase 4 Regression Summary

| File | Line | Issue | Severity | Introduced By |
|------|------|-------|----------|--------------|
| AdaptiveCompressionService.swift | 43-56 | `compressedEntries.insert()` not MainActor-isolated | CRITICAL | Phase4 |
| CommunityView.swift | 283 | Skeleton shimmer no reduceMotion check | CRITICAL | Phase4 |
| CalendarView.swift | 20 | `exportTask` not cancelled on dismiss | HIGH | Phase4 |
| PrivacyLockView.swift | 42 | `biometricTask` not cancelled on dismiss | HIGH | Phase4 |
| SocialShareSheet.swift | 174 | `DispatchQueue.main.asyncAfter` not Phase4 but unremediated | MEDIUM | Pre-existing |

---

## Also Notable

**PrivacyInfo.xcprivacy missing** — Platform calls this the single most blocking item for App Store readiness. Not in top 10 because no other agent flagged it (platform-specific), but it is critical.

**Siri Shortcuts provider missing** — AppShortcutsProvider not implemented, NSUserActivityTypes not in Info.plist. "Hey Siri, Record a Blink" does nothing.

**YearInReviewGraphic "83 clips"** — CustomGraphics.swift:310 hardcodes number in OnboardingScreen1. New users with 0 clips see "83 clips." Confirmed by Brand only (architectural, not cross-agent).

---

*End of Phase 2 Cross-Pollination Report*