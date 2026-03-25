import Foundation
import AVFoundation
import Vision
import UIKit

/// Deep AI analysis service for R7: deeper scene understanding, emotion detection, categorization
final class DeepAnalysisService: ObservableObject {
    static let shared = DeepAnalysisService()

    @Published private(set) var isAnalyzing = false
    @Published private(set) var analysisProgress: Double = 0
    @Published private(set) var analyzedEntries: [ID: EntryAnalysis] = [:]
    @Published private(set) var insights: [LifeInsight] = []

    struct EntryAnalysis: Codable, Identifiable {
        let id: UUID
        let entryId: UUID
        let scenes: [SceneClassification]
        let emotions: [EmotionMoment]
        let tags: [String]
        let quality: Double
        let brightness: Double
        let hasFaces: Bool
        let dominantColors: [String]
        let analyzedAt: Date
    }

    struct SceneClassification: Codable {
        let type: SceneType
        let confidence: Double
    }

    enum SceneType: String, Codable, CaseIterable {
        case outdoor = "Outdoor"
        case indoor = "Indoor"
        case travel = "Travel"
        case family = "Family"
        case friends = "Friends"
        case food = "Food & Drink"
        case nature = "Nature"
        case urban = "Urban"
        case celebration = "Celebration"
        case quiet = "Quiet Moment"
        case activity = "Activity"
        case unknown = "Other"
    }

    struct EmotionMoment: Codable {
        let timestamp: Double
        let emotion: Emotion
        let intensity: Double
    }

    enum Emotion: String, Codable {
        case happy = "Happy"
        case sad = "Sad"
        case excited = "Excited"
        case calm = "Calm"
        case surprised = "Surprised"
        case neutral = "Neutral"
    }

    struct LifeInsight: Identifiable {
        let id = UUID()
        let icon: String
        let title: String
        let description: String
        let type: InsightType
    }

    enum InsightType {
        case pattern
        case milestone
        case trend
        case discovery
    }

    typealias ID = UUID

    private let fileManager = FileManager.default
    private let analysisQueue = DispatchQueue(label: "com.blink.deepanalysis", qos: .utility)

    private init() {}

    // MARK: - Analyze All

    @MainActor
    func analyzeAll(entries: [VideoEntry]) async {
        guard !isAnalyzing else { return }
        isAnalyzing = true
        analysisProgress = 0

        let unanalyzed = entries.filter { !analyzedEntries.keys.contains($0.id) }
        let total = Double(unanalyzed.count)

        for (index, entry) in unanalyzed.enumerated() {
            let analysis = await analyzeEntry(entry)
            if let analysis = analysis {
                analyzedEntries[entry.id] = analysis
            }
            analysisProgress = Double(index + 1) / total
        }

        generateInsights(from: entries)
        isAnalyzing = false
        analysisProgress = 0
    }

    // MARK: - Analyze Single Entry

    func analyzeEntry(_ entry: VideoEntry) async -> EntryAnalysis? {
        let videoURL = entry.videoURL
        guard fileManager.fileExists(atPath: videoURL.path) else { return nil }

        do {
            let asset = AVURLAsset(url: videoURL)
            let duration = try await asset.load(.duration).seconds

            // Generate thumbnail frames for analysis
            let frames = try await extractFrames(from: videoURL, count: 5)

            var scenes: [SceneClassification] = []
            var hasFaces = false
            var dominantColors: [String] = []
            var totalBrightness: Double = 0
            var allTags: Set<String> = []

            for frame in frames {
                // Scene classification
                if let scene = try? await classifyScene(frame) {
                    scenes.append(scene)
                }

                // Face detection
                if try await detectFaces(in: frame) {
                    hasFaces = true
                }

                // Color analysis
                let colors = extractDominantColors(from: frame)
                dominantColors.append(contentsOf: colors)

                // Brightness
                totalBrightness += calculateBrightness(from: frame)

                // Tags
                let tags = await generateTags(for: frame, scene: scenes.last?.type)
                allTags.formUnion(tags)
            }

            let avgBrightness = frames.isEmpty ? 0.5 : totalBrightness / Double(frames.count)
            let quality = calculateQuality(brightness: avgBrightness, hasFaces: hasFaces, sceneCount: scenes.count)

            // Emotion analysis (simplified based on scene types)
            let emotions = generateEmotionMoments(duration: duration, scenes: scenes)

            return EntryAnalysis(
                id: UUID(),
                entryId: entry.id,
                scenes: scenes,
                emotions: emotions,
                tags: Array(allTags),
                quality: quality,
                brightness: avgBrightness,
                hasFaces: hasFaces,
                dominantColors: Array(Set(dominantColors)).prefix(5).map { $0 },
                analyzedAt: Date()
            )
        } catch {
            print("Analysis failed for \(entry.id): \(error)")
            return nil
        }
    }

    // MARK: - Frame Extraction

    private func extractFrames(from url: URL, count: Int) async throws -> [UIImage] {
        let asset = AVURLAsset(url: url)
        let duration = try await asset.load(.duration).seconds
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero

        var frames: [UIImage] = []
        let interval = duration / Double(count + 1)

        for i in 1...count {
            let time = CMTime(seconds: interval * Double(i), preferredTimescale: 600)
            do {
                let (cgImage, _) = try await generator.image(at: time)
                frames.append(UIImage(cgImage: cgImage))
            } catch {
                continue
            }
        }

        return frames
    }

    // MARK: - Vision Analysis

    private func classifyScene(_ image: UIImage) async throws -> SceneClassification {
        guard let cgImage = image.cgImage else {
            return SceneClassification(type: .unknown, confidence: 0)
        }

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNClassifyImageRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let observations = request.results as? [VNClassificationObservation] else {
                    continuation.resume(returning: SceneClassification(type: .unknown, confidence: 0))
                    return
                }

                // Map Vision labels to our scene types
                let topLabels = observations.prefix(10).map { ($0.identifier.lowercased(), $0.confidence) }

                let sceneType = self.mapToSceneType(labels: topLabels)
                let confidence = observations.first?.confidence ?? 0

                continuation.resume(returning: SceneClassification(type: sceneType, confidence: Double(confidence)))
            }

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            try? handler.perform([request])
        }
    }

    private func mapToSceneType(labels: [(String, Float)]) -> SceneType {
        let labelSet = Set(labels.map { $0.0 })

        if labelSet.contains(where: { $0.contains("outdoor") || $0.contains("landscape") }) {
            return .outdoor
        } else if labelSet.contains(where: { $0.contains("indoor") || $0.contains("room") || $0.contains("home") }) {
            return .indoor
        } else if labelSet.contains(where: { $0.contains("travel") || $0.contains("beach") || $0.contains("mountain") }) {
            return .travel
        } else if labelSet.contains(where: { $0.contains("food") || $0.contains("restaurant") || $0.contains("meal") }) {
            return .food
        } else if labelSet.contains(where: { $0.contains("nature") || $0.contains("forest") || $0.contains("park") }) {
            return .nature
        } else if labelSet.contains(where: { $0.contains("celebration") || $0.contains("party") || $0.contains("wedding") }) {
            return .celebration
        } else if labelSet.contains(where: { $0.contains("city") || $0.contains("urban") || $0.contains("street") }) {
            return .urban
        } else if labelSet.contains(where: { $0.contains("people") || $0.contains("group") }) {
            return .friends
        }

        return .unknown
    }

    private func detectFaces(in image: UIImage) async throws -> Bool {
        guard let cgImage = image.cgImage else { return false }

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNDetectFaceRectanglesRequest { request, error in
                if error != nil {
                    continuation.resume(returning: false)
                    return
                }
                let count = request.results?.count ?? 0
                continuation.resume(returning: count > 0)
            }

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            try? handler.perform([request])
        }
    }

    // MARK: - Image Analysis

    private func extractDominantColors(from image: UIImage) -> [String] {
        guard let cgImage = image.cgImage else { return [] }

        let width = 10
        let height = 10
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
        ) else { return [] }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        var colorCounts: [String: Int] = [:]

        for y in 0..<height {
            for x in 0..<width {
                let offset = (y * width + x) * 4
                let r = rawData[offset]
                let g = rawData[offset + 1]
                let b = rawData[offset + 2]

                let colorName = colorName(r: r, g: g, b: b)
                colorCounts[colorName, default: 0] += 1
            }
        }

        return colorCounts.sorted { $0.value > $1.value }.prefix(3).map { $0.key }
    }

    private func colorName(r: UInt8, g: UInt8, b: UInt8) -> String {
        if r > 200 && g > 200 && b > 200 { return "white" }
        if r < 50 && g < 50 && b < 50 { return "black" }
        if r > 150 && g < 100 && b < 100 { return "red" }
        if r > 100 && g > 150 && b < 100 { return "green" }
        if r < 100 && g < 100 && b > 150 { return "blue" }
        if r > 200 && g > 200 && b < 100 { return "yellow" }
        if r > 150 && g > 100 && b > 100 { return "warm" }
        if r < 100 && g > 100 && b > 100 { return "cool" }
        return "neutral"
    }

    private func calculateBrightness(from image: UIImage) -> Double {
        guard let cgImage = image.cgImage else { return 0.5 }

        let width = 10
        let height = 10
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
        ) else { return 0.5 }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        var totalBrightness: Double = 0

        for y in 0..<height {
            for x in 0..<width {
                let offset = (y * width + x) * 4
                let r = Double(rawData[offset]) / 255.0
                let g = Double(rawData[offset + 1]) / 255.0
                let b = Double(rawData[offset + 2]) / 255.0
                totalBrightness += (r + g + b) / 3.0
            }
        }

        return totalBrightness / Double(width * height)
    }

    private func calculateQuality(brightness: Double, hasFaces: Bool, sceneCount: Int) -> Double {
        var quality: Double = 0.5

        // Good brightness range
        if brightness > 0.3 && brightness < 0.7 {
            quality += 0.2
        }

        // Faces add quality
        if hasFaces {
            quality += 0.15
        }

        // Scene variety
        if sceneCount > 2 {
            quality += 0.1
        }

        return min(1.0, quality)
    }

    private func generateTags(for image: UIImage, scene: SceneType?) async -> [String] {
        var tags: [String] = []

        if let scene = scene {
            tags.append(scene.rawValue.lowercased())
        }

        // Add time of day based on analysis (simplified)
        tags.append("moment")

        return tags
    }

    private func generateEmotionMoments(duration: Double, scenes: [SceneClassification]) -> [EmotionMoment] {
        guard !scenes.isEmpty else {
            return [EmotionMoment(timestamp: duration / 2, emotion: .neutral, intensity: 0.5)]
        }

        return scenes.enumerated().compactMap { index, scene in
            let timestamp = (duration / Double(scenes.count)) * Double(index + 1)
            let emotion = mapSceneToEmotion(scene.type)
            return EmotionMoment(timestamp: timestamp, emotion: emotion, intensity: scene.confidence)
        }
    }

    private func mapSceneToEmotion(_ scene: SceneType) -> Emotion {
        switch scene {
        case .celebration, .friends: return .happy
        case .nature, .quiet: return .calm
        case .travel: return .excited
        case .family: return .happy
        default: return .neutral
        }
    }

    // MARK: - Insights Generation

    private func generateInsights(from entries: [VideoEntry]) {
        var newInsights: [LifeInsight] = []

        // Analyze patterns
        let sceneCounts = countScenes()
        if let topScene = sceneCounts.max(by: { $0.value < $1.value }), topScene.value > 3 {
            newInsights.append(LifeInsight(
                icon: "sparkles",
                title: "\(topScene.key.rawValue) Lover",
                description: "You capture a lot of \(topScene.key.rawValue.lowercased()) moments. Keep it up!",
                type: .pattern
            ))
        }

        // Face analysis
        let entriesWithFaces = analyzedEntries.values.filter { $0.hasFaces }.count
        if entriesWithFaces > 5 {
            newInsights.append(LifeInsight(
                icon: "person.2.fill",
                title: "People Person",
                description: "Most of your clips have people in them. Your memories are about connections.",
                type: .pattern
            ))
        }

        // Quality insights
        let avgQuality = analyzedEntries.values.map { $0.quality }.reduce(0, +) / Double(max(1, analyzedEntries.count))
        if avgQuality > 0.7 {
            newInsights.append(LifeInsight(
                icon: "star.fill",
                title: "Quality Moments",
                description: "Your clips have excellent lighting and composition!",
                type: .discovery
            ))
        }

        // Milestone
        if entries.count >= 50 {
            newInsights.append(LifeInsight(
                icon: "trophy.fill",
                title: "50 Clips!",
                description: "You've captured 50 moments. That's an amazing collection of memories!",
                type: .milestone
            ))
        }

        insights = newInsights
    }

    private func countScenes() -> [SceneType: Int] {
        var counts: [SceneType: Int] = [:]
        for analysis in analyzedEntries.values {
            for scene in analysis.scenes {
                counts[scene.type, default: 0] += 1
            }
        }
        return counts
    }

    // MARK: - Query Methods

    func analysis(for entry: VideoEntry) -> EntryAnalysis? {
        analyzedEntries[entry.id]
    }

    func entriesForScene(_ scene: SceneType) -> [UUID] {
        analyzedEntries.filter { $0.value.scenes.contains { $0.type == scene } }.map { $0.key }
    }

    func entriesWithFaces() -> [UUID] {
        analyzedEntries.filter { $0.value.hasFaces }.map { $0.key }
    }
}
