import Foundation

// MARK: - Partnerships & B2B
// R17: Family Pod, Enterprise, White-Label SDK, Integrations

/// Family Pod subscription
struct FamilyPod: Identifiable, Codable, Equatable {
    let id: UUID
    var adminDeviceID: String
    var memberDevices: [FamilyMember]
    var totalStorageGB: Int
    var monthlyPrice: Decimal
    var isActive: Bool
    var createdAt: Date
    
    struct FamilyMember: Identifiable, Codable, Equatable {
        let id: UUID
        var deviceID: String
        var displayName: String
        var role: Role
        var isApproved: Bool // For child accounts (COPPA)
        var contributedClipIDs: [UUID]
        
        enum Role: String, Codable {
            case admin
            case parent
            case child
        }
        
        init(id: UUID = UUID(), deviceID: String, displayName: String, role: Role = .parent, isApproved: Bool = true, contributedClipIDs: [UUID] = []) {
            self.id = id
            self.deviceID = deviceID
            self.displayName = displayName
            self.role = role
            self.isApproved = isApproved
            self.contributedClipIDs = contributedClipIDs
        }
    }
    
    init(id: UUID = UUID(), adminDeviceID: String, memberDevices: [FamilyMember] = [], totalStorageGB: Int = 500, monthlyPrice: Decimal = 19.99, isActive: Bool = true, createdAt: Date = Date()) {
        self.id = id
        self.adminDeviceID = adminDeviceID
        self.memberDevices = memberDevices
        self.totalStorageGB = totalStorageGB
        self.monthlyPrice = monthlyPrice
        self.isActive = isActive
        self.createdAt = createdAt
    }
    
    mutating func addMember(_ member: FamilyMember) {
        guard !memberDevices.contains(where: { $0.deviceID == member.deviceID }) else { return }
        memberDevices.append(member)
    }
    
    mutating func removeMember(_ deviceID: String) {
        memberDevices.removeAll { $0.deviceID == deviceID }
    }
    
    mutating func approveChild(_ deviceID: String) {
        if let index = memberDevices.firstIndex(where: { $0.deviceID == deviceID && $0.role == .child }) {
            memberDevices[index].isApproved = true
        }
    }
}

/// Blink for Teams enterprise account
struct TeamAccount: Identifiable, Codable, Equatable {
    let id: UUID
    var companyName: String
    var adminDeviceID: String
    var teamMembers: [TeamMember]
    var seatCount: Int
    var pricePerUser: Decimal
    var isActive: Bool
    var createdAt: Date
    
    struct TeamMember: Identifiable, Codable, Equatable {
        let id: UUID
        var deviceID: String
        var email: String
        var role: Role
        var contributedClipIDs: [UUID]
        
        enum Role: String, Codable {
            case admin
            case member
        }
        
        init(id: UUID = UUID(), deviceID: String = "", email: String = "", role: Role = .member, contributedClipIDs: [UUID] = []) {
            self.id = id
            self.deviceID = deviceID
            self.email = email
            self.role = role
            self.contributedClipIDs = contributedClipIDs
        }
    }
    
    init(id: UUID = UUID(), companyName: String, adminDeviceID: String, teamMembers: [TeamMember] = [], seatCount: Int = 10, pricePerUser: Decimal = 5, isActive: Bool = true, createdAt: Date = Date()) {
        self.id = id
        self.companyName = companyName
        self.adminDeviceID = adminDeviceID
        self.teamMembers = teamMembers
        self.seatCount = seatCount
        self.pricePerUser = pricePerUser
        self.isActive = isActive
        self.createdAt = createdAt
    }
    
    var monthlyTotal: Decimal { pricePerUser * Decimal(seatCount) }
}

/// White-Label SDK configuration
struct WhiteLabelConfig: Identifiable, Codable, Equatable {
    let id: UUID
    var hostAppName: String
    var hostBundleID: String
    var licenseType: LicenseType
    var customBranding: Branding?
    var isActive: Bool
    
    enum LicenseType: String, Codable {
        case mit = "MIT (Open Source)"
        case startup = "Startup"
        case commercial = "Commercial"
    }
    
    struct Branding: Codable, Equatable {
        var primaryColor: String
        var accentColor: String
        var logoURL: String?
        var appName: String
    }
    
    init(id: UUID = UUID(), hostAppName: String, hostBundleID: String, licenseType: LicenseType = .startup, customBranding: Branding? = nil, isActive: Bool = true) {
        self.id = id
        self.hostAppName = hostAppName
        self.hostBundleID = hostBundleID
        self.licenseType = licenseType
        self.customBranding = customBranding
        self.isActive = isActive
    }
}

/// Integration partner configuration
struct IntegrationPartner: Identifiable, Codable, Equatable {
    let id: UUID
    var partnerName: String
    var partnerType: PartnerType
    var isEnabled: Bool
    var config: [String: String]
    
    enum PartnerType: String, Codable {
        case applePhotos = "Apple Photos"
        case googlePhotos = "Google Photos"
        case weddingPlatform = "Wedding Platform"
        case airbnb = "Airbnb"
        case other = "Other"
    }
    
    init(id: UUID = UUID(), partnerName: String, partnerType: PartnerType, isEnabled: Bool = false, config: [String: String] = [:]) {
        self.id = id
        self.partnerName = partnerName
        self.partnerType = partnerType
        self.isEnabled = isEnabled
        self.config = config
    }
}
