import Foundation
import SwiftUI

/// Handles deep links from `blink://` URL scheme.
/// Routes to appropriate views: share clips, home, on-this-day, etc.
final class DeepLinkHandler: ObservableObject {
    static let shared = DeepLinkHandler()

    @Published var pendingDeepLink: DeepLink?

    enum DeepLink: Equatable {
        case share(clipId: UUID)
        case home
        case onThisDay(date: Date?)
        case record
        case highlights
    }

    private init() {}

    /// Called from BlinkApp.onOpenURL
    func handle(_ url: URL) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              components.scheme == "blink" else { return }

        switch components.host {
        case "share":
            handleShare(components)
        case "home":
            pendingDeepLink = .home
        case "record":
            pendingDeepLink = .record
        case "highlights":
            pendingDeepLink = .highlights
        case "onthisday":
            handleOnThisDay(components)
        default:
            break
        }
    }

    private func handleShare(_ components: URLComponents) {
        guard let queryItems = components.queryItems,
              let clipIdString = queryItems.first(where: { $0.name == "clip" })?.value,
              let clipId = UUID(uuidString: clipIdString) else { return }
        pendingDeepLink = .share(clipId: clipId)
    }

    private func handleOnThisDay(_ components: URLComponents) {
        let date: Date?
        if let dateString = components.queryItems?.first(where: { $0.name == "date" })?.value {
            let formatter = ISO8601DateFormatter()
            date = formatter.date(from: dateString)
        } else {
            date = nil
        }
        pendingDeepLink = .onThisDay(date: date)
    }

    /// Reset the pending deep link after it's consumed.
    func clearPending() {
        pendingDeepLink = nil
    }
}
