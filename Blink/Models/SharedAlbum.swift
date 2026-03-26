import Foundation

// MARK: - CloseCircle
/// A trusted circle of up to 10 people for shared album access
struct CloseCircle: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    var name: String
    var memberIDs: [String] // Device/user identifiers
    var ownerID: String
    var createdAt: Date
    var sharedAlbumID: UUID
    
    var isFull: Bool { memberIDs.count >= 10 }
    
    init(id: UUID = UUID(), name: String, memberIDs: [String] = [], ownerID: String, createdAt: Date = Date(), sharedAlbumID: UUID = UUID()) {
        self.id = id
        self.name = name
        self.memberIDs = memberIDs
        self.ownerID = ownerID
        self.createdAt = createdAt
        self.sharedAlbumID = sharedAlbumID
    }
    
    mutating func addMember(_ deviceID: String) {
        guard !isFull, !memberIDs.contains(deviceID) else { return }
        memberIDs.append(deviceID)
    }
    
    mutating func removeMember(_ deviceID: String) {
        memberIDs.removeAll { $0 == deviceID }
    }
}

// MARK: - SharedAlbum
/// A shared album containing clips from circle members
struct SharedAlbum: Identifiable, Codable, Equatable {
    let id: UUID
    var circleID: UUID
    var clipIDs: [UUID]
    var title: String
    var createdAt: Date
    var updatedAt: Date
    var onThisDayClipIDs: [UUID]
    var monthlyReelClipIDs: [UUID]
    
    init(id: UUID = UUID(), circleID: UUID, clipIDs: [UUID] = [], title: String = "Shared Album", createdAt: Date = Date(), updatedAt: Date = Date(), onThisDayClipIDs: [UUID] = [], monthlyReelClipIDs: [UUID] = []) {
        self.id = id
        self.circleID = circleID
        self.clipIDs = clipIDs
        self.title = title
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.onThisDayClipIDs = onThisDayClipIDs
        self.monthlyReelClipIDs = monthlyReelClipIDs
    }
    
    mutating func addClip(_ clipID: UUID) {
        guard !clipIDs.contains(clipID) else { return }
        clipIDs.append(clipID)
        updatedAt = Date()
    }
    
    mutating func removeClip(_ clipID: UUID) {
        clipIDs.removeAll { $0 == clipID }
        updatedAt = Date()
    }
}

// MARK: - CollaborativeAlbum
/// An album inviteable via link, any contributor can trim/favorite
struct CollaborativeAlbum: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    var creatorID: String
    var inviteLink: String
    var contributorIDs: [Contributor]
    var clipIDs: [UUID]
    var title: String
    var createdAt: Date
    var isActive: Bool
    
    struct Contributor: Identifiable, Codable, Equatable, Hashable {
        let id: UUID
        var deviceID: String
        var displayName: String
        var contributedClipIDs: [UUID]
        var joinedAt: Date
        
        init(id: UUID = UUID(), deviceID: String, displayName: String, contributedClipIDs: [UUID] = [], joinedAt: Date = Date()) {
            self.id = id
            self.deviceID = deviceID
            self.displayName = displayName
            self.contributedClipIDs = contributedClipIDs
            self.joinedAt = joinedAt
        }
    }
    
    init(id: UUID = UUID(), creatorID: String, inviteLink: String = "", contributorIDs: [Contributor] = [], clipIDs: [UUID] = [], title: String = "Collaborative Album", createdAt: Date = Date(), isActive: Bool = true) {
        self.id = id
        self.creatorID = creatorID
        self.inviteLink = inviteLink.isEmpty ? "https://blink.app/collab/\(id.uuidString)" : inviteLink
        self.contributorIDs = contributorIDs
        self.clipIDs = clipIDs
        self.title = title
        self.createdAt = createdAt
        self.isActive = isActive
    }
    
    mutating func addContributor(_ contributor: Contributor) {
        guard !contributorIDs.contains(where: { $0.deviceID == contributor.deviceID }) else { return }
        contributorIDs.append(contributor)
    }
    
    mutating func removeContributor(_ deviceID: String) {
        contributorIDs.removeAll { $0.deviceID == deviceID }
    }
    
    mutating func addClip(_ clipID: UUID) {
        guard !clipIDs.contains(clipID) else { return }
        clipIDs.append(clipID)
    }
    
    mutating func removeClip(_ clipID: UUID) {
        clipIDs.removeAll { $0 == clipID }
    }
    
    mutating func removeAnyClip(_ clipID: UUID) {
        removeClip(clipID)
        for i in contributorIDs.indices {
            contributorIDs[i].contributedClipIDs.removeAll { $0 == clipID }
        }
    }
}

// MARK: - PublicMoment
/// An anonymous public moment shared to the curated feed
struct PublicMoment: Identifiable, Codable, Equatable {
    let id: UUID
    var clipID: UUID
    var blurFaces: Bool
    var reactions: [Reaction]
    var weekNumber: Int
    var year: Int
    var sharedAt: Date
    var viewCount: Int
    var viewerIDs: [String] // anonymized
    
    struct Reaction: Identifiable, Codable, Equatable {
        let id: UUID
        var emoji: String
        var count: Int
        var reactorDeviceIDs: [String]
        
        init(id: UUID = UUID(), emoji: String, count: Int = 1, reactorDeviceIDs: [String] = []) {
            self.id = id
            self.emoji = emoji
            self.count = count
            self.reactorDeviceIDs = reactorDeviceIDs
        }
    }
    
    init(id: UUID = UUID(), clipID: UUID, blurFaces: Bool = true, reactions: [Reaction] = [], weekNumber: Int = Calendar.current.component(.weekOfYear, from: Date()), year: Int = Calendar.current.component(.year, from: Date()), sharedAt: Date = Date(), viewCount: Int = 0, viewerIDs: [String] = []) {
        self.id = id
        self.clipID = clipID
        self.blurFaces = blurFaces
        self.reactions = reactions
        self.weekNumber = weekNumber
        self.year = year
        self.sharedAt = sharedAt
        self.viewCount = viewCount
        self.viewerIDs = viewerIDs
    }
    
    var totalReactions: Int {
        reactions.reduce(0) { $0 + $1.count }
    }
    
    mutating func addReaction(_ emoji: String, from deviceID: String) {
        if let index = reactions.firstIndex(where: { $0.emoji == emoji }) {
            if !reactions[index].reactorDeviceIDs.contains(deviceID) {
                reactions[index].count += 1
                reactions[index].reactorDeviceIDs.append(deviceID)
            }
        } else {
            reactions.append(Reaction(emoji: emoji, reactorDeviceIDs: [deviceID]))
        }
    }
    
    mutating func recordView(from deviceID: String) {
        if !viewerIDs.contains(deviceID) {
            viewerIDs.append(deviceID)
            viewCount += 1
        }
    }
}

// MARK: - SharingSettings
/// Per-clip sharing configuration
struct SharingSettings: Codable, Equatable {
    enum ShareTarget: String, Codable, CaseIterable {
        case closeCircleOnly = "Close Circle Only"
        case specificPeople = "Specific People"
        case publicMoment = "Public (Anonymous)"
        case privateOnly = "Private"
    }
    
    var target: ShareTarget
    var circleIDs: [UUID]
    var specificDeviceIDs: [String]
    var faceBlurEnabled: Bool
    var autoShareEnabled: Bool // false = "Never share automatically"
    var sharingHistory: [ShareHistoryEntry]
    
    struct ShareHistoryEntry: Identifiable, Codable, Equatable {
        let id: UUID
        var viewerID: String
        var viewedAt: Date
        var shareType: String
        
        init(id: UUID = UUID(), viewerID: String, viewedAt: Date = Date(), shareType: String) {
            self.id = id
            self.viewerID = viewerID
            self.viewedAt = viewedAt
            self.shareType = shareType
        }
    }
    
    init(target: ShareTarget = .privateOnly, circleIDs: [UUID] = [], specificDeviceIDs: [String] = [], faceBlurEnabled: Bool = false, autoShareEnabled: Bool = false, sharingHistory: [ShareHistoryEntry] = []) {
        self.target = target
        self.circleIDs = circleIDs
        self.specificDeviceIDs = specificDeviceIDs
        self.faceBlurEnabled = faceBlurEnabled
        self.autoShareEnabled = autoShareEnabled
        self.sharingHistory = sharingHistory
    }
    
    mutating func recordView(from viewerID: String, shareType: String) {
        let entry = ShareHistoryEntry(viewerID: viewerID, shareType: shareType)
        sharingHistory.append(entry)
    }
}
