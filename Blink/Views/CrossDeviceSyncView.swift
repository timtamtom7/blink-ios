import SwiftUI

/// R8: Cross-device sync settings view
struct CrossDeviceSyncView: View {
    @StateObject private var syncService = CrossDeviceSyncService.shared
    @State private var showAddDevice = false
    @State private var syncTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "0a0a0a")
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Sync status
                        syncStatusCard

                        // Connected devices
                        devicesSection

                        // Sync settings
                        syncSettingsSection
                    }
                    .padding(16)
                }

                // Coming Soon overlay — only when content has loaded AND is empty
                if syncService.connectedDevices.isEmpty {
                    VStack {}
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color(hex: "0a0a0a").opacity(0.85))
                        .overlay {
                            VStack(spacing: 16) {
                                Image(systemName: "icloud.slash")
                                    .font(BlinkFontStyle.icon48.font)
                                    .foregroundColor(Color(hex: "333333"))
                                Text("Coming Soon")
                                    .font(BlinkFontStyle.title2.font)
                                    .foregroundColor(Color(hex: "f5f5f5"))
                                Text("Cross-device sync is in development.")
                                    .font(BlinkFontStyle.body.font)
                                    .foregroundColor(Color(hex: "8a8a8a"))
                                    .multilineTextAlignment(.center)
                            }
                            .padding(32)
                        }
                }
            }
            .navigationTitle("Sync")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color(hex: "0a0a0a"), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .onDisappear {
                syncTask?.cancel()
            }
        }
    }

    private var syncStatusCard: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("iCloud Sync")
                        .font(BlinkFontStyle.title3.font)
                        .foregroundColor(Color(hex: "f5f5f5"))

                    Text(syncService.lastSyncText)
                        .font(BlinkFontStyle.subheadline.font)
                        .foregroundColor(Color(hex: "8a8a8a"))
                }

                Spacer()

                if syncService.isSyncing {
                    ProgressView()
                        .tint(Color(hex: "ff3b30"))
                } else {
                    Button {
                        syncTask = Task {
                            try? await syncService.syncAll()
                        }
                    } label: {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(BlinkFontStyle.title3.font)
                            .foregroundColor(Color(hex: "ff3b30"))
                    }
                }
            }

            if syncService.isSyncing {
                VStack(spacing: 8) {
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: Theme.cornerRadiusSmall)
                                .fill(Color(hex: "1e1e1e"))
                                .frame(height: 4)

                            RoundedRectangle(cornerRadius: Theme.cornerRadiusSmall)
                                .fill(Color(hex: "ff3b30"))
                                .frame(width: geometry.size.width * syncService.syncProgress, height: 4)
                        }
                    }
                    .frame(height: 4)

                    Text("Syncing your memories…")
                        .font(BlinkFontStyle.footnote.font)
                        .foregroundColor(Color(hex: "8a8a8a"))
                }
            }
        }
        .padding(16)
        .background(Color(hex: "141414"))
        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadiusLarge))
    }

    private var devicesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Devices")
                    .font(BlinkFontStyle.title3.font)
                    .foregroundColor(Color(hex: "f5f5f5"))

                Spacer()

                Button {
                    showAddDevice = true
                } label: {
                    Image(systemName: "plus")
                        .font(BlinkFontStyle.body.font)
                        .foregroundColor(Color(hex: "ff3b30"))
                }
            }

            if syncService.connectedDevices.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "iphone.and.arrow.forward")
                        .font(BlinkFontStyle.lockIconLarge.font)
                        .foregroundColor(Color(hex: "333333"))

                    Text("No devices connected")
                        .font(BlinkFontStyle.body.font)
                        .foregroundColor(Color(hex: "8a8a8a"))

                    Text("Sign in with the same Apple ID on other devices to sync your clips.")
                        .font(BlinkFontStyle.subheadline.font)
                        .foregroundColor(Theme.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(24)
                .background(Color(hex: "141414"))
                .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadiusLarge))
            } else {
                ForEach(syncService.connectedDevices) { device in
                    deviceRow(device)
                }
            }
        }
    }

    private func deviceRow(_ device: CrossDeviceSyncService.Device) -> some View {
        HStack(spacing: 12) {
            Image(systemName: deviceIcon(device.type))
                .font(BlinkFontStyle.title2.font)
                .foregroundColor(device.isConnected ? Color(hex: "34c759") : Color(hex: "8a8a8a"))
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(device.name)
                    .font(BlinkFontStyle.body.font)
                    .foregroundColor(Color(hex: "f5f5f5"))

                Text(device.isConnected ? "Connected" : "Last seen recently")
                    .font(BlinkFontStyle.footnote.font)
                    .foregroundColor(Color(hex: "8a8a8a"))
            }

            Spacer()

            if device.isConnected {
                Circle()
                    .fill(Color(hex: "34c759"))
                    .frame(width: 8, height: 8)
            }
        }
        .padding(12)
        .background(Color(hex: "141414"))
        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadiusSmall))
    }

    private func deviceIcon(_ type: CrossDeviceSyncService.Device.DeviceType) -> String {
        switch type {
        case .iPhone: return "iphone"
        case .iPad: return "ipad"
        case .mac: return "laptopcomputer"
        case .appleWatch: return "applewatch"
        }
    }

    private var syncSettingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Settings")
                .font(BlinkFontStyle.title3.font)
                .foregroundColor(Color(hex: "f5f5f5"))

            VStack(spacing: 0) {
                syncSettingRow(title: "Auto-sync on Wi-Fi", icon: "wifi", isOn: .constant(true))
                Divider().background(Color(hex: "2a2a2a"))
                syncSettingRow(title: "Sync over Cellular", icon: "antenna.radiowaves.left.and.right", isOn: .constant(false))
                Divider().background(Color(hex: "2a2a2a"))
                syncSettingRow(title: "Background Sync", icon: "arrow.clockwise.icloud", isOn: .constant(true))
            }
            .background(Color(hex: "141414"))
            .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadiusLarge))
        }
    }

    private func syncSettingRow(title: String, icon: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(BlinkFontStyle.body.font)
                .foregroundColor(Color(hex: "ff3b30"))
                .frame(width: 24)

            Text(title)
                .font(BlinkFontStyle.body.font)
                .foregroundColor(Color(hex: "f5f5f5"))

            Spacer()

            Toggle("", isOn: isOn)
                .tint(Color(hex: "ff3b30"))
        }
        .padding(14)
    }
}

#Preview {
    CrossDeviceSyncView()
        .preferredColorScheme(.dark)
}
