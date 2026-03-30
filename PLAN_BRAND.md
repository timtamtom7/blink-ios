# Brand/UX Action Plan — Phase 3: Unified Plan

**Auditor:** Brand/UX Auditor  
**Date:** 2026-03-30  
**Sources:** AUDIT_BRAND.md · AUDIT_PHASE2_BRAND.md · AUDIT_ACCESSIBILITY.md · AUDIT_PHASE2_ACCESSIBILITY.md · AUDIT_ARCHITECT.md · AUDIT_PHASE2_ARCHITECT.md · AUDIT_SWIFTUI.md · AUDIT_PHASE2_SWIFTUI.md · AUDIT_PLATFORM.md · AUDIT_PHASE2_PLATFORM.md

---

## Context

This plan is drafted from the Brand/UX perspective across all Phase 1 + Phase 2 audit findings. Where other agents (Architect, Accessibility, SwiftUI, Platform) identified the same root cause, those cross-cutting findings inform the fix approach here.

The most important insight from Phase 2: **the Theme.swift design token system is completely bypassed by all views** — this single fact explains most Brand/UX inconsistencies (color drift, spacing chaos, typography hierarchy broken). Fixing that one file's adoption unlocks every other Brand fix.

---

## Priority 1: Fix FreemiumEnforcementView — User Trap (CRITICAL UX + A11y)

This is the single worst user experience failure in the app. Free users are architecturally trapped.

### 1a. Fix ContentView.swift re-trigger bug
- **File:** `blink-ios/Blink/App/ContentView.swift`
- **Line ~49-51** — Remove or guard the `onAppear` block that fires `FreemiumEnforcementView` on every appear
- **What to do:** Add an `@AppStorage("hasAcknowledgedFreemiumToday")` flag. Only show enforcement if (a) user is free tier AND (b) they haven't acknowledged today. Reset flag at midnight via a date comparison check on appear.

### 1b. Add dismiss mechanism to FreemiumEnforcementView
- **File:** `blink-ios/Blink/Views/FreemiumEnforcementView.swift`
- **Lines ~35-93** — All 7 buttons currently have no `accessibilityLabel` (Accessibility CRITICAL #43-49)
- **What to do:** Add a "Maybe Later" / "Continue Browsing" button that writes the acknowledgment flag and dismisses the sheet. This button must be accessible and labeled.

### 1c. Fix all 7 missing accessibility labels
- **File:** `blink-ios/Blink/Views/FreemiumEnforcementView.swift`
- **Lines ~35, 44, 52, 57, 75, 84, 93** — Every interactive element needs `.accessibilityLabel("...")`:
  - Upgrade button → `"Upgrade to Blink Memories"`
  - Maybe Later button → `"Continue with free version"`
  - Crown icon button → `"Upgrade for unlimited clips"`
  - Clock icon button → `"Upgrade to extend clip length"`
- **Brand note:** Rename generic "Upgrade to Unlock" CTA to communicate value: `"Upgrade to Blink Memories"` / `"Get unlimited clips up to 60 seconds"`

---

## Priority 2: Complete the Onboarding Experience (CRITICAL UX Gaps)

### 2a. Add illustration to Onboarding page 1 (currently blank)
- **File:** `blink-ios/Blink/Views/OnboardingView.swift`
- **Lines ~45-66** — Page 1 "Blink" has title + subtitle on black with no graphic
- **What to do:** Create a `BlinkLogoGraphic` or `ApertureIcon` custom graphic matching the aperture motif. Every other onboarding page has a graphic — page 1 should too.

### 2b. Add onboarding completion/celebration page
- **File:** `blink-ios/Blink/Views/OnboardingView.swift`
- **After current page 3 (line ~110)** — Add a 4th page: `"You're all set."` with a celebratory checkmark animation or graphic, then a "Start Recording" CTA
- **What to do:** Insert a `Spacer()` + celebratory `Image(systemName: "checkmark.circle.fill")` with the brand red `#ff3b30`, followed by "Start Recording" button that sets `hasCompletedOnboarding = true`

### 2c. Fix ApertureGraphic animation — it never opens
- **File:** `blink-ios/Blink/Views/OnboardingView.swift`
- **Line ~72-86** (Page 2 "One Second") — `ApertureGraphic()` is displayed but `.onAppear` never sets `isOpen = true`
- **What to do:** On page 2's container, add `.onAppear { isOpen = true }` to trigger the aperture open animation
- **Also:** Wrap the animation in `if !accessibilityReduceMotion { }` check per Accessibility #140

### 2d. Fix YearInReviewGraphic showing "83 clips" during onboarding
- **File:** `blink-ios/Blink/Views/CustomGraphics.swift` (or wherever `YearInReviewGraphic` lives)
- **Lines ~88-110** — `YearInReviewGraphic` used in Onboarding page 3 shows hardcoded "83 clips"
- **What to do:** For onboarding context, pass `clipsThisYear: 0` or show a dynamic count from `videoStore.entries.count`. Onboarding page should show "Start your collection" energy, not "you already have 83 clips" which misleads new users.

---

## Priority 3: Loading States + Feedback — Zero Feedback for Async Operations (CRITICAL UX)

### 3a. RecordView camera setup loading state
- **File:** `blink-ios/Blink/Views/RecordView.swift`
- **Lines ~1-60** — No loading/splash while `setupSession()` runs
- **What to do:** Add `@State private var isSettingUp = true`. During `setupSession()`, show a centered `ProgressView()` with `"Setting up camera…"` label over a darkened background. Set `isSettingUp = false` when session is ready.

### 3b. SocialShareSheet private link loading state
- **File:** `blink-ios/Blink/Views/SocialShareSheet.swift`
- **Line ~21** — "Private Link" tap triggers `createPrivateLink()` with no loading feedback
- **What to do:** Add `@State private var isGeneratingLink = false`. On tap, set `isGeneratingLink = true`. Show `ProgressView()` in button area while generating. Show link + copy confirmation when done.

### 3c. CommunityView loading skeletons + empty state
- **File:** `blink-ios/Blink/Views/CommunityView.swift`
- **Lines ~40-82** — Shows fake placeholder data (`user_a7x2`, static like counts). No empty state, no loading skeleton.
- **What to do:** Replace fake data with real empty state: `EmptyStateView(icon: "globe", title: "No public clips yet", subtitle: "Be the first to share a blink")`. Add loading skeleton (`LazyVStack` of gray shimmer rectangles) during `loadPublicFeed()`.

---

## Priority 4: Humanize Error Copy + Undo Patterns (HIGH UX Quality)

### 4a. Rewrite all ErrorStatesView messages
- **File:** `blink-ios/Blink/Views/ErrorStatesView.swift`
- **Lines ~44, 58** and throughout — Replace clinical copy with humanized copy:
  - `"Something went wrong. Please try again."` → `"That didn't work. Let's try again."`
  - `"Unable to load your clips."` → `"We couldn't load your clips. Make sure you're connected to the internet."`
  - `"Clip not found"` → `"This clip seems to have gone missing."`
- **Platform context:** Do this AFTER establishing `String(localized:)` infrastructure — these strings need to be in a `.strings` catalog, not raw literals.

### 4b. Add undo toast after clip deletion
- **File:** `blink-ios/Blink/Views/PlaybackView.swift`
- **Lines ~100-115** — `onDelete` dismisses view with no undo path
- **What to do:** Add a `ToastView` or snackbar overlay. On delete, show: `"Clip deleted"` with an `"Undo"` button for 4 seconds. If undo tapped, restore the entry to `VideoStore`. If timer expires, commit deletion.
- **Reference:** Standard iOS pattern (`SwiftUI Toast` / `.overlay` modifier)

### 4c. YearInReviewCompilationView fake progress — make real
- **File:** `blink-ios/Blink/Views/YearInReviewCompilationView.swift`
- **Line ~226** — `Timer` animates progress 0-90% decoupled from actual work
- **What to do:** Either: (a) hook the `Timer` to actual `Task` progress callbacks, or (b) replace with an indeterminate `ProgressView()` with label `"Creating your reel…"` if true progress cannot be measured. A misleading progress indicator is worse than no indicator.

---

## Priority 5: Adopt Theme.swift Design Tokens — The Root Cause Fix (HIGH Impact)

This single fix resolves color inconsistency, spacing chaos, typography hierarchy broken, and Dynamic Type failures across all 40+ view files.

### 5a. Audit current hardcoded values (pre-work)
- **File:** `blink-ios/Blink/App/Theme.swift`
- Before touching views, audit what values are actually used vs. what Theme defines:
  - Backgrounds: `Color(hex: "0a0a0a")` → `Theme.background`
  - Accents: `Color(hex: "ff3b30")` → `Theme.accent`
  - Text: `Color(hex: "f5f5f5")` → `Theme.textPrimary`
  - Secondary text: `Color(hex: "8a8a8a")` → `Theme.textSecondary`
  - Corner radii: `RoundedRectangle(cornerRadius: 12)` → `RoundedRectangle(cornerRadius: Theme.cornerRadiusMedium)`
  - Spacing: `.padding(12)` → `.padding(Theme.spacingSmall)` etc.

### 5b. Fix Theme.swift font tokens for Dynamic Type
- **File:** `blink-ios/Blink/App/Theme.swift`
- **Lines ~20-25** — All `font*` tokens use `.system(size:)` with fixed sizes
- **What to do:** Replace with `.scaled()` variants:
  ```swift
  static let fontLargeTitle = Font.largeTitle.scaled()  // supports Dynamic Type
  static let fontTitle1 = Font.title.scaled()
  static let fontBody = Font.body.scaled()
  // etc.
  ```
- **This unblocks:** Accessibility HIGH #120-138 — all 19+ files using fixed `.font(.system(size:))`

### 5c. Consolidate Theme.swift corner radius tokens
- **File:** `blink-ios/Blink/App/Theme.swift`
- **Current:** `cornerRadiusSmall = 8`, `cornerRadiusMedium = 12`, `cornerRadiusLarge = 16` — only 4pt between medium and large
- **What to do:** Either: (a) make `cornerRadiusLarge = 20` or (b) consolidate to `cornerRadiusSmall = 8`, `cornerRadiusMedium = 16`. A 4pt delta is meaningless at small sizes.

### 5d. Enforce Theme adoption — SwiftLint rule
- Add a SwiftLint rule or build-phase script that warns on any `Color(hex:)` or `.system(size:)` usage in view files. The tokens exist — the enforcement mechanism doesn't.

---

## Medium-Priority Brand Fixes

### M1. PrivacyLockView — explain biometric auth on first setup
- **File:** `blink-ios/Blink/Views/PrivacyLockView.swift` + `PrivacySettingsView.swift`
- Add explanatory copy above passcode entry: `"App Lock adds a security layer — your blinks stay private even if someone borrows your phone."` with a `"What's this?"` disclosure link
- Toggle subtitles: `"Require biometric to open Blink"` / `"Lock automatically when you leave the app"`

### M2. FAQ section in SubscriptionsView — add expand/collapse
- **File:** `blink-ios/Blink/Views/SubscriptionsView.swift`
- **Lines ~1-100** — All FAQ answers visible at once
- **What to do:** Convert to `@State private var expandedQuestion: Int? = nil`. Tap toggles expanded; only one open at a time. Standard accordion pattern.

### M3. Countdown audio + haptics
- **File:** `blink-ios/Blink/Views/RecordView.swift`
- **Line ~303** (`startCountdown()`) — `countdownTick()` haptic is defined in HapticService but never called
- **What to do:** Call `HapticService.shared.countdownTick()` on each tick (3, 2, 1). Consider adding system sound (`AudioServicesPlaySystemSound`) for audio countdown cue, matching standard camera app behavior.
- **Also:** Wrap countdown `animation(.easeInOut(duration: 0.3))` in `if !accessibilityReduceMotion { }` (Accessibility #145)

### M4. PasscodeSetupView — add haptic on digit entry
- **File:** `blink-ios/Blink/Views/PasscodeSetupView.swift`
- **Lines ~93-114** — Digit entry has no haptic feedback, no error shake animation
- **What to do:** Add `HapticService.shared.buttonTap()` on each digit tap. Add `withAnimation(.default)` shake on wrong passcode.

### M5. Calendar day cells — distinguish 0 clips from ≥1 clip
- **File:** `blink-ios/Blink/Views/CalendarView.swift`
- **Lines ~228-320** — Days with 0 clips look identical to days with 1 clip (just day number)
- **What to do:** Style days with 0 clips in `textTertiary` color; days with ≥1 clips in `textPrimary` + a dot indicator. At minimum, the visual treatment must distinguish "empty" from "has content."

### M6. PricingView — conditional header copy
- **File:** `blink-ios/Blink/Views/PricingView.swift`
- **Lines ~171-180** — "Your year deserves more" shown in both onboarding and settings context
- **What to do:** Add a `context: PricingContext` enum (`onboarding`, `settings`). Use context-appropriate header: `"Your year deserves more"` for onboarding; `"Upgrade Your Plan"` for settings.

### M7. OnThisDayView — add explicit back navigation
- **File:** `blink-ios/Blink/Views/OnThisDayView.swift`
- **Line ~37** — Presented as `.fullScreenCover` with only drag-to-dismiss
- **What to do:** Add an `X` button in the top-right corner with `accessibilityLabel("Close")`. Drag-to-dismiss is fine as secondary but cannot be the only path.

---

## Lower-Priority Brand Fixes

### L1. TrimView alert — more helpful secondary actions
- **File:** `blink-ios/Blink/Views/TrimView.swift`
- **Lines ~85-97** — Alerts use `.default(Text("OK"))` dismiss. Consider: "Trim failed" → ["Save as new clip", "Discard", "Cancel"]

### L2. CloseCircleView — replace UUIDs with names
- **File:** `blink-ios/Blink/Views/CloseCircleView.swift`
- **Line ~40** — `memberID.prefix(8)` shows meaningless hex strings
- **What to do:** Display contact name (from Contacts framework) or phone number instead. If no contact info, show "Member 1", "Member 2" etc.

### L3. Multiple silent clipboard operations
- **File:** `blink-ios/Blink/Services/SocialShareService.swift` and related
- Throughout: `UIPasteboard.general.string = ...` with no toast confirmation
- **What to do:** Standardize on a `ToastService` — every clipboard write shows a brief toast: `"Link copied!"` for 2 seconds.

### L4. StorageDashboardView — hide zero-value sections
- **File:** `blink-ios/Blink/Views/StorageDashboardView.swift`
- **Lines ~100-120** — Shows "0 MB saved" and "0 duplicates found" for new users
- **What to do:** Use `@ViewBuilder` conditionals to hide sections where the value is 0. New users shouldn't see "Compression savings: 0 MB" — it clutters the dashboard.

---

## My Top 5 for Unified Plan (Brand Contribution)

These are the Brand/UX issues that, if fixed, will have the most immediate positive impact on user experience:

```
1. FreemiumEnforcementView user trap — [ContentView.swift line ~49] add hasAcknowledgedFreemiumToday flag + [FreemiumEnforcementView.swift] add dismiss button with "Continue Browsing" + add accessibilityLabel to all 7 buttons. This is the single worst UX failure in the app.

2. Onboarding completion page missing + page 1 has no illustration — [OnboardingView.swift] add celebratory 4th page after "Unlock More" with "You're all set" + create BlinkLogoGraphic for page 1. Onboarding is the first impression — it currently ends on a marketing page with no closure moment.

3. No loading states anywhere (RecordView camera setup, SocialShareSheet private link, CommunityView) — Add ProgressView overlays + skeleton states. Users see black screens and silent waits where every other camera app shows feedback. This is a trust signal issue.

4. Theme.swift design tokens completely unused — All 40+ views use hardcoded Color(hex:) instead of Theme.*. One systematic migration (Theme.swift → all views) simultaneously fixes: color drift (Architect), Dynamic Type failure (Accessibility), spacing chaos (Architect), and brand consistency (Brand). This is the highest-leverage single refactor.

5. ErrorStatesView clinical copy + PlaybackView no undo — Rewrite error messages to be human ("That didn't work. Let's try again." not "Something went wrong.") + add undo toast in PlaybackView after delete. These two small fixes address the emotional moments where users feel abandoned by the app.
```

---

## Architectural Dependencies (For Coordinated Fixes)

| Fix | Depends On | Enables |
|-----|-----------|---------|
| Priority 1 (FreemiumEnforcement) | `@AppStorage` flag in ContentView | FreemiumState management, a11y fixes |
| Priority 2 (Onboarding) | ApertureGraphic animation fix | Accessibility Reduce Motion compliance |
| Priority 3 (Loading states) | Task cancellation (SwiftUI) | Network monitoring (Platform) |
| Priority 4 (Humanized copy) | `String(localized:)` infrastructure (Platform) | Localization, a11y string auditing |
| Priority 5 (Theme tokens) | Font token fixes in Theme.swift | Dynamic Type, SwiftLint rule, a11y color contrast |

---

*End of Brand/UX Action Plan — Phase 3*
