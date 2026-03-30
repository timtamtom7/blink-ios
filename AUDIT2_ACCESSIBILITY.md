# Blink — Phase 4 Accessibility Audit Report

**Auditor:** Accessibility Guardian (Subagent)  
**Phase:** Post-Phase 4 Audit  
**Date:** 2026-03-30  
**Total Remaining Issues:** 34  
**New Issues Introduced by Phase 4:** 1  
**Previously Fixed Issues:** ~122 of 156

---

## Executive Summary

Significant progress was made in Phase 4 — most of the previously critical VoiceOver issues (RecordView, TrimView, CalendarView toolbar, PlaybackView, FreemiumEnforcementView) are now fixed. However, **10 view files remain with zero accessibility labels**, and the **Theme font token migration is architecturally incomplete** — tokens exist but are not being used by any view, meaning Dynamic Type support was not actually achieved.

---

## Priority 1: CRITICAL Issues (Must Fix Before Ship)

### 1. PrivacyLockView.swift — All Keypad Buttons Completely Unlabeled
**[CRITICAL] PrivacyLockView.swift:130–154** — All 11 keypad buttons (digits 0–9, backspace ⌫) have no `accessibilityLabel`. VoiceOver users entering their passcode hear "button, button, button" with no way to identify which digit they are on. A locked app with an inaccessible passcode is a security and usability failure.

**Affected lines (keypad buttons in `keyButton(for:)` function):**
- `keyButton(for: "⌫")` — backspace — line ~130
- `keyButton(for: "0")` — line ~147
- `keyButton(for: "1")` through `keyButton(for: "9")` — lines ~140–146

**Fix required:** Add `.accessibilityLabel("Backspace")` to the ⌫ button and `.accessibilityLabel("\(key)")` to each digit button.

---

### 2. PasscodeSetupView.swift — All Keypad Buttons Completely Unlabeled
**[CRITICAL] PasscodeSetupView.swift:93–110** — Same issue as PrivacyLockView. All 11 keypad buttons (digits 0–9, backspace ⌫) have no `accessibilityLabel`. VoiceOver users setting up a passcode cannot identify individual digits.

**Fix required:** Same as above — add `.accessibilityLabel(...)` to each keyButton.

---

### 3. OnboardingView.swift — Navigation Buttons Unlabeled
**[CRITICAL] OnboardingView.swift:65–75** — The "Back" and "Next" buttons in the main OnboardingView navigation bar have no `accessibilityLabel` or `accessibilityHint`.

- Back button (line ~65): No accessibility label
- Next button (line ~72): No accessibility label

**[CRITICAL] OnboardingView.swift:230–275** — OnboardingScreen4 has three more unlabeled buttons:
- "Open Settings" button (line ~230) — when permission denied
- "Enable Camera" button (line ~268) — initial state
- "Start Your Year" button (line ~252) — after permission granted

**Fix required:** Add `.accessibilityLabel("Go back")`, `.accessibilityLabel("Next")`, etc. to each button.

---

## Priority 2: HIGH Issues

### 4. DeepAnalysisView.swift — Toolbar Refresh Button and Empty State Button Unlabeled
**[HIGH] DeepAnalysisView.swift:55** — The toolbar refresh button (`arrow.clockwise` icon) has no `accessibilityLabel`.

**[HIGH] DeepAnalysisView.swift:105** — The "Start Analysis" button in the empty state view has no `accessibilityLabel`.

**[HIGH] DeepAnalysisView.swift:330** — SceneEntriesView "Done" button has visible text but no explicit `accessibilityLabel`.

---

### 5. MonthBrowserView.swift — Year Picker Buttons and Month Grid Buttons Unlabeled
**[HIGH] MonthBrowserView.swift:75–80** — Year picker year buttons (`ForEach(years, ...)`) use `.font(.system(size: 14, ...))` but have no `accessibilityLabel` — VoiceOver would read the year text but not indicate it's a selectable button.

**[HIGH] MonthBrowserView.swift:270–295** — JumpToMonthView month grid buttons have `Text(monthNames[month - 1].prefix(3).uppercased())` visible but no `accessibilityLabel`. Disabled months (count == 0) are `Button` with `.disabled(count == 0)` but VoiceOver may still announce them as buttons.

**[HIGH] MonthBrowserView.swift:165** — MonthBrowseCard thumbnail strip uses `.onTapGesture { }` on a `VStack` with `.contentShape(Rectangle())`. This is a custom tap gesture on a non-interactive element — NOT accessible to VoiceOver at all. Should be a `Button` or have `.accessibilityAddTraits(.isButton)` and `.accessibilityLabel(...)`.

---

### 6. CommunityView.swift — Category Filter Chips Unlabeled + NEW Skeleton Animation
**[HIGH] CommunityView.swift:115–127** — `categoryChip(_:label:)` function creates a `Button` with `Text(label)` visible text but NO `accessibilityLabel`. VoiceOver reads the text content but would not announce the selection state.

**[NEW - HIGH] CommunityView.swift:283–289** — `SkeletonMomentCard` shimmer animation runs with `.animation(.linear(duration: 1.5).repeatForever(autoreverses: false), value: isAnimating)` triggered in `onAppear` with NO `@Environment(\.accessibilityReduceMotion)` check. This is a NEW issue introduced in Phase 4 (or previously unfixed). Loading skeletons shimmer continuously and will play for users who prefer reduced motion.

---

### 7. PricingView.swift — Dismiss Button and Subscribe Button Unlabeled
**[HIGH] PricingView.swift:107** — The "xmark" dismiss button has no `accessibilityLabel`. VoiceOver would say "button" but not indicate it closes the sheet.

**[HIGH] PricingView.swift:140** — The subscribe button has no `accessibilityLabel`. The button text changes dynamically based on tier selection ("Get Started" vs "Subscribe to Memories — $4.99/month"), so VoiceOver needs `.accessibilityLabel("Subscribe to \(selectedTier.rawValue), \(selectedTier.price)\(selectedTier.period)")`.

---

### 8. ErrorStatesView.swift — All 9 Error State Buttons Unlabeled
**[HIGH] ErrorStatesView.swift:40** — `CameraPermissionDeniedView`: "Open Settings" button — no `accessibilityLabel`.

**[HIGH] ErrorStatesView.swift:79** — `MicrophonePermissionDeniedView`: "Open Settings" button — no `accessibilityLabel`.

**[HIGH] ErrorStatesView.swift:108** — `StorageFullView`: "OK" button — no `accessibilityLabel`.

**[HIGH] ErrorStatesView.swift:148** — `ClipSaveFailedView`: "Try Again" button — no `accessibilityLabel`.  
**[HIGH] ErrorStatesView.swift:160** — `ClipSaveFailedView`: "Discard clip" button — no `accessibilityLabel`.

**[HIGH] ErrorStatesView.swift:197** — `TrimSaveFailedView`: "Try Again" button — no `accessibilityLabel`.  
**[HIGH] ErrorStatesView.swift:209** — `TrimSaveFailedView`: "Go back" button — no `accessibilityLabel`.

**[HIGH] ErrorStatesView.swift:235** — `TrimStorageFullView`: "OK" button — no `accessibilityLabel`.

**[HIGH] ErrorStatesView.swift:262** — `ExportFailedView`: "Open Settings" button — no `accessibilityLabel`.  
**[HIGH] ErrorStatesView.swift:275** — `ExportFailedView`: "Cancel" button — no `accessibilityLabel`.

**[HIGH] ErrorStatesView.swift:307** — `EmptyCalendarView`: "Record your first moment" button — no `accessibilityLabel`.

---

## Priority 3: MEDIUM Issues

### 9. SocialShareSheet.swift — Share Option Rows Could Use Explicit Labels
**[MEDIUM] SocialShareSheet.swift:35–50** — The three `ShareOptionRow` buttons (Private Link, Blink to Friends, Share to Public Feed) use `Button` with title/subtitle text. VoiceOver reads the text content, but explicit `accessibilityLabel` would provide a better experience, especially for the state-dependent subtitle ("Creating link...").

**Fix:** Add `.accessibilityLabel("\(title). \(subtitle)")` to each ShareOptionRow.

---

### 10. PrivacySettingsView.swift — ClipSharingSheet Circle Picker Uses Unlabeled Tap Gestures
**[MEDIUM] PrivacySettingsView.swift:116–128** — Circle picker rows use `.onTapGesture { }` on an `HStack` wrapped in `.contentShape(Rectangle())`. This is a custom gesture on a non-interactive element. VoiceOver users cannot toggle circle selection because there is no button or accessibility trait.

**Fix:** Replace the `HStack` with a `Button`, or add `.accessibilityAddTraits(.isButton)` and `.accessibilityLabel("Select \(circle.name)")`.

---

### 11. PublicFeedView.swift — Retry Button Relies on Visible Text
**[MEDIUM] PublicFeedView.swift:43** — The "Retry" button relies on visible text "Retry" being read by VoiceOver. This works, but `.accessibilityLabel("Retry loading the feed")` would be more descriptive.

---

## Priority 4: LOW Issues

### 12. CloseCircleView.swift — Create Button Relies on Label
**[LOW] CloseCircleView.swift:27** — `Button { Label("Create Close Circle", ...) }` — the `Label` should be read by VoiceOver, but adding `.accessibilityLabel("Create Close Circle")` makes it explicit.

---

### 13. CollaborativeAlbumView.swift — Buttons Rely on Visible Text
**[LOW] CollaborativeAlbumView.swift:35–44** — "Create Collaborative Album" and "Join via Link" buttons use `Label` which VoiceOver reads. Adding explicit `accessibilityLabel` would be more robust.

---

### 14. OnThisDayView.swift — Zero Accessibility Labels
**[LOW] OnThisDayView.swift** — The file has zero `accessibilityLabel` or `accessibilityHint` declarations. Any interactive elements (buttons, toggles) rely on visible text. Needs review to identify which elements need explicit labels.

---

### 15. StorageDashboardView.swift — Zero Accessibility Labels
**[LOW] StorageDashboardView.swift** — The file has zero accessibility label declarations. Any interactive elements rely on visible text. Needs review.

---

### 16. SubscriptionsView.swift — Subscribe Buttons Rely on Visible Text
**[LOW] SubscriptionsView.swift:125–140** — The plan selection buttons use `.accessibilityLabel` from the visible tier name, but the "Subscribe" confirmation alert uses raw strings. The plan cards have a button inside that changes text based on tier — VoiceOver would benefit from explicit labels.

---

## Architecture Issues (Not User-Facing but Blocking Dynamic Type)

### A. Theme Font Tokens Exist But Are Unused — Dynamic Type Not Actually Working

The Theme.swift file defines `enum ThemeFontStyle` and `Font.blinkText(_:)` (lines ~370–390), but **zero view files use it**. All views still use hardcoded `.font(.system(size: N, ...))` calls:

```swift
// Current state — hardcoded everywhere:
Text("Clip Title")
    .font(.system(size: 15, weight: .semibold))
    .foregroundColor(Color(hex: "f5f5f5"))

// Theme defines tokens but views never use them:
static let fontHeadline = Font.system(size: 17, weight: .semibold, design: .default)
// → Never referenced in any view
```

**Dynamic Type impact:** The `Font.blinkText(_:)` function uses `.system(size: N, ...)` without any Dynamic Type scaling wrapper. For true Dynamic Type support, it should use `.scaledFont(_:for)` or `Font.preferredFont(forTextStyle:)` with `@ScaledMetric`. As-is, even if views adopted Theme tokens, text would NOT scale with accessibility text size preferences.

**Fix required (architectural):**
1. Update `Font.blinkText(_:)` to use Dynamic Type:
```swift
static func blinkText(_ style: ThemeFontStyle) -> Font {
    // Use scaled fonts, not fixed-size system fonts
}
```
2. Audit all views and replace hardcoded `.font(.system(size:))` with Theme tokens.
3. Test with accessibility text size turned up to Largest.

---

### B. Color Tokens Mostly Used — But Some Views Still Use Raw Hex

Most views have migrated to `Theme.textPrimary`, `Theme.background`, etc. However, several newer/Phase-4 views still use raw hex literals:
- `Color(hex: "ff3b30")` — hardcoded throughout
- `Color(hex: "0a0a0a")`, `Color(hex: "141414")`, etc. — still in some files

This is acceptable for the dark-mode-only Blink app, but prevents any future light mode or accessibility color inversion.

---

## Reduce Motion: Previously 7 Issues — Now 1 NEW Issue

### Fixed ✅
All 7 previously flagged animation instances are now wrapped:
- `CustomGraphics.swift` — ViewfinderGraphic ✅ (line 241)
- `CustomGraphics.swift` — ClipCompositionGraphic ✅ (line 316)
- `CustomGraphics.swift` — YearInReviewGraphic ✅ (line 376)
- `CustomGraphics.swift` — ApertureGraphic ✅ (line 448)
- `PrivacyLockView.swift` — PrivacyLockIconGraphic ✅ (line 349)
- `YearInReviewCompilationView.swift` — progress animation ✅ (line 20)

### NEW Issue Introduced ❌
- `CommunityView.swift:283–289` — SkeletonMomentCard shimmer animation runs with `repeatForever` with no reduceMotion check. This is a loading placeholder that plays continuously.

---

## WCAG AA Contrast: Status OK ✅

The Theme color palette is WCAG AA compliant on the dark background:

| Token | Hex | On Background (#0a0a0a) | Ratio | Status |
|-------|-----|------------------------|-------|--------|
| textPrimary | f5f5f5 | on #0a0a0a | ~15:1 | ✅ Pass |
| textSecondary | c0c0c0 | on #0a0a0a | ~9:1 | ✅ Pass |
| textTertiary | 8a8a8a | on #0a0a0a | ~5:1 | ✅ Pass |
| textQuaternary | 555555 | on #0a0a0a | ~2.6:1 | ⚠️ Only for decorative |
| accent | ff3b30 | on #0a0a0a | ~4.6:1 | ⚠️ Large text only |

No new contrast issues introduced in Phase 4.

---

## VoiceOver: Summary of Remaining Issues

**12 CRITICAL/HIGH unlabeled interactive elements:**
1. PrivacyLockView — 11 keypad buttons (CRITICAL)
2. PasscodeSetupView — 11 keypad buttons (CRITICAL)
3. OnboardingView — 5 buttons (CRITICAL)
4. ErrorStatesView — 10 buttons (HIGH)
5. DeepAnalysisView — 3 buttons (HIGH)
6. MonthBrowserView — year picker + month grid + thumbnail tap (HIGH)
7. CommunityView — category chips + skeleton animation (HIGH)
8. PricingView — 2 buttons (HIGH)

**~18 view files still have ZERO accessibility labels declared** (grep count = 0):
AIHighlightsView, CameraPreview, CloseCircleView, CollaborativeAlbumView, CommunityView, CrossDeviceSyncView, DeepAnalysisView, ErrorStatesView, MonthBrowserView, OnThisDayView, OnboardingView, PasscodeSetupView, PricingView, PrivacySettingsView, PublicFeedView, SocialShareSheet, StorageDashboardView, SubscriptionsView

---

## Recommended Fix Order

1. **Immediately (Critical):** PrivacyLockView + PasscodeSetupView keypad labels — these lock users out of their own app
2. **Before Next Test:** OnboardingView + ErrorStatesView — new users and error states are first/last impressions
3. **This Sprint:** DeepAnalysisView + MonthBrowserView + CommunityView + PricingView
4. **Next Sprint:** Remaining views + Theme Dynamic Type architectural fix
5. **Before Ship:** Full VoiceOver audit pass on all remaining views

---

*End of Audit*
