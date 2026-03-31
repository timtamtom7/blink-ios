# SwiftUI Audit Round 4 — Blink iOS

**Auditor:** SwiftUI Pedant Agent
**Date:** 2026-03-31
**Scope:** Force unwraps, data flow, recomputation bugs, @State/@Binding correctness, Swift 6 concurrency, architecture bugs

---

## CRITICAL Issues

### [CRITICAL] StorageDashboardView.swift:198 — Computed property recomputation in view body

```swift
private func compressionSection(_ stats: StorageDashboardService.StorageStats) -> some View {
    VStack(alignment: .leading, spacing: 12) {
        ...
        let candidates = compressionService.analyzeCompressionCandidates(entries: videoStore.entries)
```

**Problem:** `compressionSection` is a computed property (`var`) used inside `body`. Every time `body` is evaluated (any @Published change in VideoStore, compressionService, deduplicationService, or dashboardService), `analyzeCompressionCandidates` is called which iterates over ALL entries and filters them. This is O(n) work on every state change.

**Fix:** Cache `candidates` in a `@State` variable, or better yet, have `AdaptiveCompressionService` expose a published `compressionCandidates` that it updates when entries change.

---

### [CRITICAL] ContentView.swift:49 — Fire-and-forget DispatchQueue with no cancellation

```swift
DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
    if hasCompletedOnboarding && !hasSeenPricing {
        showPricing = true
        hasSeenPricing = true
    }
}
```

**Problem:** This `asyncAfter` in `.onAppear` has no cancellation. If the user rapidly navigates (onboards → goes to settings → comes back), multiple asyncAfter closures can accumulate and fire. On older devices this can cause multiple pricing sheets.

**Fix:** Store the work item and cancel it in `onDisappear`:
```swift
@State private var pricingWorkItem: DispatchWorkItem?
...
let workItem = DispatchWorkItem { ... }
pricingWorkItem = workItem
DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: workItem)
...
.onDisappear { pricingWorkItem?.cancel() }
```

---

### [CRITICAL] ContentView.swift:112 — Another fire-and-forget asyncAfter

```swift
DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
    showPricing = true
}
```

**Problem:** Same issue as above — pricing nudge after 3 clips with no cancellation on `onDisappear`.

**Fix:** Same pattern — cancel on disappear.

---

## HIGH Issues

### [HIGH] VideoStore.swift — `@MainActor` conformance but no explicit actor isolation

```swift
final class VideoStore: ObservableObject {
    static let shared = VideoStore()
    @Published private(set) var entries: [VideoEntry] = []
```

**Problem:** VideoStore is `@MainActor` but the singleton is accessed from `CalendarView` (which is `@MainActor`), `MonthCard` (struct view), `TrimView`, `PlaybackView`, and others. Since all SwiftUI Views run on main actor by default, this mostly works. However:

1. `VideoEntry.videoURL` accesses `VideoStore.shared.videosDirectory` — this is a cross-actor access since VideoEntry is a struct used everywhere.
2. `ThumbnailGenerator.shared` is also a singleton but not marked `@MainActor` — it's accessed from within `VideoStore.addVideo` which IS `@MainActor`.

**Fix:** Add `@MainActor` to ThumbnailGenerator, or ensure all cross-actor accesses are intentional.

---

### [HIGH] AIHighlightsView.swift:139-143 — Fire-and-forget Task from .sheet binding

```swift
.sheet(item: Binding(
    get: { reelURL.map { ReelSheetItem(url: $0) } },
    set: { reelURL = $0?.url }
)) { item in
    HighlightReelView(reelURL: item.url) {
        reelURL = nil
    }
}
```

**Problem:** `HighlightReelView` uses `AVPlayer` with `.onAppear` that creates and starts a player. If the sheet is dismissed while playback is active, resources may not be cleaned up promptly (though `onDisappear` does pause the player). More critically, `HighlightReelView` stores `player` as a local in `.onAppear` rather than as @State, so it recreates on every appear.

---

### [HIGH] MonthCard.swift:48-51 — Force unwrap in view computed property

```swift
private var monthName: String {
    let formatter = DateFormatter()
    formatter.dateFormat = "MMMM"
    var components = DateComponents()
    components.month = month
    components.year = year
    components.day = 1
    guard let date = Calendar.current.date(from: components) else { return "" }
    return formatter.string(from: date)
}
```

**Problem:** `monthName` recomputes on every access. It's called in `MonthCard`'s body. This is called 12 times (once per month) in the `monthGrid`. Minor inefficiency — the date formatter is created each time.

**Fix:** Cache the DateFormatter as a static, or compute monthName once per card.

---

### [HIGH] CalendarView.swift:193-212 — `.task(id:)` and tab switching semantics

```swift
.task(id: exportMonth) {
    guard isExporting, exportMonth > 0, exportYear > 0 else { return }
    do {
        let outputURL = try await ExportService.shared.exportMonthClips(...)
        ...
    } catch {
        isExporting = false
        exportError = error.localizedDescription
    }
}
```

**Problem:** This `.task(id:)` uses `exportMonth` as the id. The task fires when `exportMonth` CHANGES. However:

1. If the export succeeds, `exportMonth` is NOT reset to 0 — so a subsequent call to `exportThisMonth()` with the same month (e.g., user exports March twice in different years) won't trigger a new task since the id didn't change.
2. When the user switches tabs, CalendarView stays in memory (TabView keeps all tabs alive), so the task is NOT cancelled. The export continues in background.
3. When the user switches BACK to calendar tab, if the export finished while away, `isExporting` is still true but `exportMonth` hasn't changed — so the `.task` won't re-fire.

**Fix:** Reset `exportMonth = 0` after export completes, or use a UUID-based task id that's always unique.

---

### [HIGH] PlaybackView.swift — notificationToken stored but not explicitly cancelled on all paths

```swift
@State private var notificationToken: NSObjectProtocol?
...
notificationToken = NotificationCenter.default.addObserver(...)
...
.onDisappear {
    player?.pause()
    if let token = notificationToken {
        NotificationCenter.default.removeObserver(token)
        notificationToken = nil
    }
    ...
}
```

**Problem:** Looks correct, but `notificationToken` is only removed in `.onDisappear`. If `showTrim` fullScreenCover is presented (via `showTrim = true`), the PlaybackView's `onDisappear` does fire (since it's covered), but the player continues to exist. When the trim sheet is dismissed, `.onAppear` is called again which calls `setupPlayer()` AGAIN — creating a SECOND notification observer without removing the first.

**Fix:** Cancel and nil out the token in `setupPlayer()` before adding a new one:
```swift
if let token = notificationToken {
    NotificationCenter.default.removeObserver(token)
    notificationToken = nil
}
notificationToken = NotificationCenter.default.addObserver(...)
```

---

## MEDIUM Issues

### [MEDIUM] VideoStore.swift:166-170 — `_cachedOnThisDayEntries` invalidated but not thread-safe

```swift
private var _cachedOnThisDayEntries: [VideoEntry]?
private var _onThisDayCacheEntryCount: Int = 0

private func invalidateOnThisDayCache() {
    _cachedOnThisDayEntries = nil
}
```

**Problem:** `invalidateOnThisDayCache()` is called from `@MainActor` methods (`addVideo`, `deleteEntry`, `trimClip`, `updateEntry`, `restoreEntry`, `updateTitle`, `toggleLock`). But `onThisDayEntries()` itself is not marked `@MainActor` and reads the cached values. Since VideoStore is `@MainActor`, all these are fine, but the cache invalidation pattern is fragile.

**Fix:** Mark `onThisDayEntries()` as `@MainActor` to match the rest.

---

### [MEDIUM] TrimView.swift — periodicObserver not cleaned up on all paths

```swift
private var periodicObserver: Any?
...
periodicObserver = player.addPeriodicTimeObserver(...)
...
.onDisappear {
    player?.pause()
    if let observer = periodicObserver {
        player?.removeTimeObserver(observer)
        periodicObserver = nil
    }
    ...
}
```

**Problem:** Looks correct, but if `setupPlayer()` crashes or the player is nil, `periodicObserver` would never be set but `onDisappear` would still run (safe). The issue is that `setupPlayer()` uses a Task (`setupTask`) to load duration, but the periodic observer is added synchronously. If the Task is cancelled before completion, the observer is still added (since it's after the Task block). This is actually fine but the code structure is confusing.

---

### [MEDIUM] AdaptiveCompressionService — `compressEntry` not @MainActor but accesses VideoStore.singleton

```swift
func compressEntry(_ entry: VideoEntry) async -> Int64 {
    let originalURL = entry.videoURL  // accesses VideoStore.shared.videosDirectory
```

**Problem:** `compressEntry` is not `@MainActor` but accesses `VideoStore.shared` which IS `@MainActor`. This works because Swift automatically hops to the main actor for singleton access, but it's implicit and could break in Swift 6 strict concurrency if not properly annotated.

---

### [MEDIUM] DeepAnalysisService — uses DispatchQueue but not @MainActor isolated

```swift
private let analysisQueue = DispatchQueue(label: "com.blink.deepanalysis", qos: .utility)
```

**Problem:** `analysisQueue` is used nowhere in the code I can see. The actual analysis is done via async/await with `withCheckedThrowingContinuation` inside Vision request handlers. The `DispatchQueue` is dead code. More importantly, `DeepAnalysisService` itself is not `@MainActor` but is accessed from `DeepAnalysisView` which is a SwiftUI View (main actor). Since all the analysis methods are async and don't directly mutate `@Published` properties (they do it via `analyzedEntries[entry.id] = analysis` which is a write), this could be a data race.

**Fix:** Either remove the unused `analysisQueue` or mark `DeepAnalysisService` as `@MainActor`.

---

### [MEDIUM] CalendarView.swift — `effectiveShowAIHighlights` computed property reads @State every time

```swift
private var effectiveShowAIHighlights: Bool {
    showHighlightsBinding?.wrappedValue ?? showAIHighlights
}
```

**Problem:** This is a computed property (no caching) that reads `showHighlightsBinding?.wrappedValue` or `showAIHighlights` every time it's accessed. It's accessed in `aiHighlightsBinding` which is used in `.fullScreenCover(isPresented: aiHighlightsBinding)`. The fullScreenCover binding is evaluated on every frame, so this recomputes every time. Minor but unnecessary.

---

### [MEDIUM] SceneEntriesView — entries computed property called in body

```swift
var entries: [VideoEntry] {
    let ids = analysisService.entriesForScene(scene)
    return videoStore.entries.filter { ids.contains($0.id) }
}

var body: some View {
    ...
    ForEach(entries) { entry in  // recomputes on every body evaluation
```

**Problem:** `entries` recomputes on every body evaluation. It filters `videoStore.entries` (all entries) and does a `contains` check on `ids` (which is a `[UUID]` array, not a Set — O(n) lookup). With many entries this could be slow.

**Fix:** Use a Set for `ids`, or cache entries in @State.

---

### [MEDIUM] OnThisDayView — `groupedByYear` and `similarMoodGroups` recompute in body

```swift
private var groupedByYear: [YearGroup] { ... }  // called in body
private var similarMoodEntries: [VideoEntry] { ... }  // called in body
private var similarMoodGroups: [SimilarMoodGroup] { ... }  // called in body
```

**Problem:** All these computed properties iterate over `entries` on every body evaluation. With many clips and multiple years, this could cause jank when navigating "On This Day".

---

## LOW Issues

### [LOW] StorageDashboardView — Task variables shadowing in `.onDisappear`

```swift
.onDisappear {
    deduplicationTask?.cancel()
    compressionTask?.cancel()
    duplicateDeleteTask?.cancel()
    sheetRefreshTask?.cancel()
}
```

**Problem:** These are `@State private var` Task properties. When `.onDisappear` fires, it cancels them but does NOT nil them out. If the view re-appears, the old Task objects are still referenced (though cancelled). The new tasks replace them. Minor leak of Task objects.

**Fix:** Set to `nil` after cancelling.

---

### [LOW] CalendarView — `clipsThisYear` recomputes via `videoStore.entriesForYear`

```swift
private var clipsThisYear: Int {
    videoStore.entriesForYear(selectedYear).count
}
```

**Problem:** Called multiple times in body (yearSummaryCard, monthGrid toolbar, empty state check). Each time it filters all entries. With many clips this is O(n). Minor since clip counts are typically small.

---

### [LOW] VideoEntry — `dayOfYear` force unwrap with `?? 0`

```swift
var dayOfYear: Int {
    Calendar.current.ordinality(of: .day, in: .year, for: date) ?? 0
}
```

**Problem:** `ordinality` returns `Int?` and the fallback is 0 which could be a valid day 1. But since day-of-year is always >= 1, this is fine.

---

### [LOW] PrivacyService — biometricType computed property creates LAContext on every access

```swift
var biometricType: BiometricType {
    let context = LAContext()
    var error: NSError?
    guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
        return .none
    }
    ...
}
```

**Problem:** `biometricType` is a computed property accessed from SettingsView's body. It creates a new LAContext on every access. While LAContext is lightweight, this is called in the SettingsView body which re-evaluates on every state change.

**Fix:** Cache the result since biometry type doesn't change at runtime.

---

## Already-Fixed Issues (Confirmed)

### ✅ NaN% Display — Fixed

CalendarView.swift line 303:
```swift
return max(1, calendar.dateComponents([.day], from: startOfYear, to: now).day ?? 1)
```

`daysElapsedThisYear` is guaranteed >= 1, so `CGFloat(clipsThisYear) / CGFloat(daysElapsedThisYear)` can never be NaN or divide-by-zero.

---

### ✅ Round 3 Fixes — Verified

- `VideoStore.trimClip` now properly handles `saveAsNew = false` by preserving the original ID
- `ContentView` uses `onChange(of:)` with new SwiftUI 5.0 syntax (two-parameter closure)
- `PrivacyService.unlockWithBiometrics` is properly marked `@MainActor`
- `CalendarView` properly passes deep link bindings
- Task cancellation in `StorageDashboardView.onDisappear` is present

---

## Summary

| Severity | Count |
|----------|-------|
| CRITICAL | 2 |
| HIGH | 5 |
| MEDIUM | 8 |
| LOW | 5 |

**Top 3 Priority Fixes:**
1. **StorageDashboardView compressionSection** — computed property with expensive O(n) call in view body
2. **ContentView asyncAfter** — two fire-and-forget dispatches with no cancellation
3. **CalendarView .task(id:)** — export task won't re-fire if month/year same as previous

---

*End of Audit Round 4*
