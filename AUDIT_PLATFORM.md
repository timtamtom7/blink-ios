# Blink — Phase 1: Platform Audit

**Auditor:** Platform Guardian  
**Scope:** `blink-ios/` (Swift files) + `blink/` (cross-platform Swift files)  
**Date:** 2026-03-30

---

## Findings Summary

| Severity | Count |
|---|---|
| CRITICAL | 6 |
| HIGH | 7 |
| MEDIUM | 8 |
| LOW | 4 |

---

## 1. Notifications

**[CRITICAL] — No local notification infrastructure anywhere**

`UNUserNotificationCenter` is never imported, configured, or used. The app has multiple features that logically require notifications:

- **On This Day** reminders (e.g., "You blinked on this day 1 year ago")
- Subscription renewal / expiration warnings
- Daily reminder to record ("You haven't blinked today")
- Freemium limit reminders
- Privacy consent reminders (R2/R3 passcode/biometric)

No notification categories defined (`UNUserNotificationCenter.setNotificationCategories`), no deep-link action handlers (`UNNotificationCenterDelegate`), no provisional authorization request.

---

## 2. App Shortcuts / Siri

**[CRITICAL] — Zero App Intents or Siri Shortcuts defined**

`AppIntents` framework is never imported across any Swift file. For a daily recording app, expected shortcuts include:

- "Record my blink" / "Take a blink" → starts recording
- "Show my highlights" → opens AI Highlights
- "View this day last year" → opens On This Day

No `AppShortcuts`, no `AppIntent` conformances, no `INStartRecordingIntent` or equivalent.

---

## 3. iOS 26 APIs

**[CRITICAL] — App not targeting iOS 26 opportunities**

iOS 26 (assumed next major) is entirely unaddressed:

- No `ActivityKit` / **Live Activities** for recording status in Lock Screen or Dynamic Island
- No `WidgetKit` / **Lock Screen widgets** (e.g., today's blink status, streak counter)
- No **Control Center** plugin or Media Intents integration
- No `AppIntents` for system-level shortcuts
- No `inlineLargeTitle` or updated navigation APIs
- `VNClassifyImageRequest` uses older Vision API; newer scene understanding APIs not used

**[MEDIUM] — `VNDetectFaceRectanglesRequest` used instead of newer `VNDetectHumanBodyPoseRequest` or combined Vision requests**

In `blink/Sources/Services/AIVisionService.swift:36-46`, face detection and scene classification are done as separate requests rather than using the more efficient combined pipeline available in newer iOS.

---

## 4. Privacy

**[HIGH] — Camera and microphone permissions lack proper purpose-string handling in Info.plist**

`CameraService.swift:59-70` and `RecordView.swift:296-310` call `AVCaptureDevice.requestAccess(for:)` without verifying that `NSCameraUsageDescription` and `NSMicrophoneUsageDescription` are present and human-readable in `Info.plist`. App Store rejection risk if usage strings are missing or insufficient.

**[HIGH] — No privacy consent flow for R2/R3**

`PrivacyService.swift` manages passcode/biometric lock but there is no onboarding consent flow explaining what data is collected, how it's stored, and what the biometric requirement means. Missing: privacy manifest (`PrivacyInfo.xcprivacy`), no `NSPrivacyTracking` / `NSPrivacyTrackingDomains` declarations.

**[MEDIUM] — Contacts access without purpose explanation**

`SocialShareService.swift:95-103` calls `CNContactStore().requestAccess(for: .contacts)` with no usage description validation. Users are not told WHY contacts are needed (only for "Blink to Friends" feature).

---

## 5. Camera

**[MEDIUM] — Camera session uses front-facing camera only, no switching option**

`CameraService.swift:72` hardcodes `.builtInWideAngleCamera` with `.front` position. No toggle between front/back camera. Users cannot record from the rear camera.

**[MEDIUM] — No landscape recording support**

The `CameraPreview` and all recording UI is portrait-only (`aspectRatio(9/16)`). Recording in landscape would require orientation changes.

---

## 6. Photo Library / PhotosUI

**[HIGH] — `PHPhotoLibrary` integration incomplete**

`ExportService.swift` (referenced in `CalendarView.swift:exportThisMonth()`) calls `saveToCameraRoll` but the actual `PHPhotoLibrary.performChanges` implementation is not visible in reviewed files. `SharingService.syncVideosToiCloudPhotos()` is a stub with no actual `PHAssetChangeRequest`. Photos framework is imported but `PhotosUI` (`PHPickerViewController`) is imported in `PlaybackView.swift` (line ~8) but never used.

**[MEDIUM] — No `PHPickerViewController` for selecting existing videos**

The app only records new clips. There is no `PhotosUI` picker allowing users to import existing videos into Blink.

---

## 7. Haptics

**[MEDIUM] — Recording start/stop in `CameraService` has no internal haptic calls**

`CameraService.startRecording()` and `stopRecording()` do not trigger haptics internally. Haptics are triggered at the `RecordView` layer (lines 212-215), meaning if recording is ever started programmatically without going through `RecordView`, no haptic fires.

---

## 8. URL Schemes / Deep Links

**[CRITICAL] — `blink://` URL scheme is defined but never handled**

`SocialShareService.swift:32` builds `blink://share?...` URLs. `BlinkApp.swift` has `deepLinkURL` state variable but **never processes it** (no `onOpenURL` modifier, no router). No view handles incoming `blink://` links.

**[HIGH] — iOS Settings deep link not handled**

`BlinkApp.swift` does not implement `onOpenURL(perform:)` for custom URL schemes. Settings redirects (`UIApplication.openSettingsURLString`) open the app's settings page but the app has no way to handle a return-to-app deep link after settings changes.

---

## 9. Localization

**[HIGH] — Extensive hardcoded strings throughout all views**

Zero usage of `String(localized:)` or `.localizedStringKey` / `Text("key")` with a `LocalizedStringKey` catalog. Every visible string is a raw Swift string literal.

Key offenders (non-exhaustive):

- `CalendarView.swift:97` — `"Calendar"`, `"AI Highlights"`, `"Public feed"`, `"Search clips"`, `"Browse by month"`, `"Export options"` (toolbar items)
- `CalendarView.swift:161` — `"On This Day"` (card title)
- `CalendarView.swift:210-214` — year navigation: `"Previous year"`, `"Next year"` (accessibility labels)
- `CalendarView.swift:246` — `"Review"` (button text)
- `OnboardingView.swift` — All onboarding text: `"Your year, one moment"`, `"30 seconds of life"`, `"Your private archive"`, `"Start recording"`, `"Enable Camera"`, `"Start Your Year"`, `"Back"`, `"Next"` (lines throughout)
- `PlaybackView.swift` — `"Delete this clip?"`, `"Export to Camera Roll"`, `"Trim clip"`, `"Delete clip"`, `"Share with friends"`, `"Edit Title"`, `"Cancel"`, `"Save"`, `"Default:"`, `"Clip Title"`, `"Add a title…"` — all accessibility labels also hardcoded
- `RecordView.swift:157` — `"No clip recorded today"`, `"This year: X clips"` (accessibility labels)
- `ErrorStatesView.swift` — All error messages: `"Camera access required"`, `"Microphone access required"`, `"Storage full"`, `"Couldn't save clip"`, `"Trim failed"`, `"Not enough space"`, `"Couldn't save to Camera Roll"`, `"No clips yet"`, `"Your 2025 Blink diary is blank"`, and all tip text
- `FreemiumEnforcementView.swift` — `"Daily Limit Reached"`, `"Upgrade to Memories"`, `"Maybe Later"`
- `SocialShareSheet.swift` — `"Share Blink"`, `"Private Link"`, `"Blink to Friends"`, `"Active Links"`, `"Link expires in X"`, `"Views: X/Y"`, all form labels
- `TrimView.swift` — `"Trim"`, `"Save"`, `"Cancel"`, time labels, all UI strings
- `PricingView.swift` — All pricing text hardcoded
- `SettingsView.swift` — `"Settings"`, all setting row labels
- `PrivacySettingsView.swift` — `"Privacy & Sharing"`, `"Never Share Automatically"`, `"Blur Faces by Default"`, `"Sharing History"`, `"Close Circles"`, `"Collaborative Albums"` — all strings

---

## 10. Network / Offline

**[HIGH] — No network connectivity monitoring**

No `NWPathMonitor` / `Network` framework usage anywhere. The app assumes network availability for:
- Cloud backup uploads
- Shared album sync (CloudKit stubs)
- Public feed
- AI highlights generation

No offline-first architecture, no "no connection" banner, no queuing of failed uploads for later retry.

**[HIGH] — `CrossDeviceSyncService`, `CloudBackupService`, `CommunityService` are all stubs**

All three services contain only placeholder comments (`// CloudKit stub:`, `// TODO: implement`) with simulated delays. No actual CloudKit implementation. The app advertises cross-device sync and cloud backup as features but the code is non-functional.

**[MEDIUM] — `PublicFeedView` and `CommunityView` have no network layer**

Both views are fully implemented UI with no corresponding network service. `SocialShareService.submitToPublicFeed()` and `fetchPublicFeed()` are no-op stubs returning local data.

---

## 11. Share Sheet

**[MEDIUM] — `ShareLink` used correctly but share options are incomplete**

`SocialShareSheet.swift` uses SwiftUI `ShareLink` correctly. However:
- "Private Link" feature generates `blink://share?...` URLs (line ~32) that are never handled on the receiving end
- "Blink to Friends" (`shareViaMessages`) falls back to clipboard copy with a comment "let the user send manually" — this is a degraded UX
- No `UISharingServicePicker` for custom service list

---

## 12. Settings Deep Link

**[MEDIUM] — No iOS Settings return-to-app deep link**

When the app opens `UIApplication.openSettingsURLString` (permission denied views, privacy settings), users change settings but have no way to return to a specific screen in Blink. No URL scheme handles this return path.

---

## 13. On-Device AI

**[MEDIUM] — `Speech` framework not used for transcription**

`CaptionService.swift` uses `AVAssetTrack` and `NLE` for video captioning but does not use `Speech` framework (`SFSpeechRecognizer`) for speech-to-text transcription of the recorded audio.

**[MEDIUM] — `NaturalLanguage` framework not used**

No sentiment analysis, language detection, or named entity recognition on clip titles or AI-generated insights. `DeepAnalysisService` could use `NLTagger` for better insight text.

**[LOW] — `AIVisionService` scene classification limited**

`VNClassifyImageRequest` is limited to a predefined set of labels. No custom trained model or `VNRecognizeTextRequest` for scene text detection (e.g., signage, captions in frame).

---

## 14. Unused Imports

**[LOW] — `EventKit` imported but unused in `CalendarView.swift`**

`CalendarView.swift` imports `EventKit` (line ~2) but no `EKEvent`, `EKEventStore`, or event-related code appears in the file.

**[LOW] — `PhotosUI` imported but unused in `PlaybackView.swift`**

`PhotosUI` is imported (line ~8) but `PHPickerViewController` or any `PhotosUI` component is never used.

**[LOW] — `AVKit` imported but unused in `blink/Sources/SharedAlbumView.swift`**

Import present but no `AVPlayerViewController` or `AVKit`-specific components used.

---

## 15. Siri / HomeKit

**[MEDIUM] — No HomeKit integration for smart home sync**

`Blink2.swift` references smart home camera integration but no `HomeKit` framework is imported or used. `HMHomeManager` and accessory sync are not implemented.

---

## 16. watchOS / watch Connectivity

**[MEDIUM] — `WatchConnectivity` referenced in `Blink2Service` but not implemented**

`Blink2Service.swift` line ~14 imports `WatchConnectivity` and references `WCSession`, but `WCSessionDelegate` methods and actual watch communication are stubbed/not implemented.

---

## Priority Fix Recommendations

1. **[CRITICAL]** Implement `UNUserNotificationCenter` setup with categories for: On This Day, Daily Reminder, Subscription, Privacy Consent
2. **[CRITICAL]** Add `onOpenURL` handler in `BlinkApp` to process `blink://share?...` links
3. **[CRITICAL]** Define App Intents for "Record blink" and "Show highlights" Siri shortcuts
4. **[HIGH]** Replace all hardcoded strings with `String(localized:)` / `LocalizedStringKey` + `.strings` catalog
5. **[HIGH]** Validate `NSCameraUsageDescription` / `NSMicrophoneUsageDescription` / `NSContactsUsageDescription` in Info.plist with human-readable strings
6. **[HIGH]** Implement `NWPathMonitor` for network state; add offline banners and upload retry queue
7. **[HIGH]** Implement or remove stub services (`CloudBackupService`, `CrossDeviceSyncService`, `CommunityService`)
8. **[MEDIUM]** Add `PHPickerViewController` for importing existing videos
9. **[MEDIUM]** Add front/back camera toggle in `CameraService`
10. **[MEDIUM]** Implement `SFSpeechRecognizer` transcription in `CaptionService`
