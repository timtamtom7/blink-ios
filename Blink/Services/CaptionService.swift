import Foundation
import AVFoundation
import Speech
import Combine

/// R11: AI Captioning — on-device speech-to-text with searchable captions
final class CaptionService: ObservableObject {
    static let shared = CaptionService()

    @Published private(set) var isTranscribing = false
    @Published private(set) var captions: [UUID: [CaptionSegment]] = [:] // entryId -> segments

    struct CaptionSegment: Identifiable, Codable {
        let id: UUID
        let startTime: Double
        let endTime: Double
        let text: String
        let confidence: Double

        var duration: Double { endTime - startTime }

        func matches(query: String) -> Bool {
            text.localizedCaseInsensitiveContains(query)
        }
    }

    private let sfSpeechRecognizer: SFSpeechRecognizer?
    private let recognitionQueue = DispatchQueue(label: "com.blink.captions", qos: .utility)

    private init() {
        // Initialize with device locale
        sfSpeechRecognizer = SFSpeechRecognizer(locale: Locale.current)
    }

    /// Request speech recognition authorization
    func requestAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }

    /// Transcribe a video entry's audio
    func transcribeEntry(_ entry: VideoEntry) async -> [CaptionSegment] {
        guard let recognizer = sfSpeechRecognizer, recognizer.isAvailable else {
            return []
        }

        let videoURL = entry.videoURL
        guard FileManager.default.fileExists(atPath: videoURL.path) else { return [] }

        // Check authorization
        let authorized = await requestAuthorization()
        guard authorized else { return [] }

        do {
            let asset = AVURLAsset(url: videoURL)
            let duration = try await asset.load(.duration).seconds

            // Extract audio to temporary file
            let tempAudioURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension("m4a")

            // Export audio track
            guard let exportSession = AVAssetExportSession(
                asset: asset,
                presetName: AVAssetExportPresetAppleM4A
            ) else { return [] }

            try? FileManager.default.removeItem(at: tempAudioURL)
            exportSession.outputURL = tempAudioURL
            exportSession.outputFileType = .m4a

            await exportSession.export()

            guard exportSession.status == .completed else { return [] }

            // Perform speech recognition
            let request = SFSpeechURLRecognitionRequest(url: tempAudioURL)
            request.shouldReportPartialResults = false
            request.addsPunctuation = true

            return await withCheckedContinuation { continuation in
                recognizer.recognitionTask(with: request) { result, error in
                    if let error = error {
                        print("Speech recognition error: \(error)")
                        continuation.resume(returning: [])
                        return
                    }

                    guard let result = result, result.isFinal else { return }

                    let segments = result.bestTranscription.segments.enumerated().map { index, segment in
                        // Estimate end time based on duration of segment
                        let avgSegmentDuration = duration / Double(result.bestTranscription.segments.count)
                        let startTime = avgSegmentDuration * Double(index)
                        let endTime = startTime + avgSegmentDuration

                        return CaptionSegment(
                            id: UUID(),
                            startTime: startTime,
                            endTime: endTime,
                            text: segment.substring,
                            confidence: Double(segment.confidence)
                        )
                    }

                    // Clean up temp file
                    try? FileManager.default.removeItem(at: tempAudioURL)

                    continuation.resume(returning: segments)
                }
            }
        } catch {
            print("Transcription failed for \(entry.id): \(error)")
            return []
        }
    }

    /// Transcribe all entries
    @MainActor
    func transcribeAll(entries: [VideoEntry]) async {
        guard !isTranscribing else { return }
        isTranscribing = true

        for entry in entries {
            guard !captions.keys.contains(entry.id) else { continue }

            let segments = await transcribeEntry(entry)
            if !segments.isEmpty {
                captions[entry.id] = segments
            }
        }

        isTranscribing = false
    }

    /// Get captions for a specific entry
    func captions(for entry: VideoEntry) -> [CaptionSegment] {
        captions[entry.id] ?? []
    }

    /// Search captions across all entries
    func search(query: String) -> [SearchResult] {
        var results: [SearchResult] = []

        for (entryId, segments) in captions {
            for segment in segments where segment.matches(query: query) {
                results.append(SearchResult(
                    entryId: entryId,
                    segment: segment
                ))
            }
        }

        return results.sorted { $0.segment.startTime < $1.segment.startTime }
    }

    struct SearchResult: Identifiable {
        let id = UUID()
        let entryId: UUID
        let segment: CaptionSegment
    }

    /// Generate a one-line description for an entry based on captions + analysis
    func generateDescription(for entry: VideoEntry, scenes: [DeepAnalysisService.SceneClassification]?) -> String {
        guard let segments = captions[entry.id], !segments.isEmpty else {
            // Fall back to scene-based description
            if let firstScene = scenes?.first {
                return "\(firstScene.type.rawValue) moment"
            }
            return "A moment"
        }

        // Concatenate first few segments for a short description
        let text = segments.prefix(5).map { $0.text }.joined(separator: " ")
        let trimmed = text.prefix(50)

        if text.count > 50 {
            return String(trimmed) + "..."
        }
        return text.isEmpty ? "A moment" : text
    }

    /// Export captions for an entry as plain text
    func exportText(for entry: VideoEntry) -> String {
        guard let segments = captions[entry.id] else { return "" }
        return segments.map { "[\(formatTime($0.startTime))] \($0.text)" }.joined(separator: "\n")
    }

    private func formatTime(_ seconds: Double) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}
