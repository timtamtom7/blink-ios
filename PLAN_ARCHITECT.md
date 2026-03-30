# ARCHITECT PLAN — Blink iOS
**Agent:** Architect
**Phase:** 3 — Unified Action Plan
**Date:** 2026-03-30

---

## Priority 1: Fix VideoStore Actor Isolation + Data Races
**Severity:** CRITICAL
**Confirmed by:** Architect (CRITICAL #4-5), SwiftUI (~30 fire-and-forget Tasks), Platform

### File: `blink-ios/Blink/Services/VideoStore.swift`
- **Line 40** — Remove `@MainActor` from class declaration; instead make `entries` and all `@Published` mutations explicitly isolated. Or migrate to `@Observable` (iOS 17+).
- **Line 50** — `init()` calls `setupVideosDirectory()` which does File I/O — wrap in `Task { @MainActor in }` or move to async initializer.
- **Add `@MainActor` isolation** to `loadEntries()`, `saveVideo()`, `deleteVideo()`, `updateEntry()` methods — all mutation sites.
- **Line 80-90** — `dateFromFilename()` is fragile string parsing — add error handling instead of returning `Date()` on parse failure.

### File: `blink-ios/Blink/Services/VideoStore+Operations.swift`
- **Lines 10-22** — Every `Task { await loadEntries() }` block that mutates `VideoStore.shared.entries` must wrap mutations in `await MainActor.run { }`.
- **Lines 28+** — Same fix for `saveVideo()`, `deleteVideo()`, `updateEntry()` — all background Tasks must use `MainActor.run` for `@Published` writes.
- **Line 50+** — Review all other operations in this file — `candidates.enumerated()` loop in `compressEligibleEntries` needs the same treatment.

### File: `blink-ios/Blink/Services/ExportService.swift`
- **Lines 60-80** — `exportClipsAsVideo()` mutates `VideoStore` from background — add `MainActor.run` isolation on callback to VideoStore.

### File: `blink-ios/Blink/Services/AdaptiveCompressionService.swift`
- **Lines 50-80** — `compressEligibleEntries()` iterates with async calls inside a `for` loop mutating `@Published` properties — wrap `totalSavedBytes += saved` in `await MainActor.run { }`.

---

## Priority 2: Passcode Security — Move from UserDefaults to Keychain
**Severity:** CRITICAL
**Confirmed by:** Architect (CRITICAL #3, #47), SwiftUI (CRITICAL #18-19), Platform (HIGH #2), Brand (HIGH #19)

### File: `blink-ios/Blink/Services/PrivacyService.swift`
- **Lines 12-18** — Remove `@AppStorage("privacyPasscode")` and `@AppStorage("isPrivacyEnabled")`. Replace with Keychain storage using a proper Keychain wrapper (e.g., `KeychainSwift` or a custom `KeychainManager`).
- **Line 55** — `verifyPasscode()` uses direct string comparison — replace with `ConstantTimeCompare` or `CryptoKit` HMAC comparison to prevent timing attacks.
- **Lines 77-101** — `unlockWithBiometrics()` uses `withCheckedContinuation` blocking the calling thread — refactor to use `async/await` with `LAContext.evaluatePolicy`'s async variant (iOS 15+) or ensure it's called off-main-thread.
- **Line 38** — `JSONEncoder().encode(privacy)!` — remove force-unwrap; add proper error handling.
- **Line 56** — `JSONDecoder().decode(...from: data)!` — remove force-unwrap; add graceful degradation on corrupted data.
- **Lines 130-145** — `biometricType` computed property creates new `LAContext` on every access — cache the result or store as `@MainActor` property updated on service init only.

### File: `blink-ios/Blink/Views/PrivacyLockView.swift`
- **Line 36** — Replace `@ObservedObject var privacy = PrivacyService.shared` with a `PrivacyLockViewModel` that wraps PrivacyService.
- **Lines 37-40** — `NSManagedObjectContext!` and `UIApplication.shared!` force-unwraps — add optional binding or `guard let` with proper error states.
- **Lines 225** — Fire-and-forget `Task { let success = await privacy.unlockWithBiometrics() }` — store the Task, cancel in `.onDisappear`.

### File: `blink-ios/Blink/Views/PrivacySettingsView.swift`
- **Lines 37-51** — Same force-unwrap issues (`UIApplication.shared!`, `data(using: .utf8)!`, `JSONEncoder().encode()!`) — apply same fixes as PrivacyLockView.

---

## Priority 3: FreemiumEnforcementView — Dismiss + State Fix
**Severity:** CRITICAL
**Confirmed by:** Brand (CRITICAL #3, #5), SwiftUI, Accessibility (10 missing labels)

### File: `blink-ios/Blink/App/ContentView.swift`
- **Lines 49-51** — The `onAppear` block that navigates to `FreemiumEnforcementView` fires every time — replace with a state flag: `if !hasAcknowledgedFreemiumToday && subscriptionTier == .free { showFreemiumEnforcement = true }`. Add `hasAcknowledgedFreemiumToday` to track daily acknowledgment via `@AppStorage`.

### File: `blink-ios/Blink/Views/FreemiumEnforcementView.swift`
- **Lines 1-100** — Add explicit dismiss mechanism: either a close `X` button or a "Maybe Later" that sets `hasAcknowledgedFreemiumToday = true` and dismisses.
- Add `accessibilityLabel` to all 7 buttons (critical gap from Accessibility audit).

### File: `blink-ios/Blink/Views/PlaybackView.swift`
- **Lines 100-115** — After `onDelete`, show a snackbar/toast with "Clip deleted" + "Undo" action for ~4 seconds before committing the deletion. Standard iOS pattern.

---

## Priority 4: Establish ViewModel Layer — Break Direct Service Observation
**Severity:** HIGH
**Confirmed by:** Architect (CRITICAL #1, #12-13, #19), SwiftUI

### File: `blink-ios/Blink/Views/RecordView.swift`
- **Lines 1-50** — Extract camera session management (`AVCaptureSession`, `AVCaptureMovieFileOutput`, timer logic) from `RecordView` into a `RecordViewModel`.
- **Line 52-60** — Camera setup in View layer — move to `RecordViewModel` or `CameraService`.
- **Lines 88, 198** — Two `.onChange` handlers fire on every frame — add debouncing or move to ViewModel as `@Published` properties.
- **Line 254** — Countdown animation not wrapped in `accessibilityReduceMotion` check.
- **Line 303** — `startCountdown()` fire-and-forget `Task` — store it, cancel in `.onDisappear`.

### File: `blink-ios/Blink/Views/CalendarView.swift`
- **Lines 50-55** — `daysInMonth` computed property recalculated on every render — make it `@State private var daysInMonth: [Date?]`.
- **Lines 80-95** — Day cell font weight inconsistent — selected day should have explicit weight.
- **Lines 106, 118, 126, 139, 165** — Five force-unwrap `.first!` calls — replace with `guard let` or `if let`.
- **Lines 376-382** — Export `Task` fires on every `.onAppear`; nested `Task { @MainActor in }` inside `onProgress` closure — restructure with stored Task and proper cancellation.
- **Create `CalendarViewModel`** to own `displayedMonth`, `selectedDate`, `daysInMonth` state.

### File: `blink-ios/Blink/Views/SearchView.swift`
- **Lines 50-70** — `filteredEntries` computed property filters on every keystroke with no debouncing — create `SearchViewModel` with `@State var searchText`, explicit `performSearch()` method.

### File: `blink-ios/Blink/Views/OnThisDayView.swift`
- **Lines 80-100** — Three computed properties (`groupedByYear`, `similarMoodEntries`, `similarMoodGroups`) that filter/group same data repeatedly — create `OnThisDayViewModel` with cached results.

### File: `blink-ios/Blink/Views/SettingsView.swift`
- **Lines 1-150** — Direct `@AppStorage` reads/writes for all settings — create `SettingsViewModel`.
- **Lines 41, 171** — `.onChange` handlers without debouncing — add debounce.

### File: `blink-ios/Blink/Views/TrimView.swift`
- **Lines 100-115** — AVPlayer setup in View — extract to `TrimViewModel`.
- **Line 34** — `UIScreen.main.scale!` force-unwrap — use optional binding.

### File: `blink-ios/Blink/Views/PlaybackView.swift`
- **Line 37** — `NSManagedObjectContext!` implicitly unwrapped at struct level — inject via `@Environment(\.managedObjectContext)`.
- **Line 399** — Fire-and-forget `Task` — store and cancel.

### File: `blink-ios/Blink/Views/YearInReviewCompilationView.swift`
- **Line 226** — `Timer.scheduledTimer` never invalidated — store in `@State`, invalidate in `.onDisappear`.
- **Lines 226-270** — Heavy AI operations in fire-and-forget `Task` — store Task, add cancellation, replace fake progress timer with actual progress.

---

## Priority 5: Enforce Theme Token Usage — Design System Adoption
**Severity:** HIGH (systemic)
**Confirmed by:** Architect (CRITICAL #7-8, #35-36), Accessibility (MEDIUM #149), Brand (HIGH #16), Platform (HIGH #9)

### File: `blink-ios/Blink/App/Theme.swift`
- **Lines 1-25** — Verify all tokens are correctly defined. Add any missing tokens (e.g., `Theme.recordingRed` for `ff3b30`).
- **Lines 20-25** — `cornerRadiusSmall=8, cornerRadiusMedium=12, cornerRadiusLarge=16` — consolidate if needed; Brand notes 12 vs 16 gap is too small. Consider `cornerRadiusMedium=16` and removing `cornerRadiusLarge`, or `cornerRadiusSmall=8, cornerRadiusMedium=16`.
- **Add SwiftLint/custom lint rule** to flag hardcoded hex colors and fixed font sizes.

### File: `blink-ios/Blink/App/Theme.swift`
- **Fonts** — Change all font tokens from `.system(size:)` to use `Font.TextStyle` via `.scaled()` for Dynamic Type support:
  - `fontLargeTitle: Font = .largeTitle.scaled()` (was `.system(size: 28)`)
  - `fontTitle1: Font = .title.scaled()` (was `.system(size: 22)`)
  - `fontTitle2: Font = .title2.scaled()` (was `.system(size: 20)`)
  - `fontTitle3: Font = .title3.scaled()` (was `.system(size: 18)`)
  - `fontHeadline: Font = .headline.scaled()` (was `.system(size: 17)`)
  - `fontBody: Font = .body.scaled()` (was `.system(size: 15)`)
  - `fontCallout: Font = .callout.scaled()` (was `.system(size: 14)`)
  - `fontSubheadline: Font = .subheadline.scaled()` (was `.system(size: 13)`)
  - `fontFootnote: Font = .footnote.scaled()` (was `.system(size: 13)`)
  - `fontCaption1: Font = .caption.scaled()` (was `.system(size: 12)`)
  - `fontCaption2: Font = .caption2.scaled()` (was `.system(size: 11)`)

### Migration — ALL view files (50+ files):
Replace all occurrences of:
- `Color(hex: "0a0a0a")` → `Theme.background`
- `Color(hex: "141414")` → `Theme.backgroundSecondary`
- `Color(hex: "1e1e1e")` → `Theme.backgroundTertiary`
- `Color(hex: "2a2a2a")` → `Theme.backgroundQuaternary`
- `Color(hex: "ff3b30")` → `Theme.recordingRed` (or `Theme.accent`)
- `Color(hex: "f5f5f5")` → `Theme.textPrimary`
- `Color(hex: "c0c0c0")` → `Theme.textSecondary`
- `Color(hex: "8a8a8a")` → `Theme.textTertiary`
- `Color(hex: "555555")` → `Theme.textQuaternary`
- `.font(.system(size: N))` → `.font(Theme.fontN)` or `Font.TextStyle.scaled()`
- `.cornerRadius(N)` → `Theme.cornerRadiusSmall/Medium/Large`
- `.padding(N)` → `Theme.spacingSmall/Medium/Large`

**Key files to migrate (in order):**
1. `OnboardingView.swift` — 100+ hardcoded values
2. `RecordView.swift` — camera UI, spacing
3. `CalendarView.swift` — month grid, day cells
4. `PlaybackView.swift` — controls, spacing
5. `SettingsView.swift` — rows, padding
6. `PricingView.swift` — subscription tier colors
7. `TrimView.swift` — trim handles, spacing
8. `SearchView.swift` — search field, results
9. `ErrorStatesView.swift` — all error UI
10. `PrivacyLockView.swift` — passcode UI, icons
11. `FreemiumEnforcementView.swift` — modal, buttons
12. `StorageDashboardView.swift` — card padding, typography
13. `AIHighlightsView.swift` — loading states, text
14. `ContentView.swift` — tab bar icons
15. All remaining views

---

## Priority 6: Service Layer — @MainActor Isolation
**Severity:** HIGH
**Confirmed by:** Architect (HIGH #13, #16-18, #28), SwiftUI (architecture notes)

### File: `blink-ios/Blink/Services/CameraService.swift`
- **Line 1-200** — Add `@MainActor` annotation to entire class.
- **Line 222** — Fire-and-forget `Task { await startCapture() }` — store Task, add cancellation.

### File: `blink-ios/Blink/Services/AIHighlightsService.swift`
- **Line 1-300** — Add `@MainActor` annotation.
- `yearInsights()` and `findBusiestMonth()` run on unknown actor — mark as `@MainActor` or explicitly run on main.

### File: `blink-ios/Blink/Services/DeepAnalysisService.swift`
- **Lines 1-400** — Add `@MainActor` annotation. All Vision request completions run on unknown dispatch queues — explicitly dispatch to `@MainActor`.

### File: `blink-ios/Blink/Services/SocialShareService.swift`
- **Line 1-100** — Add `@MainActor` annotation.
- **Lines 30-50** — `fallbackShareURL` constant — instead of silent fallback, surface error to caller.

### File: `blink-ios/Blink/Services/SubscriptionService.swift`
- **Line 1-100** — Add `@MainActor` annotation.

### File: `blink-ios/Blink/Services/HapticService.swift`
- **Lines 1-50** — Add `@MainActor` annotation — haptics must fire on main thread.

### File: `blink-ios/Blink/Services/ThumbnailGenerator.swift`
- **Line 29** — `generateCGImageAsynchronously` returning nil with no error — fix continuation resume path to not crash.

### File: `blink-ios/Blink/Services/CloudBackupService.swift`
- **Lines 40** — `private lazy var privateDatabase: CKDatabase = container.privateCloudDatabase` — clarify crash-on-access when entitlement missing; wrap access in guard.

### File: `blink-ios/Blink/Services/DeduplicationService.swift`
- **Lines 50-90** — `computeSimilarity` calls `extractFrame` multiple times in a loop — batch frame extractions where possible.

---

## Priority 7: Animations — Respect Reduce Motion
**Severity:** HIGH
**Confirmed by:** Accessibility (CRITICAL #139-145), Brand (HIGH #14)

### File: `blink-ios/Blink/Views/CustomGraphics.swift`
- **Line 285** — `ViewfinderGraphic` — wrap `.animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: isAnimating)` in `if !accessibilityReduceMotion { }`.
- **Line 452** — `ApertureGraphic` — wrap `.animation(.spring(...).repeatForever(autoreverses: true), value: isOpen)` in Reduce Motion check.
- **Line 285** — `ClipCompositionGraphic` — wrap `withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true))` in Reduce Motion check.
- **Line** — `YearInReviewGraphic` — wrap `withAnimation(.easeOut(duration: 1.5))` in Reduce Motion check.

### File: `blink-ios/Blink/Views/PrivacyLockView.swift`
- **Line 362** — `PrivacyLockIconGraphic` — wrap `.animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: isAnimating)` in `if !accessibilityReduceMotion { }`.

### File: `blink-ios/Blink/Views/YearInReviewCompilationView.swift`
- **Line 107** — `withAnimation(.easeOut(duration: 2))` for progress ring — wrap in Reduce Motion check.

### File: `blink-ios/Blink/Views/RecordView.swift`
- **Line 254** — Countdown `animation(.easeInOut(duration: 0.3), value: countdownValue)` — wrap in `if !accessibilityReduceMotion { }`.

### File: `blink-ios/Blink/Views/OnboardingView.swift`
- **Page 2 (ApertureGraphic)** — Add `.onAppear { if !accessibilityReduceMotion { isOpen = true } }` to trigger aperture animation. Also wrap in Reduce Motion check.

---

## Priority 8: ContentView.swift — JSON Decode + Deep Links
**Severity:** CRITICAL
**Confirmed by:** SwiftUI (CRITICAL #1, #46), Platform (CRITICAL #6)

### File: `blink-ios/Blink/App/ContentView.swift`
- **Line 41** — `try! JSONDecoder().decode([VideoEntry].self, from: data)` — remove force-unwrap. Replace with:
```swift
let entries: [VideoEntry] = (try? JSONDecoder().decode([VideoEntry].self, from: data)) ?? []
```
- **Lines 49-51** — Freemium enforcement re-trigger bug — see Priority 3.
- **Line 54** — Fire-and-forget `Task { await privacy.unlockWithBiometrics() }` — store Task, cancel in `.onDisappear`.

### File: `blink-ios/Blink/App/BlinkApp.swift`
- **Add `onOpenURL` modifier** to handle `blink://share?...` URLs:
```swift
.onOpenURL { url in
    handleDeepLink(url)
}
```
- Implement `handleDeepLink(_ url: URL)` to parse `blink://share?...` and navigate to the appropriate view.

---

## Priority 9: Localization Infrastructure
**Severity:** HIGH
**Confirmed by:** Platform (HIGH #9), Brand (MEDIUM #11-12)

### File: `blink-ios/Blink/App/`
- Create `Localizable.strings` catalog.
- Create a `Strings.swift` helper that wraps `String(localized:)` for common strings.
- **Systematically replace** all hardcoded strings across all 50+ view files:
  - `CalendarView.swift:97` — toolbar labels
  - `OnboardingView.swift` — all onboarding text
  - `PlaybackView.swift` — all button labels and alerts
  - `RecordView.swift:157` — accessibility labels
  - `ErrorStatesView.swift` — all error messages
  - `FreemiumEnforcementView.swift` — all copy
  - `TrimView.swift` — all UI strings
  - `PricingView.swift` — all pricing text
  - `SettingsView.swift` — all setting labels

---

## Priority 10: OnThisDayView + OnboardingView UX Fixes
**Severity:** HIGH
**Confirmed by:** Brand (CRITICAL #1-2, #8, #14, HIGH #30)

### File: `blink-ios/Blink/Views/OnboardingView.swift`
- **Page 1** — Add an illustration/graphic (CRITICAL Brand #1). Either create a `BlinkLogoGraphic` or find appropriate SF Symbol.
- **After last page** — Add a completion/celebration page before `hasCompletedOnboarding = true`. "You're all set!" with an illustration and transition animation.
- **Page 2 ApertureGraphic** — Add `.onAppear { isOpen = true }` to actually trigger the animation (Brand HIGH #14).
- **Page 3** — `YearInReviewGraphic` showing hardcoded "83 clips" — pass actual clip count or use a placeholder that doesn't mislead new users.

### File: `blink-ios/Blink/Views/OnThisDayView.swift`
- **Lines 1-100** — Add explicit back navigation: either an `X` button (`.navigationBarItems(leading:)`) or a "Done" button. The drag-to-dismiss is insufficient.

---

## My Top 5 for Unified Plan:

1. **[CRITICAL] VideoStore actor isolation** — `VideoStore+Operations.swift` + `VideoStore.swift` — Every `@Published` mutation site must use `await MainActor.run { }` inside background `Task` blocks. This is a data race that causes crashes on iOS 17+ strict concurrency. Fix before next build.

2. **[CRITICAL] Passcode moved to Keychain** — `PrivacyService.swift:12-18` — Replace `@AppStorage("privacyPasscode")` with Keychain storage + `ConstantTimeCompare` for `verifyPasscode()`. Plaintext UserDefaults passcode is a security catastrophe. Remove force-unwraps on encode/decode while you're there.

3. **[CRITICAL] FreemiumEnforcementView dismissal loop** — `ContentView.swift:49-51` + `FreemiumEnforcementView.swift` — Add `@AppStorage("hasAcknowledgedFreemiumToday")` flag; add dismiss button to FreemiumEnforcementView; free users cannot browse their clips today without this fix.

4. **[HIGH] ViewModel layer for RecordView + CalendarView** — `RecordView.swift:52-60` (camera session in View), `CalendarView.swift:50-55` (computed property recalculated every render), `CalendarView.swift:376-382` (fire-and-forget export Task) — Extract to `RecordViewModel` and `CalendarViewModel`. This unlocks testability, proper state management, and fixes the fire-and-forget Task leaks.

5. **[HIGH] Theme token migration** — All 50+ view files — Create a script to systematically replace `Color(hex: "0a0a0a")` → `Theme.background`, `.font(.system(size: N))` → `Font.TextStyle.scaled()`, `.cornerRadius(N)` → `Theme.cornerRadiusSmall/Medium/Large`. This is the single highest-leverage fix — it simultaneously resolves Architect's design token findings, Accessibility's Dynamic Type issues, and Brand's spacing/radius inconsistencies.
