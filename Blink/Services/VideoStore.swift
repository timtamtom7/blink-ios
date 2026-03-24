import Foundation
import AVFoundation
import UIKit

final class VideoStore: ObservableObject {
    static let shared = VideoStore()

    @Published private(set) var entries: [VideoEntry] = []

    let videosDirectory: URL

    private let entriesFile: URL
    private let fileManager = FileManager.default

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

    func deleteEntry(_ entry: VideoEntry) {
        let videoURL = videosDirectory.appendingPathComponent(entry.filename)
        try? fileManager.removeItem(at: videoURL)

        if let thumb = entry.thumbnailFilename {
            let thumbURL = videosDirectory.appendingPathComponent(thumb)
            try? fileManager.removeItem(at: thumbURL)
        }

        entries.removeAll { $0.id == entry.id }
        saveEntries()
    }

    func clipCountThisYear() -> Int {
        let year = Calendar.current.component(.year, from: Date())
        return entriesForYear(year).count
    }
}
