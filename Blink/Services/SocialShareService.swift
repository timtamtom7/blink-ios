import Foundation
import Contacts
import UIKit

/// Service for social sharing features:
/// - Private expiring links
/// - Share to contacts ("Blink to friends")
/// - Public feed (anonymized highlights)
final class SocialShareService: ObservableObject {
    static let shared = SocialShareService()

    @Published private(set) var sharedLinks: [SharedLink] = []

    private let linksFile: URL
    private let fileManager = FileManager.default

    private init() {
        let docsDir = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dataDir = docsDir.appendingPathComponent("BlinkData", isDirectory: true)
        try? fileManager.createDirectory(at: dataDir, withIntermediateDirectories: true)
        linksFile = dataDir.appendingPathComponent("shared_links.json")
        loadLinks()
    }

    // MARK: - Shared Link

    struct SharedLink: Identifiable, Codable {
        let id: UUID
        let entryId: UUID
        let createdAt: Date
        let expiresAt: Date
        var viewCount: Int
        let maxViews: Int

        var isExpired: Bool {
            Date() > expiresAt || viewCount >= maxViews
        }

        var shareURL: URL {
            // In a real app, this would be a backend-generated URL.
            // For now, encode link data as a custom URL scheme.
            var components = URLComponents()
            components.scheme = "blink"
            components.host = "share"
            components.queryItems = [
                URLQueryItem(name: "id", value: id.uuidString),
                URLQueryItem(name: "clip", value: entryId.uuidString)
            ]
            return components.url ?? URL(string: "blink://share")!
        }
    }

    /// Create a private expiring link for a clip.
    /// - Parameters:
    ///   - entry: The clip to share
    ///   - expiresIn: How long until the link expires (default 7 days)
    ///   - maxViews: Maximum number of views before auto-expire (default 3)
    /// - Returns: The generated SharedLink
    @discardableResult
    func createPrivateLink(
        for entry: VideoEntry,
        expiresIn: TimeInterval = 7 * 24 * 60 * 60,
        maxViews: Int = 3
    ) -> SharedLink {
        let link = SharedLink(
            id: UUID(),
            entryId: entry.id,
            createdAt: Date(),
            expiresAt: Date().addingTimeInterval(expiresIn),
            viewCount: 0,
            maxViews: maxViews
        )
        sharedLinks.append(link)
        saveLinks()
        return link
    }

    /// Record a view on a shared link.
    func recordView(linkId: UUID) {
        guard let index = sharedLinks.firstIndex(where: { $0.id == linkId }) else { return }
        sharedLinks[index].viewCount += 1
        saveLinks()
    }

    /// Remove a shared link.
    func revokeLink(linkId: UUID) {
        sharedLinks.removeAll { $0.id == linkId }
        saveLinks()
    }

    /// Get all active (non-expired) links for an entry.
    func activeLinks(for entryId: UUID) -> [SharedLink] {
        sharedLinks.filter { $0.entryId == entryId && !$0.isExpired }
    }

    /// Clean up expired links.
    func pruneExpiredLinks() {
        sharedLinks.removeAll { $0.isExpired }
        saveLinks()
    }

    // MARK: - Blink to Friends (Contact Sharing)

    enum ContactError: Error, LocalizedError {
        case accessDenied
        case notAuthorized
        case noContacts
        case shareFailed

        var errorDescription: String? {
            switch self {
            case .accessDenied: return "Contacts access denied. Enable in Settings > Blink > Contacts."
            case .notAuthorized: return "Not authorized to send messages."
            case .noContacts: return "No contacts found."
            case .shareFailed: return "Failed to share clip."
            }
        }
    }

    /// Request contacts access.
    func requestContactsAccess() async -> Bool {
        await withCheckedContinuation { continuation in
            CNContactStore().requestAccess(for: .contacts) { _, _ in
                continuation.resume(returning: true)
            }
        }
    }

    /// Fetch recent contacts for quick sharing via CNContactPicker.
    /// Returns a placeholder list — actual contact picking uses CNContactPickerViewController.
    func fetchRecentContacts(limit: Int = 20) async throws -> [CNContact] {
        let status = CNContactStore.authorizationStatus(for: .contacts)
        guard status == .authorized else {
            throw ContactError.accessDenied
        }

        // Return empty — actual picking is done via CNContactPickerViewController in the UI layer
        return []
    }

    /// Share a clip via Messages (SMS) to a contact.
    @MainActor
    func shareViaMessages(to contact: CNContact, entry: VideoEntry) async throws {
        let link = createPrivateLink(for: entry)

        // Try Messages share via URL scheme
        let messageText = "Blink: \(entry.displayTitle)\n\n\(link.shareURL.absoluteString)"

        // Check if we can open the messages app
        let phoneNumber = contact.phoneNumbers.first?.value.stringValue ?? ""
        let encodedBody = messageText.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? messageText
        if let smsURL = URL(string: "sms:\(phoneNumber)&body=\(encodedBody)") {
            // Note: actual SMS sending requires MFMessageComposeViewController (not available in SwiftUI easily)
            // We'll copy to clipboard and let the user send manually
            UIPasteboard.general.string = messageText
        }
    }

    /// Copy share text to clipboard.
    func copyShareText(for entry: VideoEntry) {
        let link = createPrivateLink(for: entry)
        let text = "My Blink moment: \(entry.displayTitle)\n\(link.shareURL.absoluteString)"
        UIPasteboard.general.string = text
    }

    // MARK: - Public Feed

    /// Submit a clip to the public feed (anonymized).
    /// Only submits non-locked, non-titled clips. No faces, no names.
    func submitToPublicFeed(entry: VideoEntry) async throws {
        // In a real app, this would upload to a backend.
        // The entry would be stripped of: title, locked status, exact date → only month/year
        // Thumbnails would be blurred/scrubbed of identifiable info
        // For now, this is a no-op placeholder
        guard !entry.isLocked else { return }
    }

    /// Fetch public feed highlights (anonymized clips from all users).
    func fetchPublicFeed() async throws -> [PublicFeedItem] {
        // In a real app, this would fetch from a backend.
        // For now, return local clips as placeholders (anonymized)
        return VideoStore.shared.entries
            .filter { !$0.isLocked }
            .prefix(10)
            .map { entry in
                PublicFeedItem(
                    id: entry.id,
                    monthYear: entry.date,
                    clipCount: 1,
                    previewThumbnail: entry.thumbnailFilename,
                    insightText: insightForEntry(entry)
                )
            }
    }

    struct PublicFeedItem: Identifiable {
        let id: UUID
        let monthYear: Date
        let clipCount: Int
        let previewThumbnail: String?
        let insightText: String

        var monthYearText: String {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMMM yyyy"
            return formatter.string(from: monthYear)
        }
    }

    private func insightForEntry(_ entry: VideoEntry) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        let dayName = formatter.string(from: entry.date)

        let insights = [
            "A moment on a Thursday afternoon.",
            "Captured on a busy \(dayName).",
            "A quiet moment, preserved.",
            "Something worth remembering.",
            "One second of real life."
        ]
        return insights.randomElement() ?? "A meaningful moment."
    }

    // MARK: - Persistence

    private func saveLinks() {
        do {
            let data = try JSONEncoder().encode(sharedLinks)
            try data.write(to: linksFile)
        } catch {
            print("Failed to save shared links: \(error)")
        }
    }

    private func loadLinks() {
        guard fileManager.fileExists(atPath: linksFile.path) else { return }
        do {
            let data = try Data(contentsOf: linksFile)
            sharedLinks = try JSONDecoder().decode([SharedLink].self, from: data)
        } catch {
            print("Failed to load shared links: \(error)")
        }
    }
}
