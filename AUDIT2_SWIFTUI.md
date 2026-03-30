# SwiftUI Audit — Phase 4 Post-Fix (Round 2)

**Auditor:** SwiftUI Pedant Agent
**Date:** 2026-03-30
**Scope:** Blink iOS codebase — Phase4-committed code (PrivacyService, VideoStore, AdaptiveCompressionService, YearInReview)
**Previous issues:** 75 (Phase 1 audit)
**Status:** Many fixed. New and remaining issues documented below.

---

## Executive Summary

Phase4 fixes were substantial. `JSONEncoder().encode(privacy)!` is gone (PrivacyService refactored to Keychain). The `progressTimer` leak is fixed. Most Task fire-and-forget patterns are resolved. However, **new issues** surfaced in Phase4 code and **some old issues remain**.

---

## ✅ FIXED (Previously Critical)

| # | File | Issue | Status |
|---|------|-------|--------|
| 1 | PrivacyService.swift | `JSONEncoder().encode(privacy)!` force-unwrap | ✅ FIXED — Keychain-based storage |
| 2 | PrivacyService.swift | `try! JSONDecoder().decode(PrivacySettings.self, from: data)` | ✅ FIXED — No longer uses JSON encode/decode for settings |
| 3 | YearInReviewCompilationView.swift | `progressTimer` Timer leak (not stored, not cancelled) | ✅ FIXED — Now `@State private var progressTimer: Timer?` with `.onDisappear { progressTimer?.invalidate() }` |
| 4 | ~30 fire-and-forget Tasks | Not stored/cancelled | ✅ MOSTLY FIXED — `.task {}` and stored Task variables now used throughout |
| 5 | AdaptiveCompressionService.swift | `compatibilityCapability!` force-unwrap | ✅ FIXED — No longer present in current code |
| 6 | AdaptiveCompressionService.swift | `selectedTier!` force-unwrap | ✅ FIXED — No longer present in current code |

---

## CRITICAL

### 1. TrimView.swift — Periodic Time Observer Never Removed
**Lines 270–275** (setupPlayer)

```swift
player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.05, preferredTimescale: 600), queue: .main) { time in
    let secs = time.seconds
    self.currentTime = secs
    if secs >= self.endTime - 0.1 {
        self.seekToStart()
    }
}
```

**Problem:** `AVPlayer.addPeriodicTimeObserver` returns an `Any` observer token that **must** be retained and passed to `removeTimeObserver(_:)` when done. The code adds the observer but never stores the token or removes it. When the view disappears and `player = nil` is set, the player retains the observer, causing:
- Memory leak (closure captures `self`)
- Potential crash if callback fires after view deallocation

**Fix:** Store the observer token and call `player?.removeTimeObserver(token)` in `onDisappear`, before setting player to nil.

```swift
@State private var player: AVPlayer?
@State private var timeObserverToken: Any?

// In setupPlayer():
timeObserverToken = player.addPeriodicTimeObserver(...)

// In onDisappear:
if let token = timeObserverToken {
    player?.removeTimeObserver(token)
    timeObserverToken = nil
}
player?.pause()
player = nil
setupTask?.cancel()
saveTask?.cancel()
```

---

### 2. PlaybackView.swift — Export Task Not Cancelled on Disappear
**Lines 29–30**

```swift
@State private var exportTask: Task<Void, Never>?
```

**Problem:** `exportClip()` stores `exportTask` but `onDisappear` only does `exportTask?.cancel()`. If `exportClip()` is in flight when the view disappears, the task is cancelled but the in-progress `videoStore.exportToCameraRoll` operation continues in the background (the cancel only cancels the Task wrapper, not the underlying async work). The task should be fully handled.

**Fix:** Add explicit cancellation check in `onDisappear`:
```swift
.onDisappear {
    player?.pause()
    player = nil
    exportTask?.cancel()
    exportTask = nil  // Ensure no stale reference
}
```

---

## HIGH

### 3. PlaybackView.swift — Notification Observer Never Removed
**Lines 253–258**

```swift
NotificationCenter.default.addObserver(
    forName: .AVPlayerItemDidPlayToEndTime,
    object: player.currentItem,
    queue: .main
) { _ in
    player.seek(to: .zero)
    player.play()
}
```

**Problem:** Classic `NotificationCenter` observer leak. The observer is added to `NotificationCenter.default` but never removed. Since `player` is `@State` (reference type), the closure captures `self` (via `player`). This observer lives forever in the notification center even after the view is deallocated.

**Fix:** Store the observer token (returned by `addObserver`) and remove it in `onDisappear`:
```swift
@State private var player: AVPlayer?
@State private var endTimeObserverToken: NSObjectProtocol?

// In setupPlayer():
endTimeObserverToken = NotificationCenter.default.addObserver(...)

// In onDisappear:
if let token = endTimeObserverToken {
    NotificationCenter.default.removeObserver(token)
    endTimeObserverToken = nil
}
```

---

### 4. StorageDashboardView.swift — Computed Property Called in View Body Without Memoization
**Lines 253–255**

```swift
let candidates = compressionService.analyzeCompressionCandidates(entries: videoStore.entries)
if !candidates.isEmpty {
    HStack {
```

**Problem:** `analyzeCompressionCandidates` iterates all entries, performs date comparisons, and checks a Set for every entry. This is called on **every body evaluation** because it's a `let` in the view body (not `@State`). If the view recomputes for any reason (parent change, state update), this expensive iteration runs repeatedly.

**Fix:** Cache as `@State private var compressionCandidates: [VideoEntry] = []` and update via `.task {}` or `.onChange(of: videoStore.entries)`.

---

### 5. TrimView.swift — `endTime = min(startTime + 30, duration)` — Invalid Duration
**Lines 285–287**

```swift
let d = try? await asset.load(.duration).seconds
await MainActor.run {
    self.duration = d ?? entry.duration
    self.endTime = min(self.duration, 30)
}
```

**Problem:** If `d` is nil (asset duration unavailable) and `entry.duration` is also 0 or invalid, `duration` becomes 0. Then `endTime = min(0, 30) = 0`. The trim range becomes empty and the clip cannot be trimmed. While it won't crash, it silently produces a broken UX state.

**Fix:** Guard against zero duration:
```swift
self.duration = d ?? entry.duration
if self.duration <= 0 {
    self.duration = 1.0  // Prevent zero/negative duration
}
self.endTime = min(self.duration, 30)
```

---

## MEDIUM

### 6. ContentView.swift — Multiple `.onChange` Without Debouncing
**Lines 63–83**

```swift
.onChange(of: scenePhase) { oldPhase, newPhase in
    if newPhase == .background && oldPhase == .active { ... }
    if newPhase == .active && wasInBackground { ... Task { await privacy.unlockWithBiometrics() } }
}

.onChange(of: selectedTab) { _, newTab in
    HapticService.shared.selectionChanged()
    if newTab == .calendar { ... DispatchQueue.main.asyncAfter(deadline: ...) }
}
```

**Problem:** Two `.onChange` handlers that fire synchronously. The `scenePhase` change can fire rapidly (background → active → background quickly). The `selectedTab` change triggers both a haptic and a delayed `DispatchQueue.main.asyncAfter` for pricing. No debouncing means rapid tab switching could queue multiple async operations.

**Fix:** Add debouncing for `selectedTab`:
```swift
.onChange(of: selectedTab) { oldTab, newTab in
    HapticService.shared.selectionChanged()
    if newTab == .calendar {
        pricingDebounceTask?.cancel()
        pricingDebounceTask = Task {
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            if !Task.isCancelled {
                showPricing = true
            }
        }
    }
}
```

---

### 7. RecordView.swift — `.onChange` Without Debouncing
**Lines 77–82**

```swift
.onChange(of: cameraService.recordedDuration) { oldValue, newValue in
    if cameraService.isRecording {
        let remaining = maxDuration - newValue
        if remaining > 0 && remaining <= 5 && !hasWarnedDuration {
            hasWarnedDuration = true
            HapticService.shared.durationWarning()
        }
    }
}
```

**Problem:** `recordedDuration` updates at ~0.1s intervals (from camera session). This `.onChange` fires 10 times/second for 30 seconds of recording. While the body is lightweight, this pattern is fragile — adding any computation to this handler will degrade performance.

**Fix:** This specific handler is simple enough that debouncing isn't critical, but flag for future-proofing. The `hasWarnedDuration` guard prevents duplicate warnings, which is good.

---

### 8. AIHighlightsView.swift — `yearInsights()` Recomputes on Every Body Evaluation
**Line 160**

```swift
var yearInsightsHeader: some View {
    let insights = AIHighlightsService.shared.yearInsights(entries: entries)
```

**Problem:** `yearInsights(entries:)` iterates all entries, groups by month/weekday, computes averages — all synchronously on the main thread. This runs on **every body evaluation** because it's a `let` in the computed property body. For large entry lists, this causes measurable main-thread blocking.

**Fix:** Cache as `@State private var cachedInsights: [String] = []` and populate in `.task {}` or via `@StateObject` on the service.

---

### 9. VideoStore.swift — `loadEntries()` File I/O on Main Thread
**Lines 30–31** (in `init`)

```swift
func loadEntries() {
    guard fileManager.fileExists(atPath: entriesFile.path) else { entries = []; return }
    do {
        let data = try Data(contentsOf: entriesFile)  // Blocking I/O on main thread
        entries = try JSONDecoder().decode([VideoEntry].self, from: data)
```

**Problem:** `loadEntries()` is called from `init()` synchronously on whatever thread creates `VideoStore.shared`. If that's the main thread (likely), file I/O blocks the UI during app launch. On large entry files, this causes jank.

**Fix:** Make `loadEntries()` async and call from `.task {}` in the first view that uses `VideoStore`, or use `Task.detached` to move off the main thread:
```swift
private func loadEntries() {
    Task.detached { [weak self] in
        guard let self = self else { return }
        // Load from disk on background thread
        let entries = await self.loadEntriesFromDisk()
        await MainActor.run {
            self.entries = entries
        }
    }
}
```

---

### 10. SocialShareSheet.swift — `DispatchQueue.main.asyncAfter` Not Using Swift Concurrency
**Lines 174–177**

```swift
DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
    showCopied = false
    isCreatingLink = false
}
```

**Problem:** Uses legacy GCD `DispatchQueue.main.asyncAfter` instead of Swift `Task.sleep`. This pattern is fine in practice but inconsistent with the rest of the codebase which uses `Task`.

**Fix:** Replace with `Task.sleep`:
```swift
Task {
    try? await Task.sleep(nanoseconds: 2_000_000_000)
    await MainActor.run {
        showCopied = false
        isCreatingLink = false
    }
}
```

---

### 11. PrivacyLockView.swift — `UIApplication.shared` Force-Unwrap
**Line 15**

```swift
Button("Open Settings") {
    if let url = URL(string: UIApplication.openSettingsURLString) {
        UIApplication.shared.open(url)  // Force-unwrap on shared
    }
}
```

**Problem:** `UIApplication.shared` is technically force-unwrapped. In normal iOS app contexts this never fails, but it could crash in extensions or headless environments.

**Fix:** Use `await UIApplication.shared.open(url)` — this is the modern async API that handles the optional safely.

---

## LOW

### 12. CalendarView.swift — `?? 1` Fallback Could Mask Edge Cases
**Lines 44–46**

```swift
return max(1, calendar.dateComponents([.day], from: startOfYear, to: now).day ?? 1)
```

**Problem:** If `.day` returns nil (shouldn't happen with valid dates), falls back to 1. For January 1st of the current year, `daysElapsedThisYear` would be 1. This is arguably correct behavior, but the `?? 1` masks an unexpected nil that might indicate a deeper issue.

**Fix:** Use `?? 0` and `max(1, ...)` handles the edge case explicitly:
```swift
return max(1, calendar.dateComponents([.day], from: startOfYear, to: now).day ?? 0)
```

---

### 13. SocialShareService.swift — Static Constant URL Force-Unwrapped
**Line 27**

```swift
private static let fallbackShareURL = URL(string: "blink://share")!
```

**Problem:** Static force-unwrap at class initialization. If the string literal were ever accidentally changed to an invalid URL, the app would crash at launch. Very low risk as-is.

**Fix:** Not critical, but could use a computed property with a guard instead of a stored constant force-unwrap.

---

## Swift 6 Concurrency Observations

### Properly Handled ✅

- `PrivacyService.unlockWithBiometrics()` correctly uses `@MainActor` — both the method and the `authenticateWithBiometrics()` it calls are `@MainActor`, so actor isolation is maintained.
- `VideoStore` methods that modify `@Published` state are all `@MainActor` (`addVideo`, `deleteEntry`, `updateTitle`, `trimClip`, `exportToCameraRoll`).
- `StorageDashboardService.refresh()` is `@MainActor` and correctly awaits service methods from other actors.
- `DeduplicationService.findDuplicates()` is `@MainActor`.

### Flag for Future Review ⚠️

- `CaptionService` is not `@MainActor` but uses `SFSpeechRecognizer` on a `DispatchQueue`. This predates Phase4 and was not in scope for this round.

---

## Actor Isolation Summary

| Service | Actor Type | Status |
|---------|-----------|--------|
| VideoStore | `@MainActor` class | ✅ Correct |
| PrivacyService | `@MainActor` class | ✅ Correct |
| AdaptiveCompressionService | Non-isolated ObservableObject | ⚠️ Acceptable (read-only published props) |
| DeduplicationService | `@MainActor` class | ✅ Correct |
| StorageDashboardService | `@MainActor` class | ✅ Correct |
| AIHighlightsService | Non-isolated ObservableObject | ⚠️ Acceptable (read-only) |
| CaptionService | Non-isolated | ⚠️ Pre-existing, not in Phase4 scope |

---

## Recommendations Priority

1. **IMMEDIATE (CRITICAL):** Fix TrimView time observer leak (#1) and PlaybackView notification observer leak (#3)
2. **SOON (HIGH):** Fix StorageDashboardView computed property (#4), TrimView duration guard (#5)
3. **NEXT SPRINT (MEDIUM):** VideoStore async loadEntries (#9), debounce `.onChange` handlers (#6), AIHighlightsView caching (#8)
4. **LOW PRIORITY:** Cleanup `DispatchQueue.main.asyncAfter` (#10), UIApplication.shared (#11)

---

## Files in Scope This Round

- Blink/Services/PrivacyService.swift
- Blink/Services/VideoStore.swift
- Blink/Services/AdaptiveCompressionService.swift
- Blink/Services/AIHighlightsService.swift
- Blink/Services/CaptionService.swift
- Blink/Services/CameraService.swift
- Blink/Services/DeepAnalysisService.swift
- Blink/Services/DeduplicationService.swift
- Blink/Services/StorageDashboardService.swift
- Blink/Services/SocialShareService.swift
- Blink/Services/ThumbnailGenerator.swift
- Blink/Services/ExportService.swift
- Blink/Views/YearInReviewCompilationView.swift
- Blink/Views/YearInReviewView.swift
- Blink/Views/CalendarView.swift
- Blink/Views/RecordView.swift
- Blink/Views/PlaybackView.swift
- Blink/Views/TrimView.swift
- Blink/Views/SearchView.swift
- Blink/Views/PrivacyLockView.swift
- Blink/Views/AIHighlightsView.swift
- Blink/Views/ContentView.swift
- Blink/Views/SocialShareSheet.swift
- Blink/Views/StorageDashboardView.swift
- Blink/Views/DeepAnalysisView.swift
- Blink/Views/PublicFeedView.swift
- Blink/Views/CommunityView.swift
- Blink/Views/OnboardingView.swift
- Blink/Views/OnThisDayView.swift
- Blink/Views/MonthBrowserView.swift
- Blink/App/ContentView.swift

---

*End of Audit — SwiftUI Pedant Agent*
