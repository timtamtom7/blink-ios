import SwiftUI

// MARK: - Month Browser View

struct MonthBrowserView: View {
    @ObservedObject private var videoStore = VideoStore.shared
    @Binding var selectedEntry: VideoEntry?
    @Environment(\.dismiss) private var dismiss

    @State private var selectedYear: Int
    @State private var selectedMonth: Int?

    init(selectedEntry: Binding<VideoEntry?>) {
        _selectedEntry = selectedEntry
        _selectedYear = State(initialValue: Calendar.current.component(.year, from: Date()))
    }

    private var monthsWithClips: [Int] {
        videoStore.monthsWithEntries(for: selectedYear)
    }

    private let monthNames = [
        "January", "February", "March", "April", "May", "June",
        "July", "August", "September", "October", "November", "December"
    ]

    private let monthAbbr = [
        "Jan", "Feb", "Mar", "Apr", "May", "Jun",
        "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"
    ]

    private var years: [Int] {
        let currentYear = Calendar.current.component(.year, from: Date())
        return Array((currentYear - 5)...currentYear).reversed()
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "0a0a0a")
                    .ignoresSafeArea()

                VStack(spacing: 24) {
                    // Year picker
                    yearPicker
                        .padding(.horizontal, 16)
                        .padding(.top, 8)

                    // Month grid
                    monthGrid
                        .padding(.horizontal, 16)

                    Spacer()
                }
            }
            .navigationTitle("Browse by Month")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color(hex: "0a0a0a"), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color(hex: "ff3b30"))
                }
            }
        }
    }

    private var yearPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(years, id: \.self) { year in
                    Button {
                        withAnimation {
                            selectedYear = year
                        }
                    } label: {
                        Text(String(year))
                            .font(.system(size: 14, weight: selectedYear == year ? .bold : .medium))
                            .foregroundColor(selectedYear == year ? .white : Color(hex: "8a8a8a"))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(selectedYear == year ? Color(hex: "ff3b30") : Color(hex: "1e1e1e"))
                            .clipShape(Capsule())
                    }
                }
            }
        }
    }

    private var monthGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            ForEach(1...12, id: \.self) { month in
                MonthBrowseCard(
                    month: month,
                    monthName: monthNames[month - 1],
                    monthAbbr: monthAbbr[month - 1],
                    clipCount: videoStore.clipCount(for: month, year: selectedYear),
                    entries: videoStore.entries.filter {
                        Calendar.current.component(.month, from: $0.date) == month &&
                        Calendar.current.component(.year, from: $0.date) == selectedYear
                    },
                    onTapEntry: { entry in
                        selectedEntry = entry
                        dismiss()
                    }
                )
            }
        }
    }
}

struct MonthBrowseCard: View {
    let month: Int
    let monthName: String
    let monthAbbr: String
    let clipCount: Int
    let entries: [VideoEntry]
    let onTapEntry: (VideoEntry) -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Month header
            Text(monthAbbr)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(clipCount > 0 ? .white : Color(hex: "8a8a8a"))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)

            Divider()
                .background(Color(hex: "2a2a2a"))

            if clipCount == 0 {
                // Empty month
                VStack(spacing: 6) {
                    Image(systemName: "video.slash")
                        .font(.system(size: 20))
                        .foregroundColor(Color(hex: "333333"))
                    Text("No clips")
                        .font(.system(size: 10))
                        .foregroundColor(Color(hex: "555555"))
                }
                .frame(height: 60)
            } else {
                // Thumbnail strip (most recent clip)
                VStack(spacing: 4) {
                    if let lastEntry = entries.last, let thumbURL = lastEntry.thumbnailURL {
                        AsyncImage(url: thumbURL) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Color(hex: "1e1e1e")
                        }
                        .frame(width: 60, height: 40)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadiusSmall))
                    }

                    // Clip count
                    HStack(spacing: 3) {
                        Image(systemName: "video.fill")
                            .font(.system(size: 11))
                        Text("\(clipCount)")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .foregroundColor(Color(hex: "ff3b30"))
                }
                .frame(height: 60)
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
                .onTapGesture {
                    if entries.count == 1 {
                        onTapEntry(entries[0])
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .background(Color(hex: "141414"))
        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadiusSmall))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cornerRadiusSmall)
                .stroke(clipCount > 0 ? Color(hex: "ff3b30").opacity(0.3) : Color.clear, lineWidth: 1)
        )
    }
}

// MARK: - Jump to Month Sheet

struct JumpToMonthView: View {
    @Binding var selectedEntry: VideoEntry?
    @Environment(\.dismiss) private var dismiss

    @State private var selectedYear: Int
    @State private var selectedMonth: Int?
    @State private var showMonthPicker = false

    private let monthNames = [
        "January", "February", "March", "April", "May", "June",
        "July", "August", "September", "October", "November", "December"
    ]

    init(selectedEntry: Binding<VideoEntry?>) {
        _selectedEntry = selectedEntry
        _selectedYear = State(initialValue: Calendar.current.component(.year, from: Date()))
    }

    private var years: [Int] {
        let currentYear = Calendar.current.component(.year, from: Date())
        return Array((currentYear - 5)...currentYear).reversed()
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "0a0a0a")
                    .ignoresSafeArea()

                VStack(spacing: 24) {
                    // Year selector
                    yearSelector
                        .padding(.horizontal, 16)

                    // Month grid
                    monthGrid
                        .padding(.horizontal, 16)

                    Spacer()
                }
            }
            .navigationTitle("Jump to Month")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color(hex: "0a0a0a"), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .font(.system(size: 16))
                    .foregroundColor(Color(hex: "8a8a8a"))
                }
            }
        }
    }

    private var yearSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(years, id: \.self) { year in
                    Button {
                        withAnimation {
                            selectedYear = year
                        }
                    } label: {
                        Text(String(year))
                            .font(.system(size: 14, weight: selectedYear == year ? .bold : .medium))
                            .foregroundColor(selectedYear == year ? .white : Color(hex: "8a8a8a"))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(selectedYear == year ? Color(hex: "ff3b30") : Color(hex: "1e1e1e"))
                            .clipShape(Capsule())
                    }
                }
            }
        }
    }

    private var monthGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            ForEach(1...12, id: \.self) { month in
                let count = VideoStore.shared.clipCount(for: month, year: selectedYear)
                let isCurrentMonth = selectedMonth == month

                Button {
                    if count > 0 {
                        selectedMonth = month
                        showEntriesForMonth(month)
                    }
                } label: {
                    VStack(spacing: 4) {
                        Text(monthNames[month - 1].prefix(3).uppercased())
                            .font(.system(size: 13, weight: isCurrentMonth ? .bold : .medium))
                            .foregroundColor(count > 0 ? (isCurrentMonth ? Color(hex: "ff3b30") : .white) : Color(hex: "555555"))

                        if count > 0 {
                            HStack(spacing: 2) {
                                Circle()
                                    .fill(Color(hex: "ff3b30"))
                                    .frame(width: 4, height: 4)
                                Text("\(count)")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(Color(hex: "8a8a8a"))
                            }
                        } else {
                            Text("—")
                                .font(.system(size: 11))
                                .foregroundColor(Color(hex: "333333"))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(isCurrentMonth ? Color(hex: "ff3b30").opacity(0.15) : Color(hex: "141414"))
                    .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadiusSmall))
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.cornerRadiusSmall)
                            .stroke(isCurrentMonth ? Color(hex: "ff3b30") : Color(hex: "2a2a2a"), lineWidth: 1)
                    )
                }
                .disabled(count == 0)
            }
        }
    }

    private func showEntriesForMonth(_ month: Int) {
        let entries = VideoStore.shared.entries.filter {
            Calendar.current.component(.month, from: $0.date) == month &&
            Calendar.current.component(.year, from: $0.date) == selectedYear
        }.sorted { $0.date < $1.date }

        if let first = entries.first {
            selectedEntry = first
            dismiss()
        }
    }
}

#Preview {
    MonthBrowserView(selectedEntry: .constant(nil))
        .preferredColorScheme(.dark)
}
