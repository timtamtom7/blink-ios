# Blink iOS — Unified Action Plan (Round 2)
**Synthesized from:** 5-agent Phase 2 cross-pollination reports
**Date:** 2026-03-30

---

## Round 2: What's Changed

Phase 4 fixed genuine issues. But it introduced regressions and left wiring gaps. The new pattern: **scaffolding without connection** — platform infrastructure exists but nothing's wired together.

---

## CRITICAL (must fix before any App Store submission)

### 1. `PrivacyInfo.xcprivacy` Missing
**Owner:** Platform
**Confirmed by:** All 5 agents (Platform, Architect, Brand)

App Store blocks submission without this. Takes 5 minutes to create.

**Fix:**
```bash
# Blink/PrivacyInfo.xcprivacy
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "...">
<plist version="1.0">
<dict>
    <key>NSPrivacyTracking</key><true/>
    <key>NSPrivacyTrackingDomains</key><array/>
    <key>NSPrivacyCollectedDataTypes</key><array/>
    <key>NSPrivacyAccessedAPITypes</key><array/>
</dict>
</plist>
```

---

### 2. Deep Link Handler — Wired But Dead
**Owner:** Platform
**Confirmed by:** Platform, Architect, Brand

`DeepLinkHandler` exists but ContentView never reads `pendingDeepLink`. `blink://` URL scheme not registered in Info.plist.

**Fix — 3 parts:**

1. `Info.plist` — register URL scheme:
```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLName</key>
        <string>com.blink.app</string>
        <key>CFBundleURLSchemes</key>
        <array><string>blink</string></array>
    </dict>
</array>
```

2. `ContentView.swift` — read `pendingDeepLink`:
```swift
// Add to ContentView body or .onChange:
.onChange(of: DeepLinkHandler.shared.pendingDeepLink) { _, newValue in
    if let link = newValue {
        handleDeepLink(link)
        DeepLinkHandler.shared.pendingDeepLink = nil
    }
}
```

3. `DeepLinkHandler` — the `pendingDeepLink` property needs to be `@Published` or trigger a refresh:
```swift
// Change to Observable macro or @Published
@Published var pendingDeepLink: DeepLink?
```

---

### 3. Siri Shortcuts — Defined But Not Exposed
**Owner:** Platform
**Confirmed by:** Platform

`RecordBlinkIntent`, `ShowHighlightsIntent`, `OnThisDayIntent` exist but no `AppShortcutsProvider` exposes them.

**Fix:**
```swift
// Blink/AppIntents/BlinkShortcuts.swift:
import AppIntents
struct BlinkShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: RecordBlinkIntent(),
            phrases: ["Record a blink in \(.applicationName)"],
            shortTitle: "Record Blink",
            systemImageName: "video.fill"
        )
        AppShortcut(
            intent: ShowHighlightsIntent(),
            phrases: ["Show my highlights in \(.applicationName)"],
            shortTitle: "Show Highlights",
            systemImageName: "sparkles"
        )
    }
}
```

---

### 4. PrivacyLockView + PasscodeSetupView — 22 Keypad Buttons Unlabeled
**Owner:** Accessibility
**Confirmed by:** Accessibility, Architect, Brand

VoiceOver users hear "button, button, button" when entering passcodes. Complete lockout.

**Fix — PrivacyLockView:**
```swift
// Add to each digit button (0-9):
.accessibilityLabel("\(digit)")  // "0", "1", "2"... "9"

// Backspace:
.accessibilityLabel("Delete")

// Add to the passcode dot indicators:
.accessibilityLabel("Passcode, \(enteredCount) of 6 digits entered")
```

**Fix — PasscodeSetupView:** Same treatment for all 11 keypad buttons.

---

### 5. TrimView — `addPeriodicTimeObserver` Token Never Removed
**Owner:** SwiftUI
**Confirmed by:** SwiftUI, Architect

AVPlayer observer leaks memory and can crash on deallocation.

**Fix:**
```swift
// Store the token:
@State private var periodicObserver: Any?

// When adding:
periodicObserver = player?.addPeriodicTimeObserver(
    forInterval: CMTime(seconds: 0.1, preferredTimescale: 600),
    queue: .main
) { time in
    // ...
}

// In .onDisappear — REMOVE IT:
if let observer = periodicObserver {
    player?.removeTimeObserver(observer)
    periodicObserver = nil
}
```

---

### 6. PlaybackView — NotificationCenter Observer Leak
**Owner:** SwiftUI
**Confirmed by:** SwiftUI, Architect

NotificationCenter observer registered but never removed on disappear.

**Fix:**
```swift
@State private var notificationToken: NSObjectProtocol?

notificationToken = NotificationCenter.default.addObserver(
    forName: .videoDeleted,
    object: nil,
    queue: .main
) { _ in
    // ...
}

// In .onDisappear:
if let token = notificationToken {
    NotificationCenter.default.removeObserver(token)
}
```

---

## HIGH

### 7. CommunityView Skeleton Shimmer — No Reduce Motion Guard
**Owner:** Accessibility
**Confirmed by:** Accessibility, Brand (Phase 4 regression)

`SkeletonMomentCard` shimmer animation uses `.repeatForever` without checking `accessibilityReduceMotion`.

**Fix:**
```swift
@Environment(\.accessibilityReduceMotion) var reduceMotion

// In the animation:
if reduceMotion {
    // Static shimmer or no animation
} else {
    // .repeatForever shimmer
}
```

---

### 8. Theme Font Tokens — `Font.blinkText()` Doesn't Scale with Dynamic Type
**Owner:** Architect + Accessibility
**Confirmed by:** Accessibility, Architect, Brand

Theme.swift defines `Font.blinkText(_:)` but it uses `.system(size:)` without scaling. Even if adopted, text won't resize.

**Fix — Theme.swift:**
```swift
static func scaledFont(size: CGFloat, weight: Font.Weight = .regular) -> Font {
    .system(size: size, weight: weight, design: .default)
    // This still doesn't fully work — need Font.TextStyle
}

// Better: use Font.TextStyle
enum BlinkFontStyle {
    case largeTitle, title, headline, body, caption
    
    var font: Font {
        switch self {
        case .largeTitle: return .largeTitle
        case .title: return .title
        case .headline: return .headline
        case .body: return .body
        case .caption: return .caption
        }
    }
}
```

Then migrate views: `.font(.system(size: 17))` → `.font(BlinkFontStyle.body.font)`

---

### 9. AdaptiveCompressionService — Race Condition on @Published Writes
**Owner:** Architect + SwiftUI
**Confirmed by:** Architect, SwiftUI (Phase 4 regression)

Phase 4 added `await MainActor.run { }` to some mutations but `compressEligibleEntries` still has a race window.

**Fix — AdaptiveCompressionService:**
```swift
// Ensure ALL @Published mutations in compressEligibleEntries use MainActor.run:
await MainActor.run {
    self.processedCount += 1
    self.totalSavedBytes += saved
}
```

---

### 10. YearInReviewGraphic — "83 Clips" Hardcoded for New Users
**Owner:** Brand
**Confirmed by:** Brand, SwiftUI

OnboardingScreen1 shows "83 clips" as placeholder — fake data visible to new users.

**Fix:**
```swift
// In OnboardingScreen1:
Text("\(clipCount) clips this year")
    .accessibilityLabel("\(clipCount) clips recorded this year")
    .font(Theme.fontCaption)
    // clipCount comes from videoStore.entries.count — real data
```

---

### 11. Localization — 19+ Strings Missing from Catalog
**Owner:** Platform
**Confirmed by:** Platform, Accessibility

New strings added since the catalog was created. Consistency audit needed.

**Fix:** Run grep across all views for raw string literals that appear user-facing:
```bash
grep -rn '"[^"]*"' Blink/Views/ | grep -v "Localized\|accessibilityLabel\|Theme\.\|systemName"
```

Then add each to `Blink/Strings/Localizable.strings`.

---

### 12. VideoStore `onThisDayEntries()` Computed Twice
**Owner:** Architect
**Confirmed by:** Architect

Same filtering computed multiple times in the view hierarchy.

**Fix — VideoStore:**
```swift
// Cache the result:
func onThisDayEntries(for date: Date) -> [VideoEntry] {
    let calendar = Calendar.current
    return entries.filter { entry in
        guard let dateOnly = entry.createdAt else { return false }
        return calendar.isDate(dateOnly, inSameDayAs: date)
    }
}
```
Mark as `private` or memoize if called multiple times per render.

---

## MEDIUM

### 13. Freemium "Maybe Later" — No Offline Distinction
**Owner:** Brand

If user dismisses freemium with no network, they see the same prompt tomorrow. Clarify that dismissal is 24h regardless of connectivity.

---

### 14. ApertureGraphic `.repeatForever` Spring — Motion-Unsafe
**Owner:** Accessibility + Brand

Animation pulses on permission screens. Check all reduceMotion guards were applied post-Phase4.

---

### 15. NWPathMonitor — Imported But Never Used
**Owner:** Platform

CloudBackupService and CrossDeviceSyncService should use `NWPathMonitor` to show offline state.

**Fix:**
```swift
import Network
@State private var isConnected = true
let monitor = NWPathMonitor()

// On appear:
monitor.pathUpdateHandler = { path in
    Task { @MainActor in
        isConnected = path.status == .satisfied
    }
}
monitor.start(queue: DispatchQueue.global())
// On disappear:
monitor.cancel()
```

---

## Phase 4 Execution

| Agent | Owns |
|-------|------|
| **Platform** | Priorities 1, 2 (Info.plist + ContentView wiring), 3, 11, 15 |
| **Accessibility** | Priorities 4 (keypad labels), 7, 8 (font tokens) |
| **SwiftUI** | Priorities 5, 6 |
| **Architect** | Priorities 8 (Theme font), 9, 12 |
| **Brand** | Priorities 10, 13 |

All execute in parallel. Build and push.
