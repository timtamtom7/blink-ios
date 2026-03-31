import SwiftUI
import AVFoundation

// MARK: - Search View

struct SearchView: View {
    @ObservedObject private var videoStore = VideoStore.shared
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var selectedFilter: ClipFilter = .all
    @State private var selectedEntry: VideoEntry?
    @State private var minDurationFilter: Double = 0 // seconds, 0 = no filter

    enum ClipFilter: String, CaseIterable {
        case all = "All"
        case hasAudio = "Has Audio"
        case longerThan30 = "> 30s"
        case longerThan60 = "> 60s"
    }

    private var filteredEntries: [VideoEntry] {
        var results = videoStore.entries.filter { !$0.isLocked }

        // Text search
        if !searchText.isEmpty {
            let lowercased = searchText.lowercased()
            results = results.filter { entry in
                // Search by title
                if let title = entry.title, title.lowercased().contains(lowercased) {
                    return true
                }
                // Search by date string
                let dateStr = entry.defaultTitle.lowercased()
                if dateStr.contains(lowercased) {
                    return true
                }
                return false
            }
        }

        // Duration filter
        switch selectedFilter {
        case .all:
            break
        case .hasAudio:
            // All Blink clips have audio by default - this is a placeholder for future audio-only clips
            break
        case .longerThan30:
            results = results.filter { $0.duration > 30 }
        case .longerThan60:
            results = results.filter { $0.duration > 60 }
        }

        // Min duration filter (slider)
        if minDurationFilter > 0 {
            results = results.filter { $0.duration >= minDurationFilter }
        }

        return results.sorted { $0.date > $1.date }
    }

    private var searchResultsByMonth: [Int: [VideoEntry]] {
        var grouped: [Int: [VideoEntry]] = [:]
        for entry in filteredEntries {
            let month = Calendar.current.component(.month, from: entry.date)
            if grouped[month] == nil {
                grouped[month] = []
            }
            grouped[month]?.append(entry)
        }
        return grouped
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "0a0a0a")
                    .ignoresSafeArea()

                if filteredEntries.isEmpty && searchText.isEmpty && selectedFilter == .all {
                    emptyState
                } else if filteredEntries.isEmpty {
                    noResultsState
                } else {
                    searchResults
                }
            }
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color(hex: "0a0a0a"), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                    .font(BlinkFontStyle.body.font)
                    .foregroundColor(Color(hex: "ff3b30"))
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        ForEach(ClipFilter.allCases, id: \.self) { filter in
                            Button {
                                selectedFilter = filter
                            } label: {
                                HStack {
                                    Text(filter.rawValue)
                                    if selectedFilter == filter {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "line.3.horizontal.decrease.circle")
                                .font(BlinkFontStyle.body.font)
                            Text(selectedFilter == .all ? "Filter" : selectedFilter.rawValue)
                                .font(BlinkFontStyle.callout.font)
                        }
                        .foregroundColor(Color(hex: "ff3b30"))
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search by title or date")
            .preferredColorScheme(.dark)
        }
        .fullScreenCover(item: $selectedEntry) { entry in
            PlaybackView(entry: entry, onDelete: {
                videoStore.deleteEntry(entry)
                selectedEntry = nil
            }, onTrim: { updatedEntry in
                videoStore.updateEntry(updatedEntry)
                selectedEntry = updatedEntry
            })
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(Color(hex: "333333"))

            Text("Search your clips")
                .font(.system(size: 17, weight: .medium))
                .foregroundColor(Color(hex: "8a8a8a"))

            Text("Find clips by title or date")
                .font(BlinkFontStyle.callout.font)
                .foregroundColor(Color(hex: "555555"))
        }
    }

    private var noResultsState: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(Color(hex: "333333"))

            Text("No results")
                .font(.system(size: 17, weight: .medium))
                .foregroundColor(Color(hex: "8a8a8a"))

            Text("Try a different search term or filter")
                .font(BlinkFontStyle.callout.font)
                .foregroundColor(Color(hex: "555555"))
        }
    }

    private var searchResults: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                // Results count
                HStack {
                    Text("\(filteredEntries.count) clip\(filteredEntries.count == 1 ? "" : "s") found")
                        .font(BlinkFontStyle.subheadline.font)
                        .foregroundColor(Color(hex: "8a8a8a"))
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)

                ForEach(filteredEntries) { entry in
                    SearchResultRow(entry: entry) {
                        selectedEntry = entry
                    }
                }
            }
            .padding(.bottom, 24)
        }
    }
}

struct SearchResultRow: View {
    let entry: VideoEntry
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Thumbnail
                if let thumbURL = entry.thumbnailURL {
                    AsyncImage(url: thumbURL) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Color(hex: "1e1e1e")
                    }
                    .frame(width: 72, height: 48)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadiusSmall))
                } else {
                    RoundedRectangle(cornerRadius: Theme.cornerRadiusSmall)
                        .fill(Color(hex: "1e1e1e"))
                        .frame(width: 72, height: 48)
                        .overlay(
                            Image(systemName: "video")
                                .foregroundColor(Color(hex: "555555"))
                        )
                }

                // Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.displayTitle)
                        .font(BlinkFontStyle.callout.font)
                        .foregroundColor(Color(hex: "f5f5f5"))
                        .lineLimit(1)

                    HStack(spacing: 6) {
                        Text(entry.formattedDate)
                            .font(BlinkFontStyle.footnote.font)
                            .foregroundColor(Color(hex: "8a8a8a"))

                        Text("•")
                            .foregroundColor(Color(hex: "555555"))

                        Text(formatDuration(entry.duration))
                            .font(BlinkFontStyle.footnote.font)
                            .foregroundColor(Color(hex: "8a8a8a"))
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(BlinkFontStyle.footnote.font)
                    .foregroundColor(Color(hex: "555555"))
            }
            .padding(12)
            .background(Color(hex: "141414"))
            .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadiusMedium))
        }
        .padding(.horizontal, 16)
        .accessibilityLabel("\(entry.displayTitle), \(entry.formattedDate), duration \(formatDuration(entry.duration))")
        .accessibilityHint("Double tap to play this clip.")
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

#Preview {
    SearchView()
        .preferredColorScheme(.dark)
}
