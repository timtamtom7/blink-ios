# Blink iOS — Final SwiftUI/Swift 6 Concurrency Audit

**Auditor:** SwiftUI Pedant Agent  
**Scope:** Full codebase at `/Users/mauriello/.openclaw/workspace/projects/blink-ios/`  
**Focus:** Force unwraps, data flow, `@State`/`@Binding`, Swift 6 concurrency readiness  
**Note:** All `[weak self]` patterns in existing code are generally correct; only problematic usages flagged below.

---

## CRITICAL

**[CRITICAL] `Blink/Views/AIHighlightsView.swift:523` — Unremoved notification observer, captured player, crash on dismiss**

```swift
// HighlightPlaybackView.setupPlayer()
NotificationCenter.default.addObserver(
    forName: .AVPlayerItemDidPlayToEndTime,
    object: playerItem,
    queue: .main
) { _ in
    player.seek(to: seekTime)
    player.play()
}
```

The observer is **never stored as a token** and **never removed**. The closure captures `player` (a `@State` local to `setupPlayer()`) strongly. `onDisappear` only calls `player?.pause()` — it does not invalidate the observer.

If the clip loops and the view is dismissed, the notification fires against a paused, potentially deallocated player instance. The closure also captures `seekTime` and `playerItem`. **Fix:** Store the token, call `NotificationCenter.default.removeObserver(token)` in `onDisappear`, and guard the seek/play with a `player != nil` check.

---

**[CRITICAL] `Blink/Views/TrimView.swift` — `addPeriodicTimeObserver` callback mutates @State off MainActor**

```swift
periodicObserver = player.addPeriodicTimeObserver(
    forInterval: CMTime(seconds: 0.05, preferredTimescale: 600),
    queue: .main  // ← documentation promise; callback may still fire on render queue
) { time in
    let secs = time.seconds
    self.currentTime = secs  // ← @State mutation on unknown queue
    if secs >= self.endTime - 0.1 { self.seekToStart() }
}
```

`AVPlayer.addPeriodicTimeObserver` documents that its callback fires on the specified queue, but iOS makes no guarantee the queue is `@MainActor`-isolated. Directly mutating `@State private var currentTime: Double` from this callback is a **data race**. Under Swift 6 strict concurrency this is a crash. All mutations inside the callback (`currentTime`, `endTime`, `seekToStart()`) must be wrapped in `Task { @MainActor in { ... } }` or dispatched via `MainActor.run`.

Same pattern exists in `PlaybackView.setupPlayer()` — `periodicObserver` callback mutates `@State private var currentTime` in `TrimView`. The notification observer in `PlaybackView` uses `.main` queue and `NotificationCenter` guarantees main-thread delivery, so that's safe, but the periodic observer pattern is not.

---

## HIGH

**[HIGH] `Blink/App/ContentView.swift:136` — `onChange(of: scenePhase)` calls async function without `await`**

```swift
.onChange(of: scenePhase) { oldPhase, newPhase in
    if newPhase == .active && wasInBackground {
        Task {
            await PrivacyService.shared.unlockWithBiometrics()
        }
        wasInBackground = false
    } else if newPhase == .background {
        wasInBackground = true
    }
}
```

`unlockWithBiometrics()` is correctly `await`ed inside a `Task`, but `wasInBackground = false` runs synchronously before the async authentication completes. If the user dismisses the lock view immediately after unlock succeeds, the timing is still correct. However, the `PrivacyService.shared.unlockWithBiometrics()` call itself (line 138) is NOT awaited — it's fire-and-forget. If authentication fails and `isAppLocked` stays `true`, the UI state may not reflect this until the next cycle. The fix: `await Task { ... }` or make the onChange async and properly await.

---

**[HIGH] `Blink/Services/CameraService.swift:143–165` — `DispatchQueue.main.async` mixes GCD with Swift 6 structured concurrency in delegate callback**

```swift
func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL,
                from connections: [AVCaptureConnection], error: Error?) {
    DispatchQueue.main.async {   // ← GCD, not Task { @MainActor in }
        self.isRecording = false
        self.recordedDuration = 0
        self.stopDurationTimer()
    }
    // ...
    Task {
        let success = await VideoStore.shared.addVideo(at: outputFileURL)
        if success {
            await MainActor.run {
                SubscriptionService.shared.recordClipRecorded()
            }
        } else {
            await MainActor.run { self.error = .clipSaveFailed }
        }
    }
}
```

This mixes `DispatchQueue.main.async` (GCD) for state resets with `Task { @MainActor.run }` (structured concurrency) for the save path. Under Swift 6, `@MainActor` isolation on `CameraService` means `self` is already isolated; calling `self.stopDurationTimer()` directly (no `self.` needed under `@MainActor`) would be cleaner. The GCD dispatch is unnecessary and inconsistent. Additionally, `VideoStore.shared.addVideo` is `async` but `CameraService` is `@MainActor`, so calling it from a nonisolated delegate callback is correct only because it's `await`ed. Consolidate all main-thread work into `Task { @MainActor in }`.

---

**[HIGH] `Blink/Views/PlaybackView.swift` — `fullScreenCover(item:)` accesses entry directly; stale data if entry deleted**

```swift
.fullScreenCover(item: $deepLinkShareEntry) { entry in
    PlaybackView(entry: entry, onDelete: {
        videoStore.deleteEntry(entry)    // ← entry captured at closure creation time
        deepLinkShareEntry = nil
    }, onTrim: { updatedEntry in
        videoStore.updateEntry(updatedEntry)
        deepLinkShareEntry = updatedEntry
    })
}
```

If the user has the `PlaybackView` open and simultaneously the entry is deleted from another view (e.g., the calendar's month card), the `entry` captured in the closure is now stale. The `onDelete` calls `videoStore.deleteEntry(entry)` with the stale reference — if `VideoStore` uses `id` for deletion lookup this is fine, but if it mutates the entry in place this is a bug. More critically, `PlaybackView` reads `currentEntry.videoURL` on every render via a computed property that re-searches `videoStore.entries`. If the entry is deleted, `videoStore.entries.first { $0.id == entry.id }` returns `nil` and falls back to `entry` (the parameter), which may now be semantically invalid. **Fix:** Make `currentEntry` an `@State` var initialized once in `onAppear`, not a computed property.

---

**[HIGH] `Blink/Views/PrivacyLockView.swift:185` — Fire-and-forget animation dispatches never cancelled**

```swift
private func shakeAnimation() {
    let values: [CGFloat] = [-10, 10, -8, 8, -5, 5, -3, 3, 0]
    let stepDuration = 0.5 / Double(values.count - 1)

    for (i, v) in values.enumerated() {
        DispatchQueue.main.asyncAfter(deadline: .now() + stepDuration * Double(i)) {
            dotsShakeOffset = v   // ← runs even after view is dismissed
        }
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + totalDuration) {
        dotsShakeOffset = 0
    }
}
```

`shakeAnimation()` is called when a wrong passcode is entered. All 9 `asyncAfter` dispatches fire regardless of whether the view is still on screen. If the user enters a wrong passcode and immediately dismisses the lock view, these dispatches fire into dead UI state. **Fix:** Store the pending dispatches as `Int` tasks and cancel them in `onDisappear`, or use `withAnimation` with explicit `transaction`.

---

**[HIGH] `Blink/Views/CalendarView.swift` — `fullScreenCover(isPresented: aiHighlightsBinding)` recreates `Binding` on every read**

```swift
private var aiHighlightsBinding: Binding<Bool> {
    Binding(
        get: { effectiveShowAIHighlights },
        set: { newValue in
            if showHighlightsBinding != nil {
                showHighlightsBinding?.wrappedValue = newValue
            } else {
                showAIHighlights = newValue
            }
        }
    )
}
```

`aiHighlightsBinding` is a **computed property** — each access creates a **new `Binding` struct**. When used in `.fullScreenCover(isPresented: aiHighlightsBinding)`, SwiftUI may call `get` and `set` repeatedly. While `Binding` is a value type and the logic is technically sound, recomputing the `Binding` on every access is wasteful and fragile. This is particularly problematic if SwiftUI stores the `Binding` reference internally and calls `get` on layout passes. **Fix:** Cache the binding as `@State private var aiHighlightsBindingValue: Binding<Bool>` computed once in `init`.

---

## MEDIUM

**[MEDIUM] `Blink/Services/VideoStore.swift:75` — `url.lastPathComponent` has no guard for empty path**

```swift
let thumbnailFilename = await ThumbnailGenerator.shared.generateThumbnail(
    for: url, videoFilename: url.lastPathComponent  // ← crash if url is file:///
)
let entry = VideoEntry(
    id: UUID(),
    date: Date(),
    filename: url.lastPathComponent,
    duration: duration ?? 0,
    thumbnailFilename: thumbnailFilename
)
```

If `url` is malformed (e.g., `file:///`), `url.lastPathComponent` returns an empty string, creating a `VideoEntry` with an empty `filename`. This would make `videoURL` return an invalid URL. The subsequent `videoStore.appendEntry(entry)` would save this invalid entry to disk. Guard with `guard !url.lastPathComponent.isEmpty else { return nil }`.

---

**[MEDIUM] `Blink/Views/CalendarView.swift:exportTrigger` — Race condition on rapid successive calls**

```swift
private func exportThisMonth() {
    exportMonth = currentMonth
    exportYear = currentYear
    exportTrigger += 1   // ← cancels previous .task
    isExporting = true
    exportProgress = 0
}

.task(id: exportTrigger) {
    guard isExporting, exportMonth > 0, exportYear > 0 else { return }
    // ...
    isExporting = false   // ← only set on success/error path
    // ...
}
```

If the user taps "Export This Month" multiple times in rapid succession (before the previous task's `isExporting = false` executes), each call increments `exportTrigger`, cancelling the previous task. But `isExporting` may still be `true` when the new task starts (the old task hasn't reached `isExporting = false` yet). The guard `guard isExporting` passes. The new task runs alongside the remnants of the old task. **Fix:** Set `isExporting = false` at the start of `exportThisMonth()` and/or use a `@State private var isExportingTask: Task<Void, Never>?` to cancel explicitly.

---

**[MEDIUM] `Blink/Services/DeepAnalysisService.swift:166` — `VNImageRequestHandler.perform` fires on unspecified queue**

```swift
private func classifyScene(_ image: UIImage) async throws -> SceneClassification {
    return try await withCheckedThrowingContinuation { continuation in
        let request = VNClassifyImageRequest { request, error in
            // ...
            continuation.resume(returning: SceneClassification(...))
        }
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try? handler.perform([request])   // ← may fail silently; continuation never resumed
    }
}
```

If `handler.perform([request])` throws (e.g., invalid image format), the continuation is **never resumed**, causing the task to hang forever. The `try?` silently swallows the error. This same pattern exists in `detectFaces`. **Fix:** Use `withCheckedThrowingContinuation` with `resume(throwing:)` in the error path, or use `withCheckedThrowingContinuation` properly: `try await withCheckedThrowingContinuation { cont in handler.perform([request]) { cont.resume(...) } }` style with explicit error handling.

---

**[MEDIUM] `Blink/Views/RecordView.swift:220` — `maxRecordingDuration` written from main thread, read from `sessionQueue`**

```swift
// On main thread (RecordView):
cameraService.maxRecordingDuration = subscription.maxRecordingDuration

// On sessionQueue (CameraService.sessionQueue):
movieOutput.maxRecordedDuration = CMTime(seconds: maxRecordingDuration, preferredTimescale: 600)
```

`maxRecordingDuration` is a plain `var` on `CameraService` (a `@MainActor` class). Writing from main thread and reading from `sessionQueue` without synchronization is a data race. Under Swift 6 this could cause issues. **Fix:** Make `maxRecordingDuration` an `@Atomic` property or read it inside the `sessionQueue.async` block from a captured local constant.

---

**[MEDIUM] `Blink/Views/RecordView.swift:276` — `onChange(of: cameraService.recordedDuration)` reads `maxDuration` on each change**

```swift
.onChange(of: cameraService.recordedDuration) { oldValue, newValue in
    if cameraService.isRecording {
        let remaining = maxDuration - newValue  // ← maxDuration read from @State var
        if remaining > 0 && remaining <= 5 && !hasWarnedDuration {
            hasWarnedDuration = true
            HapticService.shared.durationWarning()
        }
    }
}
```

`maxDuration` is a computed property reading `subscription.maxRecordingDuration` which comes from `SubscriptionService.currentTier.maxClipDuration`. If the user upgrades mid-session (unlikely but possible), `maxDuration` changes but the `onChange` still uses the stale captured value. The haptic only fires once (`hasWarnedDuration` guard) so this is minor, but the pattern is fragile. **Fix:** Move the `remaining` calculation inside the `if cameraService.isRecording` guard with explicit reading.

---

**[MEDIUM] `Blink/Services/DeepAnalysisService.swift:71` — `analyzeEntry` accesses `@Published analyzedEntries` from multiple concurrent tasks**

```swift
func analyzeEntry(_ entry: VideoEntry) async -> EntryAnalysis? {
    // ...
    analyzedEntries[entry.id] = analysis   // ← concurrent write from multiple Task instances
}
```

`analyzeAll` runs entries in a `for` loop (sequential), but each `analyzeEntry` may spawn sub-tasks internally (frame extraction, Vision analysis). The `analyzedEntries[entry.id] = analysis` write happens on whatever actor context `analyzeEntry` completes on. Since `analyzeEntry` is not isolated to any specific actor, concurrent callers could race on writes to `analyzedEntries`. `analyzedEntries` is `@Published private(set)` on `@MainActor DeepAnalysisService`. If `analyzeEntry` is called concurrently from outside `@MainActor`, this is undefined behavior. **Fix:** Either make `analyzedEntries` access thread-safe (e.g., use a lock or actor-isolated access) or ensure all writes go through `@MainActor`-isolated methods.

---

## LOW

**[LOW] `Blink/Views/PlaybackView.swift:264` — `exportTask?.cancel()` called without waiting**

```swift
.onDisappear {
    player?.pause()
    // ...
    player = nil
    exportTask?.cancel()   // ← fire-and-forget; if task holds resources, they may not clean up in time
}
```

`exportTask` is a background export that writes to the camera roll. Cancelling it without `await` means the underlying `AVAssetExportSession` may not clean up its temp files promptly. Minor (temp files get cleaned on next launch), but worth noting. **Fix:** `if let task = exportTask { exportTask = nil; task.cancel() }` and optionally await a short delay for cleanup.

---

**[LOW] `Blink/Views/PlaybackView.swift:261` — `notificationToken` observer not invalidated if `onAppear` called twice**

```swift
.onAppear {
    editedTitle = currentEntry.title ?? ""
    setupPlayer()
}

private func setupPlayer() {
    if let oldToken = notificationToken {   // ← checks, removes old token
        NotificationCenter.default.removeObserver(oldToken)
        notificationToken = nil
    }
    // ...
}
```

If `onAppear` fires twice (e.g., navigation overlay dismissed and re-presented), `setupPlayer()` removes the old token before registering a new one. This is correct — but the previous player's `AVPlayerItemDidPlayToEndTime` notification could fire between `removeObserver` and the new registration. The old `player` has been `nil`ed so the notification handler would no-op, but the timing window exists. Use `player?.currentItem` as the `object:` parameter to scope notifications more tightly.

---

**[LOW] `Blink/Services/CloudBackupService.swift:83` — `@MainActor` class uses non-isolated `NWPathMonitor`**

```swift
@MainActor
final class CloudBackupService: ObservableObject {
    private let networkMonitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "com.blink.networkmonitor")

    private func startNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor [weak self] in
                self?.isConnected = path.status == .satisfied
            }
        }
        networkMonitor.start(queue: monitorQueue)
    }
}
```

`NWPathMonitor` runs on its own `DispatchQueue` and updates `isConnected` via `Task { @MainActor }`, which is correct. However, `monitorQueue` is a plain `DispatchQueue`, not a Swift concurrency executor. Under Swift 6 strict concurrency, `pathUpdateHandler` is a closure that can race with `@MainActor` state. The `Task { @MainActor }` wrapper handles this correctly, but the pattern is non-idiomatic. **Suggestion:** Use `withCheckedContinuation` or `AsyncStream` for the monitor.

---

**[LOW] `Blink/Views/CalendarView.swift:299` — `monthGrid` recomputes `entryMap` on every access**

```swift
private var entryMap: [Int: VideoEntry] {
    var map: [Int: VideoEntry] = [:]
    for entry in entries {
        let day = Calendar.current.component(.day, from: entry.date)
        map[day] = entry
    }
    return map
}
```

`entryMap` is a computed property called inside the `LazyVGrid`'s `ForEach`. SwiftUI re-evaluates it on every render pass (layout, animation, state change). With `entries.filter { ... }` this is O(n) per render. For a calendar with hundreds of clips, this adds up. **Fix:** Make `entryMap` a `@State private var entryMap: [Int: VideoEntry]` computed once and invalidated with `onChange(of: entries)`.

---

**[LOW] `Blink/Views/RecordView.swift:249` — `savedAnimationTask?.cancel()` in `onDisappear` but `savedAnimationTask` is local**

```swift
.onDisappear {
    cameraService.stopSession()
    countdownTask?.cancel()      // ← countdownTask captured in closure; cancellation is correct
    savedAnimationTask?.cancel() // ← savedAnimationTask captured in closure; correct
}
```

Both tasks are correctly captured in `onDisappear`. However, `savedAnimationTask` holds a reference to the view through its closure. If the user records and immediately dismisses, the task is cancelled but the `showSaved = false` animation may have been scheduled via `DispatchQueue.main.asyncAfter`. The cancellation happens synchronously, so this is fine, but `showSaved` stays `true` if the task was cancelled mid-flight. The next appearance would see `showSaved = true`. **Fix:** Reset `showSaved = false` unconditionally in `onDisappear`.

---

**[LOW] `Blink/Models/VideoEntry.swift:47` — `dayOfYear` returns 0 on calendar edge case**

```swift
var dayOfYear: Int {
    Calendar.current.ordinality(of: .day, in: .year, for: date) ?? 0
}
```

`Calendar.ordinality(of:in:for:)` returns `nil` for dates that cannot be expressed in that unit (e.g., a date with a different calendar). Returning `0` as a fallback could cause off-by-one issues in arrays indexed by day-of-year (array index 0 vs nil). **Fix:** Use `Calendar.current.ordinality(of: .day, in: .year, for: date) ?? 1` or throw an error.

---

## SUMMARY TABLE

| Severity | File | Line(s) | Issue |
|----------|------|---------|-------|
| CRITICAL | `AIHighlightsView.swift` | 523 | Unremoved NotificationCenter observer crashes on dismiss |
| CRITICAL | `TrimView.swift` | ~200 | `addPeriodicTimeObserver` mutates @State off MainActor |
| HIGH | `ContentView.swift` | 136 | `onChange` fires async without await; `wasInBackground` races |
| HIGH | `CameraService.swift` | 143–165 | GCD `DispatchQueue.main.async` mixed with `Task { @MainActor }` |
| HIGH | `PlaybackView.swift` | ~104 | `fullScreenCover` entry may be stale if deleted simultaneously |
| HIGH | `PrivacyLockView.swift` | 185 | Fire-and-forget `asyncAfter` dispatches outlive view |
| HIGH | `CalendarView.swift` | ~30 | `aiHighlightsBinding` computed property recreates Binding on every read |
| MEDIUM | `VideoStore.swift` | 75–80 | `url.lastPathComponent` unguarded; empty filename crashes downstream |
| MEDIUM | `CalendarView.swift` | ~220 | `exportTrigger` race: `isExporting = false` not reset on rapid calls |
| MEDIUM | `DeepAnalysisService.swift` | 166 | `VNImageRequestHandler.perform` silently fails; continuation hangs |
| MEDIUM | `RecordView.swift` | 220 | `maxRecordingDuration` written main / read `sessionQueue` unsynced |
| MEDIUM | `DeepAnalysisService.swift` | 71 | `analyzedEntries` concurrent write from non-isolated `analyzeEntry` |
| LOW | `PlaybackView.swift` | 264 | `exportTask?.cancel()` fire-and-forget may leak temp files |
| LOW | `PlaybackView.swift` | 261 | `notificationToken` observer timing window on re-appear |
| LOW | `CloudBackupService.swift` | 83 | `NWPathMonitor` closure races with `@MainActor` state |
| LOW | `CalendarView.swift` | 299 | `entryMap` O(n) recomputed every render pass |
| LOW | `RecordView.swift` | 249 | `showSaved = true` not reset when `savedAnimationTask` cancelled |
| LOW | `VideoEntry.swift` | 47 | `dayOfYear` returns `0` on edge case instead of propagating nil |

---

## SWIFT 6 CONCURRENCY READINESS SUMMARY

The codebase uses a mix of patterns:
- `@MainActor` on `CameraService`, `PrivacyService`, `DeepAnalysisService`, `SubscriptionService` ✅
- `Task { @MainActor in }` for bridging GCD callbacks ✅
- `@StateObject` / `@ObservedObject` for view state ✅
- `async/await` throughout ✅

**Key gaps for Swift 6 compliance:**
1. **All `addPeriodicTimeObserver` callbacks** must wrap state mutations in `Task { @MainActor in }`
2. **`withCheckedThrowingContinuation` in Vision calls** must handle all error paths explicitly
3. **`@MainActor` class properties** accessed from non-isolated contexts (delegate callbacks) must use explicit `MainActor.assumeIsolated` or be rewritten to `Task { @MainActor in }`
4. **Concurrent writes to `@Published` collections** in `DeepAnalysisService` must be protected
5. **`NWPathMonitor` closure** should use `AsyncStream` for Swift 6 executor model

**No `nonisolated(unsafe)` or `unchecked Sendable` found** — codebase is clean on that front.

---

*Generated by SwiftUI Pedant Agent — 2026-04-01*
