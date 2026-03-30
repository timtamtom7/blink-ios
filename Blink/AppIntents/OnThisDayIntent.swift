import AppIntents

struct OnThisDayIntent: AppIntent {
    static var title: LocalizedStringResource = "On This Day"
    static var description = IntentDescription("Shows moments you recorded on this day in previous years.")

    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        DeepLinkHandler.shared.pendingDeepLink = .onThisDay(date: nil)
        return .result()
    }
}
