import SwiftUI

struct SettingsView: View {
    @AppStorage("launchAtLogin") private var launchAtLogin = false
    @AppStorage("showInDock") private var showInDock = true
    @AppStorage("clipQuality") private var clipQuality = "High"

    private let qualities = ["Low", "Medium", "High"]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                sectionHeader("General")

                settingRow(
                    title: "Launch at Login",
                    description: "Start BlinkMac when you log in",
                    toggle: $launchAtLogin
                )

                settingRow(
                    title: "Show in Dock",
                    description: "Display app icon in the Dock",
                    toggle: $showInDock
                )

                Divider()
                    .background(Color(hex: "3A3A3A"))

                sectionHeader("Recording")

                VStack(alignment: .leading, spacing: 8) {
                    Text("Clip Quality")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Color(hex: "FAFAFA"))

                    Picker("Quality", selection: $clipQuality) {
                        ForEach(qualities, id: \.self) { quality in
                            Text(quality).tag(quality)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                .padding(12)
                .background(Color(hex: "141414"))
                .cornerRadius(8)

                Divider()
                    .background(Color(hex: "3A3A3A"))

                sectionHeader("About")

                VStack(alignment: .leading, spacing: 4) {
                    Text("BlinkMac")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Color(hex: "FAFAFA"))
                    Text("Version 1.0.0")
                        .font(.system(size: 11))
                        .foregroundColor(Color(hex: "A0A0A0"))
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(hex: "141414"))
                .cornerRadius(8)

                Spacer()
            }
            .padding(16)
        }
        .background(Color(hex: "0A0A0A"))
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(Color(hex: "5A5A5A"))
            .padding(.top, 8)
    }

    private func settingRow(title: String, description: String, toggle: Binding<Bool>) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Color(hex: "FAFAFA"))
                Text(description)
                    .font(.system(size: 11))
                    .foregroundColor(Color(hex: "A0A0A0"))
            }
            Spacer()
            Toggle("", isOn: toggle)
                .tint(Color(hex: "FF3B30"))
        }
        .padding(12)
        .background(Color(hex: "141414"))
        .cornerRadius(8)
    }
}

#Preview {
    SettingsView()
        .frame(width: 360, height: 480)
}
