import Foundation

// MARK: - Cross-Platform Sync
// R15: Android, Cross-Platform Sync, Export Hub

/// Cross-platform device registration
struct CrossPlatformDevice: Identifiable, Codable, Equatable {
    let id: UUID
    var deviceName: String
    var platform: Platform
    var lastSyncAt: Date
    var clipCount: Int
    var isPrimary: Bool
    
    enum Platform: String, Codable, CaseIterable {
        case ios = "iOS"
        case android = "Android"
        case web = "Web"
        case tvOS = "Apple TV"
        case watchOS = "watchOS"
    }
    
    init(id: UUID = UUID(), deviceName: String, platform: Platform, lastSyncAt: Date = Date(), clipCount: Int = 0, isPrimary: Bool = false) {
        self.id = id
        self.deviceName = deviceName
        self.platform = platform
        self.lastSyncAt = lastSyncAt
        self.clipCount = clipCount
        self.isPrimary = isPrimary
    }
}

/// Unified timeline entry (clips from all platforms)
struct UnifiedTimelineEntry: Identifiable, Codable, Equatable {
    let id: UUID
    let clipID: UUID
    let sourceDeviceID: UUID
    let platform: CrossPlatformDevice.Platform
    let capturedAt: Date
    let syncedAt: Date
    
    init(id: UUID = UUID(), clipID: UUID, sourceDeviceID: UUID, platform: CrossPlatformDevice.Platform, capturedAt: Date, syncedAt: Date = Date()) {
        self.id = id
        self.clipID = clipID
        self.sourceDeviceID = sourceDeviceID
        self.platform = platform
        self.capturedAt = capturedAt
        self.syncedAt = syncedAt
    }
}

/// Conflict resolution for cross-platform sync
struct SyncConflict: Identifiable, Codable, Equatable {
    let id: UUID
    let clipID: UUID
    var localVersion: SyncVersion
    var remoteVersion: SyncVersion
    var detectedAt: Date
    var resolution: Resolution?
    
    struct SyncVersion: Codable, Equatable {
        let deviceID: UUID
        let capturedAt: Date
        let fileSize: Int64
        let checksum: String
    }
    
    enum Resolution: String, Codable {
        case keepLocal = "Keep Local"
        case keepRemote = "Keep Remote"
        case keepBoth = "Keep Both"
        case autoLatest = "Latest Wins"
    }
    
    init(id: UUID = UUID(), clipID: UUID, localVersion: SyncVersion, remoteVersion: SyncVersion, detectedAt: Date = Date(), resolution: Resolution? = nil) {
        self.id = id
        self.clipID = clipID
        self.localVersion = localVersion
        self.remoteVersion = remoteVersion
        self.detectedAt = detectedAt
        self.resolution = resolution
    }
}

/// Export job
struct ExportJob: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var clipIDs: [UUID]
    var format: ExportFormat
    var status: Status
    var progress: Double
    var startedAt: Date?
    var completedAt: Date?
    var outputURL: String?
    var error: String?
    
    enum Status: String, Codable {
        case pending = "Pending"
        case processing = "Processing"
        case completed = "Completed"
        case failed = "Failed"
    }
    
    init(id: UUID = UUID(), name: String, clipIDs: [UUID] = [], format: ExportFormat = ExportFormat(), status: Status = .pending, progress: Double = 0, startedAt: Date? = nil, completedAt: Date? = nil, outputURL: String? = nil, error: String? = nil) {
        self.id = id
        self.name = name
        self.clipIDs = clipIDs
        self.format = format
        self.status = status
        self.progress = progress
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.outputURL = outputURL
        self.error = error
    }
}

/// Google Photos integration
struct GooglePhotosIntegration: Codable, Equatable {
    var isEnabled: Bool
    var autoBackup: Bool
    var lastBackupAt: Date?
    var backupFolderName: String
    
    init(isEnabled: Bool = false, autoBackup: Bool = false, lastBackupAt: Date? = nil, backupFolderName: String = "Blink") {
        self.isEnabled = isEnabled
        self.autoBackup = autoBackup
        self.lastBackupAt = lastBackupAt
        self.backupFolderName = backupFolderName
    }
}
