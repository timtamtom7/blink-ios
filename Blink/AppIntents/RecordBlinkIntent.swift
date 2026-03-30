import AppIntents

struct RecordBlinkIntent: AppIntent {
    static var title: LocalizedStringResource = "Record a Blink"
    static var description = IntentDescription("Opens Blink to record a new video message.")

    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        DeepLinkHandler.shared.pendingDeepLink = .record
        return .result()
    }
}
