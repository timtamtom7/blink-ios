import SwiftUI
import UserNotifications

struct SettingsView: View {
    @AppStorage("dailyReminderEnabled") private var dailyReminderEnabled = false
    @AppStorage("reminderHour") private var reminderHour = 20
    @AppStorage("reminderMinute") private var reminderMinute = 0
    @AppStorage("videoQuality") private var videoQuality = "high"
    @AppStorage("iCloudBackupEnabled") private var iCloudBackupEnabled = false

    @ObservedObject private var privacy = PrivacyService.shared
    @ObservedObject private var cloudBackup = CloudBackupService.shared
    @State private var showAbout = false
    @State private var showPricing = false
    @State private var showStorageDashboard = false
    @State private var showPasscodeSetup = false
    @State private var showPasscodeRemoveConfirm = false
    @State private var showRestoreConfirm = false
    @State private var showBackupProgress = false
    @State private var showRestoreProgress = false
    @State private var backupError: String?
    @State private var backupTask: Task<Void, Never>?
    @State private var restoreTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "0a0a0a")
                    .ignoresSafeArea()

                List {
                    // Privacy & Security Section
                    privacySection
                        .listRowBackground(Color(hex: "141414"))

                    Section {
                        Toggle(isOn: $dailyReminderEnabled) {
                            Label("Daily Reminder", systemImage: "bell.fill")
                                .foregroundColor(Color(hex: "f5f5f5"))
                        }
                        .tint(Color(hex: "ff3b30"))
                        .accessibilityLabel("Daily reminder toggle. Currently \(dailyReminderEnabled ? "enabled" : "disabled").")
                        .onChange(of: dailyReminderEnabled) { _, newValue in
                            if newValue {
                                scheduleReminder()
                            } else {
                                cancelReminder()
                            }
                        }

                        if dailyReminderEnabled {
                            HStack {
                                Label("Time", systemImage: "clock.fill")
                                    .foregroundColor(Color(hex: "f5f5f5"))
                                    .accessibilityLabel("Reminder time")

                                Spacer()

                                DatePicker(
                                    "",
                                    selection: Binding(
                                        get: {
                                            var components = DateComponents()
                                            components.hour = reminderHour
                                            components.minute = reminderMinute
                                            return Calendar.current.date(from: components) ?? Date()
                                        },
                                        set: { newDate in
                                            let components = Calendar.current.dateComponents([.hour, .minute], from: newDate)
                                            reminderHour = components.hour ?? 20
                                            reminderMinute = components.minute ?? 0
                                            scheduleReminder()
                                        }
                                    ),
                                    displayedComponents: .hourAndMinute
                                )
                                .labelsHidden()
                                .tint(Color(hex: "ff3b30"))
                            }
                        }
                    } header: {
                        Text("Reminders")
                            .foregroundColor(Color(hex: "8a8a8a"))
                    }
                    .listRowBackground(Color(hex: "141414"))

                    Section {
                        Button {
                            showPricing = true
                        } label: {
                            HStack {
                                Label("Upgrade Plan", systemImage: "crown.fill")
                                    .foregroundColor(Color(hex: "f5f5f5"))

                                Spacer()

                                Image(systemName: "arrow.up.right")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(Color(hex: "ff3b30"))
                            }
                        }
                        .accessibilityLabel("Upgrade Plan")
                        .accessibilityHint("Opens subscription options")
                    } header: {
                        Text("Subscription")
                            .foregroundColor(Color(hex: "8a8a8a"))
                    }
                    .listRowBackground(Color(hex: "141414"))

                    Section {
                        Picker(selection: $videoQuality) {
                            Text("High").tag("high")
                            Text("Medium").tag("medium")
                        } label: {
                            Label("Recording Quality", systemImage: "video.fill")
                                .foregroundColor(Color(hex: "f5f5f5"))
                        }
                        .tint(Color(hex: "ff3b30"))
                        .accessibilityLabel("Recording Quality")
                        .accessibilityValue(videoQuality == "high" ? "High" : "Medium")

                        Button {
                            showStorageDashboard = true
                        } label: {
                            HStack {
                                Label("Storage Dashboard", systemImage: "externaldrive.fill")
                                    .foregroundColor(Color(hex: "f5f5f5"))
                                Spacer()
                                Image(systemName: "arrow.up.right")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(Color(hex: "ff3b30"))
                            }
                        }
                        .accessibilityLabel("Storage Dashboard")
                        .accessibilityHint("View storage usage and manage clips")
                    } header: {
                        Text("Recording")
                            .foregroundColor(Color(hex: "8a8a8a"))
                    }
                    .listRowBackground(Color(hex: "141414"))

                    Section {
                        Button {
                            showAbout = true
                        } label: {
                            Label("About Blink", systemImage: "info.circle.fill")
                                .foregroundColor(Color(hex: "f5f5f5"))
                        }
                        .accessibilityLabel("About Blink")
                        .accessibilityHint("View app information and credits")

                        if let privacyURL = URL(string: "https://example.com/privacy") {
                            Link(destination: privacyURL) {
                                Label("Privacy Policy", systemImage: "hand.raised.fill")
                                    .foregroundColor(Color(hex: "f5f5f5"))
                            }
                            .accessibilityLabel("Privacy Policy")
                            .accessibilityHint("Opens privacy policy in browser")
                        }
                    } header: {
                        Text("About")
                            .foregroundColor(Color(hex: "8a8a8a"))
                    }
                    .listRowBackground(Color(hex: "141414"))

                    // iCloud Backup Section
                    Section {
                        HStack {
                            Text("iCloud Backup")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(Color(hex: "8a8a8a"))
                            Spacer()
                            Text("Coming Soon")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(Color(hex: "555555"))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color(hex: "1e1e1e"))
                                .clipShape(Capsule())
                        }
                        .listRowBackground(Color.clear)
                        .padding(.bottom, -8)

                        if !cloudBackup.iCloudAvailable {
                            VStack(alignment: .leading, spacing: 4) {
                                Label("iCloud not available", systemImage: "icloud.slash")
                                    .foregroundColor(Color(hex: "8a8a8a"))
                                Text("Sign in to iCloud in Settings to enable backup")
                                    .font(.system(size: 11))
                                    .foregroundColor(Color(hex: "555555"))
                            }
                            .padding(.vertical, 4)
                        } else {
                            Toggle(isOn: $iCloudBackupEnabled) {
                                Label("iCloud Backup", systemImage: "icloud.fill")
                                    .foregroundColor(Color(hex: "f5f5f5"))
                            }
                            .tint(Color(hex: "ff3b30"))
                            .onChange(of: iCloudBackupEnabled) { _, newValue in
                                if newValue {
                                    startBackup()
                                }
                            }

                            if iCloudBackupEnabled {
                                if cloudBackup.isBackingUp {
                                    HStack {
                                        Text("Backing up…")
                                            .font(.system(size: 13))
                                            .foregroundColor(Color(hex: "8a8a8a"))
                                        Spacer()
                                        ProgressView()
                                            .tint(Color(hex: "ff3b30"))
                                            .progressViewStyle(CircularProgressViewStyle())
                                    }
                                } else if let lastBackup = cloudBackup.lastBackupDate {
                                    HStack {
                                        Text("Last backup:")
                                            .font(.system(size: 12))
                                            .foregroundColor(Color(hex: "555555"))
                                        Text(lastBackup, style: .relative)
                                            .font(.system(size: 12))
                                            .foregroundColor(Color(hex: "8a8a8a"))
                                        Spacer()
                                        Button("Backup Now") {
                                            startBackup()
                                        }
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(Color(hex: "ff3b30"))
                                    }
                                } else {
                                    Button {
                                        startBackup()
                                    } label: {
                                        HStack {
                                            Text("Back up now")
                                                .font(.system(size: 14, weight: .medium))
                                            Spacer()
                                            Image(systemName: "arrow.up.circle")
                                                .foregroundColor(Color(hex: "ff3b30"))
                                        }
                                        .foregroundColor(Color(hex: "f5f5f5"))
                                    }
                                }

                                Button {
                                    showRestoreConfirm = true
                                } label: {
                                    HStack {
                                        Text("Restore from iCloud")
                                            .font(.system(size: 14, weight: .medium))
                                        Spacer()
                                        Image(systemName: "arrow.down.circle")
                                            .foregroundColor(Color(hex: "8a8a8a"))
                                    }
                                    .foregroundColor(Color(hex: "f5f5f5"))
                                }
                                .disabled(cloudBackup.isRestoring)
                            }
                        }
                    } header: {
                        Text("Backup")
                            .foregroundColor(Color(hex: "8a8a8a"))
                    }
                    .listRowBackground(Color(hex: "141414"))

                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Your videos are stored locally on this device. iCloud backup is optional.")
                                .font(.system(size: 13))
                                .foregroundColor(Color(hex: "8a8a8a"))

                            Text("No accounts. No sharing. No social.")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(Color(hex: "f5f5f5"))
                        }
                        .padding(.vertical, 8)
                    } header: {
                        Text("Privacy")
                            .foregroundColor(Color(hex: "8a8a8a"))
                    }
                    .listRowBackground(Color(hex: "141414"))
                }
                .scrollContentBackground(.hidden)
                .listStyle(.insetGrouped)
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color(hex: "0a0a0a"), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .sheet(isPresented: $showAbout) {
                AboutView()
            }
            .sheet(isPresented: $showPricing) {
                PricingView()
            }
            .sheet(isPresented: $showStorageDashboard) {
                StorageDashboardView()
            }
            .sheet(isPresented: $showPasscodeSetup) {
                PasscodeSetupView(onComplete: {
                    showPasscodeSetup = false
                })
            }
            .confirmationDialog("Remove App Lock?", isPresented: $showPasscodeRemoveConfirm, titleVisibility: .visible) {
                Button("Remove App Lock", role: .destructive) {
                    privacy.removePasscode()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("You will no longer need to enter a passcode to open Blink.")
            }
            .confirmationDialog("Restore from iCloud?", isPresented: $showRestoreConfirm, titleVisibility: .visible) {
                Button("Restore", role: .destructive) {
                    startRestore()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will download your clips from iCloud. Existing clips will not be affected.")
            }
            .onDisappear {
                backupTask?.cancel()
                restoreTask?.cancel()
            }
        }
    }

    private var privacySection: some View {
        Section {
            if privacy.isPasscodeEnabled {
                // Biometric toggle
                if privacy.biometricType != .none {
                    Toggle(isOn: Binding(
                        get: { privacy.isBiometricEnabled },
                        set: { privacy.isBiometricEnabled = $0 }
                    )) {
                        Label(privacy.biometricType.displayName, systemImage: privacy.biometricType.iconName)
                            .foregroundColor(Color(hex: "f5f5f5"))
                    }
                    .tint(Color(hex: "ff3b30"))
                }

                // Lock on background toggle
                Toggle(isOn: Binding(
                    get: { privacy.lockOnBackground },
                    set: { privacy.lockOnBackground = $0 }
                )) {
                    Label("Lock when leaving app", systemImage: "lock.rotation")
                        .foregroundColor(Color(hex: "f5f5f5"))
                }
                .tint(Color(hex: "ff3b30"))

                // Change passcode
                Button {
                    showPasscodeSetup = true
                } label: {
                    HStack {
                        Label("Change Passcode", systemImage: "key.fill")
                            .foregroundColor(Color(hex: "f5f5f5"))

                        Spacer()
                    }
                }

                // Remove app lock
                Button(role: .destructive) {
                    showPasscodeRemoveConfirm = true
                } label: {
                    HStack {
                        Label("Remove App Lock", systemImage: "lock.open.fill")
                            .foregroundColor(Color(hex: "ff3b30"))

                        Spacer()
                    }
                }
            } else {
                // No passcode set - show enable button
                Button {
                    showPasscodeSetup = true
                } label: {
                    HStack {
                        Label("Enable App Lock", systemImage: "lock.fill")
                            .foregroundColor(Color(hex: "ff3b30"))

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Color(hex: "8a8a8a"))
                    }
                }
            }
        } header: {
            Text("Privacy & Security")
                .foregroundColor(Color(hex: "8a8a8a"))
        }
    }

    private func scheduleReminder() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["dailyBlink"])

        let content = UNMutableNotificationContent()
        content.title = "Blink today?"
        content.body = "Your year is waiting. Record a moment."
        content.sound = .default

        var dateComponents = DateComponents()
        dateComponents.hour = reminderHour
        dateComponents.minute = reminderMinute

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: "dailyBlink", content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to schedule notification: \(error)")
            }
        }
    }

    private func cancelReminder() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["dailyBlink"])
    }

    private func startBackup() {
        guard cloudBackup.iCloudAvailable else { return }
        backupTask = Task {
            do {
                try await cloudBackup.backupAllClips()
            } catch {
                backupError = error.localizedDescription
            }
        }
    }

    private func startRestore() {
        restoreTask = Task {
            do {
                try await cloudBackup.restoreClips()
            } catch {
                backupError = error.localizedDescription
            }
        }
    }
}

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "0a0a0a")
                    .ignoresSafeArea()

                VStack(spacing: 32) {
                    Spacer()

                    VStack(spacing: 16) {
                        Image(systemName: "video.circle.fill")
                            .font(.system(size: 80))
                            .foregroundColor(Color(hex: "ff3b30"))

                        Text("Blink")
                            .font(.system(size: 34, weight: .bold))
                            .foregroundColor(Color(hex: "f5f5f5"))

                        Text("Your year, one moment at a time.")
                            .font(.system(size: 17))
                            .foregroundColor(Color(hex: "8a8a8a"))
                    }

                    VStack(spacing: 8) {
                        Text("Version 1.0.0")
                            .font(.system(size: 13))
                            .foregroundColor(Color(hex: "8a8a8a"))

                        Text("Made with love")
                            .font(.system(size: 13))
                            .foregroundColor(Color(hex: "8a8a8a"))
                    }

                    Spacer()

                    Text("The opposite of TikTok.")
                        .font(.system(size: 15, weight: .medium).italic())
                        .foregroundColor(Color(hex: "f5f5f5"))
                        .padding(.bottom, 40)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(Color(hex: "ff3b30"))
                }
            }
        }
        .presentationDetents([.medium])
    }
}

#Preview {
    SettingsView()
        .preferredColorScheme(.dark)
}
