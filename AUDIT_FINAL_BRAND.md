# Blink iOS — Brand/UX Final Audit

**Auditor:** Brand/UX Auditor (Subagent)
**Date:** 2026-04-01
**Scope:** Full codebase — visual hierarchy, copy tone, interaction quality, product coherence
**Files reviewed:** 81 Swift files across Views/, Services/, Models/, App/

---

## Summary

Blink iOS has a strong visual foundation — dark theme, consistent accent (#ff3b30), a coherent color system, and solid typographic tokens in Theme.swift. The onboarding copy is genuinely moving. But there are **critical accessibility failures**, **ghost UI overlays** that block functional screens, **inconsistent interaction patterns**, and several places where the product persona fractures.

---

## CRITICAL Issues

### 1. [CRITICAL] Theme.swift — WCAG AA Contrast Failures (3 instances)

`Theme.swift:73-87`

The file's own comments claim WCAG AA compliance, but the contrast ratios do not hold:

- `textSecondary = #AAAAAA` on `background = #0a0a0a` → **~3.5:1** (WCAG AA requires **4.5:1**)
- `textTertiary = #888888` on `backgroundSecondary = #141414` → **~3.4:1** (WCAG AA requires **4.5:1**)
- `textQuaternary = #AAAAAA` on `background = #0a0a0a` → **~3.5:1**

All three fail WCAG AA minimum for normal text. Every view that uses these tokens for readable content is inaccessible to users with low vision. This is the most serious issue in the codebase.

**Fix:** Bump all three to at least `#B0B0B0` (≈4.6:1 on #0a0a0a) and `#999999` (≈4.5:1 on #141414), or use the existing `textSecondary` (#AAAAAA) as the minimum for any body/caption text.

---

### 2. [CRITICAL] CommunityView.swift:35-40 — Ghost Overlay on Functional UI

```swift
ZStack {
    if communityService.isLoading {
        skeletonLoadingView
    } else {
        communityContent
    }
    // Coming Soon overlay — this feature is not yet functional
    VStack {}
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(hex: "0a0a0a").opacity(0.85))
        .overlay { ... "Coming Soon" ... }
}
```

The "Coming Soon" overlay covers **everything** — the skeleton loader, the content, everything. Users see a skeleton animation AND a "Coming Soon" message simultaneously, which reads as a broken UI. The overlay should only appear on `communityContent` when empty, not over loading states. Same issue in CrossDeviceSyncView.swift:35.

---

### 3. [CRITICAL] BlinkApp.swift — Freemium Gate Without Legible Floor

`BlinkApp.swift:77-79`

```swift
if !SubscriptionService.shared.hasActiveSubscription {
    FreemiumEnforcementView(...)
}
```

Every tab/view is gated by this check. Free users get `FreemiumEnforcementView` for any premium feature. This is the correct enforcement, but the copy in `FreemiumEnforcementView` doesn't clearly establish what free users CAN do. The freemium floor is invisible — users don't know if they have any access at all. The product's promise ("one moment a day") needs to be visible in the empty/allowed state, not hidden behind a paywall screen.

---

## HIGH Issues

### 4. [HIGH] ErrorStatesView.swift — "Trim didn't save" is cold and unhelpful

`ErrorStatesView.swift`

The trim failure state uses the title "Trim didn't save" — this is technically accurate but emotionally flat for what is actually a high-stakes moment (the user just spent time trimming and the result was lost). Compare to the camera error "This clip got a bit tangled" which has personality. The trim error should match the wit of the rest of the app.

---

### 5. [HIGH] ErrorStatesView.swift — "This clip got a bit tangled" tone mismatch

`ErrorStatesView.swift`

The playful tone works for minor states but feels inappropriate for a camera/recording failure. Not every error state should use warm/casual copy — severity-appropriate tone would build more trust.

---

### 6. [HIGH] PrivacyLockView.swift — Shake animation runs but wrong passcode text isn't shown

`PrivacyLockView.swift:171`

`shakeAnimation()` is called when wrong passcode entered, but `wrongPasscode = true` is set, which shows "Wrong passcode" — however the animation completes in 0.5s and `wrongPasscode` stays true indefinitely until next input. This means the error text persists even after the shake is done, confusing the user about whether they can retry.

---

### 7. [HIGH] OnThisDayView.swift — "On This Day" empty state lacks emotional pull

`OnThisDayView.swift`

The empty state headline is generic. For a product whose entire value proposition is emotional ("the only video diary that matters"), this screen's empty state should match that register. The onboarding already has the right voice ("Every day you don't record is a day you'll never quite remember the same way"). This screen should too.

---

### 8. [HIGH] Theme.swift — `glassBackground()` modifier is defined but never used

`Theme.swift:310-316`

```swift
struct GlassBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial)
            .background(Color.black.opacity(0.5))
    }
}
```

The iOS 26 "Liquid Glass" aesthetic is referenced in the file header but never applied anywhere. If this is a planned design direction, it should be visible in at least one place (e.g., the playback overlay). If it's not, it should be removed.

---

### 9. [HIGH] MonthStripView (CustomGraphics.swift) — Hardcoded density values

`CustomGraphics.swift:290-295`

```swift
private func monthHeight(for month: Int) -> CGFloat {
    let densities: [Int: CGFloat] = [
        1: 0.5, 2: 0.3, 3: 0.7, 4: 0.6, 5: 0.8, 6: 0.4,
        7: 0.9, 8: 0.7, 9: 0.5, 10: 0.6, 11: 0.8, 12: 0.4
    ]
```

These hardcoded values appear in the Year in Review mockup graphic. If the graphic is meant to preview real data, it should compute actual density. If it's purely decorative, the comment should say so. As-is, it looks like a bug.

---

### 10. [HIGH] YearInReviewGraphic.swift — Hardcoded progress ring (0.23)

`CustomGraphics.swift:233`

```swift
progress = 0.23 // ~83/365 of the year
```

83/365 = 0.227. The code says 0.23. The comment and value don't match cleanly. If this is a static preview value, it should be labeled as such and use a round number (0.25 for "Q1 complete" or whatever the intended message is).

---

## MEDIUM Issues

### 11. [MEDIUM] TrimView.swift — Uses `.system(size:)` instead of BlinkFontStyle

`TrimView.swift:many locations`

Throughout TrimView, font sizes are set with raw `.system(size:)` calls rather than the design system's `BlinkFontStyle` tokens. This creates visual inconsistency — the trim view's typography doesn't match the rest of the app.

---

### 12. [MEDIUM] CommunityService — Loaded but never called on appear

`CommunityView.swift`

```swift
@StateObject private var communityService = CommunityService.shared
...
.task {
    await communityService.loadPublicFeed()
}
```

The service is referenced and `loadPublicFeed()` is called, but the `publicMoments` array that the UI reads is always empty because the service returns stub/mock data. This is a "coming soon" screen masquerading as a live feed.

---

### 13. [MEDIUM] PricingView.swift — Subscription tiers use `.tagline` inconsistently

`PricingView.swift`

- Free tier tagline: "Just enough to start" — this frames the free tier as intentionally limited rather than genuinely useful. It may discourage signups.
- The design correctly highlights the "Memories" tier as "POPULAR" with a badge, but the Free tier's framing undermines upgrade desire by implying inadequacy.

---

### 14. [MEDIUM] PrivacyLockView.swift — Biometric prompt auto-fires without explicit consent UX

`PrivacyLockView.swift:71`

```swift
.onAppear {
    if !isSettingUp {
        attemptBiometric()
    }
}
```

Biometric authentication fires automatically on appear. While this is convenient, iOS convention is to show the passcode entry screen first and offer biometric as an option on it, rather than auto-triggering. This also creates confusion when biometric fails (the user sees a passcode screen but doesn't understand why they landed there).

---

### 15. [MEDIUM] FreemiumEnforcementView.swift — Upgrade CTA uses "Your year deserves more" but shown on feature block

`FreemiumEnforcementView.swift`

The headline "Your year deserves more" is strong and emotionally resonant. But it's shown as a *block screen* rather than a *preview*. Showing what the user is missing (a preview of the feature) before asking them to upgrade would be more compelling than a static enforcement screen.

---

### 16. [MEDIUM] RecordView.swift — "Last clip: \(todayEntry.formattedDate)" shows raw date format

`RecordView.swift:218`

The date format shows as "Apr 1, 6:30 AM" — which is the `formattedDate` from VideoEntry. This is fine, but if the user recorded a clip today, the label "Last clip: Apr 1, 6:30 AM" is confusing (they just recorded it, they know). Should say "Last clip: just now" or "Today's clip recorded" for today's date.

---

### 17. [MEDIUM] CalendarView.swift — "Default Settings" section header is flat

`CalendarView.swift`

The Settings section header "Default Settings" is generic/branded-out. Compare to other section headers like "Privacy Tools" in PrivacySettingsView — the naming is inconsistent in personality.

---

### 18. [MEDIUM] SocialShareSheet — "Blink to Friends" subtitle says "Send directly to a contact" but actually copies a link

`SocialShareSheet.swift`

The flow is: create link → copy to clipboard → user sends manually. The subtitle promises "Send directly to a contact" but the implementation doesn't actually send — it just copies. This is misleading UX.

---

## LOW Issues

### 19. [LOW] `AboutView.swift` — "Made with love" is a cliché

`SettingsView.swift` (AboutView)

"Made with love" belongs in a footer of a personal blog, not a product's About screen. The app already has strong personality elsewhere — this should match.

---

### 20. [LOW] PlaybackView.swift — "person.2.fill" icon used for social share action

`PlaybackView.swift:117`

The icon for "Share with friends" is `person.2.fill` (people/social). The share action opens `SocialShareSheet` which has three options: private link, contacts, and public feed. The icon is appropriate for the contacts path but confusing as a general share affordance. `square.and.arrow.up` (already used for export) or `paperplane.fill` would be more universally understood.

---

### 21. [LOW] BlinkFontStyle has duplicate/overlapping styles

`Theme.swift:150+`

`display42Bold` and `display64BoldRounded` are both defined. `display56` and `display50` are also both defined. These are used in different places but feel like they were added ad-hoc rather than part of a systematic scale. Consider rationalizing to a cleaner type scale.

---

### 22. [LOW] SubscriptionsView — "Manage Subscriptions" link uses a hardcoded URL

`SubscriptionsView.swift`

```swift
Link(destination: URL(string: "https://apps.apple.com/account/subscriptions")!)
```

This URL format can break with locale changes. Should use `URL(string: UIApplication.openSettingsURLString)` pattern or `SKPaymentQueue.receiptURL` approach for in-app subscription management deep links.

---

## Positive Notes

The following are genuinely strong and should be preserved:

- **Onboarding copy** is excellent — "Every day you don't record is a day you'll never quite remember the same way" is the best copy in the app. It should appear in more places.
- **Theme system** is well-structured — the color tokens, spacing tokens, and font style enum are coherent and maintainable.
- **HapticService** integration is thorough and consistent — appropriate use of haptic language throughout.
- **Accessibility labels** are present on almost all interactive elements — this is a genuine strength.
- **`accessibilityReduceMotion`** checks are present in animations — good a11y practice.
- **RecordView countdown** UX is well-thought-out — 3-2-1 countdown before recording with haptic feedback.
- **ErrorStatesView** has genuine personality in the "This clip got a bit tangled" line — tone is right for casual errors.

---

## Priority Fix Order

1. **Fix contrast ratios** (Issue #1) — legal/accessibility risk
2. **Fix ghost overlays** (Issue #2) — user confusion/broken UI perception
3. **Clarify freemium floor** (Issue #3) — product trust
4. **Fix TrimView font styles** (Issue #11) — visual consistency
5. **Fix SocialShareSheet copy vs. reality** (Issue #18) — trust/misleading UX
6. **Fix biometric auto-trigger** (Issue #14) — iOS convention
7. **Polish error state copy** (Issues #4, #5) — product voice
8. **Remove hardcoded preview values** (Issues #9, #10) — credibility
9. **Fix PrivacyLockView shake persistence** (Issue #6) — UX confusion
10. **Add `glassBackground` usage or remove it** (Issue #8) — dead code

---

*End of audit.*
