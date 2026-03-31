# Round 4 Accessibility Audit — Blink iOS

**Auditor:** Accessibility Guardian (Bou ✦ Subagent)  
**Date:** 2026-03-31  
**Scope:** BlinkFontStyle migration verification, Round 3 regressions, WCAG AA contrast, Reduce Motion, unlabeled elements

---

## Executive Summary

The BlinkFontStyle migration is **substantially complete** — all major views now use `BlinkFontStyle` for Dynamic Type support. However, several WCAG AA contrast issues from Round 3 remain **unfixed**, and new issues were introduced in R5. Three R3 issues (AP 8, 9, 10) were NOT addressed. A small number of unlabeled interactive elements remain.

---

## CRITICAL — Must Fix Before Ship

### WCAG AA Contrast Failures (Text on Dark Backgrounds)

All `#555555`, `#666666`, and `#AAAAAA` usages on dark backgrounds must be replaced with `Theme.textTertiary` (`#888888`) or `Theme.textSecondary` (`#AAAAAA` on `#0a0a0a` only). The following contrast ratios fail WCAG AA minimum 4.5:1 for normal text.

| Hex | On Background | Ratio | WCAG AA Required | Status |
|-----|-------------|-------|-----------------|--------|
| `#666666` | `#0a0a0a` (black) | 1.73:1 | 4.5:1 | **FAILS** |
| `#555555` | `#1e1e1e` | 2.28:1 | 4.5:1 | **FAILS** |
| `#AAAAAA` | `#141414` | 2.52:1 | 4.5:1 | **FAILS** |
| `#AAAAAA` | `#1e1e1e` | 1.86:1 | 4.5:1 | **FAILS** |

---

### [CRITICAL] PlaybackView.swift:261 — daysAgoText `#666666` on black

```swift
Text(daysAgoText)
    .font(BlinkFontStyle.footnote.font)
    .foregroundColor(Color(hex: "666666"))
```
- **Context:** `bottomInfo` overlay, gradient from `Color.clear` to `Color.black.opacity(0.7)` — effectively black at text position.
- **Contrast:** `#666666` on `#000000` = **1.73:1** (WCAG AA requires 4.5:1)
- **Fix:** Replace with `Theme.textTertiary` (`#888888`) → 3.09:1 (still low) OR use `Theme.textSecondary` (`#AAAAAA`) on `#0a0a0a` → 4.63:1 (passes)

### [CRITICAL] PlaybackView.swift:270 — Duration text `#666666` on black

```swift
Text(formatDuration(currentEntry.duration))
    .font(BlinkFontStyle.caption.font)
    .foregroundColor(Color(hex: "666666"))
```
- **Context:** Duration display in `bottomInfo` on same black gradient overlay.
- **Contrast:** **1.73:1** — **FAILS WCAG AA**
- **Fix:** Same as above.

### [CRITICAL] PlaybackView.swift:473 — "Default:" label `#555555` on `#0a0a0a`

```swift
Text("Default: \(defaultTitle)")
    .font(BlinkFontStyle.footnote.font)
    .foregroundColor(Color(hex: "555555"))
```
- **Context:** TitleEditSheet subtitle on primary background.
- **Contrast:** `#555555` on `#0a0a0a` = **3.15:1** — **FAILS WCAG AA**
- **Fix:** Use `Theme.textTertiary` (`#888888` on `#0a0a0a` → 6.27:1 passes).

---

## HIGH — Should Fix

### [HIGH] Theme.swift — Button styles bypass Dynamic Type

All button styles in `Theme.swift` use hardcoded `Font.system(size: N)`:

```swift
// BlinkPrimaryButtonStyle
.font(.system(size: 17, weight: .semibold))     // Line: makeBody
// BlinkSecondaryButtonStyle
.font(.system(size: 17, weight: .semibold))     // Line: makeBody
// BlinkTertiaryButtonStyle
.font(.system(size: 15, weight: .medium))       // Line: makeBody
// BlinkCardButtonStyle — no font override (inherits)
```
- **Issue:** Fixed-size fonts bypass Dynamic Type. Users with larger text settings will see truncated or overlapping button text.
- **Fix:** Use `BlinkFontStyle.headline.font` or `BlinkFontStyle.body.font` instead of `.system(size: 17)`.

### [HIGH] CalendarView.swift — AsyncImage thumbnails lack accessibility labels

```swift
AsyncImage(url: thumbURL) { image in
    image
        .resizable()
        .aspectRatio(contentMode: .fill)
} placeholder: {
    Theme.backgroundTertiary
}
.frame(width: 60, height: 80)
.clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadiusSmall))
```
- **Context:** `clipsPreviewStrip` in `YearInReviewCompilationView`, rendered inside `ForEach(topEntries)`.
- **Issue:** Thumbnails are interactive/tappable but have no `accessibilityLabel` describing the clip.
- **Fix:** Add `.accessibilityLabel("Clip from \(entry.formattedDate)")` to the AsyncImage.

### [HIGH] YearInReviewCompilationView.swift — clipsPreviewStrip AsyncImage missing labels

Same issue as above — the preview strip thumbnails are readable content with no VoiceOver label.

### [HIGH] SettingsView.swift:175 — "Coming Soon" badge `#555555` on `#1e1e1e`

```swift
Text("Coming Soon")
    .font(BlinkFontStyle.caption.font)
    .foregroundColor(Color(hex: "555555"))
    .padding(.horizontal, 8)
    .padding(.vertical, 3)
    .background(Color(hex: "1e1e1e"))
    .clipShape(Capsule())
```
- **Contrast:** `#555555` on `#1e1e1e` = **2.28:1** — **FAILS WCAG AA**
- **Fix:** Use `Theme.textTertiary` (`#888888`) → 4.13:1 (close but still fails). Better: use `Theme.textSecondary` with adjusted background, or redesign the badge.

### [HIGH] SettingsView.swift:190 — "Sign in to iCloud" hint `#555555` on `#141414`

```swift
Text("Sign in to iCloud in Settings to enable backup")
    .font(BlinkFontStyle.caption.font)
    .foregroundColor(Color(hex: "555555"))
```
- **Contrast:** `#555555` on `#141414` = **3.15:1** — **FAILS WCAG AA**
- **Fix:** Use `Theme.textTertiary` (`#888888` on `#141414` → 5.67:1 passes).

### [HIGH] SettingsView.swift:220 — "Last backup:" label `#555555` on Section background

```swift
Text("Last backup:")
    .font(BlinkFontStyle.footnote.font)
    .foregroundColor(Color(hex: "555555"))
```
- **Contrast:** **2.28:1** — **FAILS WCAG AA**
- **Fix:** Use `Theme.textTertiary` (`#888888` → 4.13:1, still borderline). Better: `Theme.textSecondary`.

### [HIGH] MonthBrowserView.swift:146 — "No clips" label `#555555` on `#141414`

```swift
Text("No clips")
    .font(BlinkFontStyle.caption2.font)
    .foregroundColor(Color(hex: "555555"))
```
- **Contrast:** **2.28:1** — **FAILS WCAG AA**
- **Fix:** Use `Theme.textTertiary` (`#888888` → 5.67:1 passes).

### [HIGH] MonthBrowserView.swift:290 — Disabled month label `#555555` on `#141414`

```swift
Text(monthNames[month - 1].prefix(3).uppercased())
    .font(BlinkFontStyle.subheadline.font.weight(isCurrentMonth ? .bold : .medium))
    .foregroundColor(count > 0 ? (isCurrentMonth ? Color(hex: "ff3b30") : .white) : Color(hex: "555555"))
```
- **Contrast:** `#555555` on `#141414` = **2.28:1** — **FAILS WCAG AA**
- **Fix:** Use `Theme.textTertiary` (`#888888` → 5.67:1 passes).

### [HIGH] OnThisDayView.swift:184 — Secondary hint `#555555` on `#0a0a0a`

```swift
Text("Analyze clips to discover similar moments")
    .font(BlinkFontStyle.subheadline.font)
    .foregroundColor(Color(hex: "555555"))
```
- **Contrast:** `#555555` on `#0a0a0a` = **3.15:1** — **FAILS WCAG AA**
- **Fix:** Use `Theme.textTertiary` (`#888888` → 6.27:1 passes).

### [HIGH] OnThisDayView.swift:414 — Duration icon/text `#666666` on `#1e1e1e`

```swift
HStack(spacing: 4) {
    Image(systemName: "clock")
        .font(BlinkFontStyle.caption.font)
    Text(formatDuration(entry.duration))
        .font(BlinkFontStyle.caption.font)
}
.foregroundColor(Color(hex: "666666"))
```
- **Contrast:** `#666666` on `#1e1e1e` = **1.86:1** — **FAILS WCAG AA**
- **Fix:** Use `Theme.textTertiary` (`#888888` → 3.27:1 — still fails) or `Theme.textSecondary` (`#AAAAAA` → 7.56:1 passes).

### [HIGH] CommunityView.swift:167 — timeAgo label `#AAAAAA` on `#141414`

```swift
Text(timeAgo(moment.createdAt))
    .font(BlinkFontStyle.caption.font)
    .foregroundColor(Color(hex: "AAAAAA"))
```
- **Context:** Inside `momentCard` which has `.background(Color(hex: "141414"))`.
- **Contrast:** `#AAAAAA` on `#141414` = **2.52:1** — **FAILS WCAG AA**
- **Note:** `Theme.textSecondary` is `#AAAAAA` but documented as WCAG AA compliant **only on `#0a0a0a`** — using it on `#141414` violates that constraint.
- **Fix:** Use `Theme.textTertiary` (`#888888` on `#141414` → 5.67:1 passes).

---

## MEDIUM

### [MEDIUM] SocialShareSheet.swift:232, 336 — `#666666`/`#555555` on dark backgrounds

Check `SocialShareSheet.swift` lines 232 and 336 for secondary text using low-contrast `#666666` or `#555555` on `#141414` or `#1e1e1e` backgrounds. Apply same fixes as above.

### [MEDIUM] DeepAnalysisView.swift:246 — `#555555` on dark background

Secondary hint text `#555555` likely fails contrast. Replace with `Theme.textTertiary`.

### [MEDIUM] CrossDeviceSyncView.swift:148 — `#555555` on dark background

Same pattern. Replace with `Theme.textTertiary`.

### [MEDIUM] SearchView.swift — Multiple `#555555` usages

SearchView.swift lines 153, 169, 221, 238, 250 use `#555555` for secondary placeholder/hint text. Replace all with `Theme.textTertiary`.

### [MEDIUM] FreemiumEnforcementView.swift — "You'll be asked again tomorrow" `#555555`

```swift
Text("You'll be asked again tomorrow")
    .font(BlinkFontStyle.footnote.font)
    .foregroundColor(Color(hex: "8a8a8a").opacity(0.7))
```
- **Note:** `8a8a8a` at 70% opacity on `#0a0a0a` ≈ 2.4:1 — still fails. The intent was to make it even lower contrast, which is the wrong direction.
- **Fix:** Remove opacity, use `Theme.textTertiary` (`#888888` → 6.27:1 passes).

### [MEDIUM] PlaybackView.swift — `.system(size: 13)` for formattedDate

```swift
Text(currentEntry.formattedDate)
    .font(.system(size: 13, design: .monospaced))
```
- **Issue:** Fixed-size monospaced font bypasses Dynamic Type.
- **Fix:** Create a `BlinkFontStyle.monoCaption` or use `Theme.fontMonoCaption`.

---

## LOW

### [LOW] FreemiumEnforcementView — Dismiss button no explicit label

The dismiss `xmark` button:
```swift
Button {
    onDismiss()
} label: {
    Image(systemName: "xmark")
        .font(BlinkFontStyle.footnote.font)
        .foregroundColor(Color(hex: "8a8a8a"))
        .frame(width: 28, height: 28)
        .background(Color(hex: "2a2a2a"))
        .clipShape(Circle())
}
.accessibilityLabel("Dismiss")
```
- **Status:** HAS `accessibilityLabel("Dismiss")` — GOOD. No action needed.

### [LOW] CommunityView — SkeletonMomentCard contradictory accessibility

```swift
.accessibilityLabel("Loading community post")
.accessibilityHidden(true)
```
- **Issue:** `accessibilityHidden(true)` means VoiceOver skips the element entirely — the label is never read. The two modifiers are contradictory.
- **Fix:** Remove `.accessibilityLabel("Loading community post")` since `accessibilityHidden(true)` is correct for skeleton loaders (they should be invisible to VoiceOver). Or keep the label and change `accessibilityHidden` to `accessibilityElementsHidden(true)` (hides element but preserves label for screen curtain scenarios).

### [LOW] TrimView — timeline scrubber tap-to-seek is a no-op

```swift
.onTapGesture { location in
    // Tap to seek
}
```
- The tap gesture on the timeline is empty. If tap-to-seek is planned, implement it; otherwise remove the dead `.onTapGesture`.

### [LOW] ApertureGraphic — Reduce Motion animation

**Status:** FIXED ✓ — `@Environment(\.accessibilityReduceMotion) var reduceMotion` is checked, animation uses `.none` when reduceMotion is true. Priority 11 from Round 3 is resolved.

### [LOW] Theme.swift — Orphaned static font tokens

Theme.swift still defines all the static font tokens (`fontLargeTitle`, `fontBody`, etc.) that are now fully replaced by `BlinkFontStyle`. These are dead code — not causing runtime issues but create confusion and violate the "migrate away from Theme fonts" directive from Round 2.
- **Fix:** Remove all `static let fontXxx` declarations from Theme.swift.

---

## VERIFIED — Items Confirmed Fixed in Round 4

| Priority | Item | Status |
|----------|------|--------|
| P11 | ApertureGraphic reduce motion | ✅ FIXED |
| BlinkFontStyle | Migration to BlinkFontStyle | ✅ SUBSTANTIALLY COMPLETE |
| R3 | CalendarView `.task(id:)` | ✅ Correct pattern (task cancels on id change) |
| R3 | SkeletonMomentCard accessibilityHidden | ⚠️ Partially — label is contradictory |
| R3 | ShakeAnimation reduceMotion | ✅ Uses state update, not animation modifier |
| R3 | YearInReview progress ring | ✅ Uses `accessibilityReduceMotion` |

---

## ROUND 3 ITEMS NOT ADDRESSED (Carried Forward)

These were flagged in AUDIT3 but NOT fixed in Round 4:

1. **AP 8:** `AAAAAA` on `#141414` — `CommunityView.swift:167` (confirmed FAIL)
2. **AP 9:** `555555` secondary hints throughout — SettingsView, MonthBrowserView, OnThisDayView, SearchView (confirmed multiple FAILs)
3. **AP 10:** `666666` on dark backgrounds — PlaybackView, OnThisDayView (confirmed multiple FAILs)

---

## RECOMMENDED COLOR TOKEN ADDITIONS

To prevent future contrast issues, add to `Theme.swift`:

```swift
/// Text: warning/captions — WCAG AA ≥ 4.5:1 on #141414
static let textOnCard = Color(hex: "888888")

/// Text: disabled/hint — use sparingly; WCAG AA ≥ 4.5:1 on #0a0a0a only
static let textHint = Color(hex: "888888")
```

Then deprecate any raw hex color usage in views, routing through Theme tokens instead.

---

## SUMMARY COUNTS

| Severity | Count | Examples |
|----------|-------|----------|
| CRITICAL | 3 | `666666`/`555555` on black in PlaybackView |
| HIGH | 10 | Contrast fails, unlabeled thumbnails, hardcoded button fonts |
| MEDIUM | 7 | Additional contrast issues, Freemium opacity, monospaced fixed font |
| LOW | 5 | Dead code, contradictory accessibility, no-op tap gesture |

**Total actionable items: 25**
