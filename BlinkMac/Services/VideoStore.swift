import Foundation
import Combine

@MainActor
class VideoStore: ObservableObject {
    static let shared = VideoStore()

    @Published var entries: [VideoEntry] = []

    private let entriesKey = "BlinkVideoEntries"
    private let userDefaults = UserDefaults.standard

    private init() {
        loadEntries()
    }

    func addEntry(_ entry: VideoEntry) {
        entries.insert(entry, at: 0)
        saveEntries()
    }

    func deleteEntry(_ entry: VideoEntry) {
        entries.removeAll { $0.id == entry.id }
        saveEntries()
    }

    func entriesForDate(_ date: Date) -> [VideoEntry] {
        let calendar = Calendar.current
        return entries.filter { calendar.isDate($0.recordedAt, inSameDayAs: date) }
    }

    func entriesForMonth(_ date: Date) -> [VideoEntry] {
        let calendar = Calendar.current
        return entries.filter {
            calendar.component(.month, from: $0.recordedAt) == calendar.component(.month, from: date) &&
            calendar.component(.year, from: $0.recordedAt) == calendar.component(.year, from: date)
        }
    }

    func clipCountThisYear() -> Int {
        let calendar = Calendar.current
        let year = calendar.component(.year, from: Date())
        return entries.filter {
            calendar.component(.year, from: $0.recordedAt) == year
        }.count
    }

    private func loadEntries() {
        guard let data = userDefaults.data(forKey: entriesKey),
              let decoded = try? JSONDecoder().decode([VideoEntry].self, from: data) else {
            return
        }
        entries = decoded
    }

    private func saveEntries() {
        guard let encoded = try? JSONEncoder().encode(entries) else { return }
        userDefaults.set(encoded, forKey: entriesKey)
    }
}
