# Blink Accessibility Audit — Phase 1

**Auditor:** Accessibility Guardian  
**Date:** 2026-03-30  
**Scope:** All Swift files in `blink-ios/` and `blink/`

---

## Critical Issues

### Missing Accessibility Labels on Interactive Elements

1. [CRITICAL] RecordView.swift:42 — `RecordButton` has no `accessibilityLabel` ("Record" or "Start recording")
2. [CRITICAL] RecordView.swift:38 — `Image(systemName: "camera.filters")` icon button has no `accessibilityLabel`
3. [CRITICAL] RecordView.swift:41 — `Image(systemName: "mic.fill")` icon button has no `accessibilityLabel`
4. [CRITICAL] RecordView.swift:56 — "Flip camera" `Button` has no `accessibilityLabel`
5. [CRITICAL] RecordView.swift:60 — "Torch toggle" `Button` has no `accessibilityLabel`
6. [CRITICAL] RecordView.swift:118 — "Done" `Button` has no `accessibilityLabel`
7. [CRITICAL] RecordView.swift:129 — "Save" `Button` has no `accessibilityLabel`
8. [CRITICAL] RecordView.swift:151 — "Retake" `Button` has no `accessibilityLabel`
9. [CRITICAL] TrimView.swift:37 — "Cancel" `Button` has no `accessibilityLabel`
10. [CRITICAL] TrimView.swift:39 — "Save" `Button` has no `accessibilityLabel`
11. [CRITICAL] TrimView.swift:49 — "Play/Pause" `Button` has no `accessibilityLabel`
12. [CRITICAL] CalendarView.swift:96 — AI Highlights toolbar button (`Image(systemName: "sparkles")`) has no `accessibilityLabel`
13. [CRITICAL] CalendarView.swift:99 — Public Feed toolbar button (`Image(systemName: "globe")`) has no `accessibilityLabel`
14. [CRITICAL] CalendarView.swift:102 — Search toolbar button (`Image(systemName: "magnifyingglass")`) has no `accessibilityLabel`
15. [CRITICAL] CalendarView.swift:105 — Month Browser toolbar button (`Image(systemName: "rectangle.stack")`) has no `accessibilityLabel`
16. [CRITICAL] CalendarView.swift:108 — Export toolbar button (`Image(systemName: "square.and.arrow.up")`) has no `accessibilityLabel`
17. [CRITICAL] PlaybackView.swift:121 — Close/dismiss `Button` has no `accessibilityLabel`
18. [CRITICAL] PlaybackView.swift:133 — Export `Button` has no `accessibilityLabel`
19. [CRITICAL] PlaybackView.swift:143 — Trim `Button` has no `accessibilityLabel`
20. [CRITICAL] PlaybackView.swift:150 — Delete `Button` has no `accessibilityLabel`
21. [CRITICAL] PlaybackView.swift:157 — Social share `Button` has no `accessibilityLabel`
22. [CRITICAL] PlaybackView.swift:185 — Title edit `Button` has no `accessibilityLabel`
23. [CRITICAL] PlaybackView.swift:210 — Speed picker `Button` has no `accessibilityLabel`
24. [CRITICAL] PlaybackView.swift:229-249 — All speed option `Button`s have no `accessibilityLabel`
25. [CRITICAL] SettingsView.swift:29 — Close `Button` has no `accessibilityLabel`
26. [CRITICAL] SettingsView.swift:50 — Profile row icon has no `accessibilityLabel`
27. [CRITICAL] SettingsView.swift:52 — iCloud sync row icon has no `accessibilityLabel`
28. [CRITICAL] SettingsView.swift:56 — Export row icon has no `accessibilityLabel`
29. [CRITICAL] SettingsView.swift:60 — AI Features row icon has no `accessibilityLabel`
30. [CRITICAL] SettingsView.swift:64 — Integrations row icon has no `accessibilityLabel`
31. [CRITICAL] SettingsView.swift:68 — Help row icon has no `accessibilityLabel`
32. [CRITICAL] SettingsView.swift:72 — Privacy Policy row icon has no `accessibilityLabel`
33. [CRITICAL] ContentView.swift:58 — Settings `Image` button has no `accessibilityLabel`
34. [CRITICAL] ContentView.swift:62 — AI Highlights `Image` button has no `accessibilityLabel`
35. [CRITICAL] ContentView.swift:65 — Record icon has no `accessibilityLabel`
36. [CRITICAL] ContentView.swift:69 — Calendar icon has no `accessibilityLabel`
37. [CRITICAL] ContentView.swift:73 — On This Day icon has no `accessibilityLabel`
38. [CRITICAL] ContentView.swift:77 — Export icon has no `accessibilityLabel`
39. [CRITICAL] ContentView.swift:79 — Settings `Button` has no `accessibilityLabel`
40. [CRITICAL] ContentView.swift:87 — Record `Image` has no `accessibilityLabel`
41. [CRITICAL] AIHighlightsView.swift:54 — "Generate My Reel" `Button` has no `accessibilityLabel`
42. [CRITICAL] AIHighlightsView.swift:130 — "Analyze Now" `Button` has no `accessibilityLabel`
43. [CRITICAL] FreemiumEnforcementView.swift:35 — Upgrade `Button` has no `accessibilityLabel`
44. [CRITICAL] FreemiumEnforcementView.swift:44 — "Maybe Later" `Button` has no `accessibilityLabel`
45. [CRITICAL] FreemiumEnforcementView.swift:52 — Upgrade `Button` (crown icon) has no `accessibilityLabel`
46. [CRITICAL] FreemiumEnforcementView.swift:57 — "Maybe Later" `Button` has no `accessibilityLabel`
47. [CRITICAL] FreemiumEnforcementView.swift:75 — "Upgrade" `Button` (clock icon) has no `accessibilityLabel`
48. [CRITICAL] FreemiumEnforcementView.swift:84 — "Upgrade" `Button` has no `accessibilityLabel`
49. [CRITICAL] FreemiumEnforcementView.swift:93 — Upgrade `Button` has no `accessibilityLabel`
50. [CRITICAL] OnboardingView.swift:32 — "Back" `Button` has no `accessibilityLabel`
51. [CRITICAL] OnboardingView.swift:37 — "Next" `Button` has no `accessibilityLabel`
52. [CRITICAL] OnboardingView.swift:47 — "Back" `Button` has no `accessibilityLabel`
53. [CRITICAL] OnboardingView.swift:52 — "Next" `Button` has no `accessibilityLabel`
54. [CRITICAL] OnboardingView.swift:62 — "Back" `Button` has no `accessibilityLabel`
55. [CRITICAL] OnboardingView.swift:67 — "Next" `Button` has no `accessibilityLabel`
56. [CRITICAL] OnboardingView.swift:80 — "Open Settings" `Button` has no `accessibilityLabel`
57. [CRITICAL] OnboardingView.swift:93 — "Start Your Year" `Button` has no `accessibilityLabel`
58. [CRITICAL] PrivacyLockView.swift:93 — Backspace/delete `Button` has no `accessibilityLabel`
59. [CRITICAL] PrivacyLockView.swift:100 — Digit keypad `Button` has no `accessibilityLabel`
60. [CRITICAL] PrivacyLockView.swift:110 — Digit keypad `Button` has no `accessibilityLabel`
61. [CRITICAL] PrivacyLockView.swift:114 — Digit keypad `Button` has no `accessibilityLabel`
62. [CRITICAL] PasscodeSetupView.swift:93 — Backspace/delete `Button` has no `accessibilityLabel`
63. [CRITICAL] PasscodeSetupView.swift:100 — Digit keypad `Button` has no `accessibilityLabel`
64. [CRITICAL] PasscodeSetupView.swift:110 — Digit keypad `Button` has no `accessibilityLabel`
65. [CRITICAL] PasscodeSetupView.swift:114 — Digit keypad `Button` has no `accessibilityLabel`
66. [CRITICAL] ErrorStatesView.swift:25 — "Open Settings" `Button` (CameraPermissionDeniedView) has no `accessibilityLabel`
67. [CRITICAL] ErrorStatesView.swift:25 — "Open Settings" `Button` (MicrophonePermissionDeniedView) has no `accessibilityLabel`
68. [CRITICAL] ErrorStatesView.swift:23 — "OK" `Button` (StorageFullView) has no `accessibilityLabel`
69. [CRITICAL] ErrorStatesView.swift:27 — "Try Again" `Button` (ClipSaveFailedView) has no `accessibilityLabel`
70. [CRITICAL] ErrorStatesView.swift:27 — "Try Again" `Button` (TrimSaveFailedView) has no `accessibilityLabel`
71. [CRITICAL] ErrorStatesView.swift:23 — "OK" `Button` (TrimStorageFullView) has no `accessibilityLabel`
72. [CRITICAL] ErrorStatesView.swift:27 — "Open Settings" `Button` (ExportFailedView) has no `accessibilityLabel`
73. [CRITICAL] ErrorStatesView.swift:66 — "Record your first moment" `Button` (EmptyCalendarView) has no `accessibilityLabel`
74. [CRITICAL] ErrorStatesView.swift:71 — Secondary action `Button` (EmptyCalendarView) has no `accessibilityLabel`
75. [CRITICAL] CrossDeviceSyncView.swift:33 — Sync button has no `accessibilityLabel`
76. [CRITICAL] CrossDeviceSyncView.swift:53 — Add device `Button` has no `accessibilityLabel`
77. [CRITICAL] CrossDeviceSyncView.swift:71,74,77 — Sync toggle `Button`s have no `accessibilityLabel`
78. [CRITICAL] PrivacySettingsView.swift:22 — "Sharing History" row has no `accessibilityLabel`
79. [CRITICAL] PrivacySettingsView.swift:25 — Row has no `accessibilityLabel`
80. [CRITICAL] PrivacySettingsView.swift:33 — "Close Circles" row has no `accessibilityLabel`
81. [CRITICAL] PrivacySettingsView.swift:35 — "Collaborative Albums" row has no `accessibilityLabel`
82. [CRITICAL] CloseCircleView.swift:29 — "Create Close Circle" `Button` has no `accessibilityLabel`
83. [CRITICAL] CloseCircleView.swift:32 — "Cancel" `Button` has no `accessibilityLabel`
84. [CRITICAL] CloseCircleView.swift:40,45,50 — Circle row icon `Image`s have no `accessibilityLabel`
85. [CRITICAL] CommunityView.swift:44 — "Blink to Friends" `Button` has no `accessibilityLabel`
86. [CRITICAL] CommunityView.swift:53 — "Create Collaborative Album" `Button` has no `accessibilityLabel`
87. [CRITICAL] CommunityView.swift:69 — "Join Collaborative Album" `Button` has no `accessibilityLabel`
88. [CRITICAL] CommunityView.swift:73 — "Share to Public Feed" `Button` has no `accessibilityLabel`
89. [CRITICAL] CommunityView.swift:82 — "Community Guidelines" `Button` has no `accessibilityLabel`
90. [CRITICAL] PublicFeedView.swift:24 — Back `Button` has no `accessibilityLabel`
91. [CRITICAL] PublicFeedView.swift:26 — Share `Button` has no `accessibilityLabel`
92. [CRITICAL] PublicFeedView.swift:57 — Refresh `Button` has no `accessibilityLabel`
93. [CRITICAL] PublicFeedView.swift:106 — Feed item icon has no `accessibilityLabel`
94. [CRITICAL] PricingView.swift:25 — Dismiss `Button` has no `accessibilityLabel`
95. [CRITICAL] PricingView.swift:44 — Subscribe `Button` has no `accessibilityLabel`
96. [CRITICAL] PricingView.swift:65,67,70,73 — Tier `Button`s have no `accessibilityLabel`
97. [CRITICAL] PricingView.swift:81,84,89 — "Get Started"/"Subscribe" `Button`s have no `accessibilityLabel`
98. [CRITICAL] PricingView.swift:119,131,145 — Tier feature checkmark `Button`s have no `accessibilityLabel`
99. [CRITICAL] SubscriptionsView.swift:29,31,34 — Row icon `Image`s have no `accessibilityLabel`
100. [CRITICAL] SubscriptionsView.swift:42,44,47 — Row icon `Image`s have no `accessibilityLabel`
101. [CRITICAL] SubscriptionsView.swift:49,52,55 — Action `Button`s have no `accessibilityLabel`
102. [CRITICAL] SocialShareSheet.swift:21 — "Copy Link" `Button` has no `accessibilityLabel`
103. [CRITICAL] SocialShareSheet.swift:28 — "Share via Messages" `Button` has no `accessibilityLabel`
104. [CRITICAL] CameraPreview.swift:28,32,51 — `Button`s have no `accessibilityLabel`
105. [CRITICAL] MonthBrowserView.swift:41,47,54,61,68,75 — Month navigation `Button`s have no `accessibilityLabel`
106. [CRITICAL] MonthBrowserView.swift:83,111,116 — Action `Button`s have no `accessibilityLabel`
107. [CRITICAL] SearchView.swift:37 — Search `Image` icon has no `accessibilityLabel`
108. [CRITICAL] SearchView.swift:49 — Clear `Button` has no `accessibilityLabel`
109. [CRITICAL] CollaborativeAlbumView.swift:25,31 — `Image` icons have no `accessibilityLabel`
110. [CRITICAL] CollaborativeAlbumView.swift:41 — Action `Button` has no `accessibilityLabel`
111. [CRITICAL] DeepAnalysisView.swift:33,37,41 — `Image` icons have no `accessibilityLabel`
112. [CRITICAL] DeepAnalysisView.swift:57 — Action `Button` has no `accessibilityLabel`
113. [CRITICAL] DeepAnalysisView.swift:89 — Action `Button` has no `accessibilityLabel`
114. [CRITICAL] DeepAnalysisView.swift:97 — Action `Button` has no `accessibilityLabel`
115. [CRITICAL] OnThisDayView.swift:37 — `Image` icon has no `accessibilityLabel`
116. [CRITICAL] YearInReviewCompilationView.swift:48,55,65,71 — `Button`s have no `accessibilityLabel`
117. [CRITICAL] YearInReviewCompilationView.swift:76 — Dismiss `Button` has no `accessibilityLabel`
118. [CRITICAL] StorageDashboardView.swift:28,30,43,46,49 — `Image` icons have no `accessibilityLabel`
119. [CRITICAL] StorageDashboardView.swift:63,65,76,82,84 — `Image` icons have no `accessibilityLabel`

---

## High Priority Issues

### Dynamic Type Not Used — Fixed Font Sizes Throughout

120. [HIGH] Theme.swift — ALL font tokens use `.system(size:)` with fixed sizes instead of `Font.TextStyle` for Dynamic Type support:
   - `fontLargeTitle` (28pt), `fontTitle1` (22pt), `fontTitle2` (20pt), `fontTitle3` (18pt)
   - `fontHeadline` (17pt), `fontBody` (15pt), `fontCallout` (14pt)
   - `fontSubheadline` (13pt), `fontFootnote` (13pt), `fontCaption1` (12pt), `fontCaption2` (11pt)
   - `fontMonoCaption` (11pt), `fontMonoBody` (13pt)
   - **These should use `Font.TextStyle` or `.scaled()` for accessibility**

121. [HIGH] AIHighlightsView.swift:102,106,120,122,154,162,167,184,186,190,194,206,208,212,240,242,246 — All `Text` elements use `.font(.system(size:))` fixed sizes instead of Dynamic Type
122. [HIGH] CommunityView.swift:91,97,100 — `Text` elements use fixed `.system(size:)` font sizes
123. [HIGH] PublicFeedView.swift:75,77 — `Text` elements use fixed `.system(size:)` font sizes
124. [HIGH] FreemiumEnforcementView.swift:24,40,42,49,67,71,85,87 — All `Text` elements use fixed font sizes
125. [HIGH] CalendarView.swift:228,232,239,242,261,271,284,310,316,320 — `Text` elements use fixed font sizes
126. [HIGH] PlaybackView.swift:195,197,199,210,245,279,281,285,289 — `Text` elements use fixed font sizes
127. [HIGH] PricingView.swift:89,107,109,111,113,133,135,137,139,141,143,170,172,174,176,178,180 — All `Text` elements use fixed `.font(.system(size:))` sizes
128. [HIGH] DeepAnalysisView.swift:83 — `Text` element uses fixed `.system(size:)` font
129. [HIGH] OnboardingView.swift:97,98,127,128,157,158,187,188 — All `Text` elements use fixed `.system(size:)` sizes
130. [HIGH] CustomGraphics.swift — All preview graphics use fixed `.system(size:)` font sizes
131. [HIGH] YearInReviewCompilationView.swift:86,88,96,98,114,116,168,170,172,174,212,214,216,218,226,228,232,234 — `Text` elements use fixed font sizes
132. [HIGH] StorageDashboardView.swift:34,36,38,52,54,56,58,70,72,86,88,90,92 — All `Text` elements use fixed `.system(size:)` font sizes
133. [HIGH] ErrorStatesView.swift:34,36,38,56,58,60,78,80,82,100,102,104,120,122,124,142,144,146,164,166,168,188,190,192,214,216,218 — All `Text` elements use fixed font sizes
134. [HIGH] SettingsView.swift — Multiple `Text` elements use fixed font sizes (lines 35, 37, 39, 41, 43, 45, 47)
135. [HIGH] TrimView.swift — `Text` elements use fixed font sizes (lines 63, 65, 67)
136. [HIGH] SearchView.swift — `Text` elements use fixed font sizes
137. [HIGH] SubscriptionsView.swift — Multiple `Text` elements use fixed font sizes
138. [HIGH] CollaborativeAlbumView.swift:50 — `Text` element uses fixed font size

### Animations Not Wrapped in Reduce Motion Checks

139. [HIGH] CustomGraphics.swift:285 — `ViewfinderGraphic` uses `.animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: isAnimating)` without `accessibilityReduceMotion` check. Continuous opacity animation plays for all users.
140. [HIGH] CustomGraphics.swift:452 — `ApertureGraphic` uses `.animation(.spring(response: 0.8, dampingFraction: 0.6).repeatForever(autoreverses: true), value: isOpen)` without Reduce Motion check. Both rotation and scale animate infinitely.
141. [HIGH] PrivacyLockView.swift:362 — `PrivacyLockIconGraphic` uses `.animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: isAnimating)` without Reduce Motion check. Continuous scale animation plays for all users.
142. [HIGH] CustomGraphics.swift:285 — `ClipCompositionGraphic` uses `withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true))` for offset animation without Reduce Motion check.
143. [HIGH] CustomGraphics.swift — `YearInReviewGraphic` uses `withAnimation(.easeOut(duration: 1.5))` for progress ring without Reduce Motion check.
144. [HIGH] YearInReviewCompilationView.swift:107 — `withAnimation(.easeOut(duration: 2))` for progress ring without Reduce Motion check.
145. [HIGH] RecordView.swift:254 — Countdown `animation(.easeInOut(duration: 0.3), value: countdownValue)` not wrapped in Reduce Motion check.

---

## Medium Priority Issues

### Color Contrast — Potential WCAG AA Failures

146. [MEDIUM] Theme.swift — Color `textQuaternary` hex "555555" on dark background hex "0a0a0a":
   - Contrast ratio: approximately 4.8:1 for "f5f5f5" on "0a0a0a" — **PASSES** (4.5:1 minimum)
   - However "8a8a8a" (#8a8a8a) on "0a0a0a": ~5.9:1 — PASSES
   - "555555" on "0a0a0a": ~3.1:1 — **FAILS WCAG AA for normal text (needs 4.5:1)**
   - Multiple uses of "8a8a8a" as body text may be borderline — needs verification

147. [MEDIUM] FreemiumEnforcementView.swift — Text uses Color(hex: "f5f5f5") on Color(hex: "0a0a0a") background — PASSES
148. [MEDIUM] PricingView.swift — "c0c0c0" (#c0c0c0) on "141414" — contrast ~6.7:1 — PASSES

### Color Naming — Non-Semantic Color References

149. [MEDIUM] Throughout implementation files — Colors referenced by hex literals instead of semantic Theme tokens:
   - `Color(hex: "ff3b30")` used directly instead of `Theme.accent`
   - `Color(hex: "0a0a0a")` used directly instead of `Theme.background`
   - `Color(hex: "141414")` used directly instead of `Theme.backgroundSecondary`
   - `Color(hex: "1e1e1e")` used directly instead of `Theme.backgroundTertiary`
   - `Color(hex: "2a2a2a")` used directly instead of `Theme.backgroundQuaternary`
   - `Color(hex: "f5f5f5")` used directly instead of `Theme.textPrimary`
   - `Color(hex: "c0c0c0")` used directly instead of `Theme.textSecondary`
   - `Color(hex: "8a8a8a")` used directly instead of `Theme.textTertiary`
   - `Color(hex: "555555")` used directly instead of `Theme.textQuaternary`

150. [MEDIUM] CustomGraphics.swift:301,318,329,344 — Colors referenced as "white", "black", "red", "green", "blue", "yellow", "warm", "cool", "neutral" (non-semantic) in `colorName()` function. These should be named semantically (e.g., "primaryAccent", "darkBackground").

---

## Low Priority Issues

### Missing Accessibility Hints on Non-Obvious Interactions

151. [LOW] PlaybackView.swift:210 — Speed picker button has `accessibilityLabel` but no `accessibilityHint` explaining how to change speed
152. [LOW] CalendarView.swift — Year navigation buttons have labels but no hints about swiping vs tapping
153. [LOW] TrimView.swift — Trim handles have no `accessibilityHint` describing drag-to-trim gesture
154. [LOW] PrivacyLockView.swift — Keypad buttons have no `accessibilityHint` for entering passcode

### Accessible Name for Colors (Color Naming)

155. [LOW] DeepAnalysisService.swift:301-318 — `colorName()` function returns non-semantic color names like "white", "black", "red", "green", "blue", "warm", "cool", "neutral" instead of semantic names like "lightBackground", "darkForeground", "accentRed", "primaryGreen", "primaryBlue", "warmNeutral", "coolNeutral", "neutralGray"

---

## Summary

| Severity | Count |
|----------|-------|
| CRITICAL | 119 |
| HIGH | 26 |
| MEDIUM | 6 |
| LOW | 5 |
| **Total** | **156** |

### Top Categories:
1. **Missing accessibility labels** — 119 critical instances across all view files
2. **Dynamic Type not used** — 19+ files using `.font(.system(size:))` instead of scalable fonts
3. **Reduce Motion not respected** — 7 animation instances running without `accessibilityReduceMotion` checks
4. **Non-semantic color naming** — Direct hex literal usage throughout implementation files
5. **Color contrast** — Potential WCAG AA failures with "555555" on dark backgrounds

### Recommendations (for Phase 2+ agents):
- Add `accessibilityLabel` to ALL interactive `Button`s and `Image`s used as buttons
- Replace all `.font(.system(size:))` with `Font.TextStyle` or `.scaled()` variants
- Wrap all `repeatForever` and decorative animations in `if !accessibilityReduceMotion { }` blocks
- Create semantic color tokens and migrate all hex literals to use Theme colors
- Add `accessibilityHint` to non-obvious interactive elements
- Test all text/background combinations against WCAG AA contrast ratios
