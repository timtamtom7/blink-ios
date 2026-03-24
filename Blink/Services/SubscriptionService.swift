import Foundation
import Combine

/// Manages subscription tier state and enforces freemium limits.
/// Free: 1 clip/day, 30-sec max, 30-day storage
/// Memories: unlimited clips, 60-sec videos, cloud backup, 1-year storage
/// Archive: unlimited duration, export all, lifetime storage, monthly highlights
final class SubscriptionService: ObservableObject {
    static let shared = SubscriptionService()

    enum Tier: String, Codable, CaseIterable {
        case free = "free"
        case memories = "memories"
        case archive = "archive"

        var displayName: String {
            switch self {
            case .free: return "Free"
            case .memories: return "Memories"
            case .archive: return "Archive"
            }
        }

        // Max clip duration in seconds
        var maxClipDuration: TimeInterval {
            switch self {
            case .free: return 30
            case .memories: return 60
            case .archive: return Double.infinity
            }
        }

        // Max clips per day (-1 = unlimited)
        var maxClipsPerDay: Int {
            switch self {
            case .free: return 1
            case .memories: return -1 // unlimited
            case .archive: return -1
            }
        }

        // Days to retain clips (-1 = forever)
        var retentionDays: Int {
            switch self {
            case .free: return 30
            case .memories: return 365
            case .archive: return -1
            }
        }

        // Max clip duration for recording UI
        var recordingMaxDuration: TimeInterval {
            maxClipDuration
        }
    }

    @Published private(set) var currentTier: Tier = .free

    private let tierKey = "com.blink.subscriptionTier"
    private let dailyClipCountKey = "com.blink.dailyClipCount"
    private let dailyClipDateKey = "com.blink.dailyClipDate"

    private init() {
        loadTier()
    }

    var isFree: Bool { currentTier == .free }
    var isMemories: Bool { currentTier == .memories || currentTier == .archive }
    var isArchive: Bool { currentTier == .archive }

    // MARK: - Tier Management

    func setTier(_ tier: Tier) {
        currentTier = tier
        saveTier()
    }

    /// Check if user can record a new clip today.
    var canRecordToday: Bool {
        if currentTier == .free {
            return clipsRecordedToday < 1
        }
        return true
    }

    /// Number of clips recorded today.
    var clipsRecordedToday: Int {
        guard let storedDate = UserDefaults.standard.object(forKey: dailyClipDateKey) as? Date else {
            return 0
        }
        let calendar = Calendar.current
        guard calendar.isDateInToday(storedDate) else {
            return 0
        }
        return UserDefaults.standard.integer(forKey: dailyClipCountKey)
    }

    /// Increment the daily clip count. Call after a successful recording.
    func recordClipRecorded() {
        let today = Date()
        if let storedDate = UserDefaults.standard.object(forKey: dailyClipDateKey) as? Date,
           Calendar.current.isDateInToday(storedDate) {
            let current = UserDefaults.standard.integer(forKey: dailyClipCountKey)
            UserDefaults.standard.set(current + 1, forKey: dailyClipCountKey)
        } else {
            // New day — reset counter
            UserDefaults.standard.set(0, forKey: dailyClipCountKey)
            UserDefaults.standard.set(today, forKey: dailyClipDateKey)
            UserDefaults.standard.set(1, forKey: dailyClipCountKey)
        }
    }

    /// Check if a clip of given duration is allowed under current tier.
    func canRecordDuration(_ duration: TimeInterval) -> Bool {
        duration <= currentTier.maxClipDuration
    }

    /// The maximum recording duration allowed for current tier.
    var maxRecordingDuration: TimeInterval {
        currentTier.maxClipDuration
    }

    /// Check if a clip should be auto-deleted based on retention policy.
    func shouldAutoDeleteClipRecordedOn(_ date: Date) -> Bool {
        guard currentTier.retentionDays > 0 else { return false }
        let daysSince = Calendar.current.dateComponents([.day], from: date, to: Date()).day ?? 0
        return daysSince > currentTier.retentionDays
    }

    /// Days until clip expires (nil = never).
    func daysUntilExpiry(for date: Date) -> Int? {
        guard currentTier.retentionDays > 0 else { return nil }
        let daysSince = Calendar.current.dateComponents([.day], from: date, to: Date()).day ?? 0
        let remaining = currentTier.retentionDays - daysSince
        return max(0, remaining)
    }

    /// Storage info for display.
    struct StorageInfo {
        let usedClips: Int
        let oldestClipDate: Date?
        let daysUntilOldestExpiry: Int?
        let retentionText: String
    }

    func storageInfo(entries: [VideoEntry]) -> StorageInfo {
        let usedClips = entries.count
        let oldest = entries.min(by: { $0.date < $1.date })?.date

        var retentionText: String
        var daysUntilOldestExpiry: Int?

        if currentTier == .free {
            if let oldest = oldest {
                daysUntilOldestExpiry = daysUntilExpiry(for: oldest)
            }
            retentionText = "\(currentTier.retentionDays)-day retention"
        } else if currentTier == .memories {
            retentionText = "1-year retention"
        } else {
            retentionText = "Lifetime storage"
        }

        return StorageInfo(
            usedClips: usedClips,
            oldestClipDate: oldest,
            daysUntilOldestExpiry: daysUntilOldestExpiry,
            retentionText: retentionText
        )
    }

    // MARK: - Persistence

    private func saveTier() {
        UserDefaults.standard.set(currentTier.rawValue, forKey: tierKey)
    }

    private func loadTier() {
        if let stored = UserDefaults.standard.string(forKey: tierKey),
           let tier = Tier(rawValue: stored) {
            currentTier = tier
        }
    }

    // MARK: - Upgrade Prompt

    /// Returns a reason string if recording should be blocked, nil if allowed.
    func blockReasonForRecording(additionalSeconds: TimeInterval = 0) -> String? {
        if !canRecordToday {
            return "You've reached your daily limit on the Free plan. Upgrade to record more clips."
        }

        if !canRecordDuration(additionalSeconds) {
            if currentTier == .free {
                return "Free clips are capped at 30 seconds. Upgrade to Memories for up to 60 seconds."
            }
            return "Recording exceeds your plan's limit."
        }

        return nil
    }
}
