# Brand/UX Audit — Round 4

## BlinkFontStyle Adoption

### CONSISTENT (good):
- Theme.swift establishes a complete BlinkFontStyle enum with body, callout, footnote, etc.
- Most views adopt the BlinkFontStyle enum consistently: SettingsView, CalendarView, AIHighlightsView, SearchView, TrimView, MonthBrowserView, OnboardingView screens 1-3, FreemiumEnforcementView, ErrorStatesView, StorageDashboardView, PlaybackView title fonts, YearInReviewGraphic, OnThisDayView, PricingView body copy

### INCONSISTENT — Raw `.font(.system(...))` in styled contexts:

**[MEDIUM] PrivacyLockView.swift:79** — `Text("Blink is locked")` uses `.font(.system(size: 40))` instead of BlinkFontStyle. This is the primary lock screen title and should be `.font(BlinkFontStyle.largeTitle.font)`.

**[MEDIUM] PrivacyLockView.swift:150** — `Text("·  ·  ·")` uses `.font(.system(size: 28, weight: .medium, design: .rounded))` for the dot separator between biometric type labels. Should use BlinkFontStyle for consistency.

**[MEDIUM] PrivacyLockView.swift:313** — `Text(biometricType.displayName)` uses `.font(.system(size: 32))`. This is a significant UI text element.

**[MEDIUM] RecordView.swift:409** — Countdown overlay uses `.font(.system(size: 120, weight: .bold, design: .rounded))`. This is a large typographic moment that should honor BlinkFontStyle.largeTitle or a defined style.

**[MEDIUM] SocialShareSheet.swift:409** — `Text("Loading friends…")` uses `.font(.system(size: 48))` for the loading state. This is visually prominent but inconsistent.

**[MEDIUM] SocialShareSheet.swift:467** — `Text("Loading…")` uses `.font(.system(size: 48))` for the friends loading state.

**[LOW] OnboardingView.swift:many** — OnboardingScreen1-4 use `.font(.system(size: 34, weight: .bold))` for titles. These should migrate to BlinkFontStyle once defined for the onboarding context.

**[LOW] CustomGraphics.swift** — Preview graphics intentionally use raw font sizing since they're static mockups, not live UI. Not a production issue.

---

## CalendarView `.task(id:)` Fix

**[LOW] CalendarView.swift:204** — `exportThisMonth()` sets `exportMonth = currentMonth` then `exportYear = currentYear`, then `isExporting = true`. The `.task(id: exportMonth)` modifier will fire when `exportMonth` transitions from 0→currentMonth. This works, but it creates a subtle dependency on the initial value being 0. If anyone refactors the initial state, the export breaks silently. Consider adding a comment explaining the 0-initialization contract, or use a dedicated `@State private var isExportingMonth = false` binding.

---

## YearInReview Real Progress

**[GOOD] YearInReviewCompilationView.swift:48** — `yearProgress` is computed as `clipsThisYear / totalDays`, which is honest. The insight copy at line 115 is calibrated correctly ("Remarkable" at ≥80%, "Good" at ≥50%, etc.).

**[GOOD] YearInReviewCompilationView.swift:72-86** — The generating overlay shows "Creating your reel…" without a percentage counter. This is appropriate — showing a fake progress % for AI generation would feel dishonest.

**[GOOD] CustomGraphics.swift:YearInReviewGraphic** — The graphic uses `progress = 0.23` (hardcoded example value) in `.onAppear`, which is correct for a static preview. Live code uses real calculation.

**[OBSERVATION] YearInReviewCompilationView.swift:44** — `topEntries` filters out locked entries with `!$0.isLocked`, but `generateHighlightReel(clips:)` receives `Array(entries.prefix(10))` which includes locked entries (line 186). This is a minor inconsistency — the AI reel generation includes locked clips that don't appear in the top-10 preview. Low impact since the user explicitly chose to share those clips.

---

## PrivacyLockView Shake Feedback

**[MEDIUM] PrivacyLockView.swift:241-254** — `shakeAnimation()` uses a series of `DispatchQueue.main.asyncAfter` calls to cycle `dotsShakeOffset`. Issues:

1. **Does not respect `reduceMotion`** — The shake plays even if the user has enabled Reduce Motion in accessibility settings. Every other animated element in the app (countdown, saved overlay, aperture graphic, shimmer skeletons) checks `reduceMotion` before animating. The shake should be gated:
   ```swift
   @Environment(\.accessibilityReduceMotion) var reduceMotion
   // in shakeAnimation():
   guard !reduceMotion else {
       dotsShakeOffset = 0
       return
   }
   ```

2. **Timing feels mechanical** — The `[-10, 10, -8, 8, -5, 5, -3, 3, 0]` sequence is well-designed but could add slight randomness or use spring animation for a more organic feel.

3. **The dots use `.offset(x:)` which is simple but effective** — The `scaleEffect(1.2)` on filled dots and `.offset(x: dotsShakeOffset)` on the whole row is a reasonable SwiftUI-native approach.

**[GOOD] PrivacyLockView.swift:146** — The passcode dots use `Theme.backgroundQuaternary` for empty dots instead of a fully transparent color, making them visible on dark backgrounds.

---

## SocialShareSheet Loading States

**[MEDIUM] SocialShareSheet.swift:407-416** — The loading state for "Loading friends…" uses:
```swift
ProgressView()
    .tint(Color(hex: "ff3b30"))
Text("Loading friends…")
    .font(.system(size: 48))
```
The 48pt font is visually aggressive for a loading state. A loading label should be subordinate to the spinner, not competing with it. Consider BlinkFontStyle.title2 or title3.font with secondary color.

**[MEDIUM] SocialShareSheet.swift:465-472** — Same issue for the "Loading…" state at 48pt.

**[LOW] SocialShareSheet.swift:219** — `friendsListOverlay` is shown with `showFriendsList = true` while `isLoadingFriendsList`. The loading ProgressView sits above the overlay but the overlay itself (with its `friendsList`) isn't conditionally hidden. If `friendsList` is empty during load, the empty state from line 406 could briefly flash before the spinner appears. The overlay's empty state check (`contacts.isEmpty`) should also check `isLoadingFriendsList`.

**[GOOD] SocialShareSheet.swift** — The skeleton loading state for the share card uses a well-designed shimmer animation (linear gradient sweep). Good approach.

**[GOOD] SocialShareSheet.swift** — The friends list in `FriendsListView` uses a `List` with `.listRowBackground(Color(hex: "141414"))`, consistent with the rest of the app.

---

## New UX Issues (Round 3 Code)

### Passcode Dots Clarity
**[MEDIUM] PrivacyLockView.swift:95** — Empty passcode dots use:
```swift
.fill(index < currentPasscode.count ? Theme.accent : Theme.backgroundQuaternary)
.frame(width: 14, height: 14)
```
When empty, dots use `Theme.backgroundQuaternary`. On the dark lock screen background (`Color(hex: "0a0a0a")`), `backgroundQuaternary` (assumed to be `141414`) should be distinguishable, but the dot has **no hollow/border treatment** — it's a filled circle in a dark color, not a ring. On a very dark background, this makes empty dots nearly invisible, which is actually good for security (not showing dot positions) but bad for UX (user can't tell how many dots are unfilled at a glance). The current approach (filled dark circle) vs. a ring (hollow with border) is a design choice — currently it shows filled dots in red when entered, and filled dots in dark gray when not entered. Consider making unfilled dots rings (stroke only) to create more visual contrast.

### Missing `.friendButtonStyle`
**[HIGH] SocialShareSheet.swift:336** — `FriendsListView` references `.friendButtonStyle` in its `List` row background, but `FriendsListView` is a standalone file that doesn't define this style. This would cause a SwiftUI compilation failure. The style should either be defined in `FriendsListView.swift` or replaced with a direct color reference like other views use.

### Empty State Copy Inconsistency
**[LOW] SocialShareSheet.swift:408** — "No contacts found" in `ContactPickerView` uses generic copy that doesn't match Blink's voice ("one short video. Every single day. At the end of the year, you'll have the only video diary that actually matters — yours."). This empty state should reflect Blink's personality, e.g., "No friends using Blink yet — share the app to start a shared Blink."

### FreemiumNudge Copy on Today with 0 Clips
**[LOW] FreemiumEnforcementView.swift:154-155** — `FreePlanNudgeView` shows:
```
"Record your first clip today" (when clipCount == 0)
"1 clip/day • 30s limit • 30-day storage" (otherwise)
```
The first variant is good. The second variant correctly informs users of freemium limits.

### CommunityView "Coming Soon" Overlay
**[LOW] CommunityView.swift:34** — There's a "Coming Soon" overlay covering the entire view, making the community feed inaccessible. The skeleton loading view and filtering are implemented but completely hidden. This is appropriate for a placeholder feature but should be removed once R9 community features are functional.

### Accessibility: OnThisDay Screen Reader
**[LOW] OnThisDayView.swift:92** — The tab buttons use `for: OnThisDayTab` in `tabButton` with `Image(systemName:)` SF Symbols, but there's no `accessibilityLabel` on these tab buttons. Should add:
```swift
.accessibilityLabel(tab == .sameDate ? "Same date tab" : "Similar mood tab")
```

---

## Empty/Loading/Error States — Regressions Check

**[GOOD] ErrorStatesView** — Well-crafted empty states with product voice ("Your 2026 Blink diary is blank. Start today — every great year begins with a single moment."). Appropriate icons (video.circle with plus), and "Record Now" CTA.

**[GOOD] CalendarView** — Empty state uses `EmptyCalendarView` with contextual copy for the current year. Year selector allows browsing past years.

**[GOOD] StorageDashboardView** — Empty state shows "No clips yet" with camera icon and "Record your first clip to see storage stats."

**[GOOD] AIHighlightsView** — Empty state is specific: "No highlights yet — Record more clips to discover your most meaningful moments." with "Analyze Now" button.

**[GOOD] PublicFeedView** — Empty state: "No moments yet today — Be the first to share a meaningful moment with the Blink community." Reflects product personality.

**[GOOD] SearchView** — Separate empty state ("Search your clips") and no-results state ("No results — Try a different search term or filter").

**[OBSERVATION] OnThisDayView** — The `similarMoodEntries` filter requires clips to be analyzed with `DeepAnalysisService`. The "no similar mood" state ("Analyze clips to discover similar moments") correctly guides users to AI Highlights. Good flow design.

**[MEDIUM] CommunityView** — The "Coming Soon" overlay covers the empty/loading states entirely. When the overlay is eventually removed, the current skeletonLoadingView and communityContent will display correctly.

---

## Summary

| Category | Status |
|---|---|
| BlinkFontStyle adoption | Partially consistent — ~6-8 raw `.font(.system(...))` calls remain in production UI |
| CalendarView `.task(id:)` fix | Works but fragile — add initialization contract comment |
| YearInReview honest progress | ✅ Honest calculation, appropriate loading UX |
| PrivacyLockView shake | Basic but functional — **missing `reduceMotion` respect** |
| SocialShareSheet loading | 48pt loading labels too large; overall states are appropriate |
| New UX issues | 1 HIGH (missing `.friendButtonStyle` style), 1 MEDIUM (passcode dots hollow treatment), 1+ LOW |
| Empty/loading/error states | No regressions — all well-designed with product voice |

### Priority Fixes
1. **[HIGH]** Define or remove `.friendButtonStyle` reference in `FriendsListView` (compilation blocker)
2. **[HIGH]** Add `reduceMotion` check to `PrivacyLockView.shakeAnimation()`
3. **[MEDIUM]** Reduce 48pt loading labels in SocialShareSheet to BlinkFontStyle.title2/title3
4. **[MEDIUM]** Replace remaining raw `.font(.system(...))` in PrivacyLockView with BlinkFontStyle
5. **[MEDIUM]** Address passcode dots visual clarity (hollow vs. filled for empty state)
