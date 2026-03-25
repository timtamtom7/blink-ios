import Foundation

/// R9: Community and social features service
final class CommunityService: ObservableObject {
    static let shared = CommunityService()

    @Published private(set) var publicMoments: [PublicMoment] = []
    @Published private(set) var isLoading = false
    @Published private(set) var subscriptionTier: SubscriptionTier = .free

    struct PublicMoment: Identifiable, Codable {
        let id: UUID
        let anonymousId: String
        let thumbnailURL: String?
        let category: Category
        let mood: String
        let clipCount: Int
        let createdAt: Date
        let likes: Int
        let views: Int
    }

    enum Category: String, Codable, CaseIterable {
        case highlight = "Highlight"
        case milestone = "Milestone"
        case everyday = "Everyday"
        case celebration = "Celebration"
        case nature = "Nature"
        case travel = "Travel"
    }

    enum SubscriptionTier: String, Codable {
        case free = "Free"
        case memories = "Memories"
        case archive = "Archive"

        var maxSharesPerMonth: Int {
            switch self {
            case .free: return 3
            case .memories: return 20
            case .archive: return .max
            }
        }
    }

    private let userDefaults = UserDefaults.standard

    private init() {
        loadSubscriptionTier()
    }

    // MARK: - Public Feed

    @MainActor
    func loadPublicFeed() async {
        isLoading = true

        // Simulate loading public moments
        try? await Task.sleep(nanoseconds: 500_000_000)

        publicMoments = [
            PublicMoment(id: UUID(), anonymousId: "user_a7x2", thumbnailURL: nil, category: .highlight, mood: "Grateful", clipCount: 12, createdAt: Date().addingTimeInterval(-3600), likes: 24, views: 156),
            PublicMoment(id: UUID(), anonymousId: "user_b3k9", thumbnailURL: nil, category: .celebration, mood: "Excited", clipCount: 8, createdAt: Date().addingTimeInterval(-7200), likes: 42, views: 289),
            PublicMoment(id: UUID(), anonymousId: "user_c5m1", thumbnailURL: nil, category: .nature, mood: "Peaceful", clipCount: 5, createdAt: Date().addingTimeInterval(-10800), likes: 18, views: 98),
            PublicMoment(id: UUID(), anonymousId: "user_d8p4", thumbnailURL: nil, category: .everyday, mood: "Happy", clipCount: 3, createdAt: Date().addingTimeInterval(-14400), likes: 31, views: 201),
            PublicMoment(id: UUID(), anonymousId: "user_e2r7", thumbnailURL: nil, category: .travel, mood: "Adventurous", clipCount: 15, createdAt: Date().addingTimeInterval(-18000), likes: 56, views: 412)
        ]

        isLoading = false
    }

    // MARK: - Subscription

    func setSubscriptionTier(_ tier: SubscriptionTier) {
        subscriptionTier = tier
        userDefaults.set(tier.rawValue, forKey: "blink_subscription_tier")
    }

    private func loadSubscriptionTier() {
        if let tierString = userDefaults.string(forKey: "blink_subscription_tier"),
           let tier = SubscriptionTier(rawValue: tierString) {
            subscriptionTier = tier
        }
    }

    // MARK: - Sharing

    var sharesRemainingThisMonth: Int {
        subscriptionTier.maxSharesPerMonth
    }

    func canShare() -> Bool {
        sharesRemainingThisMonth > 0
    }
}
