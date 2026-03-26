import SwiftUI

struct CalendarView: View {
    @ObservedObject private var videoStore = VideoStore.shared
    @StateObject private var subscription = SubscriptionService.shared
    @State private var selectedYear: Int
    @State private var selectedEntry: VideoEntry?
    @State private var showYearInReview = false
    @State private var showMonthBrowser = false
    @State private var showJumpToMonth = false
    @State private var showOnThisDay = false
    @State private var showSearch = false
    @State private var showExportOptions = false
    @State private var showAIHighlights = false
    @State private var showPublicFeed = false
    @State private var showYearCompilation = false
    @State private var isExporting = false
    @State private var exportProgress: Double = 0
    @State private var exportError: String?
    @State private var exportedVideoURL: URL?
    @State private var showExportedAlert = false
    @State private var showPricing = false

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
    private let dayLabels = ["S", "M", "T", "W", "T", "F", "S"]

    init() {
        _selectedYear = State(initialValue: Calendar.current.component(.year, from: Date()))
    }

    private var clipsThisYear: Int {
        videoStore.entriesForYear(selectedYear).count
    }

    private var daysElapsedThisYear: Int {
        let now = Date()
        let calendar = Calendar.current
        let startOfYear = calendar.date(from: DateComponents(year: selectedYear, month: 1, day: 1))!
        return max(1, calendar.dateComponents([.day], from: startOfYear, to: now).day ?? 1)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "0a0a0a")
                    .ignoresSafeArea()

                if clipsThisYear == 0 && selectedYear == Calendar.current.component(.year, from: Date()) {
                    EmptyCalendarView(year: selectedYear, onRecordFirst: {})
                } else {
                    ScrollView {
                        VStack(spacing: 24) {
                            yearSelector
                                .padding(.top, 16)

                            // R5: Freemium nudge for free users
                            if subscription.isFree {
                                FreePlanNudgeView(
                                    clipCount: subscription.clipsRecordedToday,
                                    onUpgrade: {
                                        showPricing = true
                                    }
                                )
                                .padding(.horizontal, 16)
                            }

                            // Year summary card
                            yearSummaryCard
                                .padding(.horizontal, 16)

                            // On This Day card
                            if videoStore.onThisDayCount > 0 {
                                onThisDayCard
                                    .padding(.horizontal, 16)
                            }

                            monthGrid
                                .padding(.horizontal, 16)

                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("Calendar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color(hex: "0a0a0a"), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                if clipsThisYear > 0 {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        HStack(spacing: 4) {
                            Button {
                                HapticService.shared.buttonTap()
                                showAIHighlights = true
                            } label: {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(Color(hex: "8a8a8a"))
                            }
                            .accessibilityLabel("AI Highlights")

                            Button {
                                HapticService.shared.buttonTap()
                                showPublicFeed = true
                            } label: {
                                Image(systemName: "globe")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(Color(hex: "8a8a8a"))
                            }
                            .accessibilityLabel("Public feed")

                            Button {
                                HapticService.shared.buttonTap()
                                showSearch = true
                            } label: {
                                Image(systemName: "magnifyingglass")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(Color(hex: "8a8a8a"))
                            }
                            .accessibilityLabel("Search clips")

                            Button {
                                HapticService.shared.buttonTap()
                                showMonthBrowser = true
                            } label: {
                                Image(systemName: "rectangle.stack")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(Color(hex: "8a8a8a"))
                            }
                            .accessibilityLabel("Browse by month")

                            Button {
                                HapticService.shared.buttonTap()
                                showExportOptions = true
                            } label: {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(Color(hex: "8a8a8a"))
                            }
                            .accessibilityLabel("Export options")
                        }
                    }
                }
            }
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
        .fullScreenCover(isPresented: $showAIHighlights) {
            AIHighlightsView()
        }
        .fullScreenCover(isPresented: $showPublicFeed) {
            PublicFeedView()
        }
        .fullScreenCover(isPresented: $showYearCompilation) {
            YearInReviewCompilationView(
                year: selectedYear,
                entries: videoStore.entriesForYear(selectedYear),
                onDismiss: {
                    showYearCompilation = false
                }
            )
        }
        .sheet(isPresented: $showYearInReview) {
            YearInReviewView(
                clipsThisYear: clipsThisYear,
                totalDaysElapsed: daysElapsedThisYear
            )
        }
        .fullScreenCover(isPresented: $showMonthBrowser) {
            MonthBrowserView(selectedEntry: $selectedEntry)
        }
        .fullScreenCover(isPresented: $showOnThisDay) {
            OnThisDayView(
                entries: videoStore.onThisDayEntries(),
                onDismiss: {
                    showOnThisDay = false
                }
            )
        }
        .fullScreenCover(isPresented: $showSearch) {
            SearchView()
        }
        .confirmationDialog("Export", isPresented: $showExportOptions, titleVisibility: .visible) {
            if clipsThisYear > 0 {
                Button("Export \(selectedYear) Year as Video") {
                    showYearCompilation = true
                }
            }
            Button("Export This Month's Clips") {
                exportThisMonth()
            }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(isPresented: $showPricing) {
            PricingView()
        }
    }

    private var onThisDayCard: some View {
        Button {
            showOnThisDay = true
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color(hex: "ff3b30").opacity(0.15))
                        .frame(width: 48, height: 48)

                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 20))
                        .foregroundColor(Color(hex: "ff3b30"))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("On This Day")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Color(hex: "f5f5f5"))

                    Text("\(videoStore.onThisDayCount) moment\(videoStore.onThisDayCount == 1 ? "" : "s") from this date")
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: "8a8a8a"))
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color(hex: "8a8a8a"))
            }
            .padding(14)
            .background(Color(hex: "141414"))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(hex: "ff3b30").opacity(0.3), lineWidth: 1)
            )
        }
    }

    private var yearSelector: some View {
        HStack {
            Button {
                withAnimation {
                    selectedYear -= 1
                }
                HapticService.shared.selectionChanged()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(Color(hex: "f5f5f5"))
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Previous year")
            .accessibilityHint("Shows the calendar for \(selectedYear - 1)")

            Spacer()

            Text(String(selectedYear))
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(Color(hex: "f5f5f5"))
                .accessibilityLabel("\(selectedYear)")

            Spacer()

            Button {
                withAnimation {
                    selectedYear += 1
                }
                HapticService.shared.selectionChanged()
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(Color(hex: "f5f5f5"))
                    .frame(width: 44, height: 44)
            }
            .disabled(selectedYear >= Calendar.current.component(.year, from: Date()))
            .accessibilityLabel("Next year")
            .accessibilityHint(selectedYear >= Calendar.current.component(.year, from: Date()) ? "No year after \(selectedYear)" : "Shows the calendar for \(selectedYear + 1)")
        }
        .padding(.horizontal, 16)
    }

    private var yearSummaryCard: some View {
        HStack(spacing: 16) {
            // Progress ring
            ZStack {
                Circle()
                    .stroke(Color(hex: "1e1e1e"), lineWidth: 3)
                    .frame(width: 52, height: 52)

                Circle()
                    .trim(from: 0, to: min(CGFloat(clipsThisYear) / CGFloat(daysElapsedThisYear), 1.0))
                    .stroke(Color(hex: "ff3b30"), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: 52, height: 52)
                    .rotationEffect(.degrees(-90))

                Text("\(Int(Double(clipsThisYear) / Double(daysElapsedThisYear) * 100))%")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(Color(hex: "f5f5f5"))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("\(clipsThisYear) moments recorded")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Color(hex: "f5f5f5"))

                Text("\(daysElapsedThisYear) days into \(selectedYear)")
                    .font(.system(size: 13))
                    .foregroundColor(Color(hex: "8a8a8a"))
            }

            Spacer()

            if clipsThisYear > 0 {
                Button {
                    showYearCompilation = true
                } label: {
                    HStack(spacing: 4) {
                        Text("Review")
                            .font(.system(size: 13, weight: .medium))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(Color(hex: "ff3b30"))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color(hex: "ff3b30").opacity(0.15))
                    .clipShape(Capsule())
                }
            }
        }
        .padding(16)
        .background(Color(hex: "141414"))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var monthGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
            ForEach(1...12, id: \.self) { month in
                MonthCard(
                    month: month,
                    year: selectedYear,
                    entries: videoStore.entriesForYear(selectedYear),
                    onTapEntry: { entry in
                        selectedEntry = entry
                    }
                )
            }
        }
    }

    // MARK: - Export This Month

    private func exportThisMonth() {
        let calendar = Calendar.current
        let now = Date()
        let currentMonth = calendar.component(.month, from: now)
        let currentYear = calendar.component(.year, from: now)

        guard clipsThisYear > 0 else { return }

        isExporting = true
        exportProgress = 0

        Task {
            do {
                let outputURL = try await ExportService.shared.exportMonthClips(
                    month: currentMonth,
                    year: currentYear,
                    onProgress: { progress in
                        Task { @MainActor in
                            exportProgress = progress
                        }
                    }
                )

                // Save to camera roll
                try await ExportService.shared.saveToCameraRoll(url: outputURL)

                await MainActor.run {
                    isExporting = false
                    showExportedAlert = true
                    exportedVideoURL = outputURL
                }

                // Clean up temp file
                try? FileManager.default.removeItem(at: outputURL)
            } catch {
                await MainActor.run {
                    isExporting = false
                    exportError = error.localizedDescription
                }
            }
        }
    }
}

struct MonthCard: View {
    let month: Int
    let year: Int
    let entries: [VideoEntry]
    let onTapEntry: (VideoEntry) -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 7)
    private let dayLabels = ["S", "M", "T", "W", "T", "F", "S"]

    private var monthName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM"
        var components = DateComponents()
        components.month = month
        components.year = year
        components.day = 1
        guard let date = Calendar.current.date(from: components) else { return "" }
        return formatter.string(from: date)
    }

    private var daysInMonth: Int {
        var components = DateComponents()
        components.month = month
        components.year = year
        components.day = 1
        guard let date = Calendar.current.date(from: components) else { return 0 }
        return Calendar.current.range(of: .day, in: .month, for: date)?.count ?? 0
    }

    private var firstWeekday: Int {
        var components = DateComponents()
        components.month = month
        components.year = year
        components.day = 1
        guard let date = Calendar.current.date(from: components) else { return 0 }
        return Calendar.current.component(.weekday, from: date) - 1
    }

    private var entryMap: [Int: VideoEntry] {
        var map: [Int: VideoEntry] = [:]
        for entry in entries {
            let day = Calendar.current.component(.day, from: entry.date)
            map[day] = entry
        }
        return map
    }

    private var clipsThisMonth: Int {
        let calendar = Calendar.current
        return entries.filter { calendar.component(.month, from: $0.date) == month }.count
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text(monthName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color(hex: "f5f5f5"))

                Spacer()

                if clipsThisMonth > 0 {
                    Text("\(clipsThisMonth)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(Color(hex: "ff3b30"))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color(hex: "ff3b30").opacity(0.15))
                        .clipShape(Capsule())
                }
            }

            // Day labels
            LazyVGrid(columns: columns, spacing: 2) {
                ForEach(dayLabels, id: \.self) { label in
                    Text(label)
                        .font(.system(size: 8, weight: .medium))
                        .foregroundColor(Color(hex: "8a8a8a"))
                        .frame(height: 12)
                }
            }

            // Days
            LazyVGrid(columns: columns, spacing: 2) {
                ForEach(0..<firstWeekday, id: \.self) { _ in
                    Color.clear
                        .frame(height: 36)
                }

                ForEach(1...daysInMonth, id: \.self) { day in
                    DayCell(
                        day: day,
                        entry: entryMap[day],
                        isCurrentMonth: true,
                        onTap: { entry in
                            if let entry = entry {
                                onTapEntry(entry)
                            }
                        }
                    )
                }
            }
        }
        .padding(12)
        .background(Color(hex: "141414"))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct DayCell: View {
    let day: Int
    let entry: VideoEntry?
    let isCurrentMonth: Bool
    let onTap: (VideoEntry?) -> Void

    private var accessibilityLabel: String {
        if let entry = entry {
            return "Day \(day), clip recorded: \(entry.displayTitle)"
        } else {
            return "Day \(day), no clip"
        }
    }

    var body: some View {
        Button {
            HapticService.shared.buttonTap()
            onTap(entry)
        } label: {
            ZStack {
                if let entry = entry, let thumbURL = entry.thumbnailURL {
                    AsyncImage(url: thumbURL) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Color(hex: "333333")
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 4))

                    // Title overlay at bottom
                    if let title = entry.title, !title.isEmpty {
                        VStack {
                            Spacer()
                            Text(title)
                                .font(.system(size: 6, weight: .medium))
                                .foregroundColor(.white)
                                .lineLimit(1)
                                .padding(.horizontal, 2)
                                .padding(.vertical, 1)
                                .frame(maxWidth: .infinity)
                                .background(Color.black.opacity(0.5))
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                } else {
                    Circle()
                        .stroke(Color(hex: "2a2a2a"), lineWidth: 1)
                        .frame(width: 32, height: 32)
                }

                // Day number overlay
                Text("\(day)")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(entry != nil ? .white : Color(hex: "6a6a6a"))
            }
            .frame(width: 36, height: 36)
        }
        .disabled(entry == nil)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(entry != nil ? "Double tap to view this clip." : "No clip recorded on this day.")
    }
}

#Preview {
    CalendarView()
        .preferredColorScheme(.dark)
}
