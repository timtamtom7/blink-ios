import SwiftUI

struct ContentView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("hasSeenPricing") private var hasSeenPricing = false
    @AppStorage("hasAcknowledgedFreemiumToday") private var hasAcknowledgedFreemiumToday = false
    @AppStorage("freemiumAcknowledgedDate") private var freemiumAcknowledgedDate: String = ""
    @State private var showPricing = false
    @State private var showFreemium = false
    @State private var selectedTab: Tab = .record
    @State private var selectedPlaybackEntry: VideoEntry?
    @ObservedObject private var videoStore = VideoStore.shared
    @ObservedObject private var privacy = PrivacyService.shared
    @ObservedObject private var subscription = SubscriptionService.shared
    @Environment(\.scenePhase) private var scenePhase
    @State private var wasInBackground = false

    // Deep link state
    @State private var deepLinkShowHighlights = false
    @State private var deepLinkShowOnThisDay = false
    @State private var deepLinkShareEntry: VideoEntry?

    private var isNewDay: Bool {
        let today = Calendar.current.startOfDay(for: Date()).formatted(date: .numeric, time: .omitted)
        return freemiumAcknowledgedDate != today
    }

    enum Tab {
        case record
        case calendar
        case settings
    }

    var body: some View {
        Group {
            if !hasCompletedOnboarding {
                OnboardingView()
            } else {
                mainTabView
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            // Reset freemium acknowledgment if it's a new day
            if isNewDay {
                hasAcknowledgedFreemiumToday = false
                freemiumAcknowledgedDate = Calendar.current.startOfDay(for: Date()).formatted(date: .numeric, time: .omitted)
            }
            // Check if app should be locked on launch
            if privacy.isPasscodeEnabled {
                privacy.lockApp(reason: .appOpen)
            }
            // Show freemium enforcement once per day for free users
            if !hasAcknowledgedFreemiumToday && subscription.currentTier == .free {
                showFreemium = true
            }
        }
        .task {
            // Show pricing once after onboarding (with delay to not interrupt UX)
            try? await Task.sleep(nanoseconds: 500_000_000)
            if hasCompletedOnboarding && !hasSeenPricing {
                showPricing = true
                hasSeenPricing = true
            }
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            // Lock app when going to background
            if newPhase == .background && oldPhase == .active {
                wasInBackground = true
                if privacy.isPasscodeEnabled && privacy.lockOnBackground {
                    privacy.lockApp(reason: .backgroundReturn)
                }
            }
            // Try biometric on return from background
            if newPhase == .active && wasInBackground {
                wasInBackground = false
                if privacy.isPasscodeEnabled && privacy.isAppLocked {
                    Task {
                        await privacy.unlockWithBiometrics()
                    }
                }
            }
        }
        .onChange(of: DeepLinkHandler.shared.pendingDeepLink) { _, newValue in
            guard let link = newValue else { return }
            switch link {
            case .share(let clipId):
                if let entry = videoStore.entries.first(where: { $0.id == clipId }) {
                    deepLinkShareEntry = entry
                }
            case .highlights:
                selectedTab = .calendar
                deepLinkShowHighlights = true
            case .onThisDay:
                selectedTab = .calendar
                deepLinkShowOnThisDay = true
            case .record:
                selectedTab = .record
            case .home:
                selectedTab = .record
            }
            DeepLinkHandler.shared.clearPending()
        }
        .fullScreenCover(item: $deepLinkShareEntry) { entry in
            PlaybackView(entry: entry, onDelete: { })
                .environmentObject(videoStore)
        }
        .sheet(isPresented: $showPricing) {
            PricingView()
        }
        .overlay {
            if privacy.isAppLocked && privacy.isPasscodeEnabled {
                PrivacyLockView()
                    .transition(.opacity)
            }
        }
        .overlay {
            if showFreemium {
                FreemiumEnforcementView(
                    reason: "You've used your daily clip on the Free plan. Upgrade to record unlimited moments.",
                    onUpgrade: {
                        showFreemium = false
                        showPricing = true
                    },
                    onDismiss: {
                        hasAcknowledgedFreemiumToday = true
                        freemiumAcknowledgedDate = Calendar.current.startOfDay(for: Date()).formatted(date: .numeric, time: .omitted)
                        showFreemium = false
                    }
                )
                .transition(.opacity)
            }
        }
    }

    private var mainTabView: some View {
        TabView(selection: $selectedTab) {
            RecordView()
                .tabItem {
                    Label("Record", systemImage: "video.fill")
                }
                .tag(Tab.record)
                .accessibilityLabel("Record tab")

            CalendarView(showHighlightsBinding: $deepLinkShowHighlights, showOnThisDayBinding: $deepLinkShowOnThisDay)
                .tabItem {
                    Label("Calendar", systemImage: "calendar")
                }
                .tag(Tab.calendar)
                .accessibilityLabel("Calendar tab")

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
                .tag(Tab.settings)
                .accessibilityLabel("Settings tab")
        }
        .tint(Color("AccentColor"))
        .onChange(of: selectedTab) { _, newTab in
            HapticService.shared.selectionChanged()
            // Show pricing when navigating to calendar if they haven't used the app much
            if newTab == .calendar {
                let clipCount = videoStore.clipCountThisYear()
                if clipCount >= 3 && !UserDefaults.standard.bool(forKey: "hasSeenPricingAfterClips") {
                    UserDefaults.standard.set(true, forKey: "hasSeenPricingAfterClips")
                    // Show pricing after 3 clips as a gentle nudge
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        showPricing = true
                    }
                }
            }
        }
    }
}

#Preview {
    ContentView()
        .preferredColorScheme(.dark)
}
