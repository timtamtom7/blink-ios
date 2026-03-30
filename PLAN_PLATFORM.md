# Blink iOS — Platform Guardian Action Plan

**Author:** Platform Guardian (Phase 3)  
**Date:** 2026-03-30  
**Input:** All 10 Phase 1 + Phase 2 audit files from 5 agents

---

## Platform-Specific Issues (My Audit Territory)

These are issues primarily in Platform's domain: URL schemes, notifications, Siri/App Intents, iOS APIs, localization, network monitoring, and cross-platform stubs.

---

### Priority 1: Deep Link Handler — `blink://` URLs Built But Never Received

**Problem:** `SocialShareService.swift:18` constructs `blink://share?...` URLs but `BlinkApp.swift` has **no `onOpenURL` modifier** and `Blink/Info.plist` has **no `CFBundleURLTypes` entry** registering the `blink` scheme. Shared links are unopenable.

**Fix:**
- **File:** `Blink/App/BlinkApp.swift:1` — Add `onOpenURL` modifier to `WindowGroup`:
  ```swift
  WindowGroup {
      ContentView()
          .preferredColorScheme(.dark)
  }
  .onOpenURL { url in
      DeepLinkHandler.shared.handle(url)
  }
  ```
- **File:** `Blink/Info.plist` — Add `CFBundleURLTypes`:
  ```xml
  <key>CFBundleURLTypes</key>
  <array>
      <dict>
          <key>CFBundleURLName</key>
          <string>com.blink.app</string>
          <key>CFBundleURLSchemes</key>
          <array>
              <string>blink</string>
          </array>
      </dict>
  </array>
  ```
- **File:** `Blink/Services/DeepLinkHandler.swift` (new) — Create `DeepLinkHandler` service that parses `blink://share?...` params and routes to `SocialShareSheet` or `PlaybackView` for the shared clip. Parse `clipID`, `shareToken` from URL query params.
- **File:** `Blink/Services/SocialShareService.swift:18` — The `fallbackShareURL` constant (`blink://share`) silently masks URL construction failures. Replace with a logger/alert: `print("SocialShareService: URL construction failed")` and return `nil` so callers can handle gracefully.

---

### Priority 2: Notification Infrastructure — Partially Wired But No Categories/Delegate

**Problem:** `SettingsView.swift:369-391` makes `UNUserNotificationCenter.current().add/remove` calls for daily reminders, but:
1. No `UNUserNotificationCenter.setNotificationCategories()` with action buttons
2. No `UNUserNotificationCenterDelegate` implementation
3. No deep-link action handlers for notification taps
4. No provisional authorization request
5. `BlinkApp.swift` never calls `UNUserNotificationCenter.current().delegate`

**Fix:**
- **File:** `Blink/Services/NotificationService.swift` (new) — Create `NotificationService`:
  - `requestAuthorization()` — calls `requestAuthorization(options: [.alert, .badge, .sound])`
  - `registerCategories()` — defines `.dailyReminder`, `.onThisDay`, `.subscriptionRenewal` categories with action buttons
  - `scheduleOnThisDay(for entry: VideoEntry)` — schedules notification for "You blinked on this day N year ago"
  - `scheduleDailyReminder(at hour: Int, minute: Int)` — daily local notification
  - Conforms to `UNUserNotificationCenterDelegate` — `userNotificationCenter(_:didReceive:withCompletionHandler:)` routes tap to deep link
- **File:** `Blink/App/BlinkApp.swift` — Set delegate in `main()` or App init:
  ```swift
  UNUserNotificationCenter.current().delegate = NotificationService.shared
  ```
- **File:** `Blink/Info.plist` — Add `NSUserNotificationAlertStyle` for notification banners. Add `UIBackgroundModes` with `remote-notification` for push notification support.

---

### Priority 3: App Intents / Siri Shortcuts — Zero Defined

**Problem:** `AppIntents` framework is never imported anywhere. No Siri shortcuts exist for a recording app that should support "Record my blink", "Show my highlights", "View this day last year".

**Fix:**
- **File:** `Blink/Services/AppIntents/RecordBlinkIntent.swift` (new) — Define `RecordBlinkIntent: AppIntent`:
  ```swift
  struct RecordBlinkIntent: AppIntent {
      static var title: LocalizedStringResource = "Record a Blink"
      static var description = IntentDescription("Start recording a new blink")
      static var openAppWhenRun: Bool = true
      func perform() async throws -> some IntentResult {
          // Post notification to open RecordView
      }
  }
  ```
- **File:** `Blink/Services/AppIntents/ShowHighlightsIntent.swift` (new) — Define `ShowHighlightsIntent: AppIntent` for AI highlights.
- **File:** `Blink/Services/AppIntents/ThisDayIntent.swift` (new) — Define `ThisDayIntent: AppIntent` to open On This Day view.
- **File:** `Blink/Services/AppIntents/AppShortcuts.swift` (new) — Provide `AppShortcuts`:
  ```swift
  struct BlinkShortcuts: AppShortcutsProvider {
      @AppShortcutsBuilder
      static var appShortcuts: some AppShortcuts {
          AppShortcut(RecordBlinkIntent(), "Record blink", "Record my blink")
          AppShortcut(ShowHighlightsIntent(), "Show highlights", "Show my highlights")
          AppShortcut(ThisDayIntent(), "This day last year")
      }
  }
  ```
- **File:** `Blink/App/BlinkApp.swift` — Confirm `@main` entry point is `BlinkApp`. App Intents require iOS 16+.

---

### Priority 4: Localization Pipeline — Zero `String(localized:)` Usage

**Problem:** Every view file uses raw Swift string literals. `String(localized:)` is never used. No `.strings` catalog exists. This blocks internationalization, accessibility string externalization, and consistent copy. Confirmed CRITICAL by all 5 agents (hardcoded strings = hardcoded accessibility strings).

**Fix:**
- **File:** `Blink/Resources/` — Create `Localizable.strings` (English base) and `Localizable.stringsdict` for pluralization.
- **File:** `Blink/App/Theme.swift` — Add `String(localized:)` variants to all `Text` views:
  ```swift
  // Instead of: Text("Record")
  // Use: Text("record.button.label", bundle: .module)
  ```
- **File:** `Blink/Views/RecordView.swift:42,38,41,56,60,118,129,151` — Add `accessibilityLabel` using `String(localized:)` keys (coordinates with Accessibility agent).
- **File:** `Blink/Resources/AccessibilityLabels.strings` (new) — Define all 119+ accessibility label strings:
  ```
  "record.button" = "Record";
  "record.button.start" = "Start recording";
  "record.button.stop" = "Stop recording";
  "camera.flip" = "Flip camera";
  ...
  ```
- **File:** All View files — Replace hardcoded strings with `Text("key", bundle: .module)`. This is a massive migration — coordinate with Brand for copy tone review.

---

### Priority 5: Network Monitoring + Offline Architecture

**Problem:** No `NWPathMonitor` anywhere. App assumes network is always available. Cloud operations fail silently. No retry queue. No offline-first architecture. The three sync services are stubs anyway.

**Fix:**
- **File:** `Blink/Services/NetworkMonitor.swift` (new) — Create `NetworkMonitor`:
  ```swift
  final class NetworkMonitor: ObservableObject {
      static let shared = NetworkMonitor()
      private let monitor = NWPathMonitor()
      @Published var isConnected: Bool = true
      @Published var connectionType: ConnectionType = .unknown
      func start() { monitor.start(queue: networkQueue) }
      func stop() { monitor.cancel() }
  }
  ```
- **File:** `Blink/Views/ContentView.swift` — Add `OfflineBanner` overlay:
  ```swift
  if !networkMonitor.isConnected {
      VStack {
          Text("No internet connection", bundle: .module)
          .padding(8)
          .background(Color.red.opacity(0.9))
          .cornerRadius(8)
      }
  }
  ```
- **File:** `Blink/Services/CloudBackupService.swift:40` — Implement `NWPathMonitor` listener. When `isConnected` becomes `false`, queue pending uploads to `PendingUploadQueue` (UserDefaults-backed). When `isConnected` becomes `true`, process queue.
- **File:** `Blink/Services/CrossDeviceSyncService.swift` — Implement or cut. If cut, remove `CrossDeviceSyncView` and related UI (confirmed stub by Platform, Architect, Brand).

---

## Secondary Platform Priorities

### Priority 6: Privacy Consent + PrivacyInfo.xcprivacy

- **File:** `Blink/Info.plist` — Add `NSContactsUsageDescription`: "Blink uses your contacts to help you share moments with friends."
- **File:** (new) `Blink/Resources/PrivacyInfo.xcprivacy` — Create privacy manifest with `NSPrivacyTracking`, `NSPrivacyTrackingDomains`, `NSPrivacyCollectedDataTypes` entries.
- **File:** `Blink/Services/PrivacyService.swift` — Add consent flow: check `UserDefaults.bool("privacyConsentGiven")` and if false, present `PrivacyConsentView` before enabling any tracking features.

### Priority 7: iOS 26 API Opportunities

- **File:** `Blink/Services/RecordingActivityAttributes.swift` (new) — Define `RecordingActivityAttributes` for Live Activity in Dynamic Island:
  ```swift
  struct RecordingActivityAttributes: ActivityAttributes {
      struct ContentState: Codable, Hashable { var elapsed: TimeInterval; var isPaused: Bool }
      var clipName: String
  }
  ```
- **File:** `Blink/Services/CameraService.swift:72` — Add `CameraPosition` enum and `switchCamera()` method. Currently hardcoded to `.builtInWideAngleCamera` with `.front` only.
- **File:** `Blink/Views/RecordView.swift:52-60` — Move `AVCaptureSession` management entirely into `CameraService`. `RecordView` should not directly own camera objects.

### Priority 8: Stub Services — Implement or Remove

- **File:** `Blink/Services/CloudBackupService.swift` — Either implement real CloudKit (CKContainer, CKDatabase, CKModifyRecordsOperation) or remove the UI components (settings row, sync toggle).
- **File:** `Blink/Services/CommunityService.swift` — Either implement `fetchPublicFeed()` with real network layer or remove `CommunityView` and `PublicFeedView` entirely. Currently shows fake placeholder data — **confirmed by Brand as CRITICAL UX harm.**
- **File:** `Blink/Services/CrossDeviceSyncService.swift` — Either implement real WatchConnectivity/WWDC sync or remove `CrossDeviceSyncView` and `Blink2Service`.

### Priority 9: `PHPickerViewController` for Video Import

- **File:** `Blink/Views/CalendarView.swift` (or new `ImportView.swift`) — Add "Import Video" button that presents `PHPickerViewController` for selecting existing videos from photo library.
- **File:** `Blink/Services/ImportService.swift` (new) — Handle `PHPickerViewController` results, copy selected videos to Blink's videos directory, add entries to `VideoStore`.

### Priority 10: `SFSpeechRecognizer` + `NaturalLanguage` — Already Partially Wired

- **File:** `Blink/Services/CaptionService.swift:27` — `SFSpeechRecognizer` is already imported and used. Verify it works reliably; add error handling if speech recognition fails (currently just `print`).
- **File:** `Blink/Services/DeepAnalysisService.swift:1` — Add `import NaturalLanguage` and use `NLTagger` for sentiment analysis of clip titles and AI-generated insights. `colorName()` function (Accessibility LOW #155) returns non-semantic names — fix to return semantic labels.

---

## My Top 5 for Unified Plan

1. **[CRITICAL — Platform] Deep Link Handler** — `blink://share` URLs built by `SocialShareService` are unopenable. `BlinkApp.swift` needs `onOpenURL` modifier + `Blink/Info.plist` needs `CFBundleURLTypes` entry. `DeepLinkHandler.swift` (new) routes incoming links to correct view. — *Confirmed by: Platform, Architect, Brand cross-cutting*

2. **[CRITICAL — Platform] Notification Infrastructure** — `UNUserNotificationCenter` is partially wired in `SettingsView` but has no categories, no delegate, no deep-link routing. Create `NotificationService.swift` with proper setup + delegate. — *Confirmed by: Platform*

3. **[CRITICAL — Platform] App Intents / Siri Shortcuts** — Zero `AppIntents` defined for "Record blink", "Show highlights", "View this day". Define `RecordBlinkIntent`, `ShowHighlightsIntent`, `ThisDayIntent` + `AppShortcuts` provider. — *Confirmed by: Platform*

4. **[HIGH — Cross-cutting] Localization Pipeline** — Zero `String(localized:)` usage across 50+ view files. Hardcoded strings block i18n, accessibility string externalization, and Brand's copy tone fixes. Create `Localizable.strings` + migrate all view strings. — *Confirmed by: Platform, Brand, Accessibility*

5. **[HIGH — Platform + Brand] Stub Services** — `CloudBackupService`, `CrossDeviceSyncService`, `CommunityService` are non-functional stubs that show convincing fake data. Either implement or remove `CommunityView`/`PublicFeedView` and related UI. Showing users functional-looking UI for non-existent features is confirmed CRITICAL by Brand. — *Confirmed by: Platform, Architect, Brand*

---

## What I Need From Other Agents

- **Architect:** `VideoStore` actor isolation fix (CRITICAL #1 for unified plan) is Architect's territory. Coordinate on `MainActor.run` wrappers and `@MainActor` service migration.
- **Accessibility:** My Priority 4 (localization pipeline) directly enables their Priority 1 (accessibility labels). I should create the `AccessibilityLabels.strings` file skeleton; Accessibility populates it.
- **Brand:** My Priority 1 (deep link) enables Brand's Priority 10 (share sheet UX). Brand should define what screens a shared link should open.
- **SwiftUI:** My Priority 2 (notification service) needs SwiftUI's `onReceive`/view observation coordination for badge counts and notification-triggered UI updates.
