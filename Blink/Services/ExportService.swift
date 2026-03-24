import Foundation
import AVFoundation
import Photos
import UIKit

// MARK: - Export Service

final class ExportService: ObservableObject {
    static let shared = ExportService()

    enum ExportError: Error, LocalizedError {
        case noClips
        case exportFailed(String)
        case storageFull
        case permissionDenied
        case cancelled

        var errorDescription: String? {
            switch self {
            case .noClips:
                return "No clips to export."
            case .exportFailed(let reason):
                return "Export failed: \(reason)"
            case .storageFull:
                return "Not enough storage space."
            case .permissionDenied:
                return "Permission denied. Check Settings."
            case .cancelled:
                return "Export was cancelled."
            }
        }
    }

    enum ExportProgress {
        case preparing
        case exporting(progress: Double)
        case saving
        case completed(URL)
        case failed(ExportError)
    }

    private let fileManager = FileManager.default

    private init() {}

    // MARK: - Export Month Clips

    /// Export all clips from a specific month as a single video file.
    /// - Parameters:
    ///   - month: Month number (1-12)
    ///   - year: Year
    ///   - progressHandler: Called with progress updates (0.0 - 1.0)
    /// - Returns: URL of the exported video file in temp directory
    @MainActor
    func exportMonthClips(
        month: Int,
        year: Int,
        title: String? = nil,
        onProgress: ((Double) -> Void)? = nil
    ) async throws -> URL {
        let entries = VideoStore.shared.entries.filter { entry in
            let calendar = Calendar.current
            return calendar.component(.month, from: entry.date) == month &&
                   calendar.component(.year, from: entry.date) == year &&
                   !entry.isLocked
        }.sorted { $0.date < $1.date }

        guard !entries.isEmpty else {
            throw ExportError.noClips
        }

        return try await exportClipsAsVideo(
            entries: entries,
            title: title ?? "Blink \(monthName(month: month)) \(year)",
            onProgress: onProgress
        )
    }

    // MARK: - Export Year Clips

    /// Export all clips from a year as a single video file.
    /// - Parameters:
    ///   - year: Year
    ///   - progressHandler: Called with progress updates (0.0 - 1.0)
    /// - Returns: URL of the exported video file in temp directory
    @MainActor
    func exportYearClips(
        year: Int,
        onProgress: ((Double) -> Void)? = nil
    ) async throws -> URL {
        let entries = VideoStore.shared.entries.filter { entry in
            let calendar = Calendar.current
            return calendar.component(.year, from: entry.date) == year &&
                   !entry.isLocked
        }.sorted { $0.date < $1.date }

        guard !entries.isEmpty else {
            throw ExportError.noClips
        }

        return try await exportClipsAsVideo(
            entries: entries,
            title: "Blink \(year) Year in Review",
            onProgress: onProgress
        )
    }

    // MARK: - Core Export Logic

    private func exportClipsAsVideo(
        entries: [VideoEntry],
        title: String,
        onProgress: ((Double) -> Void)? = nil
    ) async throws -> URL {
        guard !entries.isEmpty else {
            throw ExportError.noClips
        }

        onProgress?(0.0)

        // Create composition
        let composition = AVMutableComposition()

        guard let videoTrack = composition.addMutableTrack(
            withMediaType: .video,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ),
        let audioTrack = composition.addMutableTrack(
            withMediaType: .audio,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else {
            throw ExportError.exportFailed("Could not create composition tracks")
        }

        var currentTime = CMTime.zero
        var videoSize = CGSize(width: 1080, height: 1920) // Default portrait

        // Add each clip
        for (index, entry) in entries.enumerated() {
            let asset = AVURLAsset(url: entry.videoURL)

            do {
                // Get video track
                if let assetVideoTrack = try await asset.loadTracks(withMediaType: .video).first {
                    let duration = try await asset.load(.duration)

                    // Get natural size and transform
                    let naturalSize = try await assetVideoTrack.load(.naturalSize)
                    let transform = try await assetVideoTrack.load(.preferredTransform)

                    // Calculate actual rendered size
                    let isPortrait = transform.a == 0 && abs(transform.b) == 1
                    if isPortrait {
                        videoSize = CGSize(width: naturalSize.height, height: naturalSize.width)
                    } else {
                        videoSize = naturalSize
                    }

                    let timeRange = CMTimeRange(start: .zero, duration: duration)

                    try videoTrack.insertTimeRange(
                        timeRange,
                        of: assetVideoTrack,
                        at: currentTime
                    )

                    // Add audio if available
                    if let assetAudioTrack = try await asset.loadTracks(withMediaType: .audio).first {
                        try audioTrack.insertTimeRange(
                            timeRange,
                            of: assetAudioTrack,
                            at: currentTime
                        )
                    }

                    currentTime = CMTimeAdd(currentTime, duration)
                }
            } catch {
                print("Could not load clip \(entry.filename): \(error)")
                continue
            }

            onProgress?(Double(index + 1) / Double(entries.count) * 0.5)
        }

        // Create video composition for proper orientation
        let videoComposition = AVMutableVideoComposition()
        videoComposition.renderSize = videoSize
        videoComposition.frameDuration = CMTime(value: 1, timescale: 30)

        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = CMTimeRange(start: .zero, duration: composition.duration)

        let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: videoTrack)
        layerInstruction.setTransform(CGAffineTransform.identity, at: .zero)
        instruction.layerInstructions = [layerInstruction]
        videoComposition.instructions = [instruction]

        // Export
        let outputFilename = "blink_export_\(ISO8601DateFormatter().string(from: Date())).mp4"
        let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent(outputFilename)

        // Remove existing file if any
        try? fileManager.removeItem(at: outputURL)

        guard let exportSession = AVAssetExportSession(
            asset: composition,
            presetName: AVAssetExportPresetHighestQuality
        ) else {
            throw ExportError.exportFailed("Could not create export session")
        }

        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mp4
        exportSession.videoComposition = videoComposition
        exportSession.shouldOptimizeForNetworkUse = true

        onProgress?(0.6)

        // Monitor progress
        let progressTask = Task {
            while !Task.isCancelled && exportSession.status == .exporting {
                await MainActor.run {
                    let progress = 0.6 + Double(exportSession.progress) * 0.3
                    onProgress?(progress)
                }
                try? await Task.sleep(nanoseconds: 200_000_000)
            }
        }

        await exportSession.export()
        progressTask.cancel()

        onProgress?(0.9)

        guard exportSession.status == .completed else {
            if let nsError = exportSession.error as? NSError,
               nsError.code == NSFileWriteOutOfSpaceError {
                throw ExportError.storageFull
            }
            throw ExportError.exportFailed(exportSession.error?.localizedDescription ?? "Unknown error")
        }

        onProgress?(1.0)

        return outputURL
    }

    // MARK: - Save to Camera Roll

    @MainActor
    func saveToCameraRoll(url: URL) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
                guard status == .authorized || status == .limited else {
                    continuation.resume(throwing: ExportError.permissionDenied)
                    return
                }

                PHPhotoLibrary.shared().performChanges {
                    PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
                } completionHandler: { success, error in
                    if success {
                        continuation.resume()
                    } else {
                        continuation.resume(throwing: ExportError.exportFailed(error?.localizedDescription ?? "Save failed"))
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private func monthName(month: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM"
        var components = DateComponents()
        components.month = month
        components.day = 1
        components.year = 2024
        guard let date = Calendar.current.date(from: components) else { return "" }
        return formatter.string(from: date)
    }
}
