import AppIntents

struct ShowHighlightsIntent: AppIntent {
    static var title: LocalizedStringResource = "Show My Highlights"
    static var description = IntentDescription("Opens your AI-generated highlights reel.")

    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        DeepLinkHandler.shared.pendingDeepLink = .highlights
        return .result()
    }
}
