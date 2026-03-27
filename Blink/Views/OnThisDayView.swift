import SwiftUI
import AVKit

// MARK: - On This Day View

struct OnThisDayView: View {
    let entries: [VideoEntry]
    let onDismiss: () -> Void
    @State private var selectedEntry: VideoEntry?
    @State private var selectedTab: OnThisDayTab = .sameDate

    enum OnThisDayTab {
        case sameDate
        case similarMood
    }

    var body: some View {
        ZStack {
            Color(hex: "0a0a0a")
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                header
                    .padding(.top, 8)

                // Tab selector
                tabSelector

                if entries.isEmpty && similarMoodEntries.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        VStack(spacing: 20) {
                            if selectedTab == .sameDate {
                                if groupedByYear.isEmpty {
                                    noSameDateState
                                } else {
                                    ForEach(groupedByYear, id: \.year) { group in
                                        YearSection(year: group.year, entries: group.entries) { entry in
                                            selectedEntry = entry
                                        }
                                    }
                                }
                            } else {
                                // Similar Mood tab
                                if similarMoodEntries.isEmpty {
                                    noSimilarMoodState
                                } else {
                                    ForEach(similarMoodGroups, id: \.sceneType) { group in
                                        SimilarMoodSection(sceneType: group.sceneType, entries: group.entries) { entry in
                                            selectedEntry = entry
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                        .padding(.bottom, 40)
                    }
                }
            }
        }
        .fullScreenCover(item: $selectedEntry) { entry in
            PlaybackView(entry: entry, onDelete: {}, onTrim: nil)
        }
    }

    private var tabSelector: some View {
        HStack(spacing: 0) {
            tabButton("Same Date", tab: .sameDate)
            tabButton("Similar Mood", tab: .similarMood)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private func tabButton(_ title: String, tab: OnThisDayTab) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedTab = tab
            }
        } label: {
            VStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: selectedTab == tab ? .semibold : .medium))
                    .foregroundColor(selectedTab == tab ? Color(hex: "f5f5f5") : Color(hex: "8a8a8a"))

                Rectangle()
                    .fill(selectedTab == tab ? Color(hex: "ff3b30") : Color.clear)
                    .frame(height: 2)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var header: some View {
        HStack {
            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color(hex: "8a8a8a"))
                    .frame(width: 44, height: 44)
            }

            Spacer()

            VStack(spacing: 2) {
                Text("On This Day")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(Color(hex: "f5f5f5"))

                Text(formattedDate)
                    .font(.system(size: 13))
                    .foregroundColor(Color(hex: "8a8a8a"))
            }

            Spacer()

            Color.clear
                .frame(width: 44, height: 44)
        }
        .padding(.horizontal, 8)
    }

    private var emptyState: some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                Circle()
                    .stroke(Color(hex: "2a2a2a"), lineWidth: 1)
                    .frame(width: 100, height: 100)

                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 36))
                    .foregroundColor(Color(hex: "333333"))
            }

            VStack(spacing: 8) {
                Text("No memories from this day")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(Color(hex: "f5f5f5"))

                Text("Clips from today in previous years will appear here.")
                    .font(.system(size: 14))
                    .foregroundColor(Color(hex: "8a8a8a"))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer()
        }
    }

    private var noSameDateState: some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar")
                .font(.system(size: 40))
                .foregroundColor(Color(hex: "333333"))

            Text("No clips on this date in past years")
                .font(.system(size: 15))
                .foregroundColor(Color(hex: "8a8a8a"))
        }
        .padding(.vertical, 40)
    }

    private var noSimilarMoodState: some View {
        VStack(spacing: 16) {
            Image(systemName: "sparkles")
                .font(.system(size: 40))
                .foregroundColor(Color(hex: "333333"))

            Text("Analyze clips to discover similar moments")
                .font(.system(size: 15))
                .foregroundColor(Color(hex: "8a8a8a"))

            Text("Go to AI Highlights to analyze your clips")
                .font(.system(size: 13))
                .foregroundColor(Color(hex: "555555"))
        }
        .padding(.vertical, 40)
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d"
        return formatter.string(from: Date())
    }

    private var groupedByYear: [YearGroup] {
        let calendar = Calendar.current
        let today = Date()
        let month = calendar.component(.month, from: today)
        let day = calendar.component(.day, from: today)

        var yearGroups: [Int: [VideoEntry]] = [:]

        for entry in entries {
            let entryMonth = calendar.component(.month, from: entry.date)
            let entryDay = calendar.component(.day, from: entry.date)
            if entryMonth == month && entryDay == day {
                let year = calendar.component(.year, from: entry.date)
                yearGroups[year, default: []].append(entry)
            }
        }

        return yearGroups
            .map { YearGroup(year: $0.key, entries: $0.value.sorted { $0.date < $1.date }) }
            .sorted { $0.year > $1.year }
    }

    // R11: Similar mood entries — group entries by AI-detected scene type
    private var similarMoodEntries: [VideoEntry] {
        let analysis = DeepAnalysisService.shared
        // Return entries that have been analyzed with at least one non-unknown scene
        return entries.filter { entry in
            guard let entryAnalysis = analysis.analysis(for: entry) else { return false }
            return entryAnalysis.scenes.contains { $0.type != .unknown }
        }
    }

    // Group similar mood entries by scene type
    private var similarMoodGroups: [SimilarMoodGroup] {
        let analysis = DeepAnalysisService.shared
        var groups: [DeepAnalysisService.SceneType: [VideoEntry]] = [:]

        for entry in similarMoodEntries {
            guard let entryAnalysis = analysis.analysis(for: entry),
                  let firstScene = entryAnalysis.scenes.first(where: { $0.type != .unknown }) else {
                continue
            }
            groups[firstScene.type, default: []].append(entry)
        }

        return groups
            .filter { $0.value.count >= 2 } // Only show groups with 2+ entries
            .map { SimilarMoodGroup(sceneType: $0.key, entries: $0.value.sorted { $0.date > $1.date }) }
            .sorted { $0.entries.count > $1.entries.count }
    }
}

struct SimilarMoodGroup {
    let sceneType: DeepAnalysisService.SceneType
    let entries: [VideoEntry]
}

struct SimilarMoodSection: View {
    let sceneType: DeepAnalysisService.SceneType
    let entries: [VideoEntry]
    let onTapEntry: (VideoEntry) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: sceneIcon)
                    .font(.system(size: 14))
                    .foregroundColor(Color(hex: "ff3b30"))

                Text("\(sceneType.rawValue) Moments")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(Color(hex: "f5f5f5"))

                Spacer()

                Text("\(entries.count) clips")
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: "8a8a8a"))
            }

            // Show first 3 as preview cards
            ForEach(entries.prefix(3)) { entry in
                OnThisDayCard(entry: entry)
                    .onTapGesture {
                        onTapEntry(entry)
                    }
            }

            if entries.count > 3 {
                Text("+ \(entries.count - 3) more")
                    .font(.system(size: 13))
                    .foregroundColor(Color(hex: "ff3b30"))
                    .padding(.top, 4)
            }
        }
        .padding(12)
        .background(Color(hex: "141414"))
        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadiusMedium))
    }

    private var sceneIcon: String {
        switch sceneType {
        case .outdoor: return "sun.max"
        case .indoor: return "house"
        case .travel: return "airplane"
        case .family: return "figure.2"
        case .friends: return "person.3"
        case .food: return "fork.knife"
        case .nature: return "leaf"
        case .urban: return "building.2"
        case .celebration: return "party.popper"
        case .quiet: return "moon"
        case .activity: return "figure.run"
        case .unknown: return "sparkles"
        }
    }
}

struct YearGroup {
    let year: Int
    let entries: [VideoEntry]
}

struct YearSection: View {
    let year: Int
    let entries: [VideoEntry]
    let onTapEntry: (VideoEntry) -> Void

    private var yearsAgo: Int {
        Calendar.current.component(.year, from: Date()) - year
    }

    private var yearsAgoText: String {
        if yearsAgo == 1 { return "1 year ago" }
        return "\(yearsAgo) years ago"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(String(year))
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(Color(hex: "f5f5f5"))

                Text("·")
                    .foregroundColor(Color(hex: "8a8a8a"))

                Text(yearsAgoText)
                    .font(.system(size: 13))
                    .foregroundColor(Color(hex: "ff3b30"))

                Spacer()

                Text("\(entries.count) clip\(entries.count == 1 ? "" : "s")")
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: "8a8a8a"))
            }

            // Clips in this year
            ForEach(entries) { entry in
                OnThisDayCard(entry: entry)
                    .onTapGesture {
                        onTapEntry(entry)
                    }
            }
        }
        .padding(12)
        .background(Color(hex: "141414"))
        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadiusMedium))
    }
}

struct OnThisDayCard: View {
    let entry: VideoEntry
    @State private var player: AVPlayer?

    var body: some View {
        HStack(spacing: 12) {
            // Thumbnail
            ZStack {
                if let thumbURL = entry.thumbnailURL {
                    AsyncImage(url: thumbURL) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Color(hex: "1e1e1e")
                    }
                } else {
                    Color(hex: "1e1e1e")
                }
            }
            .frame(width: 72, height: 48)
            .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadiusSmall))

            // Info
            VStack(alignment: .leading, spacing: 4) {
                if let title = entry.title, !title.isEmpty {
                    Text(title)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color(hex: "f5f5f5"))
                        .lineLimit(1)
                } else {
                    Text(entry.defaultTitle)
                        .font(.system(size: 13))
                        .foregroundColor(Color(hex: "f5f5f5"))
                        .lineLimit(1)
                }

                Text(formatTime(entry.date))
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(Color(hex: "8a8a8a"))

                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.system(size: 11))
                    Text(formatDuration(entry.duration))
                        .font(.system(size: 11))
                }
                .foregroundColor(Color(hex: "666666"))
            }

            Spacer()

            Image(systemName: "play.circle.fill")
                .font(.system(size: 28))
                .foregroundColor(Color(hex: "ff3b30"))
        }
        .padding(10)
        .background(Color(hex: "1e1e1e"))
        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadiusSmall))
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let secs = Int(seconds)
        if secs < 60 {
            return "\(secs)s"
        }
        let mins = secs / 60
        let rem = secs % 60
        return "\(mins)m \(rem)s"
    }
}

// MARK: - On This Day Button Graphic

struct OnThisDayButtonGraphic: View {
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color(hex: "ff3b30").opacity(0.15))
                    .frame(width: 44, height: 44)

                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 18))
                    .foregroundColor(Color(hex: "ff3b30"))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("On This Day")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color(hex: "f5f5f5"))

                Text("Same date in past years")
                    .font(.system(size: 11))
                    .foregroundColor(Color(hex: "8a8a8a"))
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Color(hex: "8a8a8a"))
        }
        .padding(12)
        .background(Color(hex: "141414"))
        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadiusMedium))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cornerRadiusMedium)
                .stroke(Color(hex: "ff3b30").opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - On This Day Preview in Calendar

struct OnThisDayCalendarBadge: View {
    let count: Int

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 11))
            Text("\(count)")
                .font(.system(size: 11, weight: .bold))
        }
        .foregroundColor(Color(hex: "ff3b30"))
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(Color(hex: "ff3b30").opacity(0.15))
        .clipShape(Capsule())
    }
}

#Preview("On This Day") {
    OnThisDayView(entries: [], onDismiss: {})
        .preferredColorScheme(.dark)
}
