# Blink — Accessibility Action Plan

**Auditor:** Accessibility Guardian  
**Phase:** 3/3 — Unified Action Plan  
**Date:** 2026-03-30  
**Sources:** AUDIT_ACCESSIBILITY.md · AUDIT_PHASE2_ACCESSIBILITY.md · AUDIT_ARCHITECT.md · AUDIT_BRAND.md · AUDIT_SWIFTUI.md · AUDIT_PLATFORM.md

---

## Priority 1: Label Every Interactive Element (119 Critical Instances)

VoiceOver is completely broken across the entire app. Every `Button` and every `Image` used as a button lacks an `accessibilityLabel`. This is the single most impactful accessibility fix — zero technical risk, pure additive labels.

### RecordView.swift
- Line 38 — `Image(systemName: "camera.filters")` icon button → add `accessibilityLabel: "Camera filters"`
- Line 41 — `Image(systemName: "mic.fill")` icon button → add `accessibilityLabel: "Microphone"`
- Line 42 — `RecordButton` (the main capture button) → add `accessibilityLabel: "Record"` or `"Start recording"`
- Line 56 — "Flip camera" `Button` → add `accessibilityLabel: "Flip camera"`
- Line 60 — "Torch toggle" `Button` → add `accessibilityLabel: "Toggle torch"`
- Line 118 — "Done" `Button` → add `accessibilityLabel: "Done"`
- Line 129 — "Save" `Button` → add `accessibilityLabel: "Save clip"`
- Line 151 — "Retake" `Button` → add `accessibilityLabel: "Retake"`

### TrimView.swift
- Line 37 — "Cancel" `Button` → add `accessibilityLabel: "Cancel trim"`
- Line 39 — "Save" `Button` → add `accessibilityLabel: "Save trim"`
- Line 49 — "Play/Pause" `Button` → add `accessibilityLabel: "Play or pause"`

### CalendarView.swift
- Line 96 — `Image(systemName: "sparkles")` AI Highlights button → `accessibilityLabel: "AI Highlights"`
- Line 99 — `Image(systemName: "globe")` Public Feed button → `accessibilityLabel: "Public feed"`
- Line 102 — `Image(systemName: "magnifyingglass")` Search button → `accessibilityLabel: "Search clips"`
- Line 105 — `Image(systemName: "rectangle.stack")` Month Browser button → `accessibilityLabel: "Browse by month"`
- Line 108 — `Image(systemName: "square.and.arrow.up")` Export button → `accessibilityLabel: "Export options"`

### PlaybackView.swift
- Line 121 — Close/dismiss `Button` → add `accessibilityLabel: "Close"`
- Line 133 — Export `Button` → add `accessibilityLabel: "Export to Camera Roll"`
- Line 143 — Trim `Button` → add `accessibilityLabel: "Trim clip"`
- Line 150 — Delete `Button` → add `accessibilityLabel: "Delete clip"`
- Line 157 — Social share `Button` → add `accessibilityLabel: "Share with friends"`
- Line 185 — Title edit `Button` → add `accessibilityLabel: "Edit title"`
- Line 210 — Speed picker `Button` → add `accessibilityLabel: "Playback speed"` + `accessibilityHint: "Swipe up or down to change playback speed"`
- Lines 229-249 — All speed option `Button`s → add per-option labels: "0.5x", "1x", "1.5x", "2x", "3x"

### SettingsView.swift
- Line 29 — Close `Button` → add `accessibilityLabel: "Close settings"`
- Line 50 — Profile row icon → add `accessibilityLabel: "Profile"`
- Line 52 — iCloud sync row icon → add `accessibilityLabel: "iCloud sync"`
- Line 56 — Export row icon → add `accessibilityLabel: "Export"`
- Line 60 — AI Features row icon → add `accessibilityLabel: "AI features"`
- Line 64 — Integrations row icon → add `accessibilityLabel: "Integrations"`
- Line 68 — Help row icon → add `accessibilityLabel: "Help"`
- Line 72 — Privacy Policy row icon → add `accessibilityLabel: "Privacy policy"`

### ContentView.swift
- Line 58 — Settings `Image` button → add `accessibilityLabel: "Settings"`
- Line 62 — AI Highlights `Image` button → add `accessibilityLabel: "AI Highlights"`
- Line 65 — Record icon → add `accessibilityLabel: "Record"`
- Line 69 — Calendar icon → add `accessibilityLabel: "Calendar"`
- Line 73 — On This Day icon → add `accessibilityLabel: "On this day"`
- Line 77 — Export icon → add `accessibilityLabel: "Export"`
- Line 79 — Settings `Button` → add `accessibilityLabel: "Settings"`
- Line 87 — Record `Image` → add `accessibilityLabel: "Record"`

### AIHighlightsView.swift
- Line 54 — "Generate My Reel" `Button` → add `accessibilityLabel: "Generate my reel"`
- Line 130 — "Analyze Now" `Button` → add `accessibilityLabel: "Analyze now"`

### FreemiumEnforcementView.swift — CRITICAL (trapping unlabeled buttons)
- Line 35 — First "Upgrade" `Button` → add `accessibilityLabel: "Upgrade to unlock"`
- Line 44 — "Maybe Later" `Button` → add `accessibilityLabel: "Maybe later"`
- Line 52 — Upgrade `Button` (crown icon) → add `accessibilityLabel: "Upgrade to memories"`
- Line 57 — "Maybe Later" `Button` → add `accessibilityLabel: "Maybe later"`
- Line 75 — "Upgrade" `Button` (clock icon) → add `accessibilityLabel: "Upgrade to extend recording time"`
- Line 84 — "Upgrade" `Button` → add `accessibilityLabel: "Upgrade"`
- Line 93 — Upgrade `Button` → add `accessibilityLabel: "Upgrade"`

### OnboardingView.swift
- Line 32 — "Back" `Button` → add `accessibilityLabel: "Back"`
- Line 37 — "Next" `Button` → add `accessibilityLabel: "Next"`
- Line 47 — "Back" `Button` → add `accessibilityLabel: "Back"`
- Line 52 — "Next" `Button` → add `accessibilityLabel: "Next"`
- Line 62 — "Back" `Button` → add `accessibilityLabel: "Back"`
- Line 67 — "Next" `Button` → add `accessibilityLabel: "Next"`
- Line 80 — "Open Settings" `Button` → add `accessibilityLabel: "Open settings"`
- Line 93 — "Start Your Year" `Button` → add `accessibilityLabel: "Start your year"`

### PrivacyLockView.swift
- Line 93 — Backspace/delete `Button` → add `accessibilityLabel: "Delete digit"` + `accessibilityHint: "Removes the last entered digit"`
- Line 100 — Digit keypad `Button` (0) → add `accessibilityLabel: "Digit 0"` + `accessibilityHint: "Enters digit 0"`
- Line 110 — Digit keypad `Button` (1) → add `accessibilityLabel: "Digit 1"`
- Line 114 — Digit keypad `Button` (2) → add `accessibilityLabel: "Digit 2"`

### PasscodeSetupView.swift
- Line 93 — Backspace/delete `Button` → add `accessibilityLabel: "Delete digit"`
- Line 100 — Digit keypad `Button` (0) → add `accessibilityLabel: "Digit 0"`
- Line 110 — Digit keypad `Button` (1) → add `accessibilityLabel: "Digit 1"`
- Line 114 — Digit keypad `Button` (2) → add `accessibilityLabel: "Digit 2"`

### ErrorStatesView.swift
- Line 25 — "Open Settings" `Button` (CameraPermissionDeniedView) → add `accessibilityLabel: "Open camera settings"`
- Line 25 — "Open Settings" `Button` (MicrophonePermissionDeniedView) → add `accessibilityLabel: "Open microphone settings"`
- Line 23 — "OK" `Button` (StorageFullView) → add `accessibilityLabel: "OK"`
- Line 27 — "Try Again" `Button` (ClipSaveFailedView) → add `accessibilityLabel: "Try again"`
- Line 27 — "Try Again" `Button` (TrimSaveFailedView) → add `accessibilityLabel: "Try again"`
- Line 23 — "OK" `Button` (TrimStorageFullView) → add `accessibilityLabel: "OK"`
- Line 27 — "Open Settings" `Button` (ExportFailedView) → add `accessibilityLabel: "Open settings"`
- Line 66 — "Record your first moment" `Button` (EmptyCalendarView) → add `accessibilityLabel: "Record your first moment"`
- Line 71 — Secondary action `Button` (EmptyCalendarView) → add `accessibilityLabel: "Learn more"`

### CrossDeviceSyncView.swift
- Line 33 — Sync button → add `accessibilityLabel: "Sync now"`
- Line 53 — Add device `Button` → add `accessibilityLabel: "Add device"`
- Lines 71,74,77 — Sync toggle `Button`s → add `accessibilityLabel: "Sync toggle for [device name]"`

### PrivacySettingsView.swift
- Line 22 — "Sharing History" row → add `accessibilityLabel: "Sharing history"`
- Line 25 — Row → add appropriate label based on context
- Line 33 — "Close Circles" row → add `accessibilityLabel: "Close circles"`
- Line 35 — "Collaborative Albums" row → add `accessibilityLabel: "Collaborative albums"`

### CloseCircleView.swift
- Line 29 — "Create Close Circle" `Button` → add `accessibilityLabel: "Create close circle"`
- Line 32 — "Cancel" `Button` → add `accessibilityLabel: "Cancel"`
- Lines 40,45,50 — Circle row icon `Image`s → add `accessibilityLabel: "Circle member"`

### CommunityView.swift
- Line 44 — "Blink to Friends" `Button` → add `accessibilityLabel: "Blink to friends"`
- Line 53 — "Create Collaborative Album" `Button` → add `accessibilityLabel: "Create collaborative album"`
- Line 69 — "Join Collaborative Album" `Button` → add `accessibilityLabel: "Join collaborative album"`
- Line 73 — "Share to Public Feed" `Button` → add `accessibilityLabel: "Share to public feed"`
- Line 82 — "Community Guidelines" `Button` → add `accessibilityLabel: "Community guidelines"`

### PublicFeedView.swift
- Line 24 — Back `Button` → add `accessibilityLabel: "Back"`
- Line 26 — Share `Button` → add `accessibilityLabel: "Share"`
- Line 57 — Refresh `Button` → add `accessibilityLabel: "Refresh feed"`
- Line 106 — Feed item icon → add `accessibilityLabel: "Posted by [username]"`

### PricingView.swift
- Line 25 — Dismiss `Button` → add `accessibilityLabel: "Dismiss"`
- Line 44 — Subscribe `Button` → add `accessibilityLabel: "Subscribe"`
- Lines 65,67,70,73 — Tier `Button`s → add `accessibilityLabel: "Select [tier name] plan"`
- Lines 81,84,89 — "Get Started"/"Subscribe" `Button`s → add `accessibilityLabel: "Get started with [tier name]"`
- Lines 119,131,145 — Tier feature checkmark `Button`s → add `accessibilityLabel: "[Feature] included in [tier]"`

### SubscriptionsView.swift
- Lines 29,31,34 — Row icon `Image`s → add `accessibilityLabel: "[Plan name]"`
- Lines 42,44,47 — Row icon `Image`s → add `accessibilityLabel: "[Plan name]"`
- Lines 49,52,55 — Action `Button`s → add `accessibilityLabel: "[Action] for [plan]"`

### SocialShareSheet.swift
- Line 21 — "Copy Link" `Button` → add `accessibilityLabel: "Copy link"`
- Line 28 — "Share via Messages" `Button` → add `accessibilityLabel: "Share via messages"`

### CameraPreview.swift
- Lines 28,32,51 — `Button`s → add appropriate `accessibilityLabel` per button purpose

### MonthBrowserView.swift
- Lines 41,47,54,61,68,75 — Month navigation `Button`s → add `accessibilityLabel: "Go to [month name]"`
- Lines 83,111,116 — Action `Button`s → add appropriate labels

### SearchView.swift
- Line 37 — Search `Image` icon → add `accessibilityLabel: "Search"`
- Line 49 — Clear `Button` → add `accessibilityLabel: "Clear search"`

### CollaborativeAlbumView.swift
- Lines 25,31 — `Image` icons → add appropriate labels
- Line 41 — Action `Button` → add `accessibilityLabel: "Collaborate"`

### DeepAnalysisView.swift
- Lines 33,37,41 — `Image` icons → add `accessibilityLabel: "[Analysis type]"`
- Line 57 — Action `Button` → add `accessibilityLabel: "Start analysis"`
- Line 89 — Action `Button` → add `accessibilityLabel: "View insights"`
- Line 97 — Action `Button` → add `accessibilityLabel: "Generate report"`

### OnThisDayView.swift
- Line 37 — `Image` icon → add `accessibilityLabel: "On this day"`

### YearInReviewCompilationView.swift
- Lines 48,55,65,71 — `Button`s → add appropriate labels
- Line 76 — Dismiss `Button` → add `accessibilityLabel: "Dismiss"`

### StorageDashboardView.swift
- Lines 28,30,43,46,49 — `Image` icons → add `accessibilityLabel: "[Storage type]"`
- Lines 63,65,76,82,84 — `Image` icons → add `accessibilityLabel: "[Section name]"`

---

## Priority 2: Wrap All Animations in Reduce Motion Checks

7 animation instances play continuously without checking `accessibilityReduceMotion`. Users with motion sensitivity are forced to see looping animations.

### CustomGraphics.swift
- Line 285 — `ViewfinderGraphic` `.animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: isAnimating)` → wrap in `if !accessibilityReduceMotion { withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) { isAnimating = true } }`
- Line 452 — `ApertureGraphic` `.animation(.spring(response: 0.8, dampingFraction: 0.6).repeatForever(autoreverses: true), value: isOpen)` → wrap in `if !accessibilityReduceMotion { }`
- Line 285 (ClipCompositionGraphic offset) — `withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true))` → wrap in `if !accessibilityReduceMotion { }`
- YearInReviewGraphic `withAnimation(.easeOut(duration: 1.5))` for progress ring → wrap in `if !accessibilityReduceMotion { }`

### PrivacyLockView.swift
- Line 362 — `PrivacyLockIconGraphic` `.animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: isAnimating)` → wrap in `if !accessibilityReduceMotion { }`

### YearInReviewCompilationView.swift
- Line 107 — `withAnimation(.easeOut(duration: 2))` for progress ring → wrap in `if !accessibilityReduceMotion { }`

### RecordView.swift
- Line 254 — Countdown `animation(.easeInOut(duration: 0.3), value: countdownValue)` → wrap in `if !accessibilityReduceMotion { withAnimation(.easeInOut(duration: 0.3)) { countdownValue = newValue } }`

### OnboardingView.swift (ApertureGraphic trigger)
- Page 2 ApertureGraphic: Add `.onAppear { if !accessibilityReduceMotion { isOpen = true } }` — fixes Brand finding #14 (animation never triggers for motion-OK users, and respects Reduce Motion for sensitive users)

---

## Priority 3: Migrate All Fonts to Dynamic Type (Font.TextStyle)

19+ view files use `.font(.system(size:))` with fixed sizes. This breaks Dynamic Type entirely — text cannot scale when users enable accessibility text sizing. Theme.swift font tokens also exist but use the wrong API.

### Theme.swift
- Lines defining font tokens (`fontLargeTitle`, `fontTitle1`, `fontTitle2`, `fontTitle3`, `fontHeadline`, `fontBody`, `fontCallout`, `fontSubheadline`, `fontFootnote`, `fontCaption1`, `fontCaption2`) — change from `.system(size:)` to `Font.TextStyle` based definitions using `.scaled()` or direct `Font.TextStyle`

### AIHighlightsView.swift
- Lines 102,106,120,122,154,162,167,184,186,190,194,206,208,212,240,242,246 — replace all `.font(.system(size:))` with `.font(.headline)`, `.font(.subheadline)`, `.font(.body)`, etc.

### CommunityView.swift
- Lines 91,97,100 — replace `.font(.system(size:))` with `.font(.body)`, `.font(.caption)`

### PublicFeedView.swift
- Lines 75,77 — replace `.font(.system(size:))` with `.font(.body)`

### FreemiumEnforcementView.swift
- Lines 24,40,42,49,67,71,85,87 — replace all `.font(.system(size:))` with `Font.TextStyle`

### CalendarView.swift
- Lines 228,232,239,242,261,271,284,310,316,320 — replace all fixed `.font(.system(size:))` with `Font.TextStyle`

### PlaybackView.swift
- Lines 195,197,199,210,245,279,281,285,289 — replace all fixed font sizes with `Font.TextStyle`

### PricingView.swift
- Lines 89,107,109,111,113,133,135,137,139,141,143,170,172,174,176,178,180 — replace all `.font(.system(size:))` with `Font.TextStyle`

### DeepAnalysisView.swift
- Line 83 — replace `.font(.system(size:))` with `Font.TextStyle`

### OnboardingView.swift
- Lines 97,98,127,128,157,158,187,188 — replace all `.font(.system(size:))` with `Font.TextStyle`

### CustomGraphics.swift
- All preview graphics font sizes → use `Font.TextStyle`

### YearInReviewCompilationView.swift
- Lines 86,88,96,98,114,116,168,170,172,174,212,214,216,218,226,228,232,234 — replace all fixed font sizes with `Font.TextStyle`

### StorageDashboardView.swift
- Lines 34,36,38,52,54,56,58,70,72,86,88,90,92 — replace all `.font(.system(size:))` with `Font.TextStyle`

### ErrorStatesView.swift
- Lines 34,36,38,56,58,60,78,80,82,100,102,104,120,122,124,142,144,146,164,166,168,188,190,192,214,216,218 — replace all fixed font sizes with `Font.TextStyle`

### SettingsView.swift
- Lines 35,37,39,41,43,45,47 — replace fixed font sizes with `Font.TextStyle`

### TrimView.swift
- Lines 63,65,67 — replace fixed font sizes with `Font.TextStyle`

### SearchView.swift
- All fixed font sizes → replace with `Font.TextStyle`

### SubscriptionsView.swift
- All fixed font sizes → replace with `Font.TextStyle`

### CollaborativeAlbumView.swift
- Line 50 — replace `.font(.system(size:))` with `Font.TextStyle`

---

## Priority 4: Fix FreemiumEnforcementView — The Accessibility Trap

This view is CRITICAL for VoiceOver users. It has 7 completely unlabeled buttons AND the user cannot escape. Cross-cutting issue confirmed by Accessibility + Brand agents.

### FreemiumEnforcementView.swift
- Add `accessibilityLabel` to all 7 buttons (see Priority 1)
- Add a dismiss mechanism: either a close `Button` (X in top-right corner) or a swipe-to-dismiss gesture that VoiceOver can activate
- Recommended: add `Button { dismiss() } label: { Image(systemName: "xmark") }` in top-right with `accessibilityLabel: "Dismiss"` and wrap the sheet in a `.interactiveDismissDisabled(false)` or add explicit dismiss support

### ContentView.swift
- Line 49-51 — Fix `onAppear` re-triggering: add `@AppStorage("hasSeenFreemiumEnforcementToday") private var hasSeenFreemiumEnforcementToday: Bool = false` and check `if !hasSeenFreemiumEnforcementToday { showFreemiumEnforcement = true }` — only trigger once per session, not on every appear
- When FreemiumEnforcementView is dismissed, set `hasSeenFreemiumEnforcementToday = true`

---

## Priority 5: Color Contrast Fixes and Semantic Color Migration

### Theme.swift / color contrast
- Fix `textQuaternary = Color(hex: "555555")` on dark backgrounds — contrast ratio ~3.1:1 FAILS WCAG AA (4.5:1 required for normal text). Either lighten to ~6e6e6e (5.7:1 on 0a0a0a) or reserve "555555" only for text on light backgrounds
- Audit all uses of "555555", "8a8a8a", and "c0c0c0" against their backgrounds to ensure minimum 4.5:1 contrast

### DeepAnalysisService.swift
- Lines 301-318 — `colorName()` function returns non-semantic names ("warm", "cool", "neutral") → return semantic names: "warmNeutral", "coolNeutral", "neutralGray", "lightBackground", "darkForeground", "accentRed", "primaryGreen", "primaryBlue"

### CustomGraphics.swift
- Lines 301,318,329,344 — Colors referenced as "white", "black", "red", "green", "blue", "yellow", "warm", "cool", "neutral" → replace with semantic Theme token names or specific hex values mapped to accessibility-meaningful names

---

## My Top 5 for Unified Plan:

1. **[CRITICAL — Accessibility + Brand] FreemiumEnforcementView trap** — Add `accessibilityLabel` to all 7 buttons AND add a dismiss mechanism AND fix `ContentView.onAppear` to not re-trigger every appearance. File: `FreemiumEnforcementView.swift` (all 7 buttons at lines 35,44,52,57,75,84,93) + `ContentView.swift:49-51`. This is both an accessibility catastrophe (VoiceOver users trapped with unlabeled buttons) and a UX critical (free users permanently stuck).

2. **[CRITICAL — Accessibility] 119 missing accessibility labels** — Add `accessibilityLabel` to every `Button` and `Image` used as a button across all 30+ view files. This is pure additive work — zero risk, maximum impact. Start with the highest-traffic screens (RecordView, CalendarView, PlaybackView, SettingsView, ContentView) and work outward. See Priority 1 for complete per-line inventory.

3. **[HIGH — Accessibility + Architect + Brand] Theme.swift tokens unused** — Migrate all `Color(hex:)` calls across all 40 view files to use `Theme.*` semantic color tokens. Simultaneously fixes: Accessibility color contrast issues (by routing through token system), Architect spacing/radius inconsistencies (by routing through token system), and Brand visual identity drift. Also migrate all `.font(.system(size:))` to `Font.TextStyle` for Dynamic Type. This is the single highest-leverage design system fix.

4. **[HIGH — Accessibility] 7 animations without Reduce Motion checks** — Wrap all `repeatForever` and decorative animations in `if !accessibilityReduceMotion { }`. Files: `CustomGraphics.swift:285,452`, `PrivacyLockView.swift:362`, `YearInReviewCompilationView.swift:107`, `RecordView.swift:254`, `OnboardingView.swift` (ApertureGraphic trigger). This is a WCAG compliance requirement — continuous looping animations can trigger vestibular disorders.

5. **[HIGH — Accessibility] Dynamic Type broken across 19+ files** — Replace all `.font(.system(size:))` with `Font.TextStyle` variants in: AIHighlightsView, CommunityView, PublicFeedView, FreemiumEnforcementView, CalendarView, PlaybackView, PricingView, DeepAnalysisView, OnboardingView, YearInReviewCompilationView, StorageDashboardView, ErrorStatesView, SettingsView, TrimView, SearchView, SubscriptionsView, CollaborativeAlbumView, CustomGraphics preview sections. Theme.swift font tokens should be the canonical source of truth but must use `Font.TextStyle` API, not `.system(size:)`.

---

## Phase 2 Cross-Cutting Priorities (Informational for Unified Plan)

These intersect with other agents' work and should be coordinated:

- **PrivacyLockView keypad buttons** — 8 buttons (lines 93,100,110,114 in both PrivacyLockView and PasscodeSetupView) need `accessibilityLabel` AND the view needs a proper ViewModel (Architect), force-unwraps need fixing (SwiftUI), and passcode needs Keychain storage (Architect/Platform). Accessibility owns the labels; coordinate with Architect/SwiftUI for structural fixes.
- **Color contrast "555555"** — `Theme.swift` textQuaternary fails WCAG AA at ~3.1:1. Architect/Brand should approve the replacement color value; Accessibility should verify the fix passes.
- **ApertureGraphic animation** — OnboardingView page 2 aperture never opens (Brand) AND it plays without Reduce Motion checks (Accessibility). Fix requires: (1) triggering `isOpen = true` in `.onAppear`, (2) wrapping in `if !accessibilityReduceMotion { }`. One edit, two fixes.
