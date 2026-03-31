import Foundation
import AVFoundation
import UIKit
import Photos

final class VideoStore: ObservableObject {
    static let shared = VideoStore()

    @Published private(set) var entries: [VideoEntry] = []

    let videosDirectory: URL

    private let entriesFile: URL
    private let fileManager = FileManager.default

    // MARK: - On This Day Cache

    private var _cachedOnThisDayEntries: [VideoEntry]?
    private var _onThisDayCacheEntryCount: Int = 0

    private func invalidateOnThisDayCache() {
        _cachedOnThisDayEntries = nil
    }

    private init() {
        let docsDir = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        videosDirectory = docsDir.appendingPathComponent("BlinkVideos", isDirectory: true)
        entriesFile = videosDirectory.appendingPathComponent("entries.json")

        try? fileManager.createDirectory(at: videosDirectory, withIntermediateDirectories: true)
        loadEntries()
    }

    func generateVideoURL() -> URL {
        let filename = "blink_\(ISO8601DateFormatter().string(from: Date())).mov"
        return videosDirectory.appendingPathComponent(filename)
    }

    func loadEntries() {
        guard fileManager.fileExists(atPath: entriesFile.path) else {
            entries = []
            return
        }

        do {
            let data = try Data(contentsOf: entriesFile)
            entries = try JSONDecoder().decode([VideoEntry].self, from: data)
        } catch {
            print("Failed to load entries: \(error)")
            entries = []
        }
    }

    func saveEntries() {
        do {
            let data = try JSONEncoder().encode(entries)
            try data.write(to: entriesFile)
        } catch {
            print("Failed to save entries: \(error)")
        }
    }

    @MainActor
    func addVideo(at url: URL) async -> Bool {
        do {
            let asset = AVURLAsset(url: url)
            let duration = try await asset.load(.duration)
            let durationSeconds = duration.seconds

            // Check file exists
            guard FileManager.default.fileExists(atPath: url.path) else {
                return false
            }

            // Generate thumbnail
            let thumbnailFilename = await ThumbnailGenerator.shared.generateThumbnail(for: url, videoFilename: url.lastPathComponent)

            let entry = VideoEntry(
                date: Date(),
                filename: url.lastPathComponent,
                duration: durationSeconds,
                thumbnailFilename: thumbnailFilename
            )

            entries.append(entry)
            saveEntries()
            invalidateOnThisDayCache()
            return true
        } catch {
            print("Failed to add video: \(error)")
            return false
        }
    }

    func entriesForYear(_ year: Int) -> [VideoEntry] {
        let calendar = Calendar.current
        return entries.filter { calendar.component(.year, from: $0.date) == year }
    }

    func entryForDate(_ date: Date) -> VideoEntry? {
        let calendar = Calendar.current
        return entries.first { calendar.isDate($0.date, inSameDayAs: date) }
    }

    func todayHasClip() -> Bool {
        entryForDate(Date()) != nil
    }

    @MainActor
    func deleteEntry(_ entry: VideoEntry) {
        let videoURL = videosDirectory.appendingPathComponent(entry.filename)
        try? fileManager.removeItem(at: videoURL)

        if let thumb = entry.thumbnailFilename {
            let thumbURL = videosDirectory.appendingPathComponent(thumb)
            try? fileManager.removeItem(at: thumbURL)
        }

        entries.removeAll { $0.id == entry.id }
        saveEntries()
        invalidateOnThisDayCache()
    }

    func clipCountThisYear() -> Int {
        let year = Calendar.current.component(.year, from: Date())
        return entriesForYear(year).count
    }

    // MARK: - Trim

    enum TrimError: Error, LocalizedError {
        case exportFailed
        case storageFull
        case sourceNotFound

        var errorDescription: String? {
            switch self {
            case .exportFailed: return "Failed to export trimmed clip."
            case .storageFull: return "Not enough storage to save the trimmed clip."
            case .sourceNotFound: return "Original clip not found."
            }
        }
    }

    /// Trim a clip and save as a new entry.
    /// - Parameters:
    ///   - entry: The original clip entry
    ///   - startTime: Trim start time in seconds
    ///   - endTime: Trim end time in seconds
    ///   - saveAsNew: If true, keeps original and creates a new clip; if false, overwrites original
    /// - Returns: The new VideoEntry if successful
    @MainActor
    func trimClip(_ entry: VideoEntry, startTime: Double, endTime: Double, saveAsNew: Bool) async throws -> VideoEntry {
        let sourceURL = entry.videoURL

        guard fileManager.fileExists(atPath: sourceURL.path) else {
            throw TrimError.sourceNotFound
        }

        let asset = AVURLAsset(url: sourceURL)
        let duration = try await asset.load(.duration).seconds
        let clampedStart = max(0, min(startTime, duration))
        let clampedEnd = max(clampedStart, min(endTime, duration))

        let outputFilename = "blink_trimmed_\(ISO8601DateFormatter().string(from: Date())).mov"
        let outputURL = videosDirectory.appendingPathComponent(outputFilename)

        // Use AVAssetExportSession to cut the clip
        guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetHighestQuality) else {
            throw TrimError.exportFailed
        }

        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mov

        let startCMTime = CMTime(seconds: clampedStart, preferredTimescale: 600)
        let endCMTime = CMTime(seconds: clampedEnd, preferredTimescale: 600)
        exportSession.timeRange = CMTimeRange(start: startCMTime, end: endCMTime)

        await exportSession.export()

        guard exportSession.status == .completed else {
            if let nsError = exportSession.error as? NSError, nsError.code == NSFileWriteOutOfSpaceError {
                throw TrimError.storageFull
            }
            throw TrimError.exportFailed
        }

        let trimmedDuration = clampedEnd - clampedStart
        let thumbnailFilename = await ThumbnailGenerator.shared.generateThumbnail(for: outputURL, videoFilename: outputFilename)

        let newEntry = VideoEntry(
            id: saveAsNew ? UUID() : entry.id,  // new UUID for saveAsNew, preserve original ID for overwrite
            date: entry.date,
            filename: outputFilename,
            duration: trimmedDuration,
            thumbnailFilename: thumbnailFilename,
            title: entry.title
        )

        if saveAsNew {
            entries.append(newEntry)
        } else {
            // Overwrite: update the original entry in-place, preserve its ID
            guard let oldIndex = entries.firstIndex(where: { $0.id == entry.id }) else {
                // Entry was deleted concurrently — treat as saveAsNew
                entries.append(newEntry)
                try? fileManager.removeItem(at: sourceURL)
                saveEntries()
                invalidateOnThisDayCache()
                return newEntry
            }
            // Remove old video file
            try? fileManager.removeItem(at: sourceURL)
            entries[oldIndex] = newEntry
        }

        saveEntries()
        invalidateOnThisDayCache()
        return newEntry
    }

    // MARK: - Export to Camera Roll

    enum ExportError: Error, LocalizedError {
        case copyFailed
        case saveFailed

        var errorDescription: String? {
            switch self {
            case .copyFailed: return "Failed to read the clip file."
            case .saveFailed: return "Failed to save clip to Camera Roll. Check Settings > Blink > Photos."
            }
        }
    }

    /// Export a single clip to the Camera Roll.
    @MainActor
    func exportToCameraRoll(_ entry: VideoEntry) async throws {
        let sourceURL = entry.videoURL

        guard fileManager.fileExists(atPath: sourceURL.path) else {
            throw ExportError.copyFailed
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
                guard status == .authorized || status == .limited else {
                    continuation.resume(throwing: ExportError.saveFailed)
                    return
                }

                PHPhotoLibrary.shared().performChanges {
                    PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: sourceURL)
                } completionHandler: { success, error in
                    if success {
                        continuation.resume()
                    } else {
                        continuation.resume(throwing: ExportError.saveFailed)
                    }
                }
            }
        }
    }

    // MARK: - Update Title

    @MainActor
    func updateTitle(for entry: VideoEntry, title: String) {
        guard let index = entries.firstIndex(where: { $0.id == entry.id }) else { return }
        entries[index].title = title.isEmpty ? nil : title
        saveEntries()
        invalidateOnThisDayCache()
    }

    @MainActor
    func updateEntry(_ entry: VideoEntry) {
        guard let index = entries.firstIndex(where: { $0.id == entry.id }) else { return }
        entries[index] = entry
        saveEntries()
        invalidateOnThisDayCache()
    }

    /// Add a restored entry from iCloud backup.
    @MainActor
    func restoreEntry(_ entry: VideoEntry) {
        // Don't add if already exists
        guard !entries.contains(where: { $0.id == entry.id }) else { return }
        entries.append(entry)
        saveEntries()
        invalidateOnThisDayCache()
    }

    // MARK: - Months

    func monthsWithEntries(for year: Int) -> [Int] {
        let calendar = Calendar.current
        let yearEntries = entriesForYear(year)
        var months = Set<Int>()
        for entry in yearEntries {
            months.insert(calendar.component(.month, from: entry.date))
        }
        return months.sorted()
    }

    func clipCount(for month: Int, year: Int) -> Int {
        let calendar = Calendar.current
        return entries.filter {
            calendar.component(.month, from: $0.date) == month &&
            calendar.component(.year, from: $0.date) == year
        }.count
    }

    // MARK: - On This Day

    /// Returns entries from the same month and day in previous years (excluding today).
    /// Results are cached and recomputed only when entries change.
    func onThisDayEntries(excludingToday: Bool = true) -> [VideoEntry] {
        // Check cache validity
        if _cachedOnThisDayEntries != nil && _onThisDayCacheEntryCount == entries.count {
            return _cachedOnThisDayEntries!
        }

        let calendar = Calendar.current
        let today = Date()
        let todayMonth = calendar.component(.month, from: today)
        let todayDay = calendar.component(.day, from: today)
        let todayYear = calendar.component(.year, from: today)

        let result = entries.filter { entry in
            let entryMonth = calendar.component(.month, from: entry.date)
            let entryDay = calendar.component(.day, from: entry.date)
            let entryYear = calendar.component(.year, from: entry.date)

            let sameDate = entryMonth == todayMonth && entryDay == todayDay
            let notToday = entryYear != todayYear

            if excludingToday {
                return sameDate && notToday && !entry.isLocked
            } else {
                return sameDate && !entry.isLocked
            }
        }.sorted { $0.date < $1.date }

        // Cache the result
        _cachedOnThisDayEntries = result
        _onThisDayCacheEntryCount = entries.count

        return result
    }

    /// Count of On This Day entries.
    var onThisDayCount: Int {
        onThisDayEntries().count
    }

    // MARK: - Lock / Unlock

    @MainActor
    func toggleLock(for entry: VideoEntry) {
        guard let index = entries.firstIndex(where: { $0.id == entry.id }) else { return }
        entries[index].isLocked.toggle()
        saveEntries()
        invalidateOnThisDayCache()
    }
}
