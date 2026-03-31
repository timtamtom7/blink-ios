# Round 3 SwiftUI Audit — Blink iOS

## Executive Summary

Round 3 deep-dive into force unwraps, data flow, recomputation bugs, @State/@Binding correctness, Swift 6 concurrency, and architecture bugs. Round 2 fixes verified: TrimView/PlaybackView observer removal is now correct. New issues found across 5 files, plus 2 latent Swift 6 concurrency violations.

---

## Round 2 Fixes — VERIFIED ✅

- **TrimView periodicObserver** — Now properly removed in `onDisappear` before `player = nil`. ✅
- **PlaybackView notificationToken** — Now properly removed in `onDisappear`. ✅
- **Task leaks in RecordView** — `countdownTask` and `savedAnimationTask` both cancelled in `onDisappear`. ✅
- **Task leaks in DeepAnalysisView** — `analysisTask` and `refreshTask` both cancelled in `onDisappear`. ✅
- **Task leaks in YearInReviewCompilationView** — `generationTask` cancelled in `onDisappear`. ✅
- **NWPathMonitor** — Properly cancelled in `deinit`, weak self capture in `pathUpdateHandler`, main actor hop correct. ✅

---

## NEW Issues Found

### HIGH

**[HIGH] StorageDashboardView.swift — NaN displayed when compression candidate has zero size**

In `CompressionCandidate.compressionRatio`:
```swift
var compressionRatio: Double {
    (originalSize - compressedSize) / Double(originalSize)
}
```
If `originalSize == 0` (zero-byte file), this produces NaN. The calling code filters `originalSize > 100 * 1024`, but the property itself is unsafe for direct use. NaN propagates to UI and displays as "NaN%".

**Recommendation:** Guard with `guard originalSize > 0 else { return 0 }` or use `nand` pattern.

---

**[HIGH] AIHighlightsService.swift — Crash in yearInsights() when yearEntries is empty**

```swift
func yearInsights(entries: [VideoEntry]) -> [String] {
    guard !entries.isEmpty else { return ["Your Blink diary starts today."] }
    // ...
    let yearEntries = entries.filter { calendar.component(.year, from: $0.date) == year }
    // ...
    let weekdayCounts = Dictionary(grouping: yearEntries) { calendar.component(.weekday, from: $0.date) }
        .mapValues { $0.count }
    if let (bestDay, _) = weekdayCounts.max(by: { $0.value < $1.value }) {  // CRASH if yearEntries is empty!
```
If `entries` is non-empty but ALL entries are from a different year, `yearEntries` is empty → `weekdayCounts` is empty → `max(by:)` crashes.

**Recommendation:** Add `guard !yearEntries.isEmpty else { return insights }` before the weekday analysis.

---

**[HIGH] CalendarView.swift — exportTask never cancelled on disappear**

```swift
@State private var exportTask: Task<Void, Never>?

// .onDisappear — NEVER DEFINED
```
`CalendarView` has no `onDisappear` handler. Since `CalendarView` lives inside a `TabView`, `onDisappear` does NOT fire when switching tabs. The export task runs to completion even after navigating away. Minor resource waste but a latent issue if exports become heavy.

**Recommendation:** Add `onDisappear { exportTask?.cancel() }`.

---

### MEDIUM

**[MEDIUM] DeepAnalysisService.swift:182 — Continuation resumed from unspecified queue in classifyScene()**

```swift
private func classifyScene(_ image: UIImage) async throws -> SceneClassification {
    return try await withCheckedThrowingContinuation { continuation in
        let request = VNClassifyImageRequest { request, error in
            // ... completion handler fires on VNImageRequestHandler's internal queue
            continuation.resume(returning: SceneClassification(type: sceneType, confidence: Double(confidence)))
        }
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try? handler.perform([request])  // fires request on unspecified queue
    }
}
```
The Vision completion handler fires on an unspecified queue. `withCheckedThrowingContinuation` resumes on the calling context's executor. If `analyzeFrame` (which calls `classifyScene`) runs on a different queue than expected, this is undefined behavior in Swift 6. Works in practice in Swift 5.x.

**Same issue at `DeepAnalysisService.swift:255`** in `detectFaces()`.

**Recommendation:** Wrap continuation resumption in `await MainActor.run { continuation.resume(...) }` or use `Task { @MainActor in continuation.resume(...) }`.

---

**[MEDIUM] YearInReviewCompilationView.swift — progressTimer never invalidated on disappear**

```swift
@State private var progressTimer: Timer?

private func generateReel() {
    progressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
        if generationProgress < 0.9 {
            generationProgress += 0.05
        }
    }
}
```
The timer fires every 0.1s until `generationProgress >= 0.9`, at which point it stops updating `generationProgress` but keeps firing forever (no `invalidate()`). The timer is only invalidated via `progressTimer?.invalidate()` if `reelURL` is set. If generation fails with an error, the timer leaks.

**Also:** `progressTimer` is NOT cancelled in `onDisappear` (only `generationTask` is cancelled).

**Recommendation:** Add `progressTimer?.invalidate()` in `onDisappear` and invalidate it when `generationProgress >= 0.9`.

---

### LOW

**[LOW] CrossPlatformSyncService.swift:52 — processExportJob Task is fire-and-forget, not cancelled**

```swift
private func processExportJob(_ jobID: UUID) {
    Task {  // fire and forget — no cancellation, no storage of Task reference
        for i in 1...10 {
            try? await Task.sleep(nanoseconds: 500_000_000)
            await MainActor.run { /* update progress */ }
        }
    }
}
```
If `cancelExportJob` is called while processing, the background Task continues running and may overwrite state on a removed job entry (no-op due to guard, but still wasteful).

**Recommendation:** Store `Task` reference or use `TaskGroup.withCancellation` with cancellation check.

---

**[LOW] AppleEcosystemService.swift:103 — fetchOnThisDayClips Task is fire-and-forget, not cancelled**

```swift
Task {
    let ids = await SharedAlbumService.shared.fetchSharedAlbumClipIDs(...)
    // ...
    await MainActor.run { /* update state */ }
}
```
No cancellation if called again before completion.

**Recommendation:** Store Task reference and cancel previous invocation.

---

**[LOW] AdaptiveCompressionService.swift — compressingEntries accessed from multiple Tasks without actor isolation**

```swift
@Published private(set) var compressingEntries: [UUID: Double] = [:]
```
Multiple `Task` instances update `compressingEntries[idx].progress = ...` from different contexts. Since `AdaptiveCompressionService` is not an actor, this is a data race in Swift 6. In Swift 5.x, it works because all writes happen from `@MainActor` contexts, but the class itself is not annotated.

**Recommendation:** Mark `AdaptiveCompressionService` as `@MainActor final class`.

---

**[LOW] CaptionService.swift:88 — SFSpeechRecognitionRequest continuation may never resume**

```swift
return await withCheckedContinuation { continuation in
    recognizer.recognitionTask(with: request) { result, error in
        // If recognitionTask never calls its completion (e.g., empty audio),
        // continuation is never resumed → leak
        guard let result = result, result.isFinal else { return }
        continuation.resume(returning: segments)
    }
}
```
If `isFinal` is never true (e.g., recognition task hangs), the continuation is never resumed. No timeout or cancellation check.

**Recommendation:** Add a `Task.checkCancellation()` poll or use `withTaskCancellationHandler`.

---

## Latent Swift 6 Concurrency Violations

These compile and work in Swift 5.x, but would be errors in Swift 6 strict concurrency mode:

**[MEDIUM] VideoStore — not @MainActor, but accessed from @MainActor contexts**

`VideoStore` is a regular `final class` with `@MainActor` methods. Its `entries` property is accessed from `@MainActor` contexts in `CloudBackupService.backupAllClips`, `CloudBackupService.restoreClips`, `ThumbnailGenerator.generateThumbnail`, `SocialShareService.fetchPublicFeed`, etc. In Swift 6, accessing non-isolated state from a different isolation domain is a compile error.

`CloudBackupService.backupAllClips` accesses `VideoStore.shared.entries.filter { ... }` — `entries` is not `@MainActor`.

**Recommendation:** Mark `VideoStore` as `@MainActor final class VideoStore`.

---

## Round 1/2 Issues — Status

| Issue | Status |
|-------|--------|
| TrimView observer not removed | ✅ FIXED |
| PlaybackView observer not removed | ✅ FIXED |
| VideoStore actor isolation | ⚠️ PARTIAL — methods are @MainActor but class itself is not |
| Task leaks (RecordView, DeepAnalysisView, YearInReview) | ✅ FIXED |
| CalendarView exportTask | ❌ STILL OPEN |
| StorageDashboardView recomputation | ✅ OK — computed property, cheap operations |
| AIHighlightsView yearInsights() | ❌ NEW BUG FOUND |
| NWPathMonitor | ✅ OK |

## Recommended Priority Fix Order

1. Fix `AIHighlightsService.yearInsights()` crash (HIGH — user-facing crash)
2. Fix `CalendarView.exportTask` cancellation (HIGH — Task leak)
3. Fix `DeepAnalysisService` continuation queue issue (MEDIUM — Swift 6 violation)
4. Fix `YearInReviewCompilationView` timer leak (MEDIUM — timer resource leak)
5. Mark `VideoStore` as `@MainActor` (MEDIUM — Swift 6 compliance)
6. Fix `StorageDashboardView` NaN (HIGH — bad UX)
7. Fix remaining LOW issues when bandwidth allows
