# Blink iOS — Unified Action Plan (Round 3)
**Synthesized from:** Architect + Accessibility + Brand + SwiftUI (4-agent cross-pollination)
**Date:** 2026-03-31

---

## The Core Problem: BlinkFontStyle

Defined in Round 1. Defined again in Round 2. **Still completely unused.** 496+ font sites across the app use `.font(.system(size: X))`. Dynamic Type is broken for the entire app. This is the single highest-impact fix remaining.

---

## CRITICAL

### 1. VideoStore.trimClip — Silent UUID Overwrite
**Owner:** Architect
**Confirmed by:** Architect (sole finder, but CRASH-LEVEL)

The trim operation creates a **new entry with a fresh auto-generated UUID** and replaces the original. All deep links, On This Day references, and external callers holding the old entry ID now point to nothing.

**Fix:**
```swift
// VideoStore.trimClip — preserve the original entry's ID
func trimClip(_ entryId: UUID, startTime: Double, endTime: Double) async throws {
    guard let original = entries.first(where: { $0.id == entryId }) else { return }
    // Create new trimmed file but KEEP original.id
    let newFileURL = try await VideoOperations.trim(
        original.fileURL,
        start: startTime,
        end: endTime
    )
    // Update in place, preserve entry.id
    await MainActor.run {
        if let index = entries.firstIndex(where: { $0.id == entryId }) {
            entries[index] = VideoEntry(
                id: original.id, // PRESERVE original ID
                fileURL: newFileURL,
                createdAt: original.createdAt,
                duration: endTime - startTime,
                thumbnailURL: original.thumbnailURL,
                isLocked: original.isLocked,
                title: original.title,
                notes: original.notes
            )
        }
    }
    try? FileManager.default.removeItem(at: original.fileURL)
    invalidateOnThisDayCache()
}
```

---

### 2. CalendarView.exportTask — Lives in TabView, Never Cancelled
**Owner:** SwiftUI + Architect
**Confirmed by:** SwiftUI, Architect

CalendarView lives inside a TabView tab. SwiftUI's `.onDisappear` does NOT fire when switching tabs — only when the TabView itself disappears. The export task runs forever, consuming resources.

**Fix — 2 options:**
```swift
// Option 1: Use .task { } (auto-cancels on view disappear)
.task {
    isExporting = true
    do {
        let url = try await ExportService.shared.exportClips(...)
        exportedURL = url
    } catch {
        // handle
    }
    isExporting = false
}

// Option 2: Store task + use TabView.selection to detect tab switches
@State private var exportTask: Task<Void, Never>?
// In .onChange(of: selectedTab):
if selectedTab != .calendar {
    exportTask?.cancel()
    exportTask = nil
}
```

---

### 3. BlinkFontStyle — Adopt It, Fix Dynamic Type
**Owner:** Architect + Accessibility + Brand
**Confirmed by:** ALL 4 AUDITORS (every round)

This has been the #1 remaining issue for 3 rounds. Time to actually fix it.

**The token system already exists:**
```swift
// Theme.swift — verify this exists:
enum BlinkFontStyle {
    case largeTitle, title, headline, body, callout, subheadline, footnote, caption
    var font: Font {
        switch self {
        case .largeTitle: return .largeTitle
        case .title: return .title
        case .headline: return .headline
        case .body: return .body
        case .callout: return .callout
        case .subheadline: return .subheadline
        case .footnote: return .footnote
        case .caption: return .caption
        }
    }
}
```

**Migration strategy — batch by file:**
1. Find all `.font(.system(size: [0-9]+))` in views
2. Replace with `.font(BlinkFontStyle.[size].font)` where [size] maps to closest TextStyle
3. Test: enable Dynamic Type in Settings → Accessibility → Display & Text Size → Larger Text — all text should scale

**Priority files for migration:**
- RecordView, PlaybackView, CalendarView, SettingsView (highest traffic)
- Then FreemiumEnforcementView (entirely unthemed per Brand)
- Then everything else

---

### 4. VideoStore OnThisDay Cache — Not Invalidated on Lock/Unlock
**Owner:** Architect
**Confirmed by:** Architect

`updateTitle()` and `toggleLock()` modify `isLocked` but don't call `invalidateOnThisDayCache()`. Users who lock/unlock clips see stale On This Day results.

**Fix — add cache invalidation to mutation methods:**
```swift
func updateTitle(_ entryId: UUID, title: String) {
    // ... existing mutation logic ...
    invalidateOnThisDayCache() // ADD THIS
}

func toggleLock(_ entryId: UUID) {
    // ... existing mutation logic ...
    invalidateOnThisDayCache() // ADD THIS
}
```

---

## HIGH

### 5. YearInReviewCompilationView — Cosmetic Progress Misleads Users
**Owner:** Brand + SwiftUI
**Confirmed by:** Brand (sole finder)

Progress % is driven by a `Timer` (cosmetic), not by actual AI work. Users watch it sit at 85% for 10+ seconds. Either tie it to real progress or remove the percentage.

**Fix:**
```swift
// Option 1: Remove % entirely — show "Creating your reel..." with no number
// Option 2: Tie to real work:
// progress = Double(completedClips) / Double(totalClips)
@State private var progress: Double = 0
.task {
    for clip in clips {
        await processClip(clip)
        progress = Double(processedCount) / Double(clips.count)
    }
}
```

---

### 6. RecordView — Hardcoded 1s Camera Delay
**Owner:** Brand
**Confirmed by:** Brand (sole finder)

Camera setup uses `DispatchQueue.main.asyncAfter(deadline: .now() + 1.0)` — a fixed delay, not a session-ready signal. Slow devices still wait 1s; fast devices wait longer than needed.

**Fix:**
```swift
// Use AVCaptureSession's isRunning state, or a delegate callback:
sessionQueue.async {
    while !session.isRunning {}
}
// Then on main:
isCameraReady = true
```

Or add a `CameraService.isSessionReady` publisher.

---

### 7. PrivacyLockView — shakeAnimation() Is Empty
**Owner:** Brand
**Confirmed by:** Brand

Wrong passcode triggers `shakeAnimation()` which does nothing. Users get no feedback.

**Fix:**
```swift
func shakeAnimation() {
    // This should animate the passcode dots
    let animation = CAKeyframeAnimation(keyPath: "transform.translation.x")
    animation.timingFunction = CAMediaTimingFunction(name: .linear)
    animation.duration = 0.5
    animation.values = [-10, 10, -8, 8, -5, 5, -3, 3, 0]
    passcodeDotsView.layer.add(animation, forKey: "shake")
}
```

---

### 8. WCAG AA Contrast Failures
**Owner:** Accessibility
**Confirmed by:** Accessibility

`#555555` on dark backgrounds (~3.1:1, below 4.5:1 minimum). `#666666`, `#c0c0c0` also fail.

**Fix — update Theme.swift:**
```swift
// Verify these are updated:
static let textSecondary = Color(hex: "AAAAAA")  // was 555555 — must be ≥ 4.5:1
static let textTertiary = Color(hex: "888888")   // was 666666 — must be ≥ 4.5:1
```

Use a contrast checker tool and update Theme.swift tokens.

---

### 9. CommunityView Skeleton Cards — No VoiceOver Label
**Owner:** Accessibility
**Confirmed by:** Accessibility

Skeleton loading cards have no accessibility label. VoiceOver users hear nothing.

**Fix:**
```swift
VStack {
    RoundedRectangle(cornerRadius: 8)
        .fill(Color.gray.opacity(0.3))
}
.accessibilityLabel("Loading community post")
.accessibilityHidden(true)  // Hide the shape itself
// Or add a label to the container
```

---

### 10. SocialShareSheet — Loading State Tracked But No UI
**Owner:** Brand
**Confirmed by:** Brand

`isSubmittingToFeed` and `isLoadingContacts` are tracked but no loading indicator is shown.

**Fix — add ProgressView overlays:**
```swift
if isSubmittingToFeed {
    ProgressView("Submitting to community...")
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.3))
}
if isLoadingContacts {
    ProgressView("Loading contacts...")
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.3))
}
```

---

### 11. ApertureGraphic repeatForever on Permission Screen
**Owner:** Accessibility + Brand
**Confirmed by:** Accessibility + Brand

The aperture spring animation plays for the entire permission dialog duration. Distracting and motion-unsafe.

**Fix:**
```swift
@Environment(\.accessibilityReduceMotion) var reduceMotion
// ApertureGraphic: only run spring if !reduceMotion
// On permission screen: consider static illustration instead of animated
```

---

## Phase 3 Execution

| Agent | Owns |
|-------|------|
| **Architect** | Priorities 1 (trimClip UUID), 3 (BlinkFontStyle migration), 4 (cache invalidation) |
| **SwiftUI** | Priority 2 (CalendarView export task) |
| **Accessibility** | Priority 8 (WCAG AA contrast), 9 (skeleton labels) |
| **Brand** | Priority 5 (cosmetic progress), 6 (camera delay), 7 (shakeAnimation), 10 (SocialShareSheet loading) |
| **All** | Priority 3 (BlinkFontStyle) — parallel migration |

All execute in parallel. Build and push.
