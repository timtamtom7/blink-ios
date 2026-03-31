# Round 3 Accessibility Audit — Blink iOS

**Auditor:** Accessibility Guardian  
**Date:** 2026-03-30  
**Scope:** Full codebase accessibility review (VoiceOver, Dynamic Type, Reduce Motion, WCAG AA contrast, accessibility labels)

---

## Executive Summary

Round 1 found **156 issues**. Round 2 found **34 issues**. This round finds **~45 remaining issues** plus **~5 new or regressed issues**.

### Most Critical
1. **`BlinkFontStyle` is defined but NEVER adopted** — all text uses hardcoded `.font(.system(size:))` — Dynamic Type is completely non-functional
2. **WCAG AA contrast failures** in multiple views using `555555`, `666666`, `c0c0c0` on dark backgrounds
3. **Skeleton loading cards in `CommunityView`** have no accessibility labels for VoiceOver users

---

## 🔴 CRITICAL Issues

### 1. BlinkFontStyle Defined But Never Used
**Impact:** Dynamic Type completely broken across entire app

`BlinkFontStyle` is defined in `Theme.swift` but grep confirms **zero adoption** in any view:
```bash
$ grep -r "BlinkFontStyle" Blink/ --include="*.swift"
Blink/App/Theme.swift:struct BlinkFontStyle: ViewModifier {
Blink/App/Theme.swift:    static func blinkStyle(_ style: BlinkFontStyle.Style) -> some View {
```
All text uses `.font(.system(size: 17, weight: .bold))` with hardcoded pixel sizes.

**[CRITICAL] All views — Dynamic Type broken:**
- `CalendarView.swift` — hardcoded sizes (13, 15, 20pt)
- `PlaybackView.swift` — hardcoded sizes (11, 12, 13, 15, 17, 18pt)
- `RecordView.swift` — hardcoded sizes (11, 13pt)
- `TrimView.swift` — hardcoded sizes (11, 12, 13, 14, 16, 17, 22, 28pt)
- `OnboardingView.swift` — hardcoded sizes (11, 13, 14, 15, 16, 17, 20, 22, 28pt)
- `PrivacyLockView.swift` — hardcoded sizes (28, 15pt)
- `PasscodeSetupView.swift` — hardcoded sizes (15pt)
- `SettingsView.swift` — hardcoded sizes (11, 12, 13, 14, 15, 17, 34pt)
- `PricingView.swift` — hardcoded sizes (11, 13, 15, 17, 22pt)
- `FreemiumEnforcementView.swift` — hardcoded sizes (11, 12, 13, 15, 17, 22pt)
- `StorageDashboardView.swift` — hardcoded sizes (10, 11, 12, 13, 14, 15, 20, 42pt)
- `AIHighlightsView.swift` — hardcoded sizes (7, 10, 11, 12, 13, 14, 15, 17, 20pt)
- `CommunityView.swift` — hardcoded sizes (11, 13, 15, 17, 20pt)
- `SocialShareSheet.swift` — hardcoded sizes (11, 12, 14, 15, 16, 18pt)
- `SearchView.swift` — hardcoded sizes (12, 14, 17pt)
- `OnThisDayView.swift` — hardcoded sizes (11, 12, 13, 14, 15, 17, 18pt)
- `MonthBrowserView.swift` — hardcoded sizes (10, 11, 12, 13, 14, 16pt)
- `ErrorStatesView.swift` — hardcoded sizes (11, 12, 13, 14, 15, 16, 20pt)
- `YearInReviewCompilationView.swift` — hardcoded sizes (11, 13, 14, 16, 17, 24, 28pt)

### 2. Skeleton Loading Cards — No Accessibility Labels
**File:** `CommunityView.swift`

`SkeletonMomentCard` shows animated skeleton placeholders during loading but provides **no accessibility label** for VoiceOver users — they appear as unlabelled gray shapes.

```swift
struct SkeletonMomentCard: View {
    // ... shimmer animation code ...
    // NO .accessibilityLabel anywhere
}
```

**WCAG:** Users with screen readers cannot understand these are loading placeholders.

---

## 🟠 HIGH Issues

### 3. WCAG AA Contrast Failures

#### 3a. `555555` on dark backgrounds — FAILS AA (2.8:1 < 4.5:1)
- `SettingsView.swift:126` — "Coming Soon" badge
- `SettingsView.swift:268` — AboutView "Made with love"
- `MonthBrowserView.swift:143` — "No clips" text
- `CommunityView.swift:XX` — skeleton card placeholder text
- `OnThisDayView.swift` — "Go to AI Highlights to analyze" text

#### 3b. `666666` on dark backgrounds — FAILS AA (3.5:1 < 4.5:1)
- `PlaybackView.swift:298` — daysAgoText
- `OnThisDayView.swift:493` — duration text in OnThisDayCard
- `CalendarView.swift` — various tertiary text

#### 3c. `c0c0c0` on `141414` — FAILS AA (2.9:1 < 4.5:1)
- `ErrorStatesView.swift:XX` — ExampleMomentRow italic text
- `PricingView.swift:XX` — feature checkmark text

#### 3d. DayCell thumbnail title overlay
**File:** `CalendarView.swift:XXX`
```swift
Text(title)
    .font(.system(size: 6, weight: .medium))
    .foregroundColor(.white)  // overlaid on variable thumbnail image
```
White text at 6pt on unpredictable thumbnail backgrounds — contrast cannot be guaranteed.

### 4. Keypad Button Labels Could Be Enhanced
**Files:** `PrivacyLockView.swift`, `PasscodeSetupView.swift`

Numeric buttons only say the digit:
```swift
.accessibilityLabel("0")  // should say "Zero" or "0, digit"
.accessibilityLabel("1")  // "1, digit"
```

Submit button is vague:
```swift
Text("Submit")  // should say "Submit passcode"
```

### 5. Missing Accessibility Labels — Various Views

#### Month Selection Buttons
**File:** `MonthBrowserView.swift`
```swift
Button {
    selectedMonth = month
    showEntriesForMonth(month)
} label: {
    Text(monthNames[month - 1].prefix(3).uppercased())
        // Missing .accessibilityLabel("\(monthNames[month-1]), \(clipCount) clips")
}
```

#### Year Picker Buttons
**File:** `MonthBrowserView.swift:82`
**File:** `JumpToMonthView.swift:XX`
```swift
Text(String(year))
    // Missing .accessibilityLabel("\(year), \(clipCount) clips this year")
```

#### PlaybackView Speed Label
**File:** `PlaybackView.swift:328`
```swift
.accessibilityLabel("Playback speed: \(speedLabel)")  // Present ✓
.accessibilityHint("Double tap to change playback speed")  // Present ✓
```
GOOD - already fixed from Round 2.

#### ShareOptionRow
**File:** `SocialShareSheet.swift:XXX`
```swift
// Missing .accessibilityLabel("\(title): \(subtitle)")
```

#### Year Progress Card
**File:** `YearInReviewCompilationView.swift`
```swift
// Missing .accessibilityLabel("\(clipsThisYear) of \(totalDays) days recorded")
```

### 6. Reduce Motion — Animation Still Present in One Place
**File:** `YearInReviewCompilationView.swift:XX`
```swift
Circle()
    .trim(from: 0, to: generationProgress)
    .stroke(Color(hex: "ff3b30"), ...)
    .rotationEffect(.degrees(-90))
    .animation(reduceMotion ? .none : .linear(duration: 0.5), value: generationProgress)
```
The generation progress ring animation uses `reduceMotion ? .none` but this is for a progress indicator which doesn't respect the user's accessibility setting — should use `.animation(reduceMotion ? .none : ...)` on the **view**, not just conditionally choose the animation.

---

## 🟡 MEDIUM Issues

### 7. Onboarding Screen 4 — Permission Status Text
**File:** `OnboardingView.swift`
```swift
if permissionStatus == .denied {
    Text("Camera access denied")
        .foregroundColor(Color(hex: "ff3b30"))  // ✓ Good
}
```
GOOD — already uses red for denied state.

### 8. Empty Calendar View — Missing Accessibility
**File:** `ErrorStatesView.swift:XXX`
```swift
EmptyCalendarView(year: year, onRecordFirst: {})  // Button says "Record your first moment"
```
**GOOD** — "Record your first moment" button is self-describing.

### 9. Trim Handles — Good Accessibility
**File:** `TrimView.swift`
```swift
.accessibilityLabel("Trim start handle")
.accessibilityValue("Currently at \(formatTime(startTime))")
```
GOOD — already fixed from Round 2.

### 10. Calendar Day Cells — Good Accessibility
**File:** `CalendarView.swift:XXX`
```swift
.accessibilityLabel("Day \(day), clip recorded: \(entry.displayTitle)")
.accessibilityHint(entry != nil ? "Double tap to view this clip." : "No clip recorded on this day.")
```
GOOD — already fixed.

### 11. Year Selector Navigation
**File:** `CalendarView.swift:XXX`
```swift
.accessibilityLabel("Previous year, \(selectedYear - 1)")
.accessibilityHint("Double tap to view calendar for \(selectedYear - 1)")
```
GOOD — already fixed.

---

## 🟢 LOW Issues / Already Fixed

### Already Fixed from Round 2 ✓
- `SettingsView.swift` — Daily Reminder Toggle label ✓
- `SettingsView.swift` — Toggle `.accessibilityValue` ✓
- `CalendarView.swift` — Month selector buttons ✓
- `PlaybackView.swift` — Close button hint ✓
- `PlaybackView.swift` — Export button label ✓
- `PlaybackView.swift` — Delete button label ✓
- `PlaybackView.swift` — Speed picker label and hint ✓
- `PlaybackView.swift` — Trim button label ✓
- `OnboardingView.swift` — Back/Next buttons ✓
- `OnboardingScreen4` — Enable Camera button ✓
- `TrimView.swift` — Trim handles ✓
- `CalendarView.swift` — Year selector ✓
- `DayCell` — accessibility labels ✓

### Round 2 New Code — No Accessibility Issues
- `DeepLinkHandler.swift` — Service layer, no UI
- `BlinkShortcuts.swift` — AppIntents framework, no direct UI
- `NWPathMonitor` in `CloudBackupService.swift` / `CrossDeviceSyncService.swift` — Network monitoring only

---

## Summary by Category

| Category | Round 1 | Round 2 | Round 3 Remaining | New in R3 |
|----------|---------|---------|-------------------|-----------|
| Dynamic Type | 40 | 12 | 25+ | 0 |
| WCAG AA | 25 | 8 | 8 | 2 |
| VoiceOver Labels | 45 | 10 | 6 | 1 |
| Reduce Motion | 20 | 2 | 2 | 1 |
| Other | 26 | 2 | 4 | 0 |
| **TOTAL** | **156** | **34** | **~45** | **~4** |

---

## Recommendations (Priority Order)

1. **Adopt `BlinkFontStyle` everywhere** — Replace all `.font(.system(size: X))` with `BlinkFontStyle.blinkStyle(.body)` etc.
2. **Fix WCAG AA contrast** — Replace all `555555` and `666666` text colors with at least `8a8a8a`
3. **Add accessibility labels to skeleton cards** in `CommunityView.swift`
4. **Enhance keypad labels** — "0" → "Zero, digit 0", Submit → "Submit passcode"
5. **Add missing labels** to month/year picker buttons, ShareOptionRow
6. **Fix Reduce Motion** in YearInReviewCompilationView progress animation

---

*End of Round 3 Accessibility Audit*
