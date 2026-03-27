import Foundation
import CloudKit
import AVFoundation

// MARK: - Cloud Backup Service

final class CloudBackupService: ObservableObject {
    static let shared = CloudBackupService()

    enum BackupError: Error, LocalizedError {
        case notSignedIn
        case uploadFailed(String)
        case downloadFailed(String)
        case noICloud
        case cancelled

        var errorDescription: String? {
            switch self {
            case .notSignedIn:
                return "Not signed in to iCloud. Enable iCloud in Settings to back up your clips."
            case .uploadFailed(let reason):
                return "Upload failed: \(reason)"
            case .downloadFailed(let reason):
                return "Download failed: \(reason)"
            case .noICloud:
                return "iCloud is not available on this device."
            case .cancelled:
                return "Backup was cancelled."
            }
        }
    }

    @Published var isBackingUp = false
    @Published var lastBackupDate: Date? {
        didSet {
            if let date = lastBackupDate {
                UserDefaults.standard.set(date, forKey: "lastBackupDate")
            }
        }
    }
    @Published var backupProgress: Double = 0
    @Published var isRestoring = false
    @Published var restoreProgress: Double = 0

    // NOTE: container and privateDatabase are lazy vars, not let constants.
    // CKContainer crashes with EXC_BREAKPOINT (not a catchable Swift error) if the
    // CloudKit entitlement isn't configured. By making these lazy, we defer the call
    // until actual use — the app can still launch and show a clean "iCloud unavailable" error.
    private lazy var container: CKContainer = CKContainer.default()
    private lazy var privateDatabase: CKDatabase = container.privateCloudDatabase
    private let recordType = "BlinkBackup"
    private let fileManager = FileManager.default

    /// Checks if iCloud is available. Safe to call at any time — does not trigger CloudKit.
    var iCloudAvailable: Bool {
        fileManager.ubiquityIdentityToken != nil
    }

    private init() {
        lastBackupDate = UserDefaults.standard.object(forKey: "lastBackupDate") as? Date
    }

    // MARK: - Backup All Clips

    @MainActor
    func backupAllClips() async throws {
        guard iCloudAvailable else {
            throw BackupError.noICloud
        }

        guard !isBackingUp else { return }

        isBackingUp = true
        backupProgress = 0

        defer {
            Task { @MainActor in
                isBackingUp = false
            }
        }

        let entries = VideoStore.shared.entries.filter { !$0.isLocked }
        guard !entries.isEmpty else {
            throw BackupError.uploadFailed("No clips to back up")
        }

        // Upload each clip as a CloudKit asset
        for (index, entry) in entries.enumerated() {
            let videoURL = entry.videoURL

            guard fileManager.fileExists(atPath: videoURL.path) else {
                continue
            }

            do {
                try await uploadClip(entry: entry, videoURL: videoURL)
            } catch {
                print("Failed to upload clip \(entry.filename): \(error)")
            }

            await MainActor.run {
                backupProgress = Double(index + 1) / Double(entries.count)
            }
        }

        // Save backup manifest
        let manifest = BackupManifest(
            entryCount: entries.count,
            backupDate: Date(),
            entries: entries.map { ManifestEntry(from: $0) }
        )

        try await saveManifest(manifest)

        await MainActor.run {
            lastBackupDate = Date()
            backupProgress = 1.0
        }
    }

    // MARK: - Restore Clips

    @MainActor
    func restoreClips() async throws {
        guard iCloudAvailable else {
            throw BackupError.noICloud
        }

        guard !isRestoring else { return }

        isRestoring = true
        restoreProgress = 0

        defer {
            Task { @MainActor in
                isRestoring = false
            }
        }

        let manifest = try await loadManifest()

        guard let manifest = manifest else {
            throw BackupError.downloadFailed("No backup found in iCloud")
        }

        // Check each entry - download if not already on device
        for (index, manifestEntry) in manifest.entries.enumerated() {
            // Check if we already have this clip
            let exists = VideoStore.shared.entries.contains { $0.id == manifestEntry.id }
            if !exists {
                do {
                    try await downloadClip(manifestEntry: manifestEntry)
                } catch {
                    print("Failed to download clip \(manifestEntry.filename): \(error)")
                }
            }

            await MainActor.run {
                restoreProgress = Double(index + 1) / Double(manifest.entries.count)
            }
        }
    }

    // MARK: - Check Backup Status

    func hasBackupInCloud() async -> Bool {
        do {
            let manifest = try await loadManifest()
            return manifest != nil
        } catch {
            return false
        }
    }

    // MARK: - Private Helpers

    private func uploadClip(entry: VideoEntry, videoURL: URL) async throws {
        let asset = CKAsset(fileURL: videoURL)

        let recordID = CKRecord.ID(recordName: entry.id.uuidString)
        let record = CKRecord(recordType: recordType, recordID: recordID)

        record["filename"] = entry.filename
        record["date"] = entry.date
        record["duration"] = entry.duration
        record["title"] = entry.title
        record["videoAsset"] = asset

        // Generate and upload thumbnail
        if let thumbURL = entry.thumbnailURL, fileManager.fileExists(atPath: thumbURL.path) {
            let thumbAsset = CKAsset(fileURL: thumbURL)
            record["thumbnailAsset"] = thumbAsset
        }

        _ = try await privateDatabase.save(record)
    }

    private func downloadClip(manifestEntry: ManifestEntry) async throws {
        let recordID = CKRecord.ID(recordName: manifestEntry.id.uuidString)

        let record: CKRecord
        do {
            record = try await privateDatabase.record(for: recordID)
        } catch {
            throw BackupError.downloadFailed("Could not find record in iCloud")
        }

        guard let asset = record["videoAsset"] as? CKAsset,
              let fileURL = asset.fileURL else {
            throw BackupError.downloadFailed("Could not download video file")
        }

        // Copy to videos directory
        let destinationURL = VideoStore.shared.videosDirectory.appendingPathComponent(manifestEntry.filename)

        if fileManager.fileExists(atPath: destinationURL.path) {
            try? fileManager.removeItem(at: destinationURL)
        }

        try fileManager.copyItem(at: fileURL, to: destinationURL)

        // Download thumbnail if available
        var thumbnailFilename: String? = nil
        if let thumbAsset = record["thumbnailAsset"] as? CKAsset,
           let thumbURL = thumbAsset.fileURL {
            let thumbName = "thumb_\(manifestEntry.filename)"
            thumbnailFilename = thumbName
            let thumbDestination = VideoStore.shared.videosDirectory.appendingPathComponent(thumbName)
            try? fileManager.copyItem(at: thumbURL, to: thumbDestination)
        }

        // Add to VideoStore
        let newEntry = VideoEntry(
            id: manifestEntry.id,
            date: manifestEntry.date,
            filename: manifestEntry.filename,
            duration: manifestEntry.duration,
            thumbnailFilename: thumbnailFilename,
            title: manifestEntry.title
        )

        await MainActor.run {
            VideoStore.shared.restoreEntry(newEntry)
        }
    }

    private func saveManifest(_ manifest: BackupManifest) async throws {
        let data = try JSONEncoder().encode(manifest)
        let tempURL = fileManager.temporaryDirectory.appendingPathComponent("blink_manifest.json")
        try data.write(to: tempURL)

        let asset = CKAsset(fileURL: tempURL)

        let recordID = CKRecord.ID(recordName: "BlinkManifest")
        let record = CKRecord(recordType: "BlinkManifest", recordID: recordID)
        record["manifest"] = asset
        record["entryCount"] = manifest.entryCount
        record["backupDate"] = manifest.backupDate

        _ = try await privateDatabase.save(record)

        try? fileManager.removeItem(at: tempURL)
    }

    private func loadManifest() async throws -> BackupManifest? {
        let recordID = CKRecord.ID(recordName: "BlinkManifest")

        do {
            let record = try await privateDatabase.record(for: recordID)

            guard let asset = record["manifest"] as? CKAsset,
                  let fileURL = asset.fileURL else {
                return nil
            }

            let data = try Data(contentsOf: fileURL)
            return try JSONDecoder().decode(BackupManifest.self, from: data)
        } catch let error as CKError where error.code == .unknownItem {
            return nil
        }
    }
}

// MARK: - Backup Manifest

struct BackupManifest: Codable {
    let entryCount: Int
    let backupDate: Date
    let entries: [ManifestEntry]
}

struct ManifestEntry: Codable {
    let id: UUID
    let date: Date
    let filename: String
    let duration: TimeInterval
    let title: String?

    init(from entry: VideoEntry) {
        self.id = entry.id
        self.date = entry.date
        self.filename = entry.filename
        self.duration = entry.duration
        self.title = entry.title
    }
}
