# Blink Brand/UX Audit — Phase 1

**Auditor:** Brand/UX Auditor Agent  
**Date:** 2026-03-30  
**Scope:** All Swift files in `blink-ios/` and `blink/` (blink-icons/ does not exist)

---

## Summary

The codebase has a strong visual identity (dark-first palette, red accent `ff3b30`, cohesive Theme constants) and generally good interaction feedback (HapticService). However, there are significant gaps in empty states, error messaging, copy tone consistency, and navigation clarity. The app has a serious tone that occasionally produces clinical microcopy where personality could shine.

---

## Findings

### CRITICAL

1. **OnboardingView.swift:45-66** — Onboarding page 1 ("Blink") has no illustration, icon, or graphic. Only a title and subtitle on a black background. Every other onboarding page has a graphic; this one is visually empty.

2. **OnboardingView.swift:1-200** — Onboarding is missing a final "completion" page with a CTA to start recording. The user reaches the last page (page 3, "Unlock More") with a "Continue" button that goes to `hasCompletedOnboarding = true`, but there's no celebratory or congratulatory moment — no "You're all set" message, no illustration, no transition animation description.

3. **ContentView.swift:49-51** — The `onAppear` block that navigates to `FreemiumEnforcementView` fires every time `ContentView` appears. If a free user tries to dismiss the enforcement sheet, it will immediately re-appear on next appear, making it impossible to dismiss. No state to track if user has acknowledged.

4. **RecordView.swift:1-100** — No loading state while camera session is being configured. If `setupSession()` takes time, user sees a black screen with no spinner, progress indicator, or "Setting up camera…" message.

5. **FreemiumEnforcementView.swift:1-100** — No close/dismiss button or gesture. The user is trapped on this view with no escape path. This is a CRITICAL navigation issue for free users who want to browse their existing clips.

6. **FreemiumEnforcementView.swift:56-60** — Generic button label: "Upgrade to Unlock". Every other primary CTA in the app is more specific ("Subscribe to Memories", "Get Started"). This button doesn't communicate value.

7. **PricingView.swift:1-100** — The onboarding pricing view (`PricingView`) is labeled "Choose Your Plan" but is used for both initial onboarding AND general settings. The header copy "Your year deserves more" is tone-deaf for users who are already subscribed or just browsing. No conditional header based on context.

8. **CalendarView.swift:53-71** — `OnThisDayView` is presented as a `.fullScreenCover` when the user taps a "On This Day" indicator on a calendar day. However, `OnThisDayView` has no explicit back navigation — no X button, no "Done" button. The only way to dismiss is a drag gesture. If drag-to-dismiss fails on any device, user is stuck.

9. **PlaybackView.swift:100-115** — After a clip is deleted (`onDelete`), the view dismisses but there's no "Undo" mechanism. Standard iOS pattern is to show a toast/snackbar with "Clip deleted" and an Undo action for ~4 seconds.

10. **SocialShareSheet.swift:1-100** — No loading state when `createPrivateLink()` is called. The user taps "Private Link" and nothing visibly changes until the link appears — potentially 1-2 seconds with no feedback.

---

### HIGH

11. **ErrorStatesView.swift:44** — Error state message: `"Something went wrong. Please try again."` — this is textbook generic error copy. The app has personality in other places but error states are all clinical. Should be humanized: "That didn't work. Let's try again."

12. **ErrorStatesView.swift:58** — `"Unable to load your clips."` — Passive, no context about why. Could include: "We couldn't load your clips. Make sure you're connected to the internet."

13. **CalendarView.swift:1-100** — The calendar month cells show clip count as a plain number (e.g., "7") with no visual distinction between "1 clip" and "7 clips." All dots are the same size and color regardless of density.

14. **OnboardingView.swift:72-86** — Onboarding page 2 ("One Second") uses the `ApertureGraphic` (a static image) rather than an animated aperture. The graphic has animation code inside it (`isOpen`, `withAnimation`), but it's inside a `#Preview` context and the actual OnboardingView just displays the static `ApertureGraphic()` without triggering the `.onAppear` animation. The aperture never opens.

15. **YearInReviewGraphic.swift (in CustomGraphics.swift)** — The `YearInReviewGraphic` used in `YearInReviewCompilationView` uses a hardcoded `"83"` clips example in its preview. The actual data (`clipsThisYear`) is passed in as a parameter but the preview renders 83 as a static string — could confuse reviewers/testers.

16. **Theme.swift** — `cornerRadiusLarge = 16` but `cornerRadiusMedium = 12` — only 4pt difference. These are so close they're visually indistinguishable at small sizes. Either consolidate or make the gap larger (e.g., 16 vs 8).

17. **SubscriptionService.swift:97** — `blockReasonForRecording` returns a string like: `"Free clips are capped at 30 seconds. Upgrade to Memories for up to 60 seconds."` — This is shown to users but is written in service-layer prose, not UI copy. It should be broken into title + body or provided as structured data (title, message, actionLabel) to match how it's displayed.

18. **CommunityView.swift:1-100** — Community/Public Feed shows placeholder data with fake anonymous IDs (`"user_a7x2"`) and static likes/views counts. There's no empty state if the public feed returns no items. There's also no loading skeleton — just a blank screen while `loadPublicFeed()` runs.

19. **PrivacyLockView.swift:1-100** — No explanation of what biometric auth is for on first setup. The passcode setup view just says "Enter a passcode" with no context about why. First-time users may think this is required to use the app vs. being an optional privacy feature.

20. **PrivacySettingsView.swift:1-100** — Toggle labels are plain and functional ("App Lock," "Lock on Background," "Require Auth to Open"). No descriptive subtitles explaining what each toggle does for a user who doesn't know what "biometric auth" means.

---

### MEDIUM

21. **SearchView.swift:1-100** — Search field placeholder is "Search by title or date" — this is fine but generic. Blink clips don't have user-defined titles by default (they use `defaultTitle` which is a date string). Searching by "title" is confusing since most clips don't have titles.

22. **TrimView.swift:85-97** — Alert titles for trim errors are functional but plain: `"Trim failed"`, `"Storage full"`, `"Clip not found"`. The messages are decent but the alerts use `.default(Text("OK"))` dismiss buttons rather than more helpful secondary actions (e.g., "Trim failed" → "Save as new clip" / "Discard").

23. **SubscriptionsView.swift:1-100** — The FAQ section has no expand/collapse behavior. All 3 answers are visible at once, making the FAQ section very long. Standard iOS pattern is accordion/expand-collapse per question.

24. **PricingView.swift:171-180** — "Cancel anytime. No commitments." as a footer below the subscribe button is good copy. However, there's no mention of what happens to clips if the user cancels — SubscriptionService has `retentionDays` logic but this is never communicated to the user in the UI.

25. **StorageDashboardView.swift:1-100** — The storage dashboard shows compression savings in bytes (`"23.4 MB saved"`) and deduplication count. But if both services return 0 savings (common for new users), the dashboard still shows these sections with 0 values, creating visual clutter for users who haven't used those features yet.

26. **CalendarView.swift** — No visual treatment for days with zero clips. Empty calendar cells look identical to days with 1 clip (just the day number). At minimum, days with 0 clips should look different from days with ≥1 clip.

27. **PasscodeSetupView.swift:1-100** — Passcode entry uses a custom 6-dot indicator. When a digit is entered, the dots fill in sequentially. However, there's no haptic feedback on digit entry, no animation on error shake, and the error state (wrong passcode) uses a generic `Text("Try again")` below the dots.

28. **RecordView.swift** — The countdown overlay (3, 2, 1, GO) has no audio cue (standard in camera apps). There's no haptic tick per countdown number — only the HapticService methods exist but are they called? Let me verify: `countdownTick()` is defined but I don't see it called in the countdown logic in `RecordView`.

29. **ContentView.swift:37** — Tab bar has unlabeled icons: the `.tabItem` labels are present but in the dark theme, tab bar icons without a selected tint may appear identical in selected/unselected states depending on system settings.

30. **OnboardingView.swift:88-110** — Page 3 ("Unlock More") uses `YearInReviewGraphic` which shows "83 clips" hardcoded in its `.onAppear`. This graphic is used as an onboarding marketing graphic — showing a user 83 clips when they have 0 is misleading.

---

### LOW

31. **Theme.swift** — All hex colors use 6-digit format. The dark background is `#0a0a0a` which is almost-black. In true black mode (`UIScreen.main.brightness`), pure black `#000000` OLED displays benefit more than `#0a0a0a`. Not a bug but a missed optimization.

32. **HapticService.swift:1-100** — All haptic methods exist and are well-organized. However, I don't see `countdownTick()` called in the RecordView countdown logic. If the countdown uses a Timer, haptics may be missing.

33. **DeepAnalysisView.swift** — The empty state icon is `brain.head.profile` (SF Symbol). This is obscure and not obviously related to "deep analysis." A more recognizable icon would help (e.g., `sparkles` or a custom brain icon).

34. **AIHighlightsView.swift:73-80** — "Analyzing your clips…" loading state is good. But the subtitle "Finding your most meaningful moments" uses third-person ("your clips") when most other loading states in the app use second-person ("your clips"). Minor but inconsistent.

35. **OnboardingView.swift:16-22** — The `OnboardingPage` struct has `let title: String, let subtitle: String, let iconName: String` — `iconName` is used for SF Symbols, but several onboarding pages use custom `GraphicView` types instead (e.g., `ApertureGraphic`, `YearInReviewGraphic`). The struct conflates simple icon pages with custom graphic pages, forcing a workaround where `iconName` is unused for custom-graphic pages.

36. **SocialShareService.swift:1-100** — The fallback share URL is `blink://share` as a constant string literal. This is fine technically but if the URL scheme `blink://` is not registered in the app's Info.plist, this link will fail silently. No defensive check exists.

37. **VideoStore.swift:131** — `formattedDate` in `VideoEntry` uses `"MMM d, h:mm a"` which produces "Mar 30, 3:30 PM". This format drops the year, which is fine for recent clips but confusing for clips from previous years — no year shown. The `displayTitle` / `defaultTitle` should clarify the year when clip is from a previous year.

38. **CloseCircleView.swift** — The circle member display uses truncated UUIDs (`memberID.prefix(8)`) which are meaningless strings. No avatar, no name, no phone number — just a hex string that gives no sense of who is in the circle.

39. **YearInReviewCompilationView.swift:1-100** — The `generateReel()` function shows a progress percentage (0-90%) animated via Timer while actual reel generation is happening. The animation is decoupled from actual progress — user could see 45% for 10 seconds with no visible activity. This creates anxiety rather than confidence.

40. **Clipboard/Export copy** — Multiple services copy to clipboard (`UIPasteboard.general.string`) without showing any toast or confirmation to the user that something was copied. Only `SocialShareSheet` shows a brief "Link copied to clipboard!" message; other clipboard operations (export confirmation, share text) are silent.

---

## Top 10 Priority Fixes

1. Fix `ContentView.onAppear` re-triggering FreemiumEnforcement on every appear (CRITICAL #3)
2. Add dismiss mechanism to FreemiumEnforcementView (CRITICAL #5)
3. Add back navigation to OnThisDayView (CRITICAL #8)
4. Fix ApertureGraphic animation not triggering on OnboardingView page 2 (HIGH #14)
5. Add loading states to RecordView camera setup (CRITICAL #4)
6. Humanize all error messages in ErrorStatesView (HIGH #11)
7. Add "Undo" after delete in PlaybackView (CRITICAL #9)
8. Add loading feedback to SocialShareSheet private link creation (CRITICAL #10)
9. Show conditional empty states in CommunityView (HIGH #18)
10. Fix year-in-review graphic showing hardcoded "83 clips" during onboarding (HIGH #30)

---

*End of Phase 1 Brand/UX Audit*
