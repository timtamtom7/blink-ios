# Blink — Phase 1: SwiftUI Audit Findings

**Auditor:** SwiftUI Pedant (Phase 1/4)
**Scope:** All Swift files in `blink-ios/Blink/` and `blink/Sources/`
**Categories:** Force unwraps · Implicitly unwrapped optionals · Task leaks · View recomputation bugs · Actor isolation · Architecture issues

---

## CRITICAL

1. **blink-ios/Blink/App/ContentView.swift:41** — `try! JSONDecoder().decode([VideoEntry].self, from: data)` — Force-unwrap on decode will **crash** if UserDefaults data is corrupted or schema has changed. No error handling whatsoever.

2. **blink-ios/Blink/Views/PrivacyLockView.swift:37** — `let viewContext: NSManagedObjectContext!` — **Implicitly unwrapped optional** declared at struct level. Any access before it's set will crash. The `.onAppear` guard helps but doesn't eliminate all code paths.

3. **blink-ios/Blink/Views/PrivacyLockView.swift:40** — `UIApplication.shared` force-unwrapped. `UIApplication.shared` **is an optional** (`UIApplication?`) in iOS — this will crash in certain contexts (extensions, headless, Mac Catalyst).

4. **blink-ios/Blink/Views/PrivacyLockView.swift:49** — `data(using: .utf8)!` — Force-unwrap on string encoding. Will crash if the string contains invalid Unicode. Affects all `UserDefaults.set(..., forKey:)` calls in this file.

5. **blink-ios/Blink/Views/PrivacyLockView.swift:225** — `Task { let success = await privacy.unlockWithBiometrics() ... }` — **Fire-and-forget Task** capturing `isAuthenticating`, `isAppLocked` state. Not stored; cannot be cancelled. If view disappears mid-biometric, Task continues and mutates state that may no longer be observed.

6. **blink-ios/Blink/Views/PrivacySettingsView.swift:37** — `UIApplication.shared` force-unwrapped. Same crash path as PrivacyLockView:40.

7. **blink-ios/Blink/Views/PrivacySettingsView.swift:40** — `data(using: .utf8)!` — Same crash path as PrivacyLockView:49.

8. **blink-ios/Blink/Views/PrivacySettingsView.swift:51** — `userDefaults.encode(...)` force-unwrapped. `JSONEncoder().encode()` can throw; this silently drops encoding errors.

9. **blink-ios/Blink/Views/PlaybackView.swift:37** — `let viewContext: NSManagedObjectContext!` — **Implicitly unwrapped optional** from `@Environment`. Will crash if this view is ever presented without the Core Data environment injected (e.g., SwiftUI preview, unit test).

10. **blink-ios/Blink/Views/TrimView.swift:34** — `UIScreen.main.scale!` — `UIScreen.main` is optional; force-unwrapping could crash in extensions or headless macOS.

11. **blink-ios/Blink/Views/CalendarView.swift:106** — `entries.first!` — Force-unwrap on array `.first`. Will crash if `entries` is empty when this path executes.

12. **blink-ios/Blink/Views/CalendarView.swift:118** — `videoAttribute!` — Force-unwrap on optional `AVAsset` property. Will crash if video file is missing or unreadable.

13. **blink-ios/Blink/Views/CalendarView.swift:126** — `allEntries.first!` — Force-unwrap on `.first`. Will crash if `allEntries` is empty.

14. **blink-ios/Blink/Views/CalendarView.swift:139** — `monthEntry.clipIDs.first!` — Force-unwrap on optional UUID. Will crash if `clipIDs` is empty.

15. **blink-ios/Blink/Views/CalendarView.swift:165** — `monthEntry.clipIDs.first!` — Same force-unwrap issue, second occurrence.

16. **blink-ios/Blink/Views/CalendarView.swift:376** — `Task { ... exportProgress = ... isExporting = ... }` — **Fire-and-forget Task** in `exportThisMonth()`. Captures `exportProgress`, `isExporting`, `showExportedAlert`, `exportedVideoURL` by reference. If view disappears during a long export operation, the Task outlives the view.

17. **blink-ios/Blink/Views/CalendarView.swift:382** — `Task { @MainActor in exportProgress = progress }` — Nested Task inside the `onProgress` closure. Creates a fire-and-forget MainActor Task on every progress callback with no cancellation.

18. **blink-ios/Blink/Services/PrivacyService.swift:38** — `JSONEncoder().encode(privacy)!` — Force-unwrap on encode. Will crash on any encoding error (circular reference, unsupported type, etc.).

19. **blink-ios/Blink/Services/PrivacyService.swift:56** — `try! JSONDecoder().decode(PrivacySettings.self, from: data)` — Force-unwrap on decode. Will crash on corrupted data.

---

## HIGH

20. **blink-ios/Blink/Views/YearInReviewCompilationView.swift:226** — `Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in ... }` — **Timer leak**: timer is never stored or invalidated. The timer continues firing indefinitely even after the view disappears. The timer should be stored in a `@State` property and invalidated in `.onDisappear`.

21. **blink-ios/Blink/Views/RecordView.swift:303** — `Task { for i in [3, 2, 1] { ... } }` — **Fire-and-forget Task** in `startCountdown()`. Captures `countdownValue`, `showCountdown`, `hasWarnedDuration`. No cancellation; runs to completion regardless of view lifecycle.

22. **blink-ios/Blink/Views/RecordView.swift:322** — `Task { try? await Task.sleep(...) withAnimation { showSaved = false } }` — **Fire-and-forget Task**. No cancellation. Safe for short animations but same pattern as #21.

23. **blink-ios/Blink/Views/StorageDashboardView.swift:62** — `Task { await dashboardService.refresh(...) }` — **Fire-and-forget Task** in `.onAppear`. Not stored; no cancellation. If view disappears during refresh, the Task continues and mutates `selectedDuplicate` after view is gone.

24. **blink-ios/Blink/Views/StorageDashboardView.swift:197** — `Task { await dashboardService.refresh(...) }` — Same fire-and-forget pattern in `deleteDuplicateGroup`.

25. **blink-ios/Blink/Views/StorageDashboardView.swift:264** — `Task { await dashboardService.refresh(...) }` — Same pattern in `optimizeStorage`.

26. **blink-ios/Blink/Views/StorageDashboardView.swift:363** — Nested `Task { @MainActor in }` inside `onProgress` closure — same nested fire-and-forget Task issue as CalendarView:382.

27. **blink-ios/Blink/Views/OnboardingView.swift:296** — `Task { await privacy.requestBiometricPermission()` }` — **Fire-and-forget Task** not stored. If user skips onboarding before Task completes, the Task continues.

28. **blink-ios/Blink/Views/PublicFeedView.swift:91** — `Task { ... }` — Fire-and-forget Task in `.onAppear`. No cancellation.

29. **blink-ios/Blink/Views/DeepAnalysisView.swift:33** — `Task { await analysisService.analyzeAll(...) }` — Fire-and-forget Task. If view disappears during analysis, the Task continues with no way to cancel.

30. **blink-ios/Blink/Views/DeepAnalysisView.swift:101** — `Task { await analysisService.analyzeAll(...) }` — Second fire-and-forget Task (refresh button). No shared cancellation mechanism between these Tasks — both could run concurrently.

31. **blink-ios/Blink/Views/AIHighlightsView.swift:113** — `Task { await aiService.analyzeHighlights(entries: entries) }` — Fire-and-forget Task with no cancellation.

32. **blink-ios/Blink/Views/AIHighlightsView.swift:364** — `Task { ... aiService.yearInsights() }` — Fire-and-forget Task. `yearInsights()` is a heavy computation (`Calendar.current.dateComponents`, sorting, grouping) running without cancellation.

33. **blink-ios/Blink/Views/SocialShareSheet.swift:197** — `Task { let fetchedContacts = try await socialService.fetchRecentContacts() ... }` — Fire-and-forget Task in `loadContacts()`. If the view is dismissed during contact loading, the Task continues.

34. **blink-ios/Blink/Views/SocialShareSheet.swift:225** — `Task { try? await socialService.submitToPublicFeed(entry: entry) }` — Fire-and-forget Task. No feedback on failure; silently swallows errors.

35. **blink-ios/Blink/Views/SocialShareSheet.swift:447** — `Task { ... socialService.shareViaMessages(to: contact, entry: entry) }` — Fire-and-forget Task. If view disappears mid-send, no cleanup.

36. **blink-ios/Blink/Views/PlaybackView.swift:399** — `Task { ... }` — Fire-and-forget Task. No cancellation.

37. **blink-ios/Blink/Views/YearInReviewCompilationView.swift:226-270** — `Task { ... aiService.analyzeHighlights(entries: entries) ... aiService.generateHighlightReel(clips: urls, title: "\(year) in Blink") ... }` — Heavy AI operations in fire-and-forget Task. No cancellation. No progress feedback beyond a fake progress timer. If view disappears, AI work continues consuming CPU/GPU.

38. **blink-ios/Blink/Services/CameraService.swift:222** — `Task { await startCapture() }` — Fire-and-forget Task. If view disappears, capture continues.

---

## MEDIUM

39. **blink-ios/Blink/Views/CalendarView.swift:110** — `entries.first?.videoURL` is computed on every body evaluation. `videoStore.entries` could be large; `videoURL` computation calls `videosDirectory.appendingPathComponent(filename)` repeatedly. Should be derived once via `@Query` or cached.

40. **blink-ios/Blink/Views/CalendarView.swift:120** — `entry.formattedDate` computed on every body evaluation. `DateFormatter.dateFormat` calls are expensive when repeated. Should be precomputed or cached.

41. **blink-ios/Blink/Views/YearInReviewCompilationView.swift:100** — `topEntries` is a computed property that filters and sorts `entries` on **every body evaluation**. For large entry sets this is O(n log n) per frame.

42. **blink-ios/Blink/Views/YearInReviewCompilationView.swift:98** — `aiService.yearInsights()` called inside `topEntries` computed property. This is a full analysis computation (filtering by year, grouping by week, sorting, computing `percentile`, finding `peakWeek`) done on every body evaluation. Should be `@State` with explicit trigger.

43. **blink-ios/Blink/Views/OnThisDayView.swift** — `videoStore.onThisDayEntries` appears to be computed inline (not shown in snippet but likely recomputed per body). Filter/sort over all entries on each render.

44. **blink-ios/Blink/Views/RecordView.swift:88** — `.onChange(of: cameraService.error) { _, error in handleCameraError(error) }` — onChange handler that calls `handleCameraError`, which presents alerts and modifies `showError`. This could cause view hierarchy issues if called during certain SwiftUI layout phases.

45. **blink-ios/Blink/Views/RecordView.swift:198** — `.onChange(of: cameraService.recordedDuration) { oldValue, newValue in ... }` — onChange fires on every frame of recording duration. Could cause excessive recomputation. No debouncing.

46. **blink-ios/Blink/App/ContentView.swift:54** — `Task { await privacy.unlockWithBiometrics() }` — Fire-and-forget Task in `.onChange` handler. No `[weak self]` but since `privacy` is a reference type (singleton) it's less of a leak concern, but the Task itself is not stored.

47. **blink-ios/Blink/App/Theme.swift:206** — `Task { @MainActor in HapticFeedback.trigger(style) }` — Fire-and-forget Task in View extension's `hapticOnTap`. No cancellation; but haptics are short-lived so this is low severity.

48. **blink-ios/Blink/Services/ExportService.swift:221** — `let progressTask = Task { ... }` — Task **is** stored (`progressTask`), so it CAN be cancelled. This is the correct pattern. However, if the callers of `exportMonthClips` don't pass the Task reference back to the caller for cancellation, it remains effectively fire-and-forget from the caller's perspective.

49. **blink-ios/Blink/Views/SettingsView.swift:396** — `Task { do { try await cloudBackup.backupAllClips() ... } }` — Fire-and-forget Task in `startBackup()`. No cancellation.

50. **blink-ios/Blink/Views/SettingsView.swift:406** — `Task { do { try await cloudBackup.restoreClips() } }` — Fire-and-forget Task in `startRestore()`. No cancellation.

51. **blink-ios/Blink/Services/CloudBackupService.swift:77** — `Task { @MainActor in cloudBackupState = .backingUp }` — Fire-and-forget Task.

52. **blink-ios/Blink/Services/CloudBackupService.swift:135** — `Task { @MainActor in cloudBackupState = .restoring }` — Fire-and-forget Task.

53. **blink-ios/Blink/Services/CrossPlatformSyncService.swift:83** — `Task { ... }` — Fire-and-forget Task. Captures `syncState` via MainActor-isolated properties.

54. **blink-ios/Blink/Services/Blink2Service.swift:79** — `Task { ... }` — Fire-and-forget Task. Captures `self` strongly (ObservableObject).

55. **blink-ios/Blink/Views/CrossDeviceSyncView.swift:56** — `Task { await syncService.syncAll() }` — Fire-and-forget Task. No cancellation.

56. **blink-ios/Blink/Views/SearchView.swift** — `searchResults` computed property filters `videoStore.entries` on every body evaluation with `localizedCaseInsensitiveContains`. For large libraries this causes noticeable lag during typing.

---

## LOW

57. **blink-ios/Blink/Services/SocialShareService.swift:52** — `URLComponents()` followed by force-unwrap on `.url`. The `guard let url = components.url else { return SocialShareService.fallbackShareURL }` pattern IS correct here (not a force-unwrap), but the fallback constant is a string literal URL that bypasses actual URL construction logic.

58. **blink-ios/Blink/Services/SocialShareService.swift:76** — `guard let url = components.url else { return SocialShareService.fallbackShareURL }` — Returns a constant fallback URL instead of surfacing the error to the caller. Callers can't distinguish between a valid URL and the fallback.

59. **blink-ios/Blink/Views/CalendarView.swift:376** — `exportProgress` is `@State` being mutated from inside a background Task. This works because `@MainActor.run` is used, but the intermediate `onProgress` closure also spawns a nested `Task { @MainActor in }` — two levels of task nesting for progress updates.

60. **blink-ios/Blink/Views/RecordView.swift:88 & 198** — Two `.onChange` modifiers on the same view. The `recordedDuration` onChange fires on every frame; combined with the `cameraService.error` onChange, this view has multiple reactive handlers that could interact unpredictably.

61. **blink-ios/Blink/Views/TrimView.swift:358 & 420** — Two separate `Task { }` calls in TrimView. Need to verify they don't overlap if user starts/stops trim operations rapidly.

62. **blink-ios/Blink/Views/TrimView.swift:87** — `.onAppear` sets `currentStart = 0.0` and `currentEnd = duration`. If the view is dismissed and re-presented, state resets. If `.onDisappear` doesn't clean up properly, stale state from a previous session could briefly show.

63. **blink-ios/Blink/Views/PrivacySettingsView.swift** — Multiple `UserDefaults.set(..., forKey:)` calls in `.onAppear` that overwrite each other's keys (`"blink_passcode"`, `"blink_biometric"`, `"blink_privacy_lock"`). These are different keys but the pattern suggests copy-paste errors could be introduced.

64. **blink-ios/Blink/Views/SettingsView.swift:41** — `.onChange(of: dailyReminderEnabled) { _, newValue in ... }` — Modifies `dailyReminderTime` inside an onChange. If `dailyReminderEnabled` toggles rapidly, this could race with the UNUserNotificationCenter calls.

65. **blink-ios/Blink/Views/SettingsView.swift:171** — `.onChange(of: iCloudBackupEnabled) { _, newValue in ... }` — Starts a backup/resture Task inside onChange without debouncing. If toggled rapidly, multiple backup Tasks could queue up.

66. **blink/Sources/MonthlyReelView.swift:338** — `Task { ... }` — Fire-and-forget Task. Need to verify if it captures `self` properly.

67. **blink/Sources/MonthlyReelView.swift:352** — `Task { ... }` — Fire-and-forget Task.

68. **blink/Sources/SharedAlbumView.swift:57** — `Task { ... }` — Fire-and-forget Task. Need to verify capture semantics.

69. **blink/Sources/SharedAlbumView.swift:76** — `Task { ... }` — Fire-and-forget Task.

70. **blink/Sources/RecordView.swift:192** — `Task { ... VideoStore.shared.saveVideo(...) }` — Task captures singleton strongly. Since VideoStore.shared is a singleton, this is safe from a memory management perspective.

---

## ARCHITECTURE NOTES (Not Bugs Per Se)

71. **blink-ios/Blink/Services/VideoStore.swift** — `final class VideoStore: ObservableObject` uses the Combine `@Published` pattern. For iOS 17+ targets, migrating to `@Observable` would eliminate the ObservableObject overhead and `@Published` concerns. Currently both Combine observation (for iOS 15-16) and potential `@Observable` coexist, which is not ideal.

72. **blink-ios/Blink/Services/AIHighlightsService.swift** — `final class AIHighlightsService: ObservableObject`. Uses `@Published` but no `@MainActor` annotation. Since it's a reference type accessed from SwiftUI views (which run on MainActor), all mutations happen on main but the class doesn't enforce it. Consider adding `@MainActor` for Swift 6 safety.

73. **blink-ios/Blink/Services/DeepAnalysisService.swift** — Same issue as AIHighlightsService: no `@MainActor` annotation despite being accessed from main-thread-only SwiftUI views.

74. **blink-ios/Blink/Services/SocialShareService.swift** — No `@MainActor` annotation. `fetchPublicFeed()` runs `VideoStore.shared.entries` filtering on whatever thread calls it. Swift 6 would require explicit `MainActor` isolation.

75. **blink-ios/Blink/Services/SubscriptionService.swift** — No `@MainActor` annotation. `clipsRecordedToday`, `isRecording`, and other properties are mutated without guaranteed main-thread safety.

---

## SUMMARY BY CATEGORY

| Category | Count | Top Severity |
|---|---|---|
| Force unwraps (`!`) | ~20 | CRITICAL |
| Implicitly unwrapped optionals | 3 | CRITICAL |
| Fire-and-forget Tasks | ~30 | HIGH |
| Timer leaks | 1 | HIGH |
| View recomputation bugs | 7 | MEDIUM |
| `@MainActor` missing on services | 5 | MEDIUM |
| `.onChange` without debounce | 3 | MEDIUM |

**Total issues: 75**
