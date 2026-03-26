import Foundation
import Combine
import UIKit

/// Service for managing Close Circle and Shared Albums
final class SharedAlbumService: ObservableObject {
    static let shared = SharedAlbumService()
    
    @Published var circles: [CloseCircle] = []
    @Published var sharedAlbums: [SharedAlbum] = []
    @Published var collaborativeAlbums: [CollaborativeAlbum] = []
    @Published var publicMoments: [PublicMoment] = []
    
    private let deviceID: String
    private let userDefaults = UserDefaults.standard
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        self.deviceID = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        loadFromDisk()
    }
    
    // MARK: - Close Circle
    
    func createCircle(name: String) -> CloseCircle {
        let circle = CloseCircle(name: name, memberIDs: [deviceID], ownerID: deviceID)
        circles.append(circle)
        
        // Auto-create shared album for circle
        let album = SharedAlbum(circleID: circle.id, title: "\(name) Album")
        sharedAlbums.append(album)
        
        saveToDisk()
        return circle
    }
    
    func joinCircle(inviteCode: String) -> Bool {
        // In real implementation, resolve invite code to circle
        // For now, return false as this would need backend
        return false
    }
    
    func leaveCircle(_ circleID: UUID) {
        guard let index = circles.firstIndex(where: { $0.id == circleID }) else { return }
        var circle = circles[index]
        circle.removeMember(deviceID)
        
        if circle.memberIDs.isEmpty {
            circles.remove(at: index)
            sharedAlbums.removeAll { $0.circleID == circleID }
        } else {
            circles[index] = circle
        }
        saveToDisk()
    }
    
    func addMemberToCircle(_ circleID: UUID, deviceID: String) {
        guard let index = circles.firstIndex(where: { $0.id == circleID }) else { return }
        circles[index].addMember(deviceID)
        saveToDisk()
    }
    
    func sharedAlbum(for circleID: UUID) -> SharedAlbum? {
        sharedAlbums.first { $0.circleID == circleID }
    }
    
    // MARK: - Collaborative Albums
    
    func createCollaborativeAlbum(title: String) -> CollaborativeAlbum {
        var album = CollaborativeAlbum(creatorID: deviceID, title: title)
        let ownerContributor = CollaborativeAlbum.Contributor(deviceID: deviceID, displayName: "You")
        album.addContributor(ownerContributor)
        collaborativeAlbums.append(album)
        saveToDisk()
        return album
    }
    
    func joinCollaborativeAlbum(via link: String) -> CollaborativeAlbum? {
        // Resolve link to album ID
        guard let albumID = extractAlbumID(from: link) else { return nil }
        guard var album = collaborativeAlbums.first(where: { $0.id == albumID }) else { return nil }
        
        let contributor = CollaborativeAlbum.Contributor(deviceID: deviceID, displayName: "Guest")
        album.addContributor(contributor)
        
        if let index = collaborativeAlbums.firstIndex(where: { $0.id == albumID }) {
            collaborativeAlbums[index] = album
        }
        saveToDisk()
        return album
    }
    
    func addClipToCollaborativeAlbum(_ albumID: UUID, clipID: UUID) {
        guard let index = collaborativeAlbums.firstIndex(where: { $0.id == albumID }) else { return }
        collaborativeAlbums[index].addClip(clipID)
        saveToDisk()
    }
    
    func removeClipFromCollaborativeAlbum(_ albumID: UUID, clipID: UUID, by moderatorID: String) {
        guard let index = collaborativeAlbums.firstIndex(where: { $0.id == albumID }) else { return }
        var album = collaborativeAlbums[index]
        
        // Moderator can remove any clip
        if moderatorID == album.creatorID {
            album.removeAnyClip(clipID)
        } else {
            // Regular contributor can only remove own clips
            if let contributorIndex = album.contributorIDs.firstIndex(where: { $0.deviceID == deviceID }) {
                let contributor = album.contributorIDs[contributorIndex]
                if contributor.contributedClipIDs.contains(clipID) {
                    album.removeClip(clipID)
                    album.contributorIDs[contributorIndex].contributedClipIDs.removeAll { $0 == clipID }
                }
            }
        }
        collaborativeAlbums[index] = album
        saveToDisk()
    }
    
    // MARK: - Public Moments
    
    func shareAsPublicMoment(clipID: UUID, blurFaces: Bool) -> PublicMoment {
        let moment = PublicMoment(clipID: clipID, blurFaces: blurFaces)
        publicMoments.insert(moment, at: 0)
        saveToDisk()
        return moment
    }
    
    func reactToMoment(_ momentID: UUID, with emoji: String) {
        guard let index = publicMoments.firstIndex(where: { $0.id == momentID }) else { return }
        publicMoments[index].addReaction(emoji, from: deviceID)
        saveToDisk()
    }
    
    func recordMomentView(_ momentID: UUID) {
        guard let index = publicMoments.firstIndex(where: { $0.id == momentID }) else { return }
        publicMoments[index].recordView(from: deviceID)
        saveToDisk()
    }
    
    func weeklyHighlightMoments() -> [PublicMoment] {
        let currentWeek = Calendar.current.component(.weekOfYear, from: Date())
        let currentYear = Calendar.current.component(.year, from: Date())
        return publicMoments
            .filter { $0.weekNumber == currentWeek && $0.year == currentYear }
            .sorted { $0.totalReactions > $1.totalReactions }
            .prefix(10)
            .map { $0 }
    }
    
    // MARK: - Privacy
    
    func recordSharingHistory(clipID: UUID, viewerID: String, shareType: String) {
        // Update sharing history for clip - handled at VideoEntry level
        NotificationCenter.default.post(name: .sharingHistoryUpdated, object: nil, userInfo: ["clipID": clipID, "viewerID": viewerID, "shareType": shareType])
    }
    
    // MARK: - Persistence
    
    private func saveToDisk() {
        if let circlesData = try? JSONEncoder().encode(circles) {
            userDefaults.set(circlesData, forKey: "blink_circles")
        }
        if let albumsData = try? JSONEncoder().encode(sharedAlbums) {
            userDefaults.set(albumsData, forKey: "blink_shared_albums")
        }
        if let collabData = try? JSONEncoder().encode(collaborativeAlbums) {
            userDefaults.set(collabData, forKey: "blink_collaborative_albums")
        }
        if let momentsData = try? JSONEncoder().encode(publicMoments) {
            userDefaults.set(momentsData, forKey: "blink_public_moments")
        }
    }
    
    private func loadFromDisk() {
        if let data = userDefaults.data(forKey: "blink_circles"),
           let decoded = try? JSONDecoder().decode([CloseCircle].self, from: data) {
            circles = decoded
        }
        if let data = userDefaults.data(forKey: "blink_shared_albums"),
           let decoded = try? JSONDecoder().decode([SharedAlbum].self, from: data) {
            sharedAlbums = decoded
        }
        if let data = userDefaults.data(forKey: "blink_collaborative_albums"),
           let decoded = try? JSONDecoder().decode([CollaborativeAlbum].self, from: data) {
            collaborativeAlbums = decoded
        }
        if let data = userDefaults.data(forKey: "blink_public_moments"),
           let decoded = try? JSONDecoder().decode([PublicMoment].self, from: data) {
            publicMoments = decoded
        }
    }
    
    private func extractAlbumID(from link: String) -> UUID? {
        guard let url = URL(string: link),
              let host = url.pathComponents.last,
              let id = UUID(uuidString: host) else { return nil }
        return id
    }
}

extension Notification.Name {
    static let sharingHistoryUpdated = Notification.Name("sharingHistoryUpdated")
}
