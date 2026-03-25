import Foundation
import AVFoundation
import UIKit
import Speech

/// R11: Smart Skip — detects dead air / static shots longer than 3s with no motion
final class SmartSkipService: ObservableObject {
    static let shared = SmartSkipService()

    @Published private(set) var isAnalyzing = false
    @Published private(set) var deadAirSegments: [DeadAirSegment] = []

    struct DeadAirSegment: Identifiable {
        let id = UUID()
        let entryId: UUID
        let startTime: Double
        let endTime: Double
        let duration: Double
    }

    private let analysisQueue = DispatchQueue(label: "com.blink.smartskip", qos: .utility)
    private let motionThreshold: Double = 0.02 // Minimum pixel change to count as motion
    private let deadAirThreshold: Double = 3.0 // Seconds of no motion = dead air

    private init() {}

    /// Detect dead air segments in a video entry
    func analyzeEntry(_ entry: VideoEntry) async -> [DeadAirSegment] {
        let videoURL = entry.videoURL
        guard FileManager.default.fileExists(atPath: videoURL.path) else { return [] }

        do {
            let asset = AVURLAsset(url: videoURL)
            let duration = try await asset.load(.duration).seconds

            // Sample frames every 0.5 seconds for motion detection
            let sampleInterval: Double = 0.5
            let sampleCount = Int(duration / sampleInterval)

            var previousFrame: UIImage?
            var deadAirRanges: [(start: Double, end: Double)] = []
            var currentDeadAirStart: Double?

            for i in 0..<sampleCount {
                let time = sampleInterval * Double(i)
                if let frame = await extractFrame(at: time, from: asset) {
                    if let prev = previousFrame {
                        let motion = calculateMotion(from: prev, to: frame)

                        if motion < motionThreshold {
                            // No motion detected
                            if currentDeadAirStart == nil {
                                currentDeadAirStart = time
                            }
                        } else {
                            // Motion detected — close out dead air range
                            if let start = currentDeadAirStart, time - start >= deadAirThreshold {
                                deadAirRanges.append((start: start, end: time))
                            }
                            currentDeadAirStart = nil
                        }
                    }
                    previousFrame = frame
                }
            }

            // Close final range if needed
            if let start = currentDeadAirStart, duration - start >= deadAirThreshold {
                deadAirRanges.append((start: start, end: duration))
            }

            return deadAirRanges.map { range in
                DeadAirSegment(
                    entryId: entry.id,
                    startTime: range.start,
                    endTime: range.end,
                    duration: range.end - range.start
                )
            }
        } catch {
            print("SmartSkip analysis failed for \(entry.id): \(error)")
            return []
        }
    }

    /// Analyze all entries and collect dead air segments
    @MainActor
    func analyzeAll(entries: [VideoEntry]) async {
        guard !isAnalyzing else { return }
        isAnalyzing = true
        deadAirSegments = []

        var allSegments: [DeadAirSegment] = []

        for entry in entries {
            let segments = await analyzeEntry(entry)
            allSegments.append(contentsOf: segments)
        }

        deadAirSegments = allSegments
        isAnalyzing = false
    }

    /// Returns suggested trim points for dead air removal
    func trimSuggestions(for entry: VideoEntry) -> [TrimRange] {
        deadAirSegments
            .filter { $0.entryId == entry.id && $0.duration >= deadAirThreshold }
            .map { TrimRange(start: $0.startTime, end: $0.endTime) }
    }

    struct TrimRange {
        let start: Double
        let end: Double
        var duration: Double { end - start }
    }

    // MARK: - Private

    private func extractFrame(at time: Double, from asset: AVURLAsset) async -> UIImage? {
        do {
            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true
            generator.requestedTimeToleranceBefore = CMTime(seconds: 0.1, preferredTimescale: 600)
            generator.requestedTimeToleranceAfter = CMTime(seconds: 0.1, preferredTimescale: 600)
            generator.requestedTimeToleranceBefore = .zero
            generator.requestedTimeToleranceAfter = .zero

            let cmTime = CMTime(seconds: time, preferredTimescale: 600)
            let (cgImage, _) = try await generator.image(at: cmTime)
            return UIImage(cgImage: cgImage)
        } catch {
            return nil
        }
    }

    private func calculateMotion(from previous: UIImage, to current: UIImage) -> Double {
        guard let prevCG = previous.cgImage,
              let currCG = current.cgImage else { return 1.0 }

        let size = CGSize(width: 40, height: 40) // Small for performance
        let prevMotion = pixelDifference(cgImage: prevCG, size: size)
        let currMotion = pixelDifference(cgImage: currCG, size: size)

        return abs(currMotion - prevMotion)
    }

    private func pixelDifference(cgImage: CGImage, size: CGSize) -> Double {
        let width = Int(size.width)
        let height = Int(size.height)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        var rawData = [UInt8](repeating: 0, count: width * height * 4)

        guard let context = CGContext(
            data: &rawData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return 0 }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        var totalDiff: Double = 0
        let count = width * height

        for i in 0..<count {
            let offset = i * 4
            let r = Double(rawData[offset])
            let g = Double(rawData[offset + 1])
            let b = Double(rawData[offset + 2])
            totalDiff += (r + g + b) / (255.0 * 3.0)
        }

        return totalDiff / Double(count)
    }
}
