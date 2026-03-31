# AUDIT3 — Architecture & Design Round 3

**Auditor:** Architect Agent
**Scope:** Blink iOS codebase — architecture, design tokens, spacing, corner radii, typography, architecture patterns
**Baseline:** Round 1 (50 issues), Round 2 (25 issues)

---

## Summary

Round 2 made meaningful progress: VideoStore memoization cache added, AdaptiveCompressionService `@MainActor` isolation, Theme font tokens defined. But several Round 2 promises remain **unfulfilled** — the new tokens were defined but not adopted, and two genuine new bugs surfaced in the trim/path code.

---

## NEW Issues (introduced in R2 or found in this round)

### CRITICAL

**[CRITICAL] VideoStore.swift:203 — trimClip overwrite path creates duplicate entry with new UUID**

```swift
} else {
    let oldIndex = entries.firstIndex { $0.id == entry.id }
    var updatedEntry = entry
    updatedEntry.thumbnailFilename = thumbnailFilename
    try? fileManager.removeItem(at: sourceURL)
    if let idx = oldIndex {
        entries[idx] = newEntry  // BUG: newEntry has auto-generated new UUID
    }
}
```

`newEntry` is initialized with `VideoEntry(...)` which auto-generates `UUID()`. The code assigns `newEntry` (with new ID) to replace `entry` (with old ID). This means:
- The original entry's ID is **silently replaced** with a new UUID
- `entries[idx] = newEntry` stores an entry with a different ID
- `updatedEntry` is computed but never used
- If `oldIndex == nil`, the old video file is deleted but `entries` still holds stale data pointing to a non-existent file

The comment says "keep same entry ID" — but the code does the opposite. This breaks all external references (deep links, On This Day, PlaybackView) that rely on stable entry IDs.

**Fix:** Replace `entries[idx] = newEntry` with `entries[idx] = entry` (preserve original ID and fields), OR properly construct `updatedEntry` with the new filename and use it.

---

**[CRITICAL] VideoStore.swift:356 — On This Day cache not invalidated by `updateTitle` or `toggleLock`**

`onThisDayEntries()` is cached via `_cachedOnThisDayEntries`. The cache is invalidated by:
- `invalidateOnThisDayCache()` → called from: `addVideo`, `deleteEntry`, `trimClip`, `updateEntry`, `restoreEntry`

But **NOT** called from:
- `updateTitle(for entry:, title:)` — modifies `entry.title`
- `toggleLock(for entry:)` — modifies `entry.isLocked` ← **changes cache eligibility**

`onThisDayEntries()` filters by `!entry.isLocked`. If a user locks/unlocks an entry, the cache returns stale results. If a user edits a title, the cache remains valid (less severe but still wrong).

**Fix:** Call `invalidateOnThisDayCache()` in both `updateTitle` and `toggleLock`.

---

### HIGH

**[HIGH] Theme.swift — BlinkFontStyle defined but ZERO views use it**

Theme.swift defines `BlinkFontStyle` and `Font.blinkText(_:)` — but across all views (496+ `.font()` call sites), **not a single view** uses `Font.blinkText(_:)`. Every view uses raw `.font(.system(size:, weight:))`. The Dynamic Type promise from R2 is **not delivered**.

This means:
- Users with accessibility text size preferences get **no scaling benefit**
- The `BlinkFontStyle` enum exists but is dead code
- WCAG compliance target (Dynamic Type) is not met

**Fix:** Migrate all views to use `Font.blinkText(_: BlinkFontStyle)` for all text elements.

---

**[HIGH] CustomGraphics.swift — All corner radii hardcoded (40+ instances)**

`CustomGraphics.swift` is a pure design asset file (preview mockups). Every corner radius is hardcoded: `cornerRadius: 6`, `cornerRadius: 10`, `cornerRadius: 12`, `cornerRadius: 16`, `cornerRadius: 4`. Not a single `Theme.cornerRadius*` token used.

While this is a preview-only file, it means the mockups don't accurately represent what the real components look like — and any future component that copies these values will inherit inconsistency.

**Fix:** Use `Theme.cornerRadiusSmall/Medium/Large` in all graphics.

---

**[HIGH] Theme.swift — All spacing tokens defined but ZERO views use them**

Theme defines `spacing2` through `spacing48` (20 tokens). Not a single view uses `Theme.spacing*` — all spacing is hardcoded numeric values (8, 12, 16, 24, etc.). The spacing scale was established but not applied.

**Fix:** Audit all view padding/margin usages and replace with Theme spacing tokens.

---

### MEDIUM

**[MEDIUM] CustomGraphics.swift:114 — TitleInputGraphic hardcodes border color instead of using Theme**

```swift
.stroke(Color(hex: "ff3b30"), lineWidth: 1)
```
Should use `Theme.accent` for consistency.

---

**[MEDIUM] CalendarView.swift:183 — yearSelector year text uses `.system(size: 20, weight: .bold)`**

Hardcoded font not using BlinkFontStyle (or even Theme.font*). Should be `Font.blinkText(.title2)` or at minimum `Theme.fontTitle2`.

---

**[MEDIUM] MonthBrowserView.swift — MonthBrowseCard uses Theme.cornerRadiusSmall correctly, but `monthGrid` in JumpToMonthView uses `Theme.cornerRadiusSmall` inconsistently with the card layout in MonthBrowserView**

Inconsistent: `MonthBrowseCard` uses `Theme.cornerRadiusSmall`, but nearby `JumpToMonthView.monthGrid` also uses it — however the grid spacing (`spacing: 12`) doesn't align with the Theme spacing scale (no `spacing12` token used anywhere, though it exists).

---

**[MEDIUM] PrivacyService.swift — `verifyPasscode` uses SHA256, not a dedicated password hashing primitive**

While SHA256 is used correctly (with constant-time comparison via `Data==`), the industry standard for password hashing is **Argon2** or **bcrypt**. SHA256 is vulnerable to GPU-accelerated brute force for short passcodes. For a 6-digit PIN this is a real risk.

**Fix:** Use `CryptoKit.PHKDF2` with sufficient iterations, or migrate to `Argon2` via a library.

---

### LOW

**[LOW] VideoStore.swift — `onThisDayEntries` cache invalidation is async-not-safe**

`invalidateOnThisDayCache()` is a plain function that sets `_cachedOnThisDayEntries = nil`. Since `VideoStore` is `@MainActor`, this is safe for the current usage. But if VideoStore is ever accessed from a background context (e.g., a widget), the cache could race. Document or enforce MainActor isolation on the cache methods.

---

**[LOW] AdaptiveCompressionService — `compressEntry` is not `@MainActor` but updates `@Published` state via `await MainActor.run { }`**

```swift
func compressEntry(_ entry: VideoEntry) async -> Int64 {
    ...
    await MainActor.run {
        processedCount += 1
        totalSavedBytes += saved
        ...
    }
}
```
This is a code smell — `compressEntry` is a plain `async` method that bridges to MainActor. Since it's only ever called from `compressEligibleEntries` (which IS `@MainActor`), it works. But it's fragile: calling `compressEntry` directly from any other context would update `@Published` state off-main-thread.

**Fix:** Mark `compressEntry` as `@MainActor` and remove the `MainActor.run` wrapper.

---

**[LOW] Theme.swift — BlinkFontStyle doesn't expose weight variations**

`BlinkFontStyle` only covers the base style (e.g., `.body` → `.body` font). It doesn't support weight variants like `fontHeadline`, `fontSubheadlineBold`, etc. All weight variants in views are hardcoded `.font(.system(size: 14, weight: .medium))`. The Theme defines `fontCaption2Bold` but the enum doesn't expose it.

---

## Remediated Issues (verified fixed from R2)

- ✅ **VideoStore memoization** — `onThisDayEntries()` cache correctly invalidated on writes
- ✅ **AdaptiveCompressionService race** — `@MainActor` on `compressEligibleEntries` with sequential `for` loop; not parallel so no race on `processedCount`/`totalSavedBytes`
- ✅ **Theme color tokens** — All views use `Color(hex:)` consistently; no raw hex strings in business logic
- ✅ **Theme corner radius in most views** — CalendarView, MonthCard, OnThisDayView, PlaybackView, SearchView, SkeletonMomentCard all use `Theme.cornerRadius*` correctly
- ✅ **CalendarView observer leaks** — R2 explicitly fixed Task/observer cleanup in TrimView and PlaybackView

---

## Remaining Issues from Prior Rounds (not yet fixed)

These were flagged in R1/R2 and persist:

1. **496+ hardcoded font sizes** across all views — BlinkFontStyle was defined but never wired up
2. **All hardcoded spacing values** — Theme.spacing tokens defined but unused
3. **CustomGraphics corner radii** — All 40+ instances hardcoded (same issue as R1)
4. **CommunityView skeleton loading** — Still uses hardcoded `cornerRadius: 14` for category chips

---

## Priority Recommendations for Round 4

| Priority | Issue | File | Impact |
|----------|-------|------|--------|
| P0 | trimClip overwrite UUID bug | VideoStore.swift:203 | Data integrity, deep links broken |
| P0 | cache invalidation missing | VideoStore.swift:356 | On This Day returns stale data |
| P1 | BlinkFontStyle zero adoption | All views | Accessibility / Dynamic Type |
| P1 | CustomGraphics corner radii | CustomGraphics.swift | Design token system incomplete |
| P1 | Spacing tokens unused | All views | Spacing system incomplete |
| P2 | compressEntry MainActor | AdaptiveCompressionService.swift | Code fragility |
| P2 | SHA256 for passcode hashing | PrivacyService.swift | Security hardening |
| P3 | BlinkFontStyle weight variants | Theme.swift | Typography system incomplete |
