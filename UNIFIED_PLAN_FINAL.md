# Blink iOS — FINAL Unified Action Plan
**Synthesized from:** 5-agent final audit (19 + 34 + 29 + 3 + 16 issues)
**Date:** 2026-04-01

---

## Cross-Cutting Theme

**WCAG AA is the biggest theme across all auditors.** Multiple agents found the same root cause: `textSecondary` (#AAAAAA on #0a0a0a) at 4.3:1 is below the 4.5:1 threshold. Fix the token once, fix it everywhere.

---

## CRITICAL (Fix First — Blockers)

### 1. WCAG AA Contrast — Theme Token Fix
**Confirmed by:** Architect, Accessibility, Brand

`textSecondary` (#AAAAAA on #0a0a0a) = 4.3:1 — below 4.5:1.
`textTertiary` (#888888 on #141414) = 4.76:1 — passes but barely.

**Fix in Theme.swift:**
```swift
static let textSecondary = Color(hex: "AAAAAA") // Already this — must be ≥4.5:1
// Verify: AAAAAA on 0a0a0a = 7.36:1 ✓
// The issue may be in actual usage contexts, not the token itself
// Audit all .foregroundColor(.secondary) usages and replace with Theme.textSecondary
```

**Also fix:** `.foregroundColor(.secondary)` system gray (#8E8E93) on #141414 = 3.2:1. Replace ALL with Theme tokens:
```swift
// Find and fix:
grep -rn "\.foregroundColor(.secondary)" Blink/Sources/ 2>/dev/null
```

---

### 2. HighlightPlaybackView — Notification Observer Crash
**Confirmed by:** SwiftUI (CRITICAL bug)

`AIHighlightsView.swift:523` — `HighlightPlaybackView` registers a `NotificationCenter` observer for loop-to-start **never removed**. Fires after view dismissed → `player.seek()` on deallocated player → **CRASH**.

**Fix:**
```swift
// In HighlightPlaybackView, store the notification token:
// @State private var loopObserverToken: NSObjectProtocol?
// On appear: loopObserverToken = NotificationCenter.default.addObserver(...)
// On disappear: if let token = loopObserverToken { NotificationCenter.default.removeObserver(token) }
// Or use Combine's with cancellables pattern
```

---

### 3. iOS 26 @available Guards Missing
**Confirmed by:** Platform (CRITICAL)

`Theme.swift` uses iOS 26 APIs without `@available(iOS 26.0, *)` guards. Will crash on iOS 25 and below.

**Fix:**
```swift
// In Theme.swift — annotate all iOS 26 references:
// @available(iOS 26.0, *)
// Or wrap in: if #available(iOS 26.0, *) { ... }
```

---

### 4. CloseCircleView / CollaborativeAlbumView — Missing Files (Compile Error!)
**Confirmed by:** Architect (HIGH)

Referenced in `PrivacySettingsView` but don't exist → compile errors.

**Fix:** Either create the files, or remove the references from `PrivacySettingsView`.

---

### 5. microBold 7pt — Below WCAG Minimum
**Confirmed by:** Architect, Accessibility

`BlinkFontStyle.microBold` at 7pt used in month bars and score overlays. Below 11pt WCAG minimum for body text.

**Fix:** Either increase to 11pt minimum or ensure it's only used for decorative/non-textual contexts.

---

## HIGH (Fix Second)

### 6. TrimView — Data Race in addPeriodicTimeObserver
**Confirmed by:** SwiftUI

`TrimView.swift:200` — `addPeriodicTimeObserver` callback mutates `@State private var currentTime` without MainActor dispatch → Swift 6 data race.

**Fix:**
```swift
// Dispatch to MainActor in the time observer callback:
let interval = CMTime(seconds: 0.1, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
    Task { @MainActor in
        self?.currentTime = time
    }
}
```

---

### 7. "Coming Soon" Overlay on Loading States
**Confirmed by:** Brand

`CommunityView` and `CrossDeviceSyncView` show "Coming Soon" on top of skeleton loaders simultaneously.

**Fix:** Show overlay only when content has actually loaded, not while `isLoading`.

---

### 8. Freemium Floor Invisible
**Confirmed by:** Brand

`FreemiumEnforcementView` blocks features but doesn't clearly communicate what free users *can* do.

**Fix:** Add visible copy explaining the free tier value prop ("one moment a day").

---

### 9. HapticFeedback.trigger() Always Fires Both Feedback Types
**Confirmed by:** Architect

`HapticFeedback.trigger()` fires impact AND notification even for types that should only fire one.

**Fix:** Separate the enum cases and fire only the appropriate feedback type.

---

### 10. iCloud "Coming Soon" Misleading
**Confirmed by:** Architect

`CloudBackupService` is fully implemented but shows "Coming Soon" label.

**Fix:** Update the label to reflect actual iCloud backup availability.

---

### 11. Missing entitlements (Bonjour)
**Confirmed by:** Platform

**Fix:** Add `com.apple.developer.networking Bonjour` entitlement if used.

---

## Phase 4 Execution

| Agent | Owns |
|-------|------|
| **Architect** | Priorities 3 (iOS 26 guards), 4 (missing files), 5 (microBold), 9 (HapticFeedback), 10 (iCloud label) |
| **SwiftUI** | Priorities 2 (HighlightPlaybackView crash), 6 (TrimView data race) |
| **Accessibility** | Priority 1 (WCAG AA contrast — .secondary usages), microBold minimum |
| **Brand** | Priority 7 (Coming Soon overlay), 8 (freemium floor) |
| **Platform** | Priority 11 (Bonjour entitlement), any iOS 26 notification APIs |

All execute in parallel. Build and push.
