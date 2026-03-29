import SwiftUI

struct CalendarGridView: View {
    let onEntrySelected: (VideoEntry) -> Void
    @State private var currentMonth = Date()
    @State private var entriesThisMonth: [VideoEntry] = []
    @StateObject private var videoStore = VideoStore.shared

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
    private let weekdays = ["S", "M", "T", "W", "T", "F", "S"]

    var body: some View {
        VStack(spacing: 0) {
            monthNavigator
            weekdayHeader
            calendarGrid
            entriesList
        }
        .background(Color(hex: "0A0A0A"))
        .onAppear {
            loadEntriesForMonth()
        }
        .onChange(of: currentMonth) { _, _ in
            loadEntriesForMonth()
        }
    }

    private var monthNavigator: some View {
        HStack {
            Button(action: { changeMonth(by: -1) }) {
                Image(systemName: "chevron.left")
                    .foregroundColor(Color(hex: "FF3B30"))
            }
            .buttonStyle(.plain)

            Spacer()

            Text(monthYearString)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Color(hex: "FAFAFA"))

            Spacer()

            Button(action: { changeMonth(by: 1) }) {
                Image(systemName: "chevron.right")
                    .foregroundColor(Color(hex: "FF3B30"))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var weekdayHeader: some View {
        LazyVGrid(columns: columns, spacing: 4) {
            ForEach(weekdays, id: \.self) { day in
                Text(day)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Color(hex: "5A5A5A"))
                    .frame(height: 24)
            }
        }
        .padding(.horizontal, 16)
    }

    private var calendarGrid: some View {
        LazyVGrid(columns: columns, spacing: 4) {
            ForEach(daysInMonth(), id: \.self) { day in
                if let date = day {
                    DayCell(
                        date: date,
                        hasEntry: hasEntry(for: date),
                        isToday: Calendar.current.isDateInToday(date)
                    )
                } else {
                    Color.clear
                        .frame(width: 36, height: 36)
                }
            }
        }
        .padding(.horizontal, 16)
    }

    private var entriesList: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Entries This Month")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Color(hex: "A0A0A0"))
                .padding(.horizontal, 16)
                .padding(.top, 12)

            if entriesThisMonth.isEmpty {
                Text("No entries this month")
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: "5A5A5A"))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 20)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(entriesThisMonth) { entry in
                            ClipRowView(entry: entry)
                                .onTapGesture {
                                    onEntrySelected(entry)
                                }
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
            Spacer()
        }
    }

    private var monthYearString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: currentMonth)
    }

    private func changeMonth(by value: Int) {
        if let newMonth = Calendar.current.date(byAdding: .month, value: value, to: currentMonth) {
            currentMonth = newMonth
        }
    }

    private func daysInMonth() -> [Date?] {
        let calendar = Calendar.current
        guard let monthInterval = calendar.dateInterval(of: .month, for: currentMonth),
              let firstWeekday = calendar.dateComponents([.weekday], from: monthInterval.start).weekday else {
            return []
        }

        var days: [Date?] = Array(repeating: nil, count: firstWeekday - 1)

        var currentDate = monthInterval.start
        while currentDate < monthInterval.end {
            days.append(currentDate)
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
        }

        return days
    }

    private func hasEntry(for date: Date) -> Bool {
        let calendar = Calendar.current
        return videoStore.entries.contains { calendar.isDate($0.recordedAt, inSameDayAs: date) }
    }

    private func loadEntriesForMonth() {
        entriesThisMonth = videoStore.entriesForMonth(currentMonth)
    }
}

struct DayCell: View {
    let date: Date
    let hasEntry: Bool
    let isToday: Bool

    var body: some View {
        ZStack {
            if isToday {
                Circle()
                    .fill(Color(hex: "FF3B30"))
                    .frame(width: 28, height: 28)
            }

            Text("\(Calendar.current.component(.day, from: date))")
                .font(.system(size: 12))
                .foregroundColor(isToday ? .white : Color(hex: "A0A0A0"))

            if hasEntry && !isToday {
                Circle()
                    .fill(Color(hex: "FF3B30"))
                    .frame(width: 4, height: 4)
                    .offset(y: 12)
            }
        }
        .frame(width: 36, height: 36)
    }
}

#Preview {
    CalendarGridView(onEntrySelected: { _ in })
        .frame(width: 360, height: 480)
}
