import Foundation
import AVFoundation
import UIKit

/// R11: Deduplication — detect near-identical clips and prompt user to keep one
final class DeduplicationService: ObservableObject {
    static let shared = DeduplicationService()

    @Published private(set) var isAnalyzing = false
    @Published private(set) var duplicates: [DuplicateGroup] = []

    struct DuplicateGroup: Identifiable {
        let id: UUID
        let entries: [VideoEntry]
        let similarity: Double // 0-1, higher = more similar
        let sharedWindow: ClosedRange<Double> // shared 30s window that triggered match

        init(entries: [VideoEntry], similarity: Double, sharedWindow: ClosedRange<Double>) {
            self.id = UUID()
            self.entries = entries
            self.similarity = similarity
            self.sharedWindow = sharedWindow
        }

        var suggested: VideoEntry? {
            // Prefer longer, higher quality entries
            entries.max(by: { $0.duration < $1.duration })
        }
    }

    private let comparisonThreshold: Double = 0.85 // 85% similarity = duplicate
    private let windowSize: Double = 30.0 // Compare 30-second windows

    private init() {}

    /// Find duplicate entries among all entries
    @MainActor
    func findDuplicates(entries: [VideoEntry]) async {
        guard !isAnalyzing else { return }
        isAnalyzing = true
        duplicates = []

        var groups: [DuplicateGroup] = []
        var processed: Set<UUID> = []

        for i in 0..<entries.count {
            guard !processed.contains(entries[i].id) else { continue }

            var groupEntries: [VideoEntry] = [entries[i]]

            for j in (i + 1)..<entries.count {
                guard !processed.contains(entries[j].id) else { continue }

                if let window = entries[i].overlaps(windowSize: windowSize, with: entries[j]) {
                    let similarity = await computeSimilarity(entries[i], entries[j], window: window)

                    if similarity >= comparisonThreshold {
                        groupEntries.append(entries[j])
                        processed.insert(entries[j].id)
                    }
                }
            }

            if groupEntries.count > 1 {
                // Compute average similarity within group
                let avgSimilarity = await computeGroupSimilarity(groupEntries, windowSize: windowSize)

                groups.append(DuplicateGroup(
                    entries: groupEntries,
                    similarity: avgSimilarity,
                    sharedWindow: 0...windowSize
                ))
            }

            processed.insert(entries[i].id)
        }

        duplicates = groups
        isAnalyzing = false
    }

    /// Delete a specific entry and remove from duplicate group
    @MainActor
    func removeEntry(_ entry: VideoEntry) async {
        VideoStore.shared.deleteEntry(entry)
        // Remove from duplicates — rebuild array since DuplicateGroup is a struct
        var newDuplicates: [DuplicateGroup] = []
        for group in duplicates {
            if group.entries.contains(where: { $0.id == entry.id }) {
                let remaining = group.entries.filter { $0.id != entry.id }
                if remaining.count >= 2 {
                    newDuplicates.append(DuplicateGroup(entries: remaining, similarity: group.similarity, sharedWindow: group.sharedWindow))
                }
                // If < 2 entries remain, drop the group entirely
            } else {
                newDuplicates.append(group)
            }
        }
        duplicates = newDuplicates
    }

    // MARK: - Private

    private func computeSimilarity(_ a: VideoEntry, _ b: VideoEntry, window: ClosedRange<Double>) async -> Double {
        // Extract frames at the same timestamps and compare
        let frameCount = 6
        let interval = (window.upperBound - window.lowerBound) / Double(frameCount)

        var totalDiff: Double = 0

        for i in 0..<frameCount {
            let time = window.lowerBound + interval * Double(i)

            async let frameA = extractFrame(at: time, from: a.videoURL)
            async let frameB = extractFrame(at: time, from: b.videoURL)

            guard let imgA = await frameA, let imgB = await frameB else { continue }

            let diff = imageDifference(imgA, imgB)
            totalDiff += diff
        }

        let avgDiff = totalDiff / Double(frameCount)
        return 1.0 - avgDiff // Convert difference to similarity
    }

    private func computeGroupSimilarity(_ entries: [VideoEntry], windowSize: Double) async -> Double {
        guard entries.count > 1 else { return 1.0 }

        var totalSimilarity: Double = 0
        var comparisons = 0

        for i in 0..<entries.count {
            for j in (i + 1)..<entries.count {
                if let window = entries[i].overlaps(windowSize: windowSize, with: entries[j]) {
                    let sim = await computeSimilarity(entries[i], entries[j], window: window)
                    totalSimilarity += sim
                    comparisons += 1
                }
            }
        }

        return comparisons > 0 ? totalSimilarity / Double(comparisons) : 0
    }

    private func extractFrame(at time: Double, from url: URL) async -> UIImage? {
        do {
            let asset = AVURLAsset(url: url)
            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true
            generator.requestedTimeToleranceBefore = CMTime(seconds: 0.1, preferredTimescale: 600)
            generator.requestedTimeToleranceAfter = CMTime(seconds: 0.1, preferredTimescale: 600)

            let cmTime = CMTime(seconds: time, preferredTimescale: 600)
            let (cgImage, _) = try await generator.image(at: cmTime)
            return UIImage(cgImage: cgImage)
        } catch {
            return nil
        }
    }

    private func imageDifference(_ a: UIImage, _ b: UIImage) -> Double {
        guard let cgA = a.cgImage, let cgB = b.cgImage else { return 1.0 }

        let size = CGSize(width: 30, height: 30) // Small for performance
        guard let ctxA = createPixelContext(cgImage: cgA, size: size),
              let ctxB = createPixelContext(cgImage: cgB, size: size) else { return 1.0 }

        let width = Int(size.width)
        let height = Int(size.height)
        let bytesPerRow = width * 4

        var dataA = [UInt8](repeating: 0, count: bytesPerRow * height)
        var dataB = [UInt8](repeating: 0, count: bytesPerRow * height)

        guard let rawDataA = ctxA.data else { return 1.0 }
        guard let rawDataB = ctxB.data else { return 1.0 }

        let ptrA = rawDataA.bindMemory(to: UInt8.self, capacity: bytesPerRow * height)
        let ptrB = rawDataB.bindMemory(to: UInt8.self, capacity: bytesPerRow * height)

        for i in 0..<(bytesPerRow * height) {
            dataA[i] = ptrA[i]
            dataB[i] = ptrB[i]
        }

        var totalDiff: Double = 0
        let count = width * height

        for i in 0..<count {
            let offset = i * 4
            let rDiff = abs(Int(dataA[offset]) - Int(dataB[offset]))
            let gDiff = abs(Int(dataA[offset + 1]) - Int(dataB[offset + 1]))
            let bDiff = abs(Int(dataA[offset + 2]) - Int(dataB[offset + 2]))
            totalDiff += Double(rDiff + gDiff + bDiff) / (255.0 * 3.0)
        }

        return totalDiff / Double(count)
    }

    private func createPixelContext(cgImage: CGImage, size: CGSize) -> CGContext? {
        let width = Int(size.width)
        let height = Int(size.height)
        let colorSpace = CGColorSpaceCreateDeviceRGB()

        return CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )?.then { ctx in
            ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        }
    }
}

// MARK: - VideoEntry Extension

extension VideoEntry {
    /// Check if this entry's time window overlaps with another entry
    func overlaps(windowSize: Double, with other: VideoEntry) -> ClosedRange<Double>? {
        // Check if the start times are within windowSize of each other
        let timeDiff = abs(date.timeIntervalSince(other.date))

        if timeDiff <= windowSize {
            let start = min(date.timeIntervalSince1970, other.date.timeIntervalSince1970)
            return start...(start + windowSize)
        }

        return nil
    }
}

// MARK: - CGContext then

extension CGContext {
    @discardableResult
    func then(_ body: (Self) -> Void) -> Self {
        body(self)
        return self
    }
}
