import Foundation

// MARK: - WebPlatform
// R14: Web App, Developer API, Widgets

/// API credentials for developer access
struct BlinkAPICredentials: Codable, Equatable {
    let clientID: String
    var accessToken: String
    var refreshToken: String?
    var expiresAt: Date?
    var tier: APITier
    
    enum APITier: String, Codable, CaseIterable {
        case free = "Free"
        case pro = "Pro Partner"
        
        var rateLimit: Int {
            switch self {
            case .free: return 1000 // req/hour
            case .pro: return Int.max
            }
        }
    }
    
    init(clientID: String = UUID().uuidString, accessToken: String = "", refreshToken: String? = nil, expiresAt: Date? = nil, tier: APITier = .free) {
        self.clientID = clientID
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.expiresAt = expiresAt
        self.tier = tier
    }
}

/// Developer API endpoints configuration
struct BlinkAPIConfig: Codable, Equatable {
    static let baseURL = "https://api.blink.app/v1"
    
    enum Endpoint: String {
        case listClips = "/clips"
        case getClip = "/clips/{id}"
        case uploadClip = "/clips/upload"
        case deleteClip = "/clips/{id}/delete"
        case getMetadata = "/clips/{id}/metadata"
    }
    
    var credentials: BlinkAPICredentials
    
    func url(for endpoint: Endpoint, clipID: UUID? = nil) -> URL? {
        var path = endpoint.rawValue
        if let id = clipID {
            path = path.replacingOccurrences(of: "{id}", with: id.uuidString)
        }
        return URL(string: BlinkAPIConfig.baseURL + path)
    }
}

/// Widget kind for home screen / lock screen
struct BlinkWidgetKind: Codable, Equatable {
    enum Kind: String, Codable {
        case memoryOfTheDay = "Memory of the Day"
        case recentClips = "Recent Clips"
        case calendarPreview = "Calendar Preview"
        case lockScreenCompact = "Lock Screen Compact"
    }
    
    let kind: Kind
    var clipID: UUID?
    var clipCount: Int?
    var date: Date?
}

/// Web session for blink.app
struct WebSession: Identifiable, Codable, Equatable {
    let id: UUID
    var userID: String
    var accessToken: String
    var expiresAt: Date
    var isPro: Bool
    
    init(id: UUID = UUID(), userID: String, accessToken: String = UUID().uuidString, expiresAt: Date = Calendar.current.date(byAdding: .hour, value: 24, to: Date()) ?? Date(), isPro: Bool = false) {
        self.id = id
        self.userID = userID
        self.accessToken = accessToken
        self.expiresAt = expiresAt
        self.isPro = isPro
    }
    
    var isExpired: Bool {
        Date() > expiresAt
    }
}

/// Shared Album web view access
struct SharedAlbumWebAccess: Identifiable, Codable, Equatable {
    let id: UUID
    var albumID: UUID
    var viewToken: String // Private link token
    var allowDownload: Bool
    var createdAt: Date
    var expiresAt: Date?
    
    init(id: UUID = UUID(), albumID: UUID, viewToken: String = UUID().uuidString, allowDownload: Bool = false, createdAt: Date = Date(), expiresAt: Date? = nil) {
        self.id = id
        self.albumID = albumID
        self.viewToken = viewToken
        self.allowDownload = allowDownload
        self.createdAt = createdAt
        self.expiresAt = expiresAt
    }
    
    var webURL: String {
        "https://blink.app/shared/\(viewToken)"
    }
}

/// Export format options
struct ExportFormat: Codable, Equatable {
    enum Format: String, Codable, CaseIterable {
        case original = "Original"
        case compressed = "Compressed"
        case gif = "GIF (Still Frame)"
        case stillImage = "Still Image"
    }
    
    enum Destination: String, Codable, CaseIterable {
        case icloud = "iCloud"
        case googleDrive = "Google Drive"
        case dropbox = "Dropbox"
        case externalDrive = "External Drive"
        case device = "Device"
    }
    
    var format: Format
    var destination: Destination
    var quality: Double // 0.0-1.0
    var includeMetadata: Bool
    
    init(format: Format = .original, destination: Destination = .device, quality: Double = 1.0, includeMetadata: Bool = true) {
        self.format = format
        self.destination = destination
        self.quality = quality
        self.includeMetadata = includeMetadata
    }
}

/// Scheduled export
struct ScheduledExport: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var frequency: Frequency
    var dateRange: DateRange
    var format: ExportFormat
    var isActive: Bool
    var lastRunAt: Date?
    var nextRunAt: Date
    
    enum Frequency: String, Codable, CaseIterable {
        case weekly = "Weekly"
        case monthly = "Monthly"
        case quarterly = "Quarterly"
        case yearly = "Yearly"
    }
    
    struct DateRange: Codable, Equatable {
        var startDate: Date
        var endDate: Date?
        
        init(startDate: Date = Date(), endDate: Date? = nil) {
            self.startDate = startDate
            self.endDate = endDate
        }
    }
    
    init(id: UUID = UUID(), name: String, frequency: Frequency = .quarterly, dateRange: DateRange = DateRange(), format: ExportFormat = ExportFormat(), isActive: Bool = true, lastRunAt: Date? = nil, nextRunAt: Date = Date()) {
        self.id = id
        self.name = name
        self.frequency = frequency
        self.dateRange = dateRange
        self.format = format
        self.isActive = isActive
        self.lastRunAt = lastRunAt
        self.nextRunAt = nextRunAt
    }
}
