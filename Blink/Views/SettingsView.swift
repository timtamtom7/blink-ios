import SwiftUI
import UserNotifications

struct SettingsView: View {
    @AppStorage("dailyReminderEnabled") private var dailyReminderEnabled = false
    @AppStorage("reminderHour") private var reminderHour = 20
    @AppStorage("reminderMinute") private var reminderMinute = 0
    @AppStorage("videoQuality") private var videoQuality = "high"

    @ObservedObject private var privacy = PrivacyService.shared
    @State private var showAbout = false
    @State private var showPricing = false
    @State private var showPasscodeSetup = false
    @State private var showPasscodeRemoveConfirm = false

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

                        Link(destination: URL(string: "https://example.com/privacy")!) {
                            Label("Privacy Policy", systemImage: "hand.raised.fill")
                                .foregroundColor(Color(hex: "f5f5f5"))
                        }
                    } header: {
                        Text("About")
                            .foregroundColor(Color(hex: "8a8a8a"))
                    }
                    .listRowBackground(Color(hex: "141414"))

                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Your videos are stored locally on this device only.")
                                .font(.system(size: 13))
                                .foregroundColor(Color(hex: "8a8a8a"))

                            Text("No cloud. No accounts. No sharing.")
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
