import Foundation

// MARK: - Subscription Business
// R16: Pricing, A/B Testing, Lifecycle Upsells, Analytics

/// Subscription tier definition
struct BlinkSubscriptionTier: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var displayName: String
    var monthlyPrice: Decimal
    var annualPrice: Decimal
    var lifetimePrice: Decimal
    var storageGB: Int
    var features: [String]
    var isMostPopular: Bool
    var variantID: String? // For A/B testing
    
    init(id: UUID = UUID(), name: String, displayName: String, monthlyPrice: Decimal = 0, annualPrice: Decimal = 0, lifetimePrice: Decimal = 0, storageGB: Int = 5, features: [String] = [], isMostPopular: Bool = false, variantID: String? = nil) {
        self.id = id
        self.name = name
        self.displayName = displayName
        self.monthlyPrice = monthlyPrice
        self.annualPrice = annualPrice
        self.lifetimePrice = lifetimePrice
        self.storageGB = storageGB
        self.features = features
        self.isMostPopular = isMostPopular
        self.variantID = variantID
    }
    
    static let free = BlinkSubscriptionTier(name: "free", displayName: "Free", storageGB: 5, features: ["5GB storage", "Basic capture", "Calendar view", "7-day free trial"])
    static let memories = BlinkSubscriptionTier(name: "memories", displayName: "Memories", monthlyPrice: 4.99, annualPrice: 47.88, storageGB: 50, features: ["50GB storage", "AI highlights", "Shared circles", "Export hub"], isMostPopular: true)
    static let archive = BlinkSubscriptionTier(name: "archive", displayName: "Archive", monthlyPrice: 9.99, annualPrice: 95.88, lifetimePrice: 149, storageGB: 500, features: ["Unlimited storage", "All platforms", "Advanced AI", "Priority support", "Family sharing"])
    static let family = BlinkSubscriptionTier(name: "family", displayName: "Family", monthlyPrice: 14.99, annualPrice: 143.88, storageGB: 500, features: ["6 members", "Shared vault", "Admin controls", "Child accounts"], variantID: "family_v1")
    
    static let allTiers: [BlinkSubscriptionTier] = [.free, .memories, .archive, .family]
}

/// A/B test variant
struct ABTestVariant: Identifiable, Codable, Equatable {
    let id: UUID
    var testName: String
    var variantName: String
    var payload: [String: String] // e.g., ["price": "4.99", "badge": "Most Popular"]
    var assignedAt: Date
    var userID: String
    
    init(id: UUID = UUID(), testName: String, variantName: String, payload: [String: String] = [:], assignedAt: Date = Date(), userID: String) {
        self.id = id
        self.testName = testName
        self.variantName = variantName
        self.payload = payload
        self.assignedAt = assignedAt
        self.userID = userID
    }
}

/// Remote config key/values from Firebase
struct RemoteConfig: Codable, Equatable {
    var pricingTiers: [BlinkSubscriptionTier]
    var paywallTriggerDays: [Int] // e.g., [3, 14]
    var freeTrialDays: Int
    var isAnnualDefault: Bool
    var featureGates: [String: Bool]
    
    static let `default` = RemoteConfig(
        pricingTiers: [.free, .memories, .archive],
        paywallTriggerDays: [3, 14],
        freeTrialDays: 14,
        isAnnualDefault: false,
        featureGates: ["ai_highlights": true, "shared_circles": true, "export_hub": false]
    )
}

/// Lifecycle event for upsell triggers
struct LifecycleEvent: Identifiable, Codable, Equatable {
    let id: UUID
    var eventType: EventType
    var triggeredAt: Date
    var userID: String
    var metadata: [String: String]
    
    enum EventType: String, Codable {
        case day3Engagement = "day_3_engagement"
        case day14Retention = "day_14_retention"
        case storageWarning = "storage_warning"
        case annualRenewalReminder = "annual_renewal_reminder"
        case churnRisk = "churn_risk"
        case subscriptionCanceled = "subscription_canceled"
    }
    
    init(id: UUID = UUID(), eventType: EventType, userID: String, metadata: [String: String] = [:], triggeredAt: Date = Date()) {
        self.id = id
        self.eventType = eventType
        self.triggeredAt = triggeredAt
        self.userID = userID
        self.metadata = metadata
    }
}

/// Subscription analytics snapshot
struct SubscriptionAnalytics: Codable, Equatable {
    var mrr: Double // Monthly recurring revenue
    var arr: Double // Annual recurring revenue
    var churnRate: Double
    var ltv: Double // Lifetime value
    var trialToPaidRate: Double
    var activeSubscriptions: Int
    var cancelledSubscriptions: Int
    
    static let empty = SubscriptionAnalytics(mrr: 0, arr: 0, churnRate: 0, ltv: 0, trialToPaidRate: 0, activeSubscriptions: 0, cancelledSubscriptions: 0)
}
