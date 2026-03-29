import Foundation
import AVFoundation

struct VideoEntry: Identifiable, Equatable {
    let id: String
    let clipURL: URL
    let recordedAt: Date
    let duration: CMTime

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, h:mm a"
        return formatter.string(from: recordedAt)
    }

    var formattedDuration: String {
        let seconds = CMTimeGetSeconds(duration)
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }

    static func == (lhs: VideoEntry, rhs: VideoEntry) -> Bool {
        lhs.id == rhs.id
    }
}

// Custom Codable conformance for VideoEntry
extension VideoEntry: Codable {
    enum CodingKeys: String, CodingKey {
        case id, clipURL, recordedAt, durationSeconds
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        clipURL = try container.decode(URL.self, forKey: .clipURL)
        recordedAt = try container.decode(Date.self, forKey: .recordedAt)
        let seconds = try container.decode(Double.self, forKey: .durationSeconds)
        duration = CMTime(seconds: seconds, preferredTimescale: 600)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(clipURL, forKey: .clipURL)
        try container.encode(recordedAt, forKey: .recordedAt)
        try container.encode(CMTimeGetSeconds(duration), forKey: .durationSeconds)
    }
}

extension VideoEntry {
    // For preview/testing
    static let preview = VideoEntry(
        id: UUID().uuidString,
        clipURL: URL(fileURLWithPath: "/tmp/preview.mov"),
        recordedAt: Date(),
        duration: CMTime(seconds: 15, preferredTimescale: 600)
    )
}
