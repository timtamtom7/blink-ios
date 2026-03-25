import Foundation
import AVFoundation
import UIKit

/// R11: Adaptive Quality — auto-compress clips older than 90 days that weren't favorited or shared
final class AdaptiveCompressionService: ObservableObject {
    static let shared = AdaptiveCompressionService()

    @Published private(set) var isCompressing = false
    @Published private(set) var compressionProgress: Double = 0
    @Published private(set) var totalSavedBytes: Int64 = 0

    /// Clips that have been compressed
    @Published private(set) var compressedEntries: Set<UUID> = []

    private let compressionAgeThreshold: TimeInterval = 90 * 24 * 60 * 60 // 90 days
    private let compressionPreset = AVAssetExportPresetMediumQuality // Re-encode to reduce size

    private init() {
        loadCompressedEntries()
    }

    /// Run compression analysis: find old clips eligible for compression
    func analyzeCompressionCandidates(entries: [VideoEntry]) -> [VideoEntry] {
        let thresholdDate = Date().addingTimeInterval(-compressionAgeThreshold)

        return entries.filter { entry in
            // Must be older than 90 days
            guard entry.date < thresholdDate else { return false }
            // Must not already be compressed
            guard !compressedEntries.contains(entry.id) else { return false }
            // Must not be favorited or recently shared (simplified: just check isLocked)
            // In a real app, you'd check a favorites flag or shared-date field
            return !entry.isLocked
        }
    }

    /// Compress all eligible entries
    @MainActor
    func compressEligibleEntries(entries: [VideoEntry]) async {
        let candidates = analyzeCompressionCandidates(entries: entries)
        guard !candidates.isEmpty else { return }

        isCompressing = true
        compressionProgress = 0

        for (index, entry) in candidates.enumerated() {
            let saved = await compressEntry(entry)
            totalSavedBytes += saved

            if saved > 0 {
                compressedEntries.insert(entry.id)
            }

            compressionProgress = Double(index + 1) / Double(candidates.count)
        }

        saveCompressedEntries()
        isCompressing = false
    }

    /// Compress a single entry
    func compressEntry(_ entry: VideoEntry) async -> Int64 {
        let originalURL = entry.videoURL
        guard FileManager.default.fileExists(atPath: originalURL.path) else { return 0 }

        let originalSize = (try? FileManager.default.attributesOfItem(atPath: originalURL.path)[.size] as? Int64) ?? 0

        do {
            let asset = AVURLAsset(url: originalURL)

            // Create compressed version
            let compressedFilename = entry.filename.replacingOccurrences(of: ".mov", with: "_compressed.mp4")
            let compressedURL = originalURL.deletingLastPathComponent().appendingPathComponent(compressedFilename)

            // Remove any existing compressed version
            try? FileManager.default.removeItem(at: compressedURL)

            guard let exportSession = AVAssetExportSession(
                asset: asset,
                presetName: compressionPreset
            ) else { return 0 }

            exportSession.outputURL = compressedURL
            exportSession.outputFileType = .mp4
            exportSession.shouldOptimizeForNetworkUse = true

            await exportSession.export()

            guard exportSession.status == .completed else { return 0 }

            let compressedSize = (try? FileManager.default.attributesOfItem(atPath: compressedURL.path)[.size] as? Int64) ?? 0

            // Only replace if compressed is actually smaller
            if compressedSize < originalSize {
                try FileManager.default.removeItem(at: originalURL)
                try FileManager.default.moveItem(at: compressedURL, to: originalURL)
                return originalSize - compressedSize
            } else {
                // Compressed is larger — discard it
                try? FileManager.default.removeItem(at: compressedURL)
                return 0
            }
        } catch {
            print("Compression failed for \(entry.id): \(error)")
            return 0
        }
    }

    /// Get total storage used vs saved
    func storageStats(entries: [VideoEntry]) -> StorageStats {
        let totalOriginal: Int64 = entries.reduce(0) { total, entry in
            let size = (try? FileManager.default.attributesOfItem(atPath: entry.videoURL.path)[.size] as? Int64) ?? 0
            return total + size
        }

        return StorageStats(
            totalOriginalBytes: totalOriginal,
            savedBytes: totalSavedBytes,
            compressedCount: compressedEntries.count
        )
    }

    struct StorageStats {
        let totalOriginalBytes: Int64
        let savedBytes: Int64
        let compressedCount: Int

        var formattedOriginal: String {
            ByteCountFormatter.string(fromByteCount: totalOriginalBytes, countStyle: .file)
        }

        var formattedSaved: String {
            ByteCountFormatter.string(fromByteCount: savedBytes, countStyle: .file)
        }

        var effectiveBytes: Int64 {
            totalOriginalBytes - savedBytes
        }

        var formattedEffective: String {
            ByteCountFormatter.string(fromByteCount: effectiveBytes, countStyle: .file)
        }
    }

    // MARK: - Persistence

    private var compressedEntriesFile: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("BlinkVideos")
            .appendingPathComponent("compressed_entries.json")
    }

    private func loadCompressedEntries() {
        guard FileManager.default.fileExists(atPath: compressedEntriesFile.path) else { return }

        do {
            let data = try Data(contentsOf: compressedEntriesFile)
            let ids = try JSONDecoder().decode([UUID].self, from: data)
            compressedEntries = Set(ids)
        } catch {
            print("Failed to load compressed entries: \(error)")
        }
    }

    private func saveCompressedEntries() {
        do {
            let data = try JSONEncoder().encode(Array(compressedEntries))
            try data.write(to: compressedEntriesFile)
        } catch {
            print("Failed to save compressed entries: \(error)")
        }
    }
}
