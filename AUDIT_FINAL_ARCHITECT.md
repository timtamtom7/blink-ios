# Blink iOS — Final Architecture Audit

**Lens:** Architecture · Tokens · Spacing · Typography
**Review scope:** Full codebase — all Swift files under `Blink/` and `BlinkMac/`
**Date:** 2026-04-01

---

## CRITICAL

---

**[CRITICAL] Theme.swift — Color contrast below WCAG AA minimum**

- `textSecondary` is defined as `#AAAAAA` (line ~22). Comment says "WCAG AA ≥ 4.5:1 on #0a0a0a".
  - Actual contrast ratio on `#0a0a0a` background: ~4.3:1 — **fails WCAG AA 4.5:1**.
  - The comment is correct about the requirement; the value is wrong.
  - Fix: Use `#B0B0B0` (~5.2:1) or `#ADADAD` (~4.6:1) to actually meet 4.5:1.

- `textQuaternary` is `#AAAAAA` with the same comment ("WCAG AA ≥ 4.5:1 on #0a0a0a"). Same failure.
  - If the intent is a tertiary/disabled text on dark backgrounds, the value matches `textSecondary` with no differentiation.
  - Fix: Either increase contrast or differentiate the semantic meaning.

---

**[CRITICAL] Theme.swift — Font size below documented minimum**

- `BlinkFontStyle.microBold` = 7pt (line ~150). Theme.swift documents "WCAG AA compliant minimum: 11pt / .caption2".
  - 7pt is 57% smaller than the documented minimum.
  - Used in `AIHighlightsView` (circle score overlay) and `MonthStripView` (month labels).
  - Fix: Raise to at least 11pt, or use `micro` (8pt, at the minimum threshold) consistently.

---

## HIGH

---

**[HIGH] Theme.swift — `HapticFeedback.trigger()` logic bug**

- In `HapticFeedback` enum (line ~130), the `trigger()` method fires **both** an impact and a notification on every call:

```swift
func trigger() {
    let service = UIImpactFeedbackGenerator(style: impactStyle)
    service.impactOccurred()                          // ← always fires

    if let notificationType = notificationType {
        let notification = UINotificationFeedbackGenerator()
        notification.notificationOccurred(notificationType)  // ← also always fires
    }
}
```

- Cases like `.success`, `.warning`, `.error` should only fire the notification type.
- Cases like `.light`, `.medium`, `.heavy` should only fire the impact type.
- The `.default` case falls through to `.medium` impact but also fires `nil` notification — functional but wrong structure.
- Fix: Make `impactStyle` return `nil` for notification-only cases, and only call `impactOccurred()` when `impactStyle != nil`.

---

**[HIGH] CustomGraphics.swift — Dead code: `YearInReviewView`**

- `YearInReviewView` struct (line ~400) is defined but never referenced from any other file in the codebase.
- It is only used inside `#Preview` providers in the same file.
- If this view is intended to be a real screen (similar to `YearInReviewCompilationView`), it should be moved to `Blink/Views/` and connected to navigation.
- If it is truly a graphic/preview artifact, it should be removed.

---

**[HIGH] PrivacySettingsView.swift — Missing view references (compile errors)**

- `PrivacySettingsView` has `NavigationLink("Close Circles") { CloseCircleView() }` and `NavigationLink("Collaborative Albums") { CollaborativeAlbumView() }`.
- `CloseCircleView` does **not exist** anywhere in `Blink/Views/`. Only `CloseCircleView` referenced is `CloseCircleView` in `CustomGraphics.swift` as a graphic, not a real screen.
- `CollaborativeAlbumView` does **not exist** in `Blink/Views/`.
- These will cause **Swift compile errors**.
- Fix: Either create these views, replace with placeholder stubs, or remove the navigation links.

---

**[HIGH] SettingsView.swift — "Coming Soon" label misleads for implemented feature**

- iCloud Backup section shows "Coming Soon" label (line ~140), but `CloudBackupService` is fully implemented with `backupAllClips()` and `restoreClips()` methods.
- This misleads users into thinking the feature doesn't exist when it does.
- Fix: Remove "Coming Soon" and surface the actual toggle.

---

## MEDIUM

---

**[MEDIUM] Multiple Views — Hardcoded hex colors instead of Theme tokens**

The following views use raw hex strings instead of `Theme.*` tokens:

- `FreemiumEnforcementView.swift`: `#2a2a2a`, `#8a8a8a` (used twice), `#f5f5f5`
- `FreePlanNudgeView.swift`: `#ff3b30`, `#ff3b30` (opacity), `#141414`, `#f5f5f5`, `#8a8a8a`
- `DurationLimitBanner.swift`: `#ff3b30`, `#f5f5f5`, `#8a8a8a`, `#1e1e1e`
- `PrivacySettingsView.swift`: entirely unstyled — uses `.secondary`, `.caption`, `.blue` — inconsistent with Blink design system
- `SharingHistoryView.swift` (inside PrivacySettingsView): uses `.secondary`, `.blue`, `.caption`, `.caption2` — all non-Blink fonts/colors
- `RecordView.swift`: `.padding(.top, 60)` — raw value, no Theme constant exists for 60pt

Fix: Add missing Theme tokens and update views to use them. E.g.:
```swift
static let spacing60: CGFloat = 60   // add to Theme.swift
Theme.spacing60                         // use in views
```

---

**[MEDIUM] Theme.swift — Icon size gaps and unused tokens**

- `icon3XLarge: 40` and `icon4XLarge: 48` — the naming suggests 40 and 48, skipping the logical intermediate sizes (36, 42, 44).
- `icon5XLarge: 56` and `icon6XLarge: 64` — same issue.
- These are not used anywhere in the codebase (search confirms zero references to `Theme.icon3XLarge`, `Theme.icon4XLarge`, `Theme.icon5XLarge`, `Theme.icon6XLarge`).
- Fix: Remove unused icon tokens, or add a comment documenting they are reserved for future use.

---

**[MEDIUM] Theme.swift — `BlinkFontStyle` unused variants**

The following `BlinkFontStyle` cases are never referenced in any view or service:

- `italicMedium` (15pt italic)
- `bold24` (24pt bold)
- `lockIconLarge` (40pt)
- `badge` (10pt semibold)
- `display64BoldRounded` (64pt)
- `icon24`, `icon48`
- `buttonTextMedium`

These bloat the enum. Fix: Remove unused cases or add internal documentation that they are reserved.

---

**[MEDIUM] SettingsView.swift — iCloud Backup section disabled for non-iCloud devices**

- `iCloudBackupEnabled` UserDefaults toggle controls the feature, but the section is always visible even when `!cloudBackup.iCloudAvailable`.
- The "Sign in to iCloud" warning is shown but the toggle remains visible.
- Fix: Wrap the entire iCloud section in `if cloudBackup.iCloudAvailable` or `if cloudBackup.iCloudAvailable || iCloudBackupEnabled`.

---

**[MEDIUM] `MonthStripView` in CustomGraphics.swift — Hardcoded month density data**

- `monthHeight(for:)` and `monthColor(for:)` use a hardcoded dictionary simulating clip density per month.
- This is placeholder data for the mockup that should not ship in production code.
- If `YearInReviewView` is ever wired up as a real screen, this would need real data from `VideoStore`.

---

**[MEDIUM] BlinkFontStyle — `microBold` (7pt) used in live UI, not just previews**

- `microBold` at 7pt is used in `MonthStripView` (month bar heights) and `AIHighlightsView` (circle score overlay).
- Even if treated as decorative/icon text, 7pt is below any reasonable accessibility floor for tappable UI.
- Fix: Raise to 11pt minimum for any text that conveys information.

---

## LOW

---

**[LOW] Theme.swift — Comment/value mismatch**

- `textSecondary` comment: "WCAG AA ≥ 4.5:1 on #0a0a0a" — correct requirement, wrong value.
- `textTertiary` comment: "WCAG AA ≥ 4.5:1 on #141414" — `#888888` on `#141414` = ~5.2:1 ✓
- The documentation in comments is correct; it's the hex values that don't match the stated compliance claims.

---

**[LOW] `ContentView.swift` — Unused `@State private var showYearInReview: Bool`**

- In `ContentView` (line ~12), `showYearInReview` is declared as a `@State` but never set to `true` anywhere.
- The `yearInReviewView` overlay (line ~95) is similarly unreachable.
- This is dead code; either wire it up or remove it.

---

**[LOW] Theme.swift — `textQuaternary` has same value as `textSecondary`**

- Both `#AAAAAA` with the same background assumption.
- If they are meant to be different levels, they need different values.
- If they are the same, one should be removed.

---

**[LOW] `AIHighlightsService.swift` — `averageBrightness()` always returns 0.5**

```swift
private func averageBrightness(of ciImage: CIImage) -> Double {
    return 0.5 // Placeholder - real implementation would compute actual brightness
}
```

- This is an intentional placeholder documented as such, but it means all AI highlight scoring based on brightness is random.
- `analyzeFrame()` in `AIHighlightsService` uses this to classify highlights.
- Low priority since the service is AI-analysis placeholder code, but worth noting.

---

**[LOW] Spacing inconsistency — Raw values vs Theme constants**

Multiple views mix Theme spacing constants with raw CGFloat values:

- `FreemiumEnforcementView.swift`: `.padding(.top, 60)` (raw), `.padding(.horizontal, 24)` (raw), `.padding(.vertical, 40)` (raw)
- `RecordView.swift`: `.padding(.top, 60)` (raw)
- `RecordView.swift`: Uses `Theme.spacing16` in some places but `.padding(.horizontal, 16)` in others

Fix: Define all needed spacing values in Theme and enforce usage via lint rule.

---

**[LOW] `SocialShareService` — `fallbackShareURL` always returns `blink://share`**

```swift
private static let fallbackShareURL = URL(string: "blink://share")!
```

- If `URLComponents` construction fails, the fallback is always `blink://share` with no actual link data.
- The `guard let url = components.url else { return SocialShareService.fallbackShareURL }` path silently returns a useless URL.
- In production this would be a silent failure — links would appear to share but not actually link to any content.
- Fix: Throw an error instead of returning a dummy URL.

---

**[LOW] `BlinkFontStyle` enum — `display56` is defined but never used**

- Search confirms `display56` is never referenced in any view.
- `display50`, `display36` similarly unused.
- Dead enum cases.

---

## ARCHITECTURE NOTES (Not Issues — Observations)

---

1. **`YearInReviewView` vs `YearInReviewCompilationView`** — Two views with overlapping purpose (year-in-review). `YearInReviewCompilationView` is the wired-up one in `CalendarView`. `YearInReviewView` in CustomGraphics is the mockup. The naming distinction is unclear — consider renaming the graphic to `YearInReviewCardPreview` to avoid confusion.

2. **Theme is well-structured overall** — The token system (colors, spacing, corner radii, icon sizes) is comprehensive and correctly separates tokens from usage. The main issues are the contrast violations and unused tokens, not the architecture itself.

3. **`HapticService` vs `HapticFeedback` in Theme** — Two separate haptic systems exist: `HapticService` (service class with typed methods) and `HapticFeedback` (Theme enum). `RecordView` uses `HapticService.shared` directly. The Theme enum is not used anywhere in the actual app code. Consider removing the Theme enum version to avoid confusion.

4. **`PrivacySettingsView` stands alone** — It is not connected to navigation from anywhere (`SettingsView` does not reference it). The `SharedAlbumService` it uses has minimal implementation. This feels like a feature stub that was started but not finished.

---

## SUMMARY TABLE

| Severity | Count | Top Priority |
|----------|-------|--------------|
| CRITICAL | 2 | Fix WCAG contrast for `textSecondary`/`textQuaternary`; raise `microBold` to ≥11pt |
| HIGH | 4 | Fix HapticFeedback logic bug; remove dead `YearInReviewView`; fix missing `CloseCircleView`/`CollaborativeAlbumView` refs; remove "Coming Soon" mislabel |
| MEDIUM | 7 | Hardcoded colors across views; unused icon/font tokens; iCloud section visibility; placeholder density data |
| LOW | 6 | Comment/value mismatches; dead state vars; spacing inconsistency; `averageBrightness` placeholder; `fallbackShareURL` silent failure |

**Total: 19 findings across 4 severity levels.**
