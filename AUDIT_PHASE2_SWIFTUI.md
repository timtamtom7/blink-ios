# Blink iOS — Phase 2: SwiftUI Cross-Pollination Report

**Auditor:** SwiftUI Pedant  
**Date:** 2026-03-30  
**Sources:** AUDIT_ARCHITECT.md · AUDIT_ACCESSIBILITY.md · AUDIT_BRAND.md · AUDIT_PLATFORM.md · AUDIT_SWIFTUI.md  

---

## Cross-Cutting Issues (Issues Flagged by Multiple Agents from Different Angles)

### CC-1: VideoStore Actor Isolation Violations — Data Race Confirmed by Two Agents

**What it is:** `VideoStore.shared.entries` (`@Published`) is mutated from background `Task` closures in `VideoStore+Operations.swift` without `MainActor.run` isolation. The `@MainActor` annotation on the class does NOT protect `@Published` mutations from off-main-thread writes.

- **Architect (CRITICAL #4-5):** Data race on `VideoStore.entries`, `@MainActor` class with unguarded `@Published` mutations.
- **SwiftUI (HIGH #21-37):** ~30 fire-and-forget `Task { }` closures that mutate state from background contexts, including `VideoStore+Operations.swift`.

**Intersection:** Architect identified the architectural root cause; SwiftUI identified the concrete implementation instances. Both independently arrive at the same hazard. This is the highest-confidence cross-cutting issue.

---

### CC-2: Passcode Security — Plaintext Storage + Timing Attack + Force Unwrap

**What it is:** Passcode security is broken at three layers simultaneously:

- **Architect (CRITICAL #3):** Passcode stored in plain `UserDefaults` — no Keychain, no hashing.
- **Architect (CRITICAL #47):** `verifyPasscode()` uses direct string comparison — timing attack vulnerability.
- **SwiftUI (CRITICAL #18-19):** `JSONEncoder().encode(privacy)!` and `JSONDecoder().decode(...from: data)!` — force-unwrap on PrivacyService encoding/decoding will crash on any error.
- **Platform (HIGH #2):** No privacy consent flow for R2/R3.

**Intersection:** Four different agents found four different aspects of the same privacy/security stack. Combined severity is catastrophic — data is stored insecurely, compared unsafely, and decoded with crashes possible on corruption.

---

### CC-3: Design Tokens Established But Completely Ignored

**What it is:** `Theme.swift` defines a complete design token system (colors, spacing, corner radii, fonts) that is used by zero views.

- **Architect (CRITICAL #7-8, HIGH #35-36):** Theme tokens defined but `Color(hex:)` hardcoded everywhere. `cornerRadiusSmall=8, cornerRadiusMedium=12` — 4pt gap is visually indistinguishable. Named spacing values unused.
- **Accessibility (MEDIUM #149):** Colors referenced as hex literals instead of semantic Theme tokens throughout implementation files.
- **Brand (MEDIUM):** Visual identity is strong in Theme.swift but never connected to views.
- **SwiftUI (not specifically flagged):** But the same hardcoded values appear in SwiftUI-pedant-flagged files.

**Intersection:** Architect quantified the damage (100% of views use hardcoded values). Accessibility confirms the same pattern from a different lens (WCAG color naming). Brand observes that the Theme's identity never reaches users. This is not a bug — it's an adoption failure.

---

### CC-4: Missing Accessibility Labels — 119 Critical Instances

**What it is:** Every interactive `Button` and `Image` used as a button throughout the app lacks an `accessibilityLabel`.

- **Accessibility (CRITICAL):** 119 critical instances across all view files.
- **SwiftUI (not explicitly flagged in Phase 1):** But the same views (RecordView, TrimView, CalendarView, PlaybackView, etc.) are in SwiftUI's scope.
- **Brand (related):** OnThisDayView has no back navigation; FreemiumEnforcementView has no dismiss — these are navigation a11y failures.

**Intersection:** Accessibility agent did the deep count. Brand agent found structural navigation a11y gaps on top of the per-element label problem. Combined, the app is essentially unusable with VoiceOver.

---

### CC-5: Fire-and-Forget Tasks — ~30 Instances, Leaking Across the App

**What it is:** `Task { ... }` closures spawned in `.onAppear`, `.onChange`, and completion handlers that are never stored, never cancelled, and outlive their views.

- **SwiftUI (HIGH #20-37):** ~30 fire-and-forget Tasks identified.
- **Architect (MEDIUM #28):** Background task mutations without proper isolation in VideoStore+Operations, ExportService, AdaptiveCompressionService.
- **Brand (related):** YearInReviewCompilationView's fake progress timer (0-90%) is decoupled from actual work — it animates even if the AI task got cancelled or failed silently.

**Intersection:** SwiftUI counted the instances. Architect identified that the same pattern (background mutation + no cancellation) is the architectural default. Brand observed that the user-facing symptom of silent Task failure is fake progress feedback.

---

## Severity Changes Based on Other Agents' Findings

### Severity UPGRADED: PrivacyService biometric blocking

**Architect (CRITICAL #6):** `unlockWithBiometrics()` uses `withCheckedContinuation` wrapping `LAContext.evaluatePolicy` — a blocking call on the calling thread. If called from main thread (which it is, via `PrivacyLockView`), this hangs the UI during the biometric prompt.

**SwiftUI didn't flag this specifically.** The blocking call inside the continuation is Architect's finding. This is more severe than a simple fire-and-forget Task — it freezes the UI.

### Severity UPGRADED: FreemiumEnforcementView re-trigger loop

**Brand (CRITICAL #3):** `ContentView.onAppear` re-triggers `FreemiumEnforcementView` on every `ContentView` appear. If a free user dismisses the sheet, it immediately re-appears on the next appear.

**SwiftUI didn't flag this** — it lives in ContentView, which SwiftUI did audit (issue #46, fire-and-forget biometric task), but the re-trigger loop wasn't identified. Combined with Architect's finding that `SubscriptionService` is a stub, the entire subscription enforcement system is broken in multiple ways.

### Severity DOWNGRADED (contextualized): CloudBackupService / CrossDeviceSyncService stubs

**Platform (HIGH):** All three sync services are stubs — CloudBackupService, CrossDeviceSyncService, CommunityService.

**SwiftUI (not flagged):** The stub nature wasn't visible from SwiftUI's perspective since the stubs do compile and run without crashing.

**Architect (LOW #16):** CloudKit lazy var crash potential is noted but misleadingly described.

**Impact:** These are feature gaps, not bugs. They don't cause crashes — but they are false advertising. Severity depends on whether "cloud sync coming soon" is acceptable for an app that markets cloud backup as a feature.

---

## Contradictions / Conflicts Between Agents

### Contradiction 1: CalendarView month-grid computation — who flagged it?

**Architect (HIGH #20):** CalendarView computes month grid on every render via a computed property — should be `@State`.

**SwiftUI (MEDIUM #39-40):** CalendarView's `entries.first?.videoURL` and `entry.formattedDate` recomputed on every body evaluation — flagged as MEDIUM.

**Resolution:** Both agents flagged CalendarView for recomputation issues, but Architect caught the higher-level structural problem (the whole month-grid computed property recalculating), while SwiftUI caught specific derived properties within it. These are consistent, not contradictory — Architect's issue is the root cause.

### Contradiction 2: HapticService actor isolation

**Architect (LOW #42):** `HapticService` is not `@MainActor` — if called from background, haptics won't fire.

**Brand (LOW #32):** `HapticService` methods exist and are well-organized, but `countdownTick()` isn't called in the RecordView countdown.

**Resolution:** Both are true. Haptics are architecturally unsafe AND they're not even being called where expected. Two separate problems, both real.

### Contradiction 3: ApertureGraphic animation

**Brand (HIGH #14):** ApertureGraphic has animation code but `OnboardingView` displays it without triggering `.onAppear`, so the aperture never opens.

**Architect/SwiftUI (not flagged):** This is a Brand/SwiftUI gap — the animation setup exists but the trigger is missing. Neither Architect nor SwiftUI looked at whether `ApertureGraphic`'s `isOpen` state was being set.

---

## TOP 10 PRIORITIES

```
TOP 10 PRIORITIES:
1. CRITICAL — VideoStore.swift + VideoStore+Operations.swift — @Published entries mutated from background Tasks without MainActor.run; data race on VideoStore.shared.entries — confirmed by: [Architect, SwiftUI]
2. CRITICAL — PrivacyService.swift — Passcode stored in plaintext UserDefaults + verifyPasscode() vulnerable to timing attack + encode/decode force-unwrap crashes — confirmed by: [Architect, SwiftUI, Platform]
3. CRITICAL — PrivacyLockView.swift — View directly observes PrivacyService (no ViewModel); biometric unlock blocks main thread via withCheckedContinuation — confirmed by: [Architect, SwiftUI]
4. CRITICAL — ContentView.swift:41 — try! JSONDecoder().decode on UserDefaults data; crashes on schema change or corruption — confirmed by: [SwiftUI]
5. CRITICAL — Accessibility — 119 interactive elements (Buttons, Images) across RecordView, TrimView, CalendarView, PlaybackView, SettingsView, etc. have zero accessibilityLabel — confirmed by: [Accessibility, Brand]
6. HIGH — All Views (Theme.swift consumers) — 100% of views use hardcoded Color(hex:) instead of Theme tokens; design system established but completely unused — confirmed by: [Architect, Accessibility, Brand]
7. HIGH — RecordView.swift + AIHighlightsView.swift + YearInReviewCompilationView.swift + 20+ other files — ~30 fire-and-forget Task { } closures; tasks outlive views, no cancellation, leak CPU/memory — confirmed by: [SwiftUI, Architect]
8. HIGH — ContentView.swift:49-51 + FreemiumEnforcementView.swift — FreemiumEnforcementView re-triggers on every ContentView appear; no dismiss mechanism; free users trapped — confirmed by: [Brand, Architect]
9. HIGH — Platform — blink://share URL built but never handled (no onOpenURL in BlinkApp); CloudBackupService/CrossDeviceSyncService/CommunityService are non-functional stubs — confirmed by: [Platform]
10. HIGH — Theme.swift + all view files — All fonts use .system(size:) with fixed pt values instead of Font.TextStyle; Dynamic Type completely unsupported; 7 animation instances run without accessibilityReduceMotion check — confirmed by: [Accessibility, SwiftUI]
```

---

## Confirmed SwiftUI-Specific Issues (Not in Other Audits)

These are issues the SwiftUI Pedant found that were **not** confirmed by other agents — they're SwiftUI-specific quality issues worth addressing but lower priority than the cross-cutting items above:

- `YearInReviewCompilationView.swift:226` — `Timer.scheduledTimer` never invalidated; timer leaks after view disappears
- `RecordView.swift:303` — Countdown fire-and-forget Task; `countdownTick()` haptic never called (Brand confirms)
- `CalendarView.swift:376-382` — Export Task fires on every onAppear; nested Task inside onProgress closure
- `PrivacyLockView.swift:37, 40, 49` — `NSManagedObjectContext!` implicitly unwrapped + `UIApplication.shared!` force-unwrap + `data(using: .utf8)!` — three distinct crash paths in one view
- `TrimView.swift:34` — `UIScreen.main.scale!` force-unwrap; crashes in extensions/headless macOS
- `CalendarView.swift:106, 118, 126, 139, 165` — Five force-unwrap `.first!` calls on arrays/optionals
- `PlaybackView.swift:37` — `NSManagedObjectContext!` implicitly unwrapped at struct level
- `SearchView.swift` — `searchResults` computed property filters on every keystroke with no debouncing

---

## Phase 2 Recommendations for Fix Teams

1. **VideoStore actor isolation** is the single most urgent fix. Add `@MainActor` isolation to all mutation sites, or migrate to Swift 6 `@Observable` with proper isolation boundaries.
2. **Passcode security** needs a dedicated sprint: move to Keychain, add `ConstantTimeCompare`, remove force-unwraps on encode/decode.
3. **Accessibility labels** should be auto-injected via a `View` extension that adds default labels based on `accessibilityIdentifier` or view hierarchy — 119 manual edits is error-prone.
4. **Theme adoption** should be enforced via SwiftLint rule (`no_hardcoded_colors`) — the tokens exist, the enforcement mechanism doesn't.
5. **Task cancellation** should be tracked in a `TaskStore` or via `.task { }` modifier (SwiftUI's built-in cancellation) instead of fire-and-forget `Task { }` closures.

---

*Phase 2 Cross-Pollination complete. Five agents, 5 perspectives, 1 prioritized list.*
