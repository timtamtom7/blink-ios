import Foundation
import UIKit

/// R11: Storage Dashboard — shows Blink's storage usage and savings from compression/deduplication
final class StorageDashboardService: ObservableObject {
    static let shared = StorageDashboardService()

    @Published private(set) var stats: StorageStats?
    @Published private(set) var isLoading = false

    struct StorageStats {
        let totalClips: Int
        let totalDuration: Double
        let originalSizeBytes: Int64
        let compressedSizeBytes: Int64
        let savedByCompression: Int64
        let savedByDeduplication: Int64
        let duplicatesRemoved: Int
        let compressedCount: Int
        let oldestClipDate: Date?
        let newestClipDate: Date?

        var formattedOriginalSize: String {
            ByteCountFormatter.string(fromByteCount: originalSizeBytes, countStyle: .file)
        }

        var formattedCompressedSize: String {
            ByteCountFormatter.string(fromByteCount: compressedSizeBytes, countStyle: .file)
        }

        var formattedEffective: String {
            ByteCountFormatter.string(fromByteCount: originalSizeBytes - savedByCompression, countStyle: .file)
        }

        var formattedTotalSaved: String {
            ByteCountFormatter.string(fromByteCount: savedByCompression + savedByDeduplication, countStyle: .file)
        }

        var totalSavedBytes: Int64 {
            savedByCompression + savedByDeduplication
        }

        var formattedDuration: String {
            let hours = Int(totalDuration) / 3600
            let mins = Int(totalDuration) % 3600 / 60
            if hours > 0 {
                return "\(hours)h \(mins)m"
            }
            return "\(mins) min"
        }

        var formattedOldest: String {
            guard let date = oldestClipDate else { return "—" }
            return DateFormatter.localizedString(from: date, dateStyle: .medium, timeStyle: .none)
        }

        var formattedNewest: String {
            guard let date = newestClipDate else { return "—" }
            return DateFormatter.localizedString(from: date, dateStyle: .medium, timeStyle: .none)
        }
    }

    private init() {}

    /// Refresh storage statistics
    @MainActor
    func refresh(entries: [VideoEntry]) async {
        isLoading = true

        var totalOriginal: Int64 = 0
        var totalCompressed: Int64 = 0
        var totalDuration: Double = 0
        var oldest: Date?
        var newest: Date?

        for entry in entries {
            let url = entry.videoURL
            let originalSize = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64) ?? 0

            // Estimate compressed size (for now, assume 50% compression ratio for compressed entries)
            let compressed = AdaptiveCompressionService.shared.compressedEntries.contains(entry.id)
            let compressedSize = compressed ? originalSize / 2 : originalSize

            totalOriginal += originalSize
            totalCompressed += compressedSize
            totalDuration += entry.duration

            if oldest == nil || entry.date < oldest! {
                oldest = entry.date
            }
            if newest == nil || entry.date > newest! {
                newest = entry.date
            }
        }

        let savedByCompression = AdaptiveCompressionService.shared.totalSavedBytes
        let savedByDeduplication: Int64 = DeduplicationService.shared.duplicates.reduce(0) { total, group in
            // Sum the sizes of all but the first (kept) entry in each duplicate group
            let removedEntries = group.entries.dropFirst()
            let saved: Int64 = removedEntries.reduce(0) { sum, entry in
                let size = (try? FileManager.default.attributesOfItem(atPath: entry.videoURL.path)[.size] as? Int64) ?? 0
                return sum + size
            }
            return total + saved
        }

        let duplicatesRemoved = DeduplicationService.shared.duplicates.reduce(0) { $0 + max(0, $1.entries.count - 1) }

        stats = StorageStats(
            totalClips: entries.count,
            totalDuration: totalDuration,
            originalSizeBytes: totalOriginal,
            compressedSizeBytes: totalCompressed,
            savedByCompression: savedByCompression,
            savedByDeduplication: savedByDeduplication,
            duplicatesRemoved: duplicatesRemoved,
            compressedCount: AdaptiveCompressionService.shared.compressedEntries.count,
            oldestClipDate: oldest,
            newestClipDate: newest
        )

        isLoading = false
    }
}
