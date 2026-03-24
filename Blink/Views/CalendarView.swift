import SwiftUI

struct CalendarView: View {
    @ObservedObject private var videoStore = VideoStore.shared
    @State private var selectedYear: Int
    @State private var selectedEntry: VideoEntry?
    @State private var showYearInReview = false
    @State private var showMonthBrowser = false
    @State private var showJumpToMonth = false

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

                            // Year summary card
                            yearSummaryCard
                                .padding(.horizontal, 16)

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
                                showMonthBrowser = true
                            } label: {
                                Image(systemName: "rectangle.stack")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(Color(hex: "8a8a8a"))
                            }

                            Button {
                                showYearInReview = true
                            } label: {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(Color(hex: "ff3b30"))
                            }
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
        .sheet(isPresented: $showYearInReview) {
            YearInReviewView(
                clipsThisYear: clipsThisYear,
                totalDaysElapsed: daysElapsedThisYear
            )
        }
        .fullScreenCover(isPresented: $showMonthBrowser) {
            MonthBrowserView(selectedEntry: $selectedEntry)
        }
    }

    private var yearSelector: some View {
        HStack {
            Button {
                withAnimation {
                    selectedYear -= 1
                }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(Color(hex: "f5f5f5"))
                    .frame(width: 44, height: 44)
            }

            Spacer()

            Text(String(selectedYear))
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(Color(hex: "f5f5f5"))

            Spacer()

            Button {
                withAnimation {
                    selectedYear += 1
                }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(Color(hex: "f5f5f5"))
                    .frame(width: 44, height: 44)
            }
            .disabled(selectedYear >= Calendar.current.component(.year, from: Date()))
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
                    showYearInReview = true
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

    var body: some View {
        Button {
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
    }
}

#Preview {
    CalendarView()
        .preferredColorScheme(.dark)
}
