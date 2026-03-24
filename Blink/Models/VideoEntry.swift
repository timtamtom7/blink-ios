import Foundation

struct VideoEntry: Identifiable, Codable, Equatable {
    let id: UUID
    let date: Date
    let filename: String
    let duration: TimeInterval
    var thumbnailFilename: String?

    init(id: UUID = UUID(), date: Date, filename: String, duration: TimeInterval, thumbnailFilename: String? = nil) {
        self.id = id
        self.date = date
        self.filename = filename
        self.duration = duration
        self.thumbnailFilename = thumbnailFilename
    }

    var videoURL: URL {
        VideoStore.shared.videosDirectory.appendingPathComponent(filename)
    }

    var thumbnailURL: URL? {
        guard let thumb = thumbnailFilename else { return nil }
        return VideoStore.shared.videosDirectory.appendingPathComponent(thumb)
    }

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, h:mm a"
        return formatter.string(from: date)
    }

    var dayOfYear: Int {
        Calendar.current.ordinality(of: .day, in: .year, for: date) ?? 0
    }
}
