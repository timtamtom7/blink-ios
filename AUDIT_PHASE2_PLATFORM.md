# Blink iOS — Phase 2: Platform Guardian Cross-Pollination Report

**Auditor:** Platform Guardian  
**Date:** 2026-03-30  
**Sources:** AUDIT_PLATFORM.md (own), AUDIT_ARCHITECT.md, AUDIT_ACCESSIBILITY.md, AUDIT_BRAND.md, AUDIT_SWIFTUI.md

---

## Cross-Cutting Issues

### 1. Theme.swift Is a Ghost — Defined But Never Used (Confirmed by 4/4 agents)

Every agent independently encountered the same root pathology: `Theme.swift` defines a full design token system (colors, spacing, corner radii, fonts), but no view actually uses it.

- **Architect** (CRITICAL #7, #8): Theme defines tokens but views use `Color(hex:)` directly. "Hardcoded hex colors everywhere" — OnboardingView, PricingView, RecordView, CalendarView, PlaybackView, SettingsView, TrimView, SearchView, OnThisDayView, MonthBrowserView, StorageDashboardView, AIHighlightsView, PrivacyLockView, ErrorStatesView, FreemiumEnforcementView — **every single view**.
- **Accessibility**: Theme font tokens use `.system(size:)` with fixed sizes instead of `Font.TextStyle` — Dynamic Type is broken app-wide (19+ files). Font tokens exist but use the wrong API.
- **Brand**: `cornerRadiusLarge = 16` vs `cornerRadiusMedium = 12` — only 4pt difference makes them visually indistinguishable. Spacing tokens (`spacingSmall = 8`, `spacingMedium = 16`) are ignored in favor of 4, 6, 10, 12, 14, 20, 28, 32, 40, 48.
- **Platform**: Hardcoded strings are everywhere — zero usage of `String(localized:)`. Localization infrastructure doesn't exist.

**This is the single highest-leverage fix in the entire codebase.** One refactor (migrate all hex literals to Theme colors, all fixed fonts to TextStyle, all hardcoded strings to String(localized:)) would simultaneously resolve findings from Architect, Accessibility, Brand, AND Platform.

---

### 2. VideoStore Actor Isolation / Data Race (Confirmed by 3/4 agents)

The `VideoStore.entries` `@Published` array is mutated from background `Task` contexts without proper `MainActor.run` isolation.

- **Architect** (CRITICAL #4, #5): `VideoStore` declared `@MainActor` but mutations in `VideoStore+Operations.swift` (`loadEntries()`, `saveVideo()`) happen in `Task { }` blocks running off-main-thread. This is a data race.
- **SwiftUI** (CRITICAL #1): `ContentView.swift:41` uses `try! JSONDecoder().decode([VideoEntry].self, from: data)` — force-unwrap on decode, no error handling, and this sits inside a View that reads from `VideoStore`.
- **Platform**: `NWPathMonitor` is absent, so network failures on save/sync are unhandled, compounding the data integrity risk around `VideoStore` mutations.

**Amplification**: Architect's finding is more severe than Platform's — it's not just a threading bug, it's a potential crash if two background tasks mutate `@Published` simultaneously. Platform didn't fully scope this; Architect's analysis upgrades it.

---

### 3. PrivacyService / Passcode Security Chain (Confirmed by 3/4 agents)

Passcode storage and biometric handling form a cluster of related weaknesses:

- **Architect** (CRITICAL #3): Passcode stored in plaintext `UserDefaults` via `@AppStorage("privacyPasscode")`. No hashing, no salting, no Keychain.
- **Architect** (CRITICAL #6): `unlockWithBiometrics()` uses `withCheckedContinuation` blocking the calling thread — will hang UI if called from main thread.
- **Architect** (MEDIUM #26): `biometricType` computed property creates a new `LAContext` on every access from `PrivacyLockView.body` — expensive main-thread operation.
- **Platform** (HIGH #2): No privacy consent onboarding flow. No `PrivacyInfo.xcprivacy`. No `NSPrivacyTracking` declarations.
- **SwiftUI** (CRITICAL #5): `PrivacyLockView` has a fire-and-forget `Task` capturing `isAuthenticating`, `isAppLocked` state — if biometric prompt is dismissed mid-flow, stale state mutations occur.
- **Brand** (HIGH #19): No explanation of what biometric auth is for on first setup — users may think it's required vs. optional.

**Amplification**: Architect raised the passcode storage from Platform's HIGH to CRITICAL. The combination of plaintext storage + timing attack vulnerability (Architect LOW #47) + biometric timing bug + no consent flow = a systemic privacy security failure, not just a missing feature.

---

### 4. Stub Services / False Feature Advertising (Confirmed by 3/4 agents)

Multiple services advertise real functionality but are non-functional:

- **Platform** (HIGH #10): `CrossDeviceSyncService`, `CloudBackupService`, `CommunityService` are all stubs — placeholder comments with simulated delays, no actual CloudKit implementation.
- **Architect** (HIGH #16): `CloudBackupService` has a CKContainer lazy var with a misleading crash comment — the crash happens on property access, not lazy init.
- **Brand** (HIGH #18): `CommunityView` shows fake placeholder data with anonymous IDs and static counts. No empty state, no loading skeleton. Users see convincing fake data for a non-existent feature.
- **Platform** (HIGH #9): `PublicFeedView` and `CommunityView` have no network layer — UI is wired to no-op stubs.
- **SwiftUI** (MEDIUM #48): `ExportService.exportMonthClips` stores the `progressTask` correctly (good), but callers don't propagate cancellation — effectively fire-and-forget from caller's perspective.

**Amplification**: Brand's finding adds user-experience harm to Platform's "feature missing" framing. Users are being shown convincing fake data for features that don't exist — this is worse than showing empty states.

---

### 5. Fire-and-Forget Task Proliferation (Confirmed by 3/4 agents)

SwiftUI identified ~30 instances of fire-and-forget `Task { }` blocks. Architect and Platform confirm the pattern extends to service layer:

- **SwiftUI** (CRITICAL/HIGH): CalendarView exports in fire-and-forget Task (CalendarView:376), RecordView countdown (RecordView:303), AIHighlightsView heavy computations, DeepAnalysisView analysis, StorageDashboardView refresh, YearInReviewCompilationView AI operations — all unbounded Tasks that outlive their views.
- **Architect** (HIGH #5, #15, #28): VideoStore+Operations mutations in background Tasks, ExportService mutates VideoStore from background, AdaptiveCompressionService `@Published` mutations in for-loops.
- **Platform** (MEDIUM #7): CameraService recording start/stop has no haptics in service layer — if recording is started programmatically without RecordView, no haptic fires. (Related: the haptics exist in HapticService but are only triggered from RecordView's view layer.)
- **Accessibility** (HIGH #139-145): 7 animation instances without Reduce Motion checks. These animations also represent unbounded UI state mutations happening outside view lifecycle.

**Amplification**: SwiftUI's count (~30 fire-and-forget Tasks) is the authoritative number. Architect and Platform provide the service-layer context. Together this is a systemic async/await discipline failure, not isolated incidents.

---

## Findings That Change Severity

| Finding | Platform Phase 1 | Cross-Pollination Verdict |
|---|---|---|
| Passcode in UserDefaults | HIGH | **CRITICAL** — plaintext + timing attack + no consent flow = systemic failure |
| `blink://` URL scheme undefined | CRITICAL | **Confirmed CRITICAL** — Brand adds: fallback URL silently masks errors |
| Theme tokens unused | Not flagged by Platform | **CRITICAL** — 4 agents independently found this; highest-leverage fix |
| Stub cloud services | HIGH | **HIGH** (no change) but Brand upgrades UX harm — fake data shown to users |
| Hardcoded strings | HIGH | **HIGH** (no change) but Accessibility quantifies at 119 critical missing labels |
| VideoStore mutations | Not flagged by Platform | **CRITICAL** — Architect's @MainActor analysis is more precise than Platform's framing |

---

## Findings That Contradict / Conflict

**No direct contradictions found.** The five audits operated on different layers (platform/features, architecture, accessibility, brand/UX, SwiftUI correctness) and their findings are complementary rather than conflicting.

Minor tension:
- **Platform** flagged "no camera toggle" as MEDIUM. **Architect** (HIGH #12) frames `RecordView` directly owning the camera session as an architecture problem. Architect's framing is more accurate — the issue isn't UX feature gap, it's separation of concerns.
- **Platform** flagged `VNDetectFaceRectanglesRequest` as MEDIUM iOS 26 API miss. **SwiftUI** flagged Vision queue issues in `DeepAnalysisService`. Neither flagged the other's finding directly, but together they confirm Vision APIs are inconsistently used.

---

## TOP 10 PRIORITIES

```
TOP 10 PRIORITIES:

1. CRITICAL — PrivacyService.swift + PrivacyLockView.swift — Passcode stored in plaintext UserDefaults, no Keychain, no hashing, no consent flow, biometric unlock blocks main thread, biometricType queried on every view access — confirmed by: [Architect, Platform, SwiftUI]

2. CRITICAL — VideoStore.swift + VideoStore+Operations.swift — @Published entries mutated from background Tasks without MainActor.run isolation; data race on concurrent writes; try! JSONDecoder in ContentView with no error handling — confirmed by: [Architect, SwiftUI]

3. CRITICAL — Theme.swift (unused) — All design tokens defined but zero views use them; every view uses hardcoded hex Color(hex:) literals; all font tokens use fixed .system(size:) breaking Dynamic Type; spacing tokens ignored — confirmed by: [Architect, Accessibility, Brand, Platform]

4. CRITICAL — RecordView.swift + CameraService.swift — RecordView directly owns AVCaptureSession bypassing CameraService; 30+ fire-and-forget Tasks in view layer (countdown, recording, save) outlive view lifecycle; no haptics in service layer — confirmed by: [Architect, SwiftUI, Platform]

5. CRITICAL — CalendarView.swift:376 + StorageDashboardView.swift:62,197,264 + AIHighlightsView.swift:113 + DeepAnalysisView.swift:33 — Fire-and-forget Tasks for export, storage refresh, AI analysis that outlive views, no cancellation; nested Task { @MainActor } in progress closures — confirmed by: [SwiftUI, Architect]

6. CRITICAL — blink:// URL scheme (SocialShareService.swift:32 + BlinkApp.swift) — blink://share URLs built but onOpenURL never implemented in BlinkApp; silent fallback to constant URL masks errors; no deep link handling at all — confirmed by: [Platform]

7. HIGH — CrossDeviceSyncService.swift + CloudBackupService.swift + CommunityService.swift — All three are non-functional stubs with simulated delays; CloudKit never implemented; CommunityView displays convincing fake placeholder data to users; no empty/loading states — confirmed by: [Platform, Architect, Brand]

8. HIGH — All 119 interactive elements (RecordView, TrimView, PlaybackView, CalendarView, SettingsView, ContentView, OnboardingView, PrivacyLockView, etc.) — Zero accessibilityLabel on any Button or icon Image; VoiceOver completely broken across entire app — confirmed by: [Accessibility, Platform]

9. HIGH — All views (OnboardingView, PricingView, RecordView, CalendarView, PlaybackView, etc.) — 19+ files using .font(.system(size:)) fixed sizes instead of Font.TextStyle; Dynamic Type completely non-functional; 7 repeatForever animations without accessibilityReduceMotion checks — confirmed by: [Accessibility, Architect]

10. HIGH — ErrorStatesView.swift + FreemiumEnforcementView.swift + ContentView.swift — FreemiumEnforcementView has no dismiss mechanism trapping free users; ContentView.onAppear re-triggers enforcement on every appear making dismissal impossible; generic clinical error copy throughout; no undo after delete in PlaybackView — confirmed by: [Brand, SwiftUI]
```

---

## Recommended Next Steps for Platform Agent

1. **Migrate all `Color(hex:)` calls to `Theme.*` tokens** — This single refactor resolves Architect CRITICAL #7/#8, Accessibility issues around color contrast and Dynamic Type font scaling, and Brand's spacing/radius inconsistencies. Coordinate with Architect for the actual migration plan.

2. **Implement `blink://` deep link handler** — `BlinkApp.swift` needs `onOpenURL(perform:)` modifier. Coordinate with Brand (share sheet UX) and SwiftUI (URL parsing).

3. **Implement `UNUserNotificationCenter`** — Notifications are entirely absent. Coordinate with Accessibility (labels for notification content) and Brand (notification copy tone).

4. **Fix VideoStore actor isolation** — Wrap all `@Published` mutations in `MainActor.run { }`. Coordinate with SwiftUI audit owner for the full list of mutation sites.

5. **Replace stub services or remove UI** — `CommunityView` should show empty states, not fake data. Either implement the stubs or cut the UI. Coordinate with Brand for empty state copy.
