import SwiftUI

struct PopoverContentView: View {
    @State private var selectedSection: Section = .today
    @State private var selectedEntry: VideoEntry?

    enum Section: String, CaseIterable {
        case today = "Today"
        case calendar = "Calendar"
        case settings = "Settings"
    }

    var body: some View {
        VStack(spacing: 0) {
            headerView
            Divider()
                .background(Color(hex: "3A3A3A"))
            sectionPicker
            Divider()
                .background(Color(hex: "3A3A3A"))
            contentArea
        }
        .frame(width: 360, height: 480)
        .background(Color(hex: "0A0A0A"))
        .sheet(item: $selectedEntry) { entry in
            PlaybackView(entry: entry)
        }
    }

    private var headerView: some View {
        HStack {
            Text("Blink")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(Color(hex: "FF3B30"))
            Spacer()
            Text(formattedDate)
                .font(.system(size: 12))
                .foregroundColor(Color(hex: "A0A0A0"))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(hex: "141414"))
    }

    private var sectionPicker: some View {
        HStack(spacing: 0) {
            ForEach(Section.allCases, id: \.self) { section in
                Button(action: { selectedSection = section }) {
                    Text(section.rawValue)
                        .font(.system(size: 13, weight: selectedSection == section ? .semibold : .regular))
                        .foregroundColor(selectedSection == section ? Color(hex: "FF3B30") : Color(hex: "A0A0A0"))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(selectedSection == section ? Color(hex: "1A1A1A") : Color.clear)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
    }

    @ViewBuilder
    private var contentArea: some View {
        switch selectedSection {
        case .today:
            TodayView(onEntrySelected: { entry in
                selectedEntry = entry
            })
        case .calendar:
            CalendarGridView(onEntrySelected: { entry in
                selectedEntry = entry
            })
        case .settings:
            SettingsView()
        }
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter.string(from: Date())
    }
}

// MARK: - Color Extension
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

#Preview {
    PopoverContentView()
}
