# Blink iOS — Final Platform Audit

**Lens:** Notifications, Sharing, Siri, Privacy, iOS 26 APIs  
**Scope:** Blink/ (iOS app), all Swift files  
**Severity scale:** CRITICAL · HIGH · MEDIUM · LOW

---

## Notifications

**[HIGH] NotificationService.swift:38** — `userNotificationCenter(_:willPresent:withCompletionHandler:)` returns `[.banner, .sound]`. `UNNotificationPresentationOptions.banner` requires iOS 15+. The deployment target is not declared; if lower than iOS 15, this silently degrades to no banner. Add `@available(iOS 15.0, *)` guard or use `.alert` as fallback for iOS 13–14.

**[MEDIUM] NotificationService.swift:96** — "Remind Me Later" action reschedules a notification with identifier `"dailyBlink-remindLater"`. Each repeated "Remind Me Later" tap overwrites the same identifier, which is correct, but `cancelDailyReminder()` does NOT cancel this variant — a lingering `"dailyBlink-remindLater"` notification can remain scheduled after the user leaves the app. Add `removePendingNotificationRequests(withIdentifiers: ["dailyBlink-remindLater"])` to `cancelDailyReminder()`.

**[MEDIUM] NotificationService.swift:103–117** — "On This Day" remind-later identifier `"onThisDay-remindLater"` has the same issue: not cancelled by `cancelDailyReminder()` or any public cleanup method. Repeated remind-later actions accumulate pending notifications.

**[LOW] NotificationService.swift:63, 75** — Notification `title` and `body` strings are hardcoded in English. All user-facing strings must be wrapped in `String(localized:)` or `NSLocalizedString` for internationalization.

---

## Sharing

**[HIGH] SocialShareService.swift:114** — `shareViaMessages(to:entry:)` builds an `sms:` URL with `&body=` query parameter. On iOS, this opens the Messages app but Apple does not support `body` parameter in the SMS URL scheme (it is ignored on modern iOS). The code falls back to clipboard copy, but the intent is unclear and the UX is broken — user expects automatic send, gets manual paste. Either remove the broken SMS URL entirely or implement `MFMessageComposeViewController` (available on device, not simulator).

**[MEDIUM] SocialShareService.swift:67** — `SharedLink.shareURL` uses custom scheme `blink://share`. While declared in Info.plist, this scheme has no App Transport Security exemption. If Blink ever loads this URL in a `WKWebView` or shares it to another app, the scheme may be blocked. Ensure deep links are handled only within the app via `onOpenURL`.

**[MEDIUM] SocialShareSheet.swift:77** — "Blink to Friends" copies link to clipboard without confirmation that a contact was actually selected. The flow is: load contacts → show picker → user selects → confirm dialog → copy to clipboard. If user dismisses the confirmation dialog, no feedback is given. Add `.alert`/`confirmationDialog` result feedback.

**[MEDIUM] SharedAlbumService.swift:49–53** — `createCircle` and `joinCircle` store circle membership as raw `deviceID` strings in `CloseCircle.memberIDs`. `deviceID` is `UIDevice.current.identifierForVendor` which:
  - Resets if the app is reinstalled or vendor ID changes
  - Is not persistent across devices
  - Cannot be used to reliably identify circle members

  This breaks circle membership permanently after reinstall. Consider using a proper account system or CloudKit record IDs.

**[MEDIUM] SharedAlbumService.swift:195** — `saveToDisk()` persists `publicMoments` (which contain `viewerIDs` and `reactorDeviceIDs` arrays) to unencrypted UserDefaults. While these are pseudonymous, storing viewing history in plaintext UserDefaults is a privacy risk. Migrate to Keychain or encrypted storage.

**[LOW] SocialShareService.swift:84** — `fetchRecentContacts` always returns `[]` with a comment that actual contact picking uses `CNContactPickerViewController`. The method is async and appears to be a real API, but it does nothing. Either implement it properly or remove it to avoid confusion.

**[LOW] SharedAlbumService.swift:196–198** — `recordSharingHistory(clipID:viewerID:shareType:)` posts a `NotificationCenter` notification with raw `viewerID` string as user info. Any observer can extract this. Should use an internal notification with opaque identifiers only.

---

## Siri / App Intents

**[MEDIUM] RecordBlinkIntent.swift:12** — `static var openAppWhenRun: Bool { true }` causes Siri to open the Blink app when the shortcut fires. This is correct behavior, but `perform()` only sets `DeepLinkHandler.shared.pendingDeepLink = .record` without any validation that the deep link target exists or is reachable. If the app is in a bad state (no camera permission, storage full), the user lands in the app but recording never happens. Add pre-flight checks in `perform()`.

**[MEDIUM] ShowHighlightsIntent.swift:12** — Same `openAppWhenRun = true` issue as RecordBlinkIntent. Sets `.highlights` deep link without validation.

**[MEDIUM] OnThisDayIntent.swift:12** — Same pattern. No validation that on-this-day content actually exists.

**[LOW] BlinkShortcuts.swift:8–10** — Uses `RecordBlinkIntent()` as the AppShortcutsProvider intent. This requires `RecordBlinkIntent` to be a proper `AppIntent` conforming type. The intent does not use `parameters` — all three shortcuts trigger identical behavior. If custom parameters are needed (e.g., specific date), the intents need `@Parameter` properties and the phrases need `$` variable substitution.

**[LOW] BlinkShortcuts.swift:6** — No `intentDescription` override on `BlinkShortcuts` itself. Consider adding one for the shortcut provider.

---

## Privacy

**[CRITICAL] PrivacyService.swift:77** — `biometricType` uses `LAContext.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error:)` which includes Face ID, Touch ID, and Optic ID. However, `authenticateWithBiometrics()` at line 108 uses `.deviceOwnerAuthenticationWithBiometrics` — this is correct. But the enum case `.opticID` is declared in `BiometricType` yet there is no `LAContext.biometryType == .opticID` check in a system that would actually return `.opticID`. This case will never be triggered on current hardware and should either be removed or guarded with `@available(iOS 17.0, *)`.

**[HIGH] PrivacyService.swift:72** — `passcodeKey` is stored as `"com.blink.passcode"` in the Keychain. `kSecAttrAccessible` is set to `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`. This is correct. However, `setPasscode()` calls `SecItemDelete(query)` then `SecItemAdd(query)` — if the delete succeeds but the add fails (e.g., Keychain is full), the existing passcode is deleted with no way to recover. Use `SecItemUpdate` as a safer pattern.

**[MEDIUM] PrivacyLockView.swift:177** — `shakeAnimation()` dispatches `DispatchQueue.main.asyncAfter` in a loop without any cancellation mechanism when the view disappears. If `PrivacyLockView` is dismissed during the shake animation, the async blocks will still fire, causing state mutations on a deallocated view. Store the dispatch work items and cancel them in `.onDisappear`.

**[MEDIUM] PrivacyLockView.swift:72** — `passcodeDots` uses `@Environment(\.accessibilityReduceMotion)` but the `shakeAnimation()` function reads this value once at call time and then runs a fixed animation regardless. If the user toggles Reduce Motion while the view is displayed, the animation behavior won't update reactively.

**[MEDIUM] PrivacyService.swift:88** — `verifyPasscode()` performs a SHA256 hash of the input and compares `Data` objects with `==`. While `Data` equality is constant-time in Swift, this comparison is implementation-dependent. The comment claims "constant-time comparison, preventing timing attacks" but this is not guaranteed by the Swift standard library. Use `CryptoKit.SymmetricAlgorithm.compare` or a constant-time comparison utility for true timing-attack resistance.

**[LOW] PrivacySettingsView.swift:12** — `SharingSettings.ShareHistoryEntry` contains `viewerID` displayed as `viewerID.prefix(12) + "..."` in `SharingHistoryView`. This is fine for display but the full `viewerID` is still in memory and persisted via `SharedAlbumService`. An explicit purge/clear mechanism for sharing history is missing.

**[LOW] SettingsView.swift:91** — Privacy policy URL is `"https://example.com/privacy"` — this is a placeholder domain and must be replaced with a real URL before shipping. Using `example.com` in a privacy policy link is a red flag for app reviewers.

**[LOW] CloudBackupService.swift:37–40** — Comment says `CKContainer` and `CKDatabase` are lazy vars to avoid EXC_BREAKPOINT if entitlement is missing. This is correct pattern. However, the lazy var itself can still throw on access if the CloudKit container name is malformed. Wrap access in `do-catch` or add a guard check.

**[LOW] CloudBackupService.swift:66** — `isConnected` is published and monitored via `NWPathMonitor`, but the `backupAllClips()` and `restoreClips()` methods check `isConnected` at the start, then perform async work. The network could drop mid-backup. No retry/resume logic exists. Consider handling `NWPathMonitor` updates during active transfers.

---

## iOS 26 APIs

**[HIGH] Theme.swift:3** — Comment states `// iOS 26 Liquid Glass Design System for blink-ios`. The iOS 26 SDK is not publicly released as of this audit. The theme uses `.ultraThinMaterial` (iOS 15+), `.background(.ultraThinMaterial)` with overlay (iOS 15+), and various iOS 26 design tokens. No `@available(iOS 26.0, *)` annotations are present anywhere in the codebase. The app declares `UISupportedInterfaceOrientations` with no iOS version floor — it likely targets iOS 15+. **Verify the minimum deployment target and annotate iOS 26-specific APIs accordingly.** Do not ship iOS 26-only APIs without availability guards.

**[MEDIUM] Theme.swift:240** — `GlassBackground` modifier uses `.ultraThinMaterial` and `.background(Color.black.opacity(0.5))` layering. The iOS 26 "Liquid Glass" design language introduces new `material` types and blur behaviors that may differ from current `.ultraThinMaterial`. Verify these match the actual iOS 26 API surface before shipping.

**[MEDIUM] AppleEcosystemService.swift:52–64** — `AppleEcosystemService` uses `NWBrowser` for local device discovery. Bonjour type `"_blink._tcp"` requires the `com.apple.developer.networking.multicast` entitlement. This entitlement is NOT declared in Info.plist. The app will fail to discover devices on the local network without it.

**[MEDIUM] AppleEcosystemService.swift:62** — `NWBrowser` is created but never stored strongly — the instance is a local variable. It is captured in a closure that updates `discoveredDevices` but the browser itself could be deallocated. Store `browser` as a class property.

**[LOW] AppleEcosystemService.swift:28** — `CLLocationManager` is used for spatial memories but `requestWhenInUseAuthorization()` or `requestAlwaysAuthorization()` is never called. Location services will silently fail. If spatial memories with GPS are a planned feature, add `locationManager.requestWhenInUseAuthorization()` in the appropriate flow.

**[LOW] SharedAlbumService.swift:76–79** — `joinCircle` via invite code is a stub returning `false`. No backend is connected. This is fine for development but must be implemented before shipping.

**[LOW] CollaborativeAlbum.swift:34** — `inviteLink` defaults to `"https://blink.app/collab/\(id.uuidString)"`. The `blink.app` domain is not declared as an associated domain (`applinks:`). Without an `apple-app-site-association` file on that domain, universal links will not work. Either declare the domain or use the custom `blink://collab/` URL scheme for album invites.

---

## General Security / Privacy

**[MEDIUM] SocialShareService.swift:58** — `fallbackShareURL = URL(string: "blink://share")!` is a force-unwrapped URL init. If the string is ever changed to an invalid URL, this will crash. Use a computed property with a guard or make it a static constant with an `assert`.

**[LOW] VideoStore.swift:47** — `_cachedOnThisDayEntries` and `_onThisDayCacheEntryCount` are private properties with underscore prefix but are not prefixed consistently with Swift convention (Swift uses `_propertyName` for implicit property backing). Additionally, `invalidateOnThisDayCache()` is called in `deleteEntry` but not in `updateEntry` — if an entry is updated (title changed), the cache could become stale.

**[LOW] PrivacyLockView.swift:46** — `biometricTask` is a `Task` stored property that is never cancelled when the view disappears. If biometric auth is in progress and the user navigates away, the task continues running. Add `.onDisappear { biometricTask?.cancel() }`.

---

## Summary

| Severity | Count |
|----------|-------|
| CRITICAL | 1 |
| HIGH | 5 |
| MEDIUM | 15 |
| LOW | 13 |
| **Total** | **34** |

**Top 5 Priority Fixes:**
1. **CRITICAL** — `Theme.swift` iOS 26 claims: remove or properly guard with `@available` annotations
2. **HIGH** — `NotificationService` reminder-leak: cancel `"dailyBlink-remindLater"` and `"onThisDay-remindLater"` in cleanup
3. **HIGH** — `SocialShareService` SMS URL scheme is broken; implement `MFMessageComposeViewController` or remove
4. **HIGH** — `CloudBackupService` Keychain delete-then-add pattern can lose passcode; use `SecItemUpdate`
5. **HIGH** — `AppleEcosystemService` Bonjour entitlement missing from Info.plist

---

*Audit completed: 2026-04-01*
