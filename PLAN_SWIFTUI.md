# SwiftUI Pedant — Phase 3: Unified Action Plan

**Agent:** SwiftUI Pedant  
**Date:** 2026-03-30  
**Sources:** AUDIT_SWIFTUI.md · AUDIT_PHASE2_SWIFTUI.md · All cross-pollination reports

---

## SWIFTUI PLAN:

## Priority 1: Eliminate Force-Unwrap Crash Paths

- **File:** `Blink/App/ContentView.swift:41` — `try! JSONDecoder().decode([VideoEntry].self, from: data)` — Replace with `try?` + graceful fallback to `[]` on error. Schema corruption should not crash the app.

- **File:** `Blink/Services/PrivacyService.swift:38` — `JSONEncoder().encode(privacy)!` — Replace with `try?`; log error, don't crash.

- **File:** `Blink/Services/PrivacyService.swift:56` — `try! JSONDecoder().decode(PrivacySettings.self, from: data)!` — Double forceunwrap. Replace with `try?`, handle `.none` case.

- **File:** `Blink/Views/PrivacyLockView.swift:40` — `UIApplication.shared` force-unwrapped. Replace with `guard let app = UIApplication.shared else { return }` — safe for extensions/headless.

- **File:** `Blink/Views/PrivacyLockView.swift:49` — `data(using: .utf8)!` — Replace with `data(using: .utf8)` + `guard let` — strings with invalid Unicode exist.

- **File:** `Blink/Views/PrivacyLockView.swift:37` — `NSManagedObjectContext!` implicitly unwrapped. Replace with `@Environment(\.managedObjectContext) private var viewContext` and use optional binding.

- **File:** `Blink/Views/PrivacySettingsView.swift:37,40,51` — Same three patterns as PrivacyLockView. Fix identically.

- **File:** `Blink/Views/PlaybackView.swift:37` — `NSManagedObjectContext!` at struct level. Same fix as PrivacyLockView:37.

- **File:** `Blink/Views/TrimView.swift:34` — `UIScreen.main.scale!` — Replace with `UIScreen.main?.scale ?? 1.0`.

- **File:** `Blink/Views/CalendarView.swift:106,118,126,139,165` — Five `entries.first!`, `allEntries.first!`, `monthEntry.clipIDs.first!` force-unwraps. Replace all with `guard let first = array.first else { return }`.

---

## Priority 2: Fix Fire-and-Forget Task Lifecycle Leaks

- **File:** `Blink/Views/YearInReviewCompilationView.swift:226` — `Timer.scheduledTimer` never stored/invalidated. Store in `@State private var progressTimer: Timer?`; invalidate in `.onDisappear { progressTimer?.invalidate() }`.

- **File:** `Blink/Views/RecordView.swift:303` — Countdown `Task { for i in [3, 2, 1] ... }` is fire-and-forget. Store via `@State private var countdownTask: Task<Void, Never>?` and cancel in `.onDisappear`.

- **File:** `Blink/Views/RecordView.swift:322` — `Task { ... withAnimation { showSaved = false } }` — short-lived but still untracked. Use same `.task` modifier pattern.

- **File:** `Blink/Views/RecordView.swift:88,198` — Two `.onChange` handlers firing on every frame during recording. Add `.animation(.default, value:)` debounce or guard `oldValue != newValue` checks to prevent redundant recomputation.

- **File:** `Blink/Views/CalendarView.swift:376` — `Task { ... exportProgress = ... isExporting = ... }` fire-and-forget export Task. Store in `@State private var exportTask: Task<Void, Never>?`; add `.onDisappear { exportTask?.cancel() }`.

- **File:** `Blink/Views/CalendarView.swift:382` — Nested `Task { @MainActor in exportProgress = progress }` inside `onProgress` closure. Remove nested Task; update state directly on MainActor since `onProgress` is already called on main.

- **File:** `Blink/Views/StorageDashboardView.swift:62,197,264` — Three `Task { await dashboardService.refresh(...) }` fire-and-forget. Store all three in `@State private var refreshTask: Task<Void, Never>?` and cancel in `.onDisappear`.

- **File:** `Blink/Views/StorageDashboardView.swift:363` — Nested `Task { @MainActor in }` inside `onProgress`. Same fix as CalendarView:382.

- **File:** `Blink/Views/OnboardingView.swift:296` — `Task { await privacy.requestBiometricPermission() }` fire-and-forget. Store and cancel.

- **File:** `Blink/Views/PublicFeedView.swift:91` — Fire-and-forget `Task { ... }` in `.onAppear`. Store and cancel.

- **File:** `Blink/Views/DeepAnalysisView.swift:33,101` — Two concurrent `Task { await analysisService.analyzeAll(...) }` with no shared cancellation. Use a single `@State private var analysisTask: Task<Void, Never>?` shared between both triggers.

- **File:** `Blink/Views/AIHighlightsView.swift:113,364` — Two fire-and-forget Tasks. Store and cancel.

- **File:** `Blink/Views/SocialShareSheet.swift:197,225,447` — Three fire-and-forget Tasks. Store and cancel.

- **File:** `Blink/Views/PlaybackView.swift:399` — Fire-and-forget Task. Store and cancel.

- **File:** `Blink/Views/YearInReviewCompilationView.swift:226-270` — Heavy AI operations in fire-and-forget Task. Store and cancel in `.onDisappear`.

- **File:** `Blink/Views/SettingsView.swift:396,406` — `startBackup()` and `startRestore()` fire-and-forget Tasks. Store and cancel.

- **File:** `Blink/Services/CameraService.swift:222` — `Task { await startCapture() }` fire-and-forget. Store and propagate cancellation to camera session teardown.

---

## Priority 3: Fix Actor Isolation — VideoStore and Services

- **File:** `Blink/Services/VideoStore+Operations.swift:10-22` — All `loadEntries()`, `saveVideo()` mutations need `MainActor.run { }` wrapping. Add `await MainActor.run { self.entries = ... }` around every `@Published` mutation site.

- **File:** `Blink/Services/VideoStore.swift:40` — `setupVideosDirectory()` on `init()` — move file I/O out of init, or defer to first async access. Do not block main actor during initialization.

- **File:** `Blink/Services/VideoStore.swift:80-90` — `dateFromFilename()` is fragile string parsing. Add `guard let date = formatter.date(from: name) else { return nil }` and propagate optional; callers currently force-unwrap.

- **File:** `Blink/Services/PrivacyService.swift:77-101` — `unlockWithBiometrics()` blocking `withCheckedContinuation` on main thread. Wrap biometric call in `Task { }` on a background actor so it doesn't block SwiftUI view rendering.

- **File:** `Blink/Services/PrivacyService.swift:130-145` — `biometricType` computed property creates `LAContext` on every access. Memoize with `@State private var cachedBiometricType: BiometricType?` refreshed only on `LAContext` invalidation or app foreground.

- **File:** `Blink/Services/PrivacyService.swift:55-65` — `verifyPasscode()` timing attack. Replace direct `==` with `ConstantTimeCompare` or `、保险柜` timing-safe comparison.

- **File:** `Blink/Services/AIHighlightsService.swift` — Add `@MainActor` annotation. All `async` methods that read/write shared state must be actor-isolated.

- **File:** `Blink/Services/DeepAnalysisService.swift` — Add `@MainActor` annotation. Vision completion handlers run on unknown queues — dispatch back to main actor.

- **File:** `Blink/Services/SocialShareService.swift` — Add `@MainActor` annotation.

- **File:** `Blink/Services/SubscriptionService.swift` — Add `@MainActor` annotation.

- **File:** `Blink/Services/HapticService.swift:1-50` — Add `@MainActor` or make it a `final class` with main-thread enforcement. Haptic feedback must fire on main thread.

- **File:** `Blink/Services/ExportService.swift:60-80` — Audio track failure should not fail entire export. Separate video and audio track creation; allow video-only export if audio fails.

- **File:** `Blink/Services/ThumbnailGenerator.swift:29` — Continuation resume path for nil image with no error. Add explicit error propagation or handle nil case with a concrete error type.

- **File:** `Blink/Services/DeduplicationService.swift:50-90` — `async let` frame extraction in loop. Consider batching frame extractions to avoid N concurrent `extractFrame` calls.

---

## Priority 4: Fix View Recomputation / Performance Bugs

- **File:** `Blink/Views/CalendarView.swift:50-55` — `daysInMonth` computed property recalculates month grid on every body access. Convert to `@State private var cachedDaysInMonth: [Date?]` with explicit refresh trigger.

- **File:** `Blink/Views/CalendarView.swift:110,120` — `entries.first?.videoURL` and `entry.formattedDate` recomputed on every render. Cache `videoURL` as computed property on `VideoEntry` itself; cache `formattedDate` as a stored property.

- **File:** `Blink/Views/SearchView.swift` — `searchResults` computed property filters on every keystroke with no debouncing. Add `@State private var searchDebounceTask: Task<Void, Never>?`; debounce 300ms before filtering.

- **File:** `Blink/Views/OnThisDayView.swift:80-100` — Three computed properties (`groupedByYear`, `similarMoodEntries`, `similarMoodGroups`) re-filter and re-group same data repeatedly. Convert to `@State` with single computation triggered by `videoStore` change.

- **File:** `Blink/Views/YearInReviewCompilationView.swift:100` — `topEntries` computed property sorts on every body evaluation. Cache as `@State private var cachedTopEntries: [VideoEntry]`.

- **File:** `Blink/Views/YearInReviewCompilationView.swift:98` — `aiService.yearInsights()` inside `topEntries` computed property. Extract to `@State private var yearInsights: YearInsights?` and compute once on appear.

- **File:** `Blink/Views/MonthBrowserView.swift:1-200` — `MonthBrowseCard.entries` computed property re-filters all entries for each month card in LazyVGrid. Cache at parent `MonthBrowserView` level and pass filtered arrays down.

- **File:** `Blink/Views/RecordView.swift` — Camera session owned directly by View. Extract to `RecordViewModel: ObservableObject`; move `AVCaptureSession`, `AVCaptureMovieFileOutput`, timer logic behind ViewModel boundary.

- **File:** `Blink/Views/TrimView.swift:100-115` — `AVPlayer` setup in View layer. Extract to `TrimViewModel: ObservableObject`.

- **File:** `Blink/Views/SettingsView.swift:1-150` — All `@AppStorage` reads/writes in View. Extract to `SettingsViewModel: ObservableObject` with `@AppStorage` backed properties moved to service layer.

- **File:** `Blink/Views/RecordView.swift:198` — `.onChange(of: cameraService.recordedDuration)` fires on every frame. Guard: `if abs(newValue - oldValue) < 0.05 { return }` to reduce noise.

---

## Priority 5: Theme Adoption — Connect Views to Design Tokens

- **File:** `Blink/App/Theme.swift:206` — `hapticOnTap` extension fires `Task { @MainActor in HapticFeedback.trigger(style) }` fire-and-forget. This is LOW severity but fix it: use `@MainActor` on the extension or remove Task wrapper since triggers are synchronous.

- **File:** `Blink/App/Theme.swift:206` — All Theme font tokens (fontLargeTitle, fontTitle1, fontBody, etc.) use `.system(size:)` fixed sizes. Update all to `Font.TextStyle` or `.scaled()` for Dynamic Type support. Then add SwiftLint rule `no_hardcoded_colors` and `no_fixed_font_size` as project policy.

- **File:** `Blink/Views/OnboardingView.swift:46-58` — All hardcoded `Color(hex:)` calls. Replace with `Theme.*` equivalents: `Color(hex: "0a0a0a")` → `Theme.background`, `Color(hex: "ff3b30")` → `Theme.accent`, `Color(hex: "f5f5f5")` → `Theme.textPrimary`, `Color(hex: "8a8a8a")` → `Theme.textSecondary`.

- **File:** `Blink/Views/RecordView.swift:95-100` — `.clipShape(RoundedRectangle(cornerRadius: 12/16/8))` hardcoded radii. Replace with `Theme.cornerRadiusSmall/Medium/Large`.

- **File:** `Blink/Views/RecordView.swift:9` — Non-8pt-grid padding values (40, 48, 20). Replace with `Theme.spacingLarge = 24` or `Theme.spacingMedium = 16`; add any missing Theme spacing tokens (40, 48 may need explicit `Theme.spacingXLarge`).

- **File:** `Blink/Views/PricingView.swift:1-200` — `Color(hex: "8a8a8a")`, `Color(hex: "ff3b30")`, `Color(hex: "f5f5f5")` hardcoded. Replace with Theme subscription tier colors via a computed `Theme.subscriptionTierAccent` or similar.

- **File:** `Blink/Views/CalendarView.swift:80-95` — Day cell `.font(.system(size: 14, weight: isToday ? .bold : .regular))` — Today uses bold, selected uses implicit regular. Make both explicit; use `Theme.fontCallout` with weight variant.

- **File:** `Blink/Views/StorageDashboardView.swift:100-120` — Hero card uses `.padding(20)`, other cards use `.padding(16)`. Standardize all cards to `Theme.spacingMedium = 16`. Add `Theme.spacingCardPadding` token if 20px is intentional.

- **File:** `Blink/Views/TrimView.swift` — `padding(.bottom, 40)` — 40 is not in Theme. Add `Theme.spacingExtraLarge = 40` or adjust to `Theme.spacingLarge = 24` with rationale.

- **File:** `Blink/Views/SettingsView.swift:30-45` — Inconsistent internal row padding. Standardize to `Theme.spacingSmall = 8` or `Theme.spacingMedium = 16`.

- **File:** `Blink/Views/PrivacyLockView.swift:110-115` — `Color(hex: "ff3b30").opacity(0.15)` hardcoded. Replace with `Theme.accent.opacity(0.15)`.

---

## My Top 5 for Unified Plan:

1. **VideoStore actor isolation** — `VideoStore+Operations.swift` mutates `@Published entries` from background Tasks without `MainActor.run`. Every view that reads `videoStore.entries` is reading potentially racy data. Fix: wrap all `self.entries = ...` mutations in `await MainActor.run { self.entries = ... }`. This unblocks everything else — no view can be made truly correct until VideoStore's concurrency is safe.

2. **Force-unwrap crash paths** — `ContentView.swift:41` `try! JSONDecoder()`, `PrivacyLockView.swift` triple force-unwrap (`UIApplication.shared!`, `data(using: .utf8)!`, `NSManagedObjectContext!`), `CalendarView.swift` five `first!` force-unwraps — any one of these can crash the app at runtime on valid user scenarios. Fix all with `try?`/`guard let`/`guard let else { return }` patterns. Low-effort per instance, high safety return.

3. **Fire-and-forget Tasks + Timer leaks** — `YearInReviewCompilationView.swift:226` Timer never invalidated; `RecordView.swift:303` countdown Task outlives view; `CalendarView.swift:376` export Task can't be cancelled. The pattern is consistent: use `.task { }` modifier (SwiftUI's built-in cancellation propagation) instead of bare `Task { }` in `.onAppear`. Store `Timer` in `@State` and invalidate in `.onDisappear`. Fix the template once (create a `View+task` extension or guideline) then apply across all 30 instances.

4. **119 missing `accessibilityLabel`s** — Every interactive `Button` and `Image` used as a button across all views has no `accessibilityLabel`. VoiceOver is completely broken app-wide. Fix: systematic find-replace adding `.accessibilityLabel("description")` to all labeled elements. Create a checklist from Accessibility audit items #1-119. This is high-volume but formulaic — batch by file, use regex find/replace where button titles are consistent strings.

5. **Theme adoption** — `Theme.swift` defines tokens used by zero views. Every color is `Color(hex: "0a0a0a")` instead of `Theme.background`, every spacing is raw `16` instead of `Theme.spacingMedium`. Fix: establish SwiftLint rule `no_hardcoded_colors` (colors must use Theme), then do a one-time migration pass converting all `Color(hex:)` calls to their Theme equivalents. This simultaneously resolves: Architect spacing inconsistencies, Accessibility Dynamic Type font scaling, Brand corner-radius confusion, and Platform localization readiness (colors defined in one place). Single highest-leverage refactor in the codebase.
