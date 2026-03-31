# Blink iOS — Unified Action Plan (Round 4)
**Synthesized from:** Architect + Accessibility + Brand + SwiftUI (4-agent cross-pollination)
**Date:** 2026-03-31

---

## The Cross-Cutting Theme

**BlinkFontStyle migration was ~15% done in Round 3.** ~60 font sites remain raw `.font(.system(size:))`. This is the single highest-leverage fix that keeps getting deprioritized. It was confirmed again by Architect + Brand in Round 4.

---

## CRITICAL

### 1. BlinkFontStyle — Complete the Migration
**Owner:** Architect + Brand
**Confirmed by:** Architect (#1 priority), Brand (font inconsistency across app)

Round 3 said 24 files. Architect now says only ~15% done — ~60 sites remain across 20 files.

**The fix:** Systematic migration — use a regex to find all `.font(.system(size:` and replace with BlinkFontStyle equivalents. Monospaced fonts can stay as-is.

**Files still needing migration:**
- Theme.swift (button styles use raw `.font(.system())`)
- PrivacyLockView (lines 79, 150, 313 — Brand confirmed)
- RecordView countdown
- SocialShareSheet loading
- PlaybackView (monospaced fonts and raw size calls)

---

### 2. FriendsListView — Undefined `.friendButtonStyle` (Compilation Blocker)
**Owner:** Brand
**Confirmed by:** Brand

`FriendsListView` references `.friendButtonStyle` which doesn't exist. This is a compilation error.

**Fix:** Either define `friendButtonStyle` in Theme.swift, or remove the reference from FriendsListView.

---

### 3. VideoEntry Data Race — Synchronous Access to @Published State
**Owner:** Architect
**Confirmed by:** Architect

`VideoEntry.videoURL` and `VideoEntry.thumbnailURL` computed properties synchronously access `VideoStore.shared` which is not on the main actor — data race in Swift 6.

**Fix:**
```swift
// VideoEntry — make computed properties simple and local, or
// make them @MainActor computed properties
@MainActor var videoURL: URL { ... }
```

---

### 4. PlaybackView WCAG AA Contrast — #666666 / #555555 on Dark
**Owner:** Accessibility
**Confirmed by:** Accessibility

- `PlaybackView.swift:261,270` — `#666666` on black gradient overlay (1.73:1, need 4.5:1)
- `PlaybackView.swift:473` — `#555555` "Default:" label on `#0a0a0a` (3.15:1)

**Fix:**
```swift
// Replace #666666 and #555555 in PlaybackView with Theme.textSecondary (AAAAAA) or accessible equivalent
```

---

## HIGH

### 5. StorageDashboardView — O(n) Computed Property in View Body
**Owner:** SwiftUI
**Confirmed by:** SwiftUI

`analyzeCompressionCandidates()` is O(n) recomputed on every body evaluation via a computed property.

**Fix — memoize or use `@State`:**
```swift
@State private var compressionCandidates: [CompressionCandidate] = []

// Compute once on appear, recompute only when entries change
.onAppear {
    compressionCandidates = VideoStore.shared.analyzeCompressionCandidates()
}
.onChange(of: VideoStore.shared.entries) { _, _ in
    compressionCandidates = VideoStore.shared.analyzeCompressionCandidates()
}
```

---

### 6. ContentView — `asyncAfter` Without Cancellation
**Owner:** SwiftUI
**Confirmed by:** SwiftUI

Two `DispatchQueue.main.asyncAfter` calls in `.onAppear` with no cleanup.

**Fix:**
```swift
// Use .task { } instead which auto-cancels
.task {
    try? await Task.sleep(nanoseconds: 2_000_000_000)
    // do thing
}
```

---

### 7. PlaybackView — Notification Observer Leak on Re-Appear
**Owner:** SwiftUI
**Confirmed by:** SwiftUI

`notificationToken` can leak if `setupPlayer()` is called multiple times (trim sheet dismiss/re-appear).

**Fix — remove old observer before adding new one:**
```swift
if let oldToken = notificationToken {
    NotificationCenter.default.removeObserver(oldToken)
}
notificationToken = NotificationCenter.default.addObserver(...)
```

---

### 8. CalendarView — `.task(id:)` Won't Re-Fire for Same Month
**Owner:** SwiftUI
**Confirmed by:** SwiftUI

`.task(id: exportMonth)` won't re-trigger if the same month is exported twice.

**Fix — use a compound id or incrementing trigger:**
```swift
@State private var exportTrigger: Int = 0
// In export function:
exportTrigger += 1
// In .task(id: exportTrigger) — now always re-runs
```

---

### 9. PrivacyLockView shakeAnimation() — No Reduce Motion Guard
**Owner:** Brand + Accessibility
**Confirmed by:** Brand, Accessibility

Every other animation gates on `accessibilityReduceMotion`. The shake doesn't.

**Fix:**
```swift
@Environment(\.accessibilityReduceMotion) var reduceMotion
// In shakeAnimation():
if reduceMotion { return } // or show visual alternative
```

---

### 10. SubscriptionService + PrivacyService — Not @MainActor
**Owner:** Architect
**Confirmed by:** Architect

`SubscriptionService` and `PrivacyService` are used as `@StateObject`/`@ObservedObject` in SwiftUI views but aren't `@MainActor`. Violation in Swift 6.

**Fix:**
```swift
@MainActor class SubscriptionService: ObservableObject { ... }
@MainActor class PrivacyService: ObservableObject { ... }
```

---

### 11. Theme.swift Button Styles — Bypass Dynamic Type
**Owner:** Accessibility
**Confirmed by:** Accessibility

Theme button styles use `.font(.system(size:))` which bypasses BlinkFontStyle Dynamic Type.

**Fix — use BlinkFontStyle in button styles:**
```swift
// In Theme.swift:
static let buttonFont: Font = BlinkFontStyle.headline.font
```

---

### 12. SettingsView + MonthBrowserView + OnThisDayView — WCAG AA Failures
**Owner:** Accessibility
**Confirmed by:** Accessibility

~7 more WCAG AA contrast failures in settings and date views (555555/666666 on dark).

**Fix — update to accessible values:**
```swift
static let textSecondary = Color(hex: "AAAAAA")  // already fixed in some places
// Audit all occurrences and replace with Theme tokens
```

---

## Phase 4 Execution

| Agent | Owns |
|-------|------|
| **Architect** | Priorities 1 (BlinkFontStyle completion), 3 (VideoEntry data race), 10 (MainActor annotations) |
| **SwiftUI** | Priorities 5 (StorageDashboard memoization), 6 (asyncAfter → .task), 7 (observer cleanup), 8 (CalendarView compound id) |
| **Accessibility** | Priorities 4 (PlaybackView contrast), 11 (Theme button fonts), 12 (remaining WCAG failures) |
| **Brand** | Priority 2 (friendButtonStyle), 9 (shakeAnimation reduceMotion) |

All execute in parallel. Build and push.
