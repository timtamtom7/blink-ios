# AUDIT2 — Platform Guardian Report (Post-Phase4)

**Auditor:** Platform Guardian (Subagent)
**Date:** 2026-03-30
**Scope:** Notifications, Sharing, Shortcuts, iOS 26 APIs, On-Device AI, Privacy, Native Feel
**Files Audited:** 60+ Swift files across Blink/, BlinkMac/, Services/, Views/, AppIntents/

---

## REMAINING ISSUES (Previously Found, Still Unfixed)

### [CRITICAL] DeepLinkHandler is a dead-end — no view consumes pendingDeepLink

- **File:** `Blink/App/BlinkApp.swift`
- **Line:** 133 — `onOpenURL` correctly calls `DeepLinkHandler.shared.handle(url)`, setting `pendingDeepLink`
- **BUT:** `ContentView.swift` has zero reference to `deepLinkHandler`, `pendingDeepLink`, or any routing logic based on it
- **Impact:** Tapping a `blink://share?clip=UUID` notification or Siri shortcut sets state that is never observed. The deep link system is completely inert.

### [CRITICAL] `blink://` URL scheme is NOT registered in Info.plist

- **File:** `Blink/Info.plist` (and `BlinkMac/Info.plist`)
- **Missing key:** `CFBundleURLTypes` — without this, iOS will not route `blink://` URLs to the app
- **Impact:** Even if `handle()` were wired, iOS won't deliver the URL. The URL scheme is dead on arrival.

### [CRITICAL] Siri Shortcuts are defined but never exposed — no AppShortcutsProvider

- **Files:** `Blink/AppIntents/RecordBlinkIntent.swift`, `ShowHighlightsIntent.swift`, `OnThisDayIntent.swift`
- **Problem:** Each intent sets `openAppWhenRun = true` and updates `pendingDeepLink`, but without an `AppShortcutsProvider` in `BlinkApp`, the system has no way to discover these shortcuts
- **Also missing:** `NSUserActivityTypes` in Info.plist
- **Impact:** "Hey Siri, Record a Blink" does nothing. No shortcuts appear in Settings > Siri & Search.

### [CRITICAL] PrivacyInfo.xcprivacy still missing

- **Required by:** App Store privacy nutrition labels (required at upload since 2020)
- **Status:** Listed in PLAN_PLATFORM.md as "Priority 6" but never created
- **Impact:** App cannot be submitted to TestFlight/App Store without this manifest.

### [HIGH] NWPathMonitor not used anywhere — network monitoring is absent

- **File:** `Blink/Services/AppleEcosystemService.swift`
- **Line 3:** `import Network` — suggests intent to use `NWPathMonitor`
- **Reality:** Only `NWBrowser` (Bonjour) is used. `NWPathMonitor` is imported but never instantiated
- **Impact:** CloudBackupService and CrossDeviceSyncService have no network reachability awareness. Sync/backup attempts proceed blindly even on cellular or offline.

### [HIGH] Privacy consent onboarding flow still missing

- **Previous audit (HIGH #2):** "No privacy consent onboarding flow. No PrivacyInfo.xcprivacy. No NSPrivacyTracking declarations."
- **Status:** PrivacyInfo.xcprivacy still missing (see above). No consent screen explaining Face ID/passcode requirement, data storage, or what is/isn't collected
- **Impact:** Privacy violation risk — users enable biometrics without informed consent about what it means.

---

## PARTIALLY FIXED (Now Functional but with Issues)

### [MEDIUM] CloudBackupService — functional CloudKit but with defensive lazy pattern

- **File:** `Blink/Services/CloudBackupService.swift`
- **Positive:** Real CloudKit implementation, lazy container/db to avoid EXC_BREAKPOINT
- **Issue:** The lazy pattern hides crashes rather than fixing them — if the CloudKit entitlement is misconfigured, users get a cryptic crash when backup is first attempted, not an informative error
- **Note:** Still better than the stub it replaced, but the entitlement config needs to be prominently documented

### [MEDIUM] CrossDeviceSyncService — functional UI but uses simulated sleeps

- **File:** `Blink/Services/CrossDeviceSyncService.swift`
- **Lines 53–65:** `uploadPendingChanges()` and `downloadRemoteChanges()` are `Task.sleep` placeholders — no actual sync
- **Positive:** The UI and device management layer is real
- **Issue:** Progress bar fills, "Syncing" text displays, but nothing actually syncs. This is misleading.

### [MEDIUM] CommunityService — fake data under "Coming Soon" overlay

- **File:** `Blink/Services/CommunityService.swift`
- **Lines 68–76:** `loadPublicFeed()` generates hardcoded fake moments (`user_a7x2`, `user_b3k9`, etc.) with fake likes/views
- **Positive:** CommunityView overlays a "Coming Soon" screen that obscures the content
- **Issue:** The fake data is still in the codebase. If the overlay is ever removed without replacing this, the app will show fabricated social data as if it were real

### [MEDIUM] SocialShareService — link creation works, everything else is clipboard fallback

- **File:** `Blink/Services/SocialShareService.swift`
- **Lines 127–150:** `shareViaMessages()` copies to clipboard instead of sending SMS — no `MFMessageComposeViewController`
- **Lines 152–155:** `fetchRecentContacts()` always returns `[]` — contact picker relies on system UI only
- **Lines 161–166:** `submitToPublicFeed()` is a no-op
- **Positive:** Private link creation and persistence is functional
- **Issue:** "Blink to Friends" and "Share to Public Feed" are non-functional UI with no user-facing indication

---

## NEW ISSUES (Post-Phase4 Introduced or Found Now)

### [HIGH] Hardcoded strings not in Localizable.strings — i18n broken

Multiple views have user-facing strings not present in `Localizable.strings`:

| File | Line | Hardcoded String |
|------|------|-----------------|
| `MonthBrowserView.swift` | 144 | `"No clips"` |
| `StorageDashboardView.swift` | 319 | `"No clips yet"` |
| `OnThisDayView.swift` | 165 | `"No clips on this date in past years"` |
| `OnThisDayView.swift` | 178 | `"Analyze clips to discover similar moments"` |
| `CollaborativeAlbumView.swift` | 151 | `"No clips yet"` |
| `DeepAnalysisView.swift` | 418 | `"No clips found"` |
| `SocialShareSheet.swift` | 66 | `"Add to today's most meaningful moments (anonymous)"` |
| `CustomGraphics.swift` | 536 | `"Your year in Blink"` |
| `CustomGraphics.swift` | 834 | `"Your year, compiled."` |
| `CommunityView.swift` | 36 | `"Coming Soon"` |
| `ErrorStatesView.swift` | 445 | `"No clips yet"` |
| `ErrorStatesView.swift` | 449 | `"Your \(String(year)) Blink diary is blank..."` (interpolated, acceptable) |
| `OnboardingView.swift` | 106 | `"Your year, one moment"` |
| `PricingView.swift` | 135 | `"Your year deserves more"` |
| `CrossDeviceSyncView.swift` | 38 | `"Coming Soon"` |
| `CrossDeviceSyncView.swift` | 107 | `"Syncing your memories…"` |
| `SettingsView.swift` | 469 | `"Your year, one moment at a time."` |

### [MEDIUM] Misleading UI — "Coming Soon" on working features

- **File:** `Blink/Views/SettingsView.swift` — Line 173 shows `"Coming Soon"` as the iCloud Backup section label, but the section below has a fully functional iCloud backup toggle, backup/restore buttons, and progress indicators. The label directly contradicts the feature's implementation state.
- **File:** `Blink/Views/CrossDeviceSyncView.swift` — Same pattern: "Coming Soon" overlay hides a partially-built device management UI.

### [LOW] iOS 26 references in code with zero iOS 26 API usage

- **File:** `Blink/App/Theme.swift` — Lines 4 and 347 reference "iOS 26 Liquid Glass Design System" in comments
- **Reality:** No `ActivityKit`, no Live Activities, no Control Center integration, no `CGWindow` privacy APIs, no iOS 26-specific UI components
- **Impact:** Documentation/code misalignment. Comments promise iOS 26 integration that doesn't exist.

### [LOW] `import Network` without NWPathMonitor usage

- **File:** `Blink/Services/AppleEcosystemService.swift` — `import Network` is present but `NWPathMonitor` is never instantiated
- This is a leftover import from the first audit's recommendation

---

## POSITIVE FINDINGS (What Was Fixed Well)

1. **NotificationService** — Fully implemented with categories, actions (View/Remind Later), deep-link routing back to `DeepLinkHandler`, and foreground presentation handling. Excellent work.
2. **HapticService** — Comprehensive haptic feedback system used consistently across RecordView, PlaybackView, CalendarView, and TrimView. Well integrated.
3. **DeepLinkHandler** — The handler itself is well-structured with proper URL parsing, deep-link enum, and clear separation of concerns. It's the *wiring* that fails (no consumer in ContentView).
4. **CloudBackupService** — Real CloudKit implementation with manifest versioning. The lazy defensive pattern is acceptable as a workaround for entitlement issues.
5. **Localization strings file** — `Localizable.strings` has good coverage for core strings; the missing ones are edge-case view strings.

---

## SUMMARY

| Severity | Count | Top Issues |
|----------|-------|-----------|
| CRITICAL | 4 | Deep links dead-end, URL scheme unregistered, Siri shortcuts not exposed, PrivacyInfo.xcprivacy missing |
| HIGH | 3 | NWPathMonitor unused, privacy consent flow missing, hardcoded strings (batch counted above) |
| MEDIUM | 6 | CloudKit lazy pattern risk, simulated sync, fake community data, clipboard-only sharing, misleading "Coming Soon" labels |
| LOW | 2 | iOS 26 comment drift, leftover `import Network` |

**Bottom line:** Phase4 made significant progress on Notifications and Haptics. The remaining platform issues are architectural wiring problems — deep links have no consumer, Siri shortcuts have no provider, and the URL scheme is unregistered. The privacy manifest is the single most blocking item for App Store readiness.

---

*Platform Guardian — 2026-03-30*
