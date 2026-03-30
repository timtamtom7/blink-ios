import AppIntents

struct BlinkShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: RecordBlinkIntent(),
            phrases: [
                "Record a blink in \(.applicationName)",
                "Record a moment in \(.applicationName)",
                "Record video in \(.applicationName)"
            ],
            shortTitle: "Record Blink",
            systemImageName: "video.fill"
        )
        AppShortcut(
            intent: ShowHighlightsIntent(),
            phrases: [
                "Show my highlights in \(.applicationName)",
                "Show highlights from \(.applicationName)",
                "View highlights in \(.applicationName)"
            ],
            shortTitle: "Show Highlights",
            systemImageName: "sparkles"
        )
        AppShortcut(
            intent: OnThisDayIntent(),
            phrases: [
                "On this day in \(.applicationName)",
                "Show on this day in \(.applicationName)",
                "Memories from this day in \(.applicationName)"
            ],
            shortTitle: "On This Day",
            systemImageName: "clock.fill"
        )
    }
}
