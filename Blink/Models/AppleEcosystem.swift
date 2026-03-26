import Foundation

// MARK: - AppleEcosystem
// R13: watchOS, visionOS, tvOS, iPad Multi-Cam support

/// Represents a clip optimized for Apple Watch viewing
struct WatchClip: Identifiable, Codable, Equatable {
    let id: UUID
    let originalClipID: UUID
    var watchThumbnailFilename: String
    var duration: TimeInterval // Shortened for watch
    var isMemoryOfTheDay: Bool
    var recordedAt: Date
    
    init(id: UUID = UUID(), originalClipID: UUID, watchThumbnailFilename: String = "", duration: TimeInterval = 10, isMemoryOfTheDay: Bool = false, recordedAt: Date = Date()) {
        self.id = id
        self.originalClipID = originalClipID
        self.watchThumbnailFilename = watchThumbnailFilename
        self.duration = duration
        self.isMemoryOfTheDay = isMemoryOfTheDay
        self.recordedAt = recordedAt
    }
}

/// Remote control command from watch to iPhone
struct RemoteRecordCommand: Codable, Equatable {
    enum Command: String, Codable {
        case startRecording
        case stopRecording
        case hapticCapture // 10s instant capture
    }
    
    let command: Command
    let issuedAt: Date
    let watchDeviceID: String
    
    init(command: Command, watchDeviceID: String, issuedAt: Date = Date()) {
        self.command = command
        self.watchDeviceID = watchDeviceID
        self.issuedAt = issuedAt
    }
}

/// Spatial Memory for visionOS
struct SpatialMemory: Identifiable, Codable, Equatable {
    let id: UUID
    var clipID: UUID
    var spatialAnchorID: String? // ARKit anchor for location-based placement
    var locationName: String?
    var latitude: Double?
    var longitude: Double?
    var memoryRoomEnabled: Bool
    var createdAt: Date
    
    init(id: UUID = UUID(), clipID: UUID, spatialAnchorID: String? = nil, locationName: String? = nil, latitude: Double? = nil, longitude: Double? = nil, memoryRoomEnabled: Bool = false, createdAt: Date = Date()) {
        self.id = id
        self.clipID = clipID
        self.spatialAnchorID = spatialAnchorID
        self.locationName = locationName
        self.latitude = latitude
        self.longitude = longitude
        self.memoryRoomEnabled = memoryRoomEnabled
        self.createdAt = createdAt
    }
}

/// Apple TV Family Room configuration
struct AppleTVFamilyRoom: Identifiable, Codable, Equatable {
    let id: UUID
    var familyMemberIDs: [String]
    var screensaverSource: ScreensaverSource
    var autoUpdate: Bool
    var lastSyncAt: Date
    
    enum ScreensaverSource: String, Codable, CaseIterable {
        case aiCurated = "AI Curated"
        case recentClips = "Recent Clips"
        case specificAlbums = "Specific Albums"
        case onThisDay = "On This Day"
    }
    
    init(id: UUID = UUID(), familyMemberIDs: [String] = [], screensaverSource: ScreensaverSource = .aiCurated, autoUpdate: Bool = true, lastSyncAt: Date = Date()) {
        self.id = id
        self.familyMemberIDs = familyMemberIDs
        self.screensaverSource = screensaverSource
        self.autoUpdate = autoUpdate
        self.lastSyncAt = lastSyncAt
    }
}

/// iPad Multi-Cam Session
struct MultiCamSession: Identifiable, Codable, Equatable {
    let id: UUID
    var connectedDeviceIDs: [String] // iPhone device IDs on local network
    var status: SessionStatus
    var sessionClips: [UUID] // Combined timeline clips
    var startedAt: Date
    var endedAt: Date?
    
    enum SessionStatus: String, Codable {
        case searching
        case connected
        case recording
        case processing
        case completed
    }
    
    init(id: UUID = UUID(), connectedDeviceIDs: [String] = [], status: SessionStatus = .searching, sessionClips: [UUID] = [], startedAt: Date = Date(), endedAt: Date? = nil) {
        self.id = id
        self.connectedDeviceIDs = connectedDeviceIDs
        self.status = status
        self.sessionClips = sessionClips
        self.startedAt = startedAt
        self.endedAt = endedAt
    }
}
