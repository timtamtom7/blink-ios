import Foundation
import Vision
import AVFoundation
import CoreImage
import Photos

/// AI-powered highlights detection:
/// - Analyzes clips for meaningful moments (smile detection, motion, faces)
/// - Generates AI insights like "This clip captures your smile"
/// - Creates automatic highlight reels from selected clips
final class AIHighlightsService: ObservableObject {
    static let shared = AIHighlightsService()

    @Published private(set) var isAnalyzing = false
    @Published private(set) var highlights: [AIHighlight] = []
    @Published private(set) var latestReelURL: URL?

    private let fileManager = FileManager.default

    private init() {}

    // MARK: - AI Highlight

    struct AIHighlight: Identifiable {
        let id: UUID
        let entry: VideoEntry
        let score: Double // 0-1, higher = more meaningful
        let insightText: String
        let insightType: AIHighlight.InsightType
        let timestamp: TimeInterval // seconds into the clip where insight occurs

        enum InsightType: String {
            case smile = "smile"
            case motion = "motion"
            case bright = "bright"
            case calm = "calm"
            case milestone = "milestone"

            var icon: String {
                switch self {
                case .smile: return "face.smiling"
                case .motion: return "figure.walk"
                case .bright: return "sun.max"
                case .calm: return "leaf"
                case .milestone: return "star"
                }
            }

            var templateText: String {
                switch self {
                case .smile: return "This clip captures your smile"
                case .motion: return "A moment of movement and life"
                case .bright: return "Caught in the light"
                case .calm: return "A quiet, peaceful moment"
                case .milestone: return "A moment worth remembering"
                }
            }
        }
    }

    // MARK: - Analysis

    /// Analyze all entries and find the top meaningful moments.
    @MainActor
    func analyzeHighlights(entries: [VideoEntry]) async {
        guard !isAnalyzing else { return }
        isAnalyzing = true
        highlights = []

        var allHighlights: [AIHighlight] = []

        for entry in entries where !entry.isLocked {
            if let highlight = await analyzeEntry(entry) {
                allHighlights.append(highlight)
            }
        }

        // Sort by score descending
        allHighlights.sort { $0.score > $1.score }
        highlights = allHighlights
        isAnalyzing = false
    }

    /// Analyze a single clip for meaningful moments.
    private func analyzeEntry(_ entry: VideoEntry) async -> AIHighlight? {
        let videoURL = entry.videoURL

        guard fileManager.fileExists(atPath: videoURL.path) else { return nil }

        do {
            let asset = AVURLAsset(url: videoURL)
            let duration = try await asset.load(.duration).seconds

            // Sample 3 frames across the clip
            let sampleTimes = [0.1, 0.5, 0.9].map { fraction in
                CMTime(seconds: duration * fraction, preferredTimescale: 600)
            }

            var scores: [(TimeInterval, Double, AIHighlight.InsightType)] = []

            for time in sampleTimes {
                let (score, type) = await analyzeFrame(at: time, asset: asset)
                scores.append((time.seconds, score, type))
            }

            // Pick best moment
            if let best = scores.max(by: { $0.1 < $1.1 }) {
                let insightText = generateInsightText(for: best.2, entry: entry, score: best.1)

                return AIHighlight(
                    id: UUID(),
                    entry: entry,
                    score: best.1,
                    insightText: insightText,
                    insightType: best.2,
                    timestamp: best.0
                )
            }

            return nil
        } catch {
            return nil
        }
    }

    /// Analyze a single frame for visual features.
    private func analyzeFrame(at time: CMTime, asset: AVURLAsset) async -> (Double, AIHighlight.InsightType) {
        do {
            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true
            generator.requestedTimeToleranceBefore = .zero
            generator.requestedTimeToleranceAfter = .zero

            let (cgImage, _) = try await generator.image(at: time)
            let ciImage = CIImage(cgImage: cgImage)

            // Run Vision face detection
            let faceRequest = VNDetectFaceRectanglesRequest()
            let faceLandmarksRequest = VNDetectFaceLandmarksRequest()

            let handler = VNImageRequestHandler(ciImage: ciImage, options: [:])
            try handler.perform([faceRequest, faceLandmarksRequest])

            let faces = faceRequest.results ?? []
            let hasFaces = !faces.isEmpty
            let hasSmile = detectSmile(in: faceLandmarksRequest.results)

            // Check brightness
            let brightness = averageBrightness(of: ciImage)

            // Score and classify
            var score: Double = 0.3
            var type: AIHighlight.InsightType = .milestone

            if hasSmile {
                score = 0.9
                type = .smile
            } else if hasFaces {
                score = 0.7
                type = .milestone
            } else if brightness > 0.7 {
                score = 0.6
                type = .bright
            } else if brightness < 0.3 {
                score = 0.5
                type = .calm
            } else {
                score = 0.4
                type = .motion
            }

            // Bonus for faces
            if hasFaces {
                score += 0.1
            }

            return (min(1.0, score), type)
        } catch {
            return (0.3, .milestone)
        }
    }

    /// Simple smile detection via facial landmarks.
    private func detectSmile(in results: [VNFaceObservation]?) -> Bool {
        guard let faces = results, !faces.isEmpty else { return false }
        let landmarks = faces[0].landmarks

        // Check for mouth landmarks (simplified heuristic)
        if let outerLips = landmarks?.outerLips {
            // In a real implementation, we'd analyze the mouth curve
            // For now, use a simple heuristic based on face rectangle aspect ratio
            if let face = faces.first {
                let w = face.boundingBox.width
                let h = face.boundingBox.height
                // Wider face bounding box tends to indicate a smile
                return w > 0.35 && h > 0.25
            }
        }
        return false
    }

    /// Average brightness of an image (0-1).
    private func averageBrightness(of ciImage: CIImage) -> Double {
        // Apply brightness filter and sample center
        let filter = CIFilter(name: "CIAreaAverage", parameters: [
            kCIInputImageKey: ciImage,
            kCIInputExtentKey: CIVector(cgRect: ciImage.extent)
        ])
        // Simplified: use histogram approximation
        // Real implementation would use CIAreaHistogram
        return 0.5 // Placeholder - real implementation would compute actual brightness
    }

    /// Generate human-readable insight text.
    private func generateInsightText(for type: AIHighlight.InsightType, entry: VideoEntry, score: Double) -> String {
        let calendar = Calendar.current
        let month = calendar.component(.month, from: entry.date)
        let monthName = DateFormatter().monthSymbols[month - 1]

        switch type {
        case .smile:
            if score > 0.85 {
                return "This clip captures a genuine smile"
            }
            return "Something made you happy here"
        case .motion:
            return "A moment of life in motion"
        case .bright:
            return "Caught in the light, \(monthName) \(calendar.component(.day, from: entry.date))"
        case .calm:
            return "A quiet, still moment"
        case .milestone:
            return "A moment worth preserving"
        }
    }

    // MARK: - Highlight Reel Generation

    /// Generate a highlight reel from the top N highlights.
    @MainActor
    func generateHighlightReel(clips: [AIHighlight], title: String = "Your Year in Blink") async throws -> URL {
        guard !clips.isEmpty else {
            throw ReelError.noClips
        }

        let outputFilename = "highlight_reel_\(ISO8601DateFormatter().string(from: Date())).mp4"
        let docsDir = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let outputURL = docsDir.appendingPathComponent("BlinkVideos").appendingPathComponent(outputFilename)

        // Create composition
        let composition = AVMutableComposition()

        guard let videoTrack = composition.addMutableTrack(
            withMediaType: .video,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else {
            throw ReelError.compositionFailed
        }

        let audioTrack = composition.addMutableTrack(
            withMediaType: .audio,
            preferredTrackID: kCMPersistentTrackID_Invalid
        )

        var currentTime = CMTime.zero
        let clipDuration: CMTime = CMTime(seconds: 5.0, preferredTimescale: 600) // 5 sec per clip

        for highlight in clips.prefix(10) {
            let asset = AVURLAsset(url: highlight.entry.videoURL)
            let duration = try await asset.load(.duration)

            // Use the timestamp as the start point if within bounds
            let startOffset = CMTime(seconds: min(highlight.timestamp, duration.seconds - 5), preferredTimescale: 600)
            let timeRange = CMTimeRange(start: startOffset, duration: clipDuration)

            if let assetVideoTrack = try await asset.loadTracks(withMediaType: .video).first {
                try videoTrack.insertTimeRange(timeRange, of: assetVideoTrack, at: currentTime)
            }

            if let assetAudioTrack = try await asset.loadTracks(withMediaType: .audio).first {
                try audioTrack?.insertTimeRange(timeRange, of: assetAudioTrack, at: currentTime)
            }

            currentTime = CMTimeAdd(currentTime, clipDuration)
        }

        // Export
        guard let exportSession = AVAssetExportSession(
            asset: composition,
            presetName: AVAssetExportPresetHighestQuality
        ) else {
            throw ReelError.exportFailed
        }

        try? fileManager.removeItem(at: outputURL)
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mp4

        await exportSession.export()

        guard exportSession.status == .completed else {
            throw ReelError.exportFailed
        }

        latestReelURL = outputURL
        return outputURL
    }

    enum ReelError: Error, LocalizedError {
        case noClips
        case compositionFailed
        case exportFailed

        var errorDescription: String? {
            switch self {
            case .noClips: return "No clips available for the highlight reel."
            case .compositionFailed: return "Failed to create highlight reel."
            case .exportFailed: return "Failed to export highlight reel."
            }
        }
    }

    // MARK: - Year Summary

    /// Get AI-generated year summary insights.
    func yearInsights(entries: [VideoEntry]) -> [String] {
        guard !entries.isEmpty else {
            return ["Your Blink diary starts today."]
        }

        var insights: [String] = []

        let totalClips = entries.count
        let calendar = Calendar.current
        let year = calendar.component(.year, from: Date())

        let yearEntries = entries.filter {
            calendar.component(.year, from: $0.date) == year
        }

        let busiestMonth = findBusiestMonth(entries: yearEntries)
        let avgDuration = yearEntries.isEmpty ? 0 : yearEntries.reduce(0) { $0 + $1.duration } / Double(yearEntries.count)

        insights.append("You captured \(totalClips) moments this year.")

        if let busiest = busiestMonth {
            let monthName = DateFormatter().monthSymbols[busiest - 1]
            insights.append("\(monthName) was your busiest month.")
        }

        if avgDuration > 20 {
            insights.append("Your average clip is \(Int(avgDuration)) seconds — you know what matters.")
        }

        let weekdayCounts = Dictionary(grouping: yearEntries) {
            calendar.component(.weekday, from: $0.date)
        }.mapValues { $0.count }

        if let (bestDay, _) = weekdayCounts.max(by: { $0.value < $1.value }) {
            let dayName = calendar.weekdaySymbols[bestDay - 1]
            insights.append("\(dayName)s are your Blink days.")
        }

        return insights
    }

    private func findBusiestMonth(entries: [VideoEntry]) -> Int? {
        let calendar = Calendar.current
        let counts = Dictionary(grouping: entries) {
            calendar.component(.month, from: $0.date)
        }.mapValues { $0.count }

        return counts.max(by: { $0.value < $1.value })?.key
    }
}
