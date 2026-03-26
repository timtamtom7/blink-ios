import Foundation

// MARK: - Blink 2.0 — The Memory OS
// R20: Memory Streams, Memory People, Place Memory, Apple Intelligence, Blink Pro

/// Memory Stream — AI-curated continuous flow of moments
struct MemoryStream: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var filterType: FilterType
    var clipIDs: [UUID]
    var lastUpdated: Date
    var theme: String? // e.g., "summer", "family", "travel"
    
    enum FilterType: String, Codable {
        case time
        case theme
        case people
        case place
        case aiCurated
    }
    
    init(id: UUID = UUID(), name: String, filterType: FilterType = .time, clipIDs: [UUID] = [], lastUpdated: Date = Date(), theme: String? = nil) {
        self.id = id
        self.name = name
        self.filterType = filterType
        self.clipIDs = clipIDs
        self.lastUpdated = lastUpdated
        self.theme = theme
    }
}

/// Memory Person — person album with all moments
struct MemoryPerson: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var faceClipIDs: [UUID] // Clips where this person is detected
    var clipCount: Int
    var thumbnailClipID: UUID?
    var isFavorite: Bool
    
    init(id: UUID = UUID(), name: String, faceClipIDs: [UUID] = [], clipCount: Int = 0, thumbnailClipID: UUID? = nil, isFavorite: Bool = false) {
        self.id = id
        self.name = name
        self.faceClipIDs = faceClipIDs
        self.clipCount = clipCount
        self.thumbnailClipID = thumbnailClipID
        self.isFavorite = isFavorite
    }
}

/// Place Memory — location-based memories
struct PlaceMemory: Identifiable, Codable, Equatable {
    let id: UUID
    var placeName: String
    var latitude: Double
    var longitude: Double
    var clipIDs: [UUID]
    var clipCount: Int
    var thumbnailClipID: UUID?
    
    init(id: UUID = UUID(), placeName: String, latitude: Double = 0, longitude: Double = 0, clipIDs: [UUID] = [], clipCount: Int = 0, thumbnailClipID: UUID? = nil) {
        self.id = id
        self.placeName = placeName
        self.latitude = latitude
        self.longitude = longitude
        self.clipIDs = clipIDs
        self.clipCount = clipCount
        self.thumbnailClipID = thumbnailClipID
    }
}

/// Unified Capture — any moment type
struct UnifiedCapture: Identifiable, Codable, Equatable {
    let id: UUID
    var captureType: CaptureType
    var contentID: UUID // References the actual content
    var capturedAt: Date
    var duration: TimeInterval?
    var textContent: String? // For text notes
    var audioFilename: String? // For audio notes
    
    enum CaptureType: String, Codable {
        case videoClip
        case photoBurst
        case audioNote
        case textNote
    }
    
    init(id: UUID = UUID(), captureType: CaptureType, contentID: UUID = UUID(), capturedAt: Date = Date(), duration: TimeInterval? = nil, textContent: String? = nil, audioFilename: String? = nil) {
        self.id = id
        self.captureType = captureType
        self.contentID = contentID
        self.capturedAt = capturedAt
        self.duration = duration
        self.textContent = textContent
        self.audioFilename = audioFilename
    }
}

/// Apple Intelligence powered Memory Movie
struct AIMemoryMovie: Identifiable, Codable, Equatable {
    let id: UUID
    var naturalLanguagePrompt: String
    var clipIDs: [UUID]
    var generatedAt: Date
    var duration: TimeInterval
    var thumbnailFilename: String?
    var status: GenerationStatus
    
    enum GenerationStatus: String, Codable {
        case queued
        case generating
        case completed
        case failed
    }
    
    init(id: UUID = UUID(), naturalLanguagePrompt: String = "", clipIDs: [UUID] = [], generatedAt: Date = Date(), duration: TimeInterval = 0, thumbnailFilename: String? = nil, status: GenerationStatus = .queued) {
        self.id = id
        self.naturalLanguagePrompt = naturalLanguagePrompt
        self.clipIDs = clipIDs
        self.generatedAt = generatedAt
        self.duration = duration
        self.thumbnailFilename = thumbnailFilename
        self.status = status
    }
}

/// Live Caption for recording
struct LiveCaption: Identifiable, Codable, Equatable {
    let id: UUID
    var clipID: UUID
    var segments: [CaptionSegment]
    var language: String
    
    struct CaptionSegment: Identifiable, Codable, Equatable {
        let id: UUID
        var text: String
        var startTime: TimeInterval
        var endTime: TimeInterval
        var confidence: Double
        
        init(id: UUID = UUID(), text: String, startTime: TimeInterval, endTime: TimeInterval, confidence: Double = 1.0) {
            self.id = id
            self.text = text
            self.startTime = startTime
            self.endTime = endTime
            self.confidence = confidence
        }
    }
    
    init(id: UUID = UUID(), clipID: UUID, segments: [CaptionSegment] = [], language: String = "en") {
        self.id = id
        self.clipID = clipID
        self.segments = segments
        self.language = language
    }
    
    var fullText: String {
        segments.map { $0.text }.joined(separator: " ")
    }
}

/// Blink Pro subscription tier
struct BlinkProTier: Codable, Equatable {
    static let monthlyPrice: Decimal = 9.99
    static let annualPrice: Decimal = 79.99
    
    var includesMemoryCloud: Bool = true
    var includesPriorityAI: Bool = true
    var includesPrintShop: Bool = true
    var cloudStorageTB: Int = 1
    
    static let features: [String] = [
        "Unlimited storage",
        "All platforms (iOS, Android, Web, Apple TV, watchOS)",
        "Memory Cloud (E2E encrypted, 1TB)",
        "Priority AI processing",
        "Memory Deep Dive",
        "Timeline reconstruction",
        "Print Shop (photos, books, calendars)",
        "Shared circles & collaborative albums",
        "Apple Intelligence integration",
        "Priority support"
    ]
}

/// Blink Creator program
struct BlinkCreator: Identifiable, Codable, Equatable {
    let id: UUID
    var creatorName: String
    var presetStyles: [MemoryStyle]
    var totalSales: Int
    var earnings: Decimal
    var rating: Double
    var reviews: [Review]
    
    struct MemoryStyle: Identifiable, Codable, Equatable {
        let id: UUID
        var name: String
        var colorGrade: String
        var musicOverlay: String?
        var transitions: String
        var previewClipID: UUID?
        var price: Decimal
        var downloadCount: Int
        
        init(id: UUID = UUID(), name: String, colorGrade: String = "", musicOverlay: String? = nil, transitions: String = "fade", previewClipID: UUID? = nil, price: Decimal = 0, downloadCount: Int = 0) {
            self.id = id
            self.name = name
            self.colorGrade = colorGrade
            self.musicOverlay = musicOverlay
            self.transitions = transitions
            self.previewClipID = previewClipID
            self.price = price
            self.downloadCount = downloadCount
        }
    }
    
    struct Review: Identifiable, Codable, Equatable {
        let id: UUID
        var reviewerName: String
        var rating: Int
        var comment: String
        var createdAt: Date
    }
    
    init(id: UUID = UUID(), creatorName: String, presetStyles: [MemoryStyle] = [], totalSales: Int = 0, earnings: Decimal = 0, rating: Double = 0, reviews: [Review] = []) {
        self.id = id
        self.creatorName = creatorName
        self.presetStyles = presetStyles
        self.totalSales = totalSales
        self.earnings = earnings
        self.rating = rating
        self.reviews = reviews
    }
}

/// Blink Premiere — scheduled public debut
struct BlinkPremiere: Identifiable, Codable, Equatable {
    let id: UUID
    var clipID: UUID
    var scheduledAt: Date
    var isLive: Bool
    var viewerCount: Int
    var reactions: [PublicMoment.Reaction]
    
    init(id: UUID = UUID(), clipID: UUID, scheduledAt: Date, isLive: Bool = false, viewerCount: Int = 0, reactions: [PublicMoment.Reaction] = []) {
        self.id = id
        self.clipID = clipID
        self.scheduledAt = scheduledAt
        self.isLive = isLive
        self.viewerCount = viewerCount
        self.reactions = reactions
    }
}
