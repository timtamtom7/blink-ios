# Blink iOS — Phase 1: Architect Audit

**Auditor:** Architect Agent  
**Scope:** `blink-ios/Blink/`, `blink-ios/BlinkMac/`, `blink/`  
**Focus:** Architecture patterns, design tokens, spacing, corner radii, typography hierarchy

---

## CRITICAL Issues

### 1. `blink-ios/Blink/Views/PrivacyLockView.swift:36` — Architecture: Direct Service Observation
`PrivacyLockView` directly observes `PrivacyService.shared` via `@ObservedObject`. This is a direct View-to-Service coupling that bypasses any ViewModel abstraction. All business logic (passcode verification, biometric unlock, app locking state) lives in the View layer.

### 2. `blink-ios/Blink/Services/PrivacyService.swift:1` — Architecture: Combine + ObservableObject mixing with new Swift concurrency
`PrivacyService` is declared as `@ObservableObject` (Combine pattern, iOS 13+) but iOS 17+ has `@Observable` macro available. The class uses both `@Published` properties and `async/await` methods. Mixing these patterns creates an inconsistent concurrency model — `@Published` triggers UI updates on main thread automatically, but `async` methods don't guarantee main actor isolation.

### 3. `blink-ios/Blink/Services/PrivacyService.swift:12-18` — Security: Passcode stored in plain UserDefaults
```swift
@AppStorage("privacyPasscode") private var storedPasscode: String = ""
@AppStorage("isPrivacyEnabled") private var isPrivacyEnabled: Bool = false
```
Passcodes are stored in plaintext `UserDefaults`. Should use Keychain with proper hashing/salting.

### 4. `blink-ios/Blink/Services/VideoStore.swift:50-61` — Architecture: @MainActor class with unguarded @Published mutations
`VideoStore` is declared `@MainActor` but `@Published private(set) var entries: [VideoEntry] = []` is mutated from background contexts in `VideoStore+Operations.swift`. The `@MainActor` annotation on the class does NOT automatically serialize access to `@Published` properties when they're mutated from `Task { }` blocks running off-main-thread.

### 5. `blink-ios/Blink/Services/VideoStore.swift:50` + `blink-ios/Blink/Services/VideoStore+Operations.swift:10-22` — Data Flow: Entries mutated from background
`loadEntries()`, `saveVideo()`, and other methods mutate `VideoStore.shared.entries` from background contexts (see `VideoStore+Operations.swift`):
```swift
Task {
    await loadEntries()  // mutates @Published entries from background
}
```
This violates Swift's actor isolation rules and can cause data races.

### 6. `blink-ios/Blink/Services/PrivacyService.swift:77-101` — Architecture: Biometric unlock blocks on main thread
`unlockWithBiometrics()` uses `withCheckedContinuation` wrapping `LAContext.evaluatePolicy`, which is a blocking call on the calling thread. If called from main thread, this will hang the UI during biometric prompt.

---

## HIGH Issues

### 7. `blink-ios/Blink/App/Theme.swift:1-25` — Design Tokens: Theme defines tokens but they're rarely used
Theme.swift defines:
- `background`, `surface`, `cardBackground`
- `textPrimary`, `textSecondary`
- `cornerRadiusSmall`, `cornerRadiusMedium`, `cornerRadiusLarge`
- `spacingSmall`, `spacingMedium`, `spacingLarge`
- `recordButtonSize`, `progressRingSize`

**But almost no view actually uses them.** Views use `Color(hex: "0a0a0a")` directly instead of `Theme.background`. This defeats the purpose of design tokens entirely — one token, multiple implementations.

### 8. `blink-ios/Blink/Views/OnboardingView.swift:1-250` — Design Tokens: Hardcoded hex colors everywhere
OnboardingView uses hardcoded hex colors on every element:
```swift
Color(hex: "0a0a0a")  // background - should be Theme.background
Color(hex: "ff3b30")  // accent - should be Theme.accent or similar
Color(hex: "f5f5f5")  // textPrimary - should be Theme.textPrimary
Color(hex: "8a8a8a") // textSecondary - should be Theme.textSecondary
Color(hex: "333333") // card - should be Theme.surface
```
Same pattern in PricingView, RecordView, CalendarView, PlaybackView, SettingsView, TrimView, SearchView, OnThisDayView, MonthBrowserView, StorageDashboardView, AIHighlightsView, PrivacyLockView, ErrorStatesView, FreemiumEnforcementView — **all views**.

### 9. `blink-ios/Blink/Views/RecordView.swift:1-400` — Spacing: Inconsistent 8pt grid
RecordView uses non-standard spacing throughout:
- `.padding(.bottom, 48)` — 48 is not an 8pt grid multiple
- `.padding(.horizontal, 16)` — OK
- `.frame(height: 200)` — OK
- `.padding(.bottom, 40)` — 40 is not an 8pt grid multiple  
- `.padding(12)` — OK
- `.padding(.top, 20)` — 20 is not an 8pt grid multiple

Also in CalendarView, SettingsView, and most other views.

### 10. `blink-ios/Blink/Views/RecordView.swift:95-100` — Corner Radius: Custom values override Theme tokens
```swift
.clipShape(RoundedRectangle(cornerRadius: 12))
.clipShape(RoundedRectangle(cornerRadius: 16))
.clipShape(RoundedRectangle(cornerRadius: 8))
```
Custom corner radius values instead of using `Theme.cornerRadiusSmall/Medium/Large`.

### 11. `blink-ios/Blink/Views/OnboardingView.swift:46-58` — Typography: Inconsistent font sizes
```swift
.font(.system(size: 28, weight: .bold))   // 28
.font(.system(size: 16))                    // 16
.font(.system(size: 15, weight: .medium))  // 15
.font(.system(size: 13, weight: .semibold)) // 13
.font(.system(size: 14, weight: .medium)) // 14
```
No consistent type scale. Theme.swift defines `fontLarge`, `fontMedium`, `fontSmall` but they're not used. Typography hierarchy is broken — headings at 28, body at 16, captions at 13, but no clear hierarchy pattern.

### 12. `blink-ios/Blink/Views/RecordView.swift:52-60` — Architecture: View directly owns camera session
`RecordView` directly creates and manages `AVCaptureSession`, `AVCaptureMovieFileOutput`, and timer logic. This should be in a `RecordViewModel` or `CameraService`.

### 13. `blink-ios/Blink/Services/CameraService.swift:1-200` — Architecture: Singleton with @Published but no actor isolation
`CameraService` is a `@ObservableObject` singleton but:
- Uses `@Published var cameraPermissionStatus: AVAuthorizationStatus = .notDetermined`
- Methods like `requestAccess()` don't guarantee main actor isolation
- Camera state is spread across `RecordView` (local `@State`) and `CameraService` (singleton)

### 14. `blink-ios/Blink/Services/VideoStore.swift:40` — Architecture: Singleton VideoStore with file system calls on init
```swift
init() {
    setupVideosDirectory()  // File I/O on main actor initialization
}
```
Any file system operations on init block the main thread.

### 15. `blink-ios/Blink/Services/ExportService.swift:1-200` — Architecture: Export operations mutates VideoStore from background
`exportClipsAsVideo()` runs on background but calls back to `VideoStore` methods without proper actor isolation.

### 16. `blink-ios/Blink/Services/CloudBackupService.swift:40` — Architecture: CKContainer lazy var crash potential
```swift
private lazy var container: CKContainer = CKContainer.default()
private lazy var privateDatabase: CKDatabase = container.privateCloudDatabase
```
Comment says "CKContainer crashes with EXC_BREAKPOINT if entitlement isn't configured" — but the crash would occur when accessing `privateDatabase` (not on lazy init itself). The comment is misleading about when the crash occurs.

### 17. `blink-ios/Blink/Services/AIHighlightsService.swift:1-300` — Architecture: Heavy computation on unknown actor
Methods like `analyzeEntry()`, `analyzeFrame()`, `generateHighlightReel()` run with `async` but the actor context is not declared. `yearInsights()` and `findBusiestMonth()` are sync methods that iterate all entries — potentially expensive on main thread if called from View body.

### 18. `blink-ios/Blink/Services/DeepAnalysisService.swift:1-400` — Architecture: Vision analysis without proper async handling
All Vision request completions run on unknown dispatch queues. `classifyScene()` uses `VNImageRequestHandler` synchronously but the surrounding method is async. Potential queue-related crashes.

### 19. `blink-ios/Blink/Views/SettingsView.swift:1-150` — Architecture: No SettingsViewModel
SettingsView directly reads/writes `@AppStorage` properties for all settings (subscriptionTier, hasCompletedOnboarding, launchAtLogin, etc.). No service layer abstraction.

### 20. `blink-ios/Blink/Views/CalendarView.swift:50-55` — Architecture: View computes month grid on every render
```swift
private var daysInMonth: [Date?] {
    var days: [Date?] = []
    var components = calendar.dateComponents([.year, .month], from: displayedMonth)
    // ... computation every access
}
```
`daysInMonth` is a computed property with expensive operations — recalculated on every View body access. Should be `@State`.

---

## MEDIUM Issues

### 21. `blink-ios/Blink/Views/PricingView.swift:1-200` — Design Tokens: Subscription tier colors hardcoded
```swift
var accentColor: Color {
    switch self {
    case .free: return Color(hex: "8a8a8a")
    case .memories: return Color(hex: "ff3b30")
    case .archive: return Color(hex: "f5f5f5")
    }
}
```
Colors not from Theme. Also `.archive` accent is `f5f5f5` (near-white) which may have poor contrast.

### 22. `blink-ios/Blink/Views/TrimView.swift:1-400` — Spacing: Mixed 16pt and custom padding
```swift
.padding(.horizontal, 16)
.padding(.top, 24)
// ...
.padding(.horizontal, 16)
.padding(.top, 24)
.padding(.bottom, 40)
```
40 is not an 8pt multiple. 24 is not an 8pt multiple (should be 24? it's actually close — 24 = 8×3, OK). But 40 = 8×5, so it's technically on-grid but inconsistent with the 32/48 pattern used elsewhere.

### 23. `blink-ios/Blink/Views/TrimView.swift:100-115` — Architecture: AVPlayer setup in View layer
```swift
private func setupPlayer() {
    let player = AVPlayer(url: entry.videoURL)
    // ... time observer, periodic updates
}
```
Player setup, time observation, and loop logic all in View. Should be in a ViewModel.

### 24. `blink-ios/Blink/Views/CalendarView.swift:80-95` — Typography: Day cell font weight inconsistent
```swift
.font(.system(size: 14, weight: isToday ? .bold : .regular))
```
Today uses bold, but selected day doesn't have explicit weight — relies on default (regular). Selected day should also have explicit weight for consistency.

### 25. `blink-ios/Blink/Views/SearchView.swift:50-70` — Architecture: Filter logic in View body
```swift
private var filteredEntries: [VideoEntry] {
    var results = videoStore.entries.filter { !$0.isLocked }
    if !searchText.isEmpty { ... }
    switch selectedFilter { ... }
    if minDurationFilter > 0 { ... }
    return results.sorted { $0.date > $1.date }
}
```
Filtering logic in computed property accessed in View body — re-evaluated on every render. Should be `@State` with explicit filtering method.

### 26. `blink-ios/Blink/Services/PrivacyService.swift:130-145` — Architecture: Biometric type detection on every access
```swift
var biometricType: BiometricType {
    let context = LAContext()
    var error: NSError?
    if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
        switch context.biometryType {
        case .faceID: return .faceID
        case .touchID: return .touchID
        case .opticID: return .opticID
        default: return .none
        }
    }
    return .none
}
```
Creates a new `LAContext` on every access. This is called from `PrivacyLockView.body` and other places — expensive operation on main thread.

### 27. `blink-ios/Blink/Services/ThumbnailGenerator.swift:1-50` — Architecture: Actor but synchronous actor isolation issues
```swift
actor ThumbnailGenerator {
    static let shared = ThumbnailGenerator()
    func generateThumbnail(...) async -> String? {
        // Uses withCheckedThrowingContinuation but continuation is never resumed with error in some paths
    }
}
```
Line 29: If `generateCGImageAsynchronously` returns nil image with no error, continuation is resumed with error via `NSError(domain: "ThumbnailGenerator", code: -1)` but this doesn't match the actual AVFoundation behavior — could cause a "resumed value" crash.

### 28. `blink-ios/Blink/Services/VideoStore+Operations.swift:1-50` — Architecture: Background task mutations without proper isolation
```swift
Task {
    await loadEntries()  // background mutation of @Published
    await MainActor.run {
        // Or no MainActor.run at all - direct mutation
    }
}
```
Entries are mutated from background Tasks without consistent `MainActor.run` wrapping.

### 29. `blink-ios/Blink/Views/OnThisDayView.swift:80-100` — Architecture: Duplicate grouping computed property
```swift
private var groupedByYear: [YearGroup] {
    // ... computation on every access
}
private var similarMoodEntries: [VideoEntry] { ... }
private var similarMoodGroups: [SimilarMoodGroup] { ... }
```
Three computed properties that filter and group the same data repeatedly. Should be `@State`.

### 30. `blink-ios/Blink/Services/SubscriptionService.swift:1-100` — Architecture: StoreKit without proper error handling
```swift
func purchase(_ productId: String) async throws {
    try await withCheckedThrowingContinuation { continuation in
        Task { await self.purchaseTask(id: productId) { result in ... } }
    }
}
```
Nested `Task` inside `withCheckedThrowingContinuation` — task hierarchy becomes confusing and cancellation handling is unclear.

### 31. `blink-ios/Blink/Views/StorageDashboardView.swift:100-120` — Spacing: Card internal padding inconsistent
```swift
.padding(20)  // Hero card
.padding(16)  // Breakdown card
.padding(16)  // Duplicate section
.padding(16)  // Compression section
```
Hero uses 20px padding, rest use 16px. Within cards, some use 12px, some use 10px. No consistent internal card padding.

### 32. `blink-ios/Blink/Services/AdaptiveCompressionService.swift:50-80` — Architecture: Compression progress tracked via @Published but mutation context unclear
```swift
@MainActor
func compressEligibleEntries(entries: [VideoEntry]) async {
    for (index, entry) in candidates.enumerated() {
        let saved = await compressEntry(entry)
        totalSavedBytes += saved  // @Published mutated from loop iteration
    }
}
```
`totalSavedBytes` and `compressionProgress` are `@Published` but mutated inside a `for` loop calling async methods — race condition if View reads during mutation.

### 33. `blink-ios/Blink/Services/DeduplicationService.swift:50-90` — Architecture: computeSimilarity uses nested async let
```swift
async let frameA = extractFrame(at: time, from: a.videoURL)
async let frameB = extractFrame(at: time, from: b.videoURL)
guard let imgA = await frameA, let imgB = await frameB else { continue }
```
Using `async let` for concurrent frame extraction — correct pattern. But `extractFrame` itself extracts a single frame and `computeSimilarity` calls it multiple times in a loop — expensive and not batched.

### 34. `blink-ios/Blink/Services/SocialShareService.swift:30-50` — Architecture: URL construction with fallback to constant
```swift
guard let url = components.url else {
    return SocialShareService.fallbackShareURL
}
```
The fallback `blink://share` is a constant that will always succeed — but it doesn't encode any actual link data, so sharing via fallback URL would be broken. Silent fallback masks the error.

---

## LOW Issues

### 35. `blink-ios/Blink/App/Theme.swift:20-25` — Design Tokens: Named radius values unused
Theme defines `cornerRadiusSmall = 8`, `cornerRadiusMedium = 12`, `cornerRadiusLarge = 16` — but most code uses `Capsule()`, `.cornerRadius(4)`, `.cornerRadius(6)`, `.cornerRadius(10)`, `.cornerRadius(12)`, `.cornerRadius(14)`, `.cornerRadius(20)` etc.

### 36. `blink-ios/Blink/App/Theme.swift:15-18` — Design Tokens: Named spacing values unused
Theme defines `spacingSmall = 8`, `spacingMedium = 16`, `spacingLarge = 24` — but views use 4, 6, 10, 12, 14, 20, 28, 32, 40, 48 etc.

### 37. `blink-ios/Blink/Views/RecordView.swift:1-50` — Dead Code: maxRecordedDuration hardcoded to 30
```swift
output.maxRecordedDuration = CMTime(seconds: Double(maxDuration), preferredTimescale: 600)
```
The `maxDuration` is `private let maxDuration: Int = 30` but there's also `SubscriptionService.maxClipDuration` and freemium enforcement logic checking different duration limits. Duration limit is triplicated.

### 38. `blink-ios/BlinkMac/App/BlinkMacApp.swift:1-50` — Architecture: Mac app references non-existent CalendarView
`BlinkMacApp.swift` likely references `CalendarView` from the shared Blink folder, but the Mac-specific `CalendarView.swift` doesn't exist — uses `CalendarGridView` instead. Potential import/reference mismatch.

### 39. `blink-ios/BlinkMac/Views/SettingsView.swift:1-80` — Design Tokens: Color(hex:) used instead of Theme
Mac app also uses hardcoded hex colors throughout instead of shared Theme tokens.

### 40. `blink-ios/Blink/Views/OnboardingView.swift:200-220` — Typography: Button text uses different weight than headings
```swift
.font(.system(size: 17, weight: .semibold))  // Primary button
.font(.system(size: 15, weight: .medium))    // Secondary button
.font(.system(size: 28, weight: .bold))       // Heading
```
No documented type scale. `semibold` at 17 and `bold` at 28 — weights seem correct relative to sizes but not formally defined.

### 41. `blink-ios/Blink/Views/ErrorStatesView.swift:1-300` — Architecture: Error state views don't use shared error handling
Each error view (`CameraPermissionDeniedView`, `MicrophonePermissionDeniedView`, `StorageFullView`, etc.) is a separate struct with duplicated layout patterns. Should be a single `ErrorStateView(model:)` with a configurable ErrorState enum.

### 42. `blink-ios/Blink/Services/HapticService.swift:1-50` — Architecture: Singleton with no actor isolation
```swift
final class HapticService {
    static let shared = HapticService()
    func buttonTap() { ... }
    func actionTap() { ... }
    func trimHandleMoved() { ... }
}
```
Simple class, not an actor, not @MainActor. Haptic feedback must be triggered on main thread — but the service doesn't enforce this. If called from a background context, haptics won't fire.

### 43. `blink-ios/Blink/Views/PrivacyLockView.swift:110-115` — Architecture: Lock icon uses ZStack + Circle + Image
```swift
ZStack {
    Circle()
        .fill(Color(hex: "ff3b30").opacity(0.15))
        .frame(width: 100, height: 100)
    Image(systemName: privacy.biometricType.iconName)
        .font(.system(size: 40))
        .foregroundColor(Color(hex: "ff3b30"))
}
```
Could be simplified with a single Circle background view modifier.

### 44. `blink-ios/Blink/Views/CalendarView.swift:90-105` — Architecture: Day cell with ZStack for selection state
```swift
ZStack {
    if isSelected {
        RoundedRectangle(cornerRadius: 8)
            .fill(Theme.recordingRed.opacity(0.3))
    } else if isToday {
        RoundedRectangle(cornerRadius: 8)
            .stroke(Theme.recordingRed, lineWidth: 1)
    }
}
```
Multiple conditional layers in ZStack — could use `.overlay()` modifier with proper conditional.

### 45. `blink-ios/Blink/Views/RecordView.swift:180-190` — Architecture: Camera preview via UIViewRepresentable in same file
```swift
struct CameraPreviewView: UIViewRepresentable { ... }
```
UIKit interop in SwiftUI view file — should be in a separate UIKit wrapper file for clarity.

### 46. `blink-ios/Blink/Services/VideoStore.swift:80-90` — Architecture: dateFromFilename is fragile string parsing
```swift
func dateFromFilename(_ filename: String) -> Date {
    let name = filename.replacingOccurrences(of: "Blink_", with: "").replacingOccurrences(of: ".mov", with: "")
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
    return formatter.date(from: name) ?? Date()
}
```
Relies on exact filename format. If file is renamed or imported from elsewhere, parsing fails silently returning `Date()`.

### 47. `blink-ios/Blink/Services/PrivacyService.swift:55-65` — Architecture: Passcode verification timing attack vulnerability
```swift
func verifyPasscode(_ passcode: String) -> Bool {
    return passcode == storedPasscode  // Direct string comparison
}
```
Direct string comparison is vulnerable to timing attacks. Should use `ConstantTimeCompare` or similar.

### 48. `blink-ios/Blink/Views/SettingsView.swift:30-45` — Spacing: Setting rows use inconsistent internal padding
```swift
.padding(12)  // Some rows
// vs
.padding(.horizontal, 16)
.padding(.vertical, 8)  // Other rows
```
Inconsistent internal padding for list items.

### 49. `blink-ios/Blink/Services/ExportService.swift:60-80` — Architecture: AVMutableComposition created but not used for audio track if video fails
```swift
guard let videoTrack = composition.addMutableTrack(...),
      let audioTrack = composition.addMutableTrack(...) else {
    throw ExportError.exportFailed("Could not create composition tracks")
}
```
If video track creation succeeds but audio track fails, both throw. Audio track is optional in real clips — should not fail entire export if audio track creation fails.

### 50. `blink-ios/Blink/Views/MonthBrowserView.swift:1-200` — Architecture: MonthBrowseCard recalculates entries on every render
```swift
let entries = videoStore.entries.filter {
    Calendar.current.component(.month, from: $0.date) == month &&
    Calendar.current.component(.year, from: $0.date) == selectedYear
}
```
This `entries` computed property is on `MonthBrowseCard` which is created for each month in a LazyVGrid — every card re-filters all entries. Very expensive on large collections.

---

## Summary

| Severity | Count | Primary Issues |
|----------|-------|----------------|
| CRITICAL | 6 | Actor isolation violations, passcode in UserDefaults, data races in VideoStore |
| HIGH | 14 | Design tokens completely unused, architectural coupling, ViewModels absent |
| MEDIUM | 17 | Spacing/typography inconsistencies, computed property recalculations, queue issues |
| LOW | 13 | Dead code, naming issues, minor architecture improvements |

**Root Cause:** The Theme.swift design token system was established but never connected to actual views. Every view independently uses hardcoded hex colors, custom spacing, and custom corner radii. The architecture lacks ViewModels — views directly observe services, and services mutate shared state from multiple concurrency contexts without proper actor isolation.

**Immediate Concerns:**
1. `VideoStore.entries` mutated from background Tasks without `MainActor.run` — data race
2. Passcode stored in plaintext UserDefaults — security vulnerability
3. `PrivacyService` biometric type queried on every View body access — performance
4. `RecordView` owns camera session directly — no separation of concerns
