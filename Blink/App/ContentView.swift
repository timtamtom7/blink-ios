import SwiftUI

struct ContentView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("hasSeenPricing") private var hasSeenPricing = false
    @State private var showPricing = false
    @State private var selectedTab: Tab = .record
    @State private var selectedPlaybackEntry: VideoEntry?
    @ObservedObject private var videoStore = VideoStore.shared

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
            // Show pricing once after onboarding (with delay to not interrupt UX)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                if hasCompletedOnboarding && !hasSeenPricing {
                    showPricing = true
                    hasSeenPricing = true
                }
            }
        }
        .sheet(isPresented: $showPricing) {
            PricingView()
        }
    }

    private var mainTabView: some View {
        TabView(selection: $selectedTab) {
            RecordView()
                .tabItem {
                    Label("Record", systemImage: "video.fill")
                }
                .tag(Tab.record)

            CalendarView()
                .tabItem {
                    Label("Calendar", systemImage: "calendar")
                }
                .tag(Tab.calendar)

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
                .tag(Tab.settings)
        }
        .tint(Color("AccentColor"))
        .onChange(of: selectedTab) { _, newTab in
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
