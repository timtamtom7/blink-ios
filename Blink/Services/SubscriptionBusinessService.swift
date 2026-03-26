import Foundation
import Combine

/// R16: Subscription Business Service
final class SubscriptionBusinessService: ObservableObject {
    static let shared = SubscriptionBusinessService()
    
    @Published var currentTier: BlinkSubscriptionTier = .free
    @Published var remoteConfig: RemoteConfig = .default
    @Published var testVariants: [ABTestVariant] = []
    @Published var lifecycleEvents: [LifecycleEvent] = []
    @Published var analytics: SubscriptionAnalytics = .empty
    
    private let userDefaults = UserDefaults.standard
    
    private init() { loadFromDisk() }
    
    // MARK: - Pricing
    
    func effectiveTiers() -> [BlinkSubscriptionTier] {
        // Apply A/B variant overrides
        return remoteConfig.pricingTiers.map { tier in
            if let variant = testVariants.first(where: { $0.testName == "pricing_\(tier.name)" }) {
                var modified = tier
                if let priceStr = variant.payload["monthly_price"], let price = Decimal(string: priceStr) {
                    modified = BlinkSubscriptionTier(id: tier.id, name: tier.name, displayName: tier.displayName, monthlyPrice: price, annualPrice: tier.annualPrice, lifetimePrice: tier.lifetimePrice, storageGB: tier.storageGB, features: tier.features, isMostPopular: variant.payload["badge"] == "Most Popular", variantID: variant.variantName)
                }
                return modified
            }
            return tier
        }
    }
    
    // MARK: - A/B Testing
    
    func assignVariant(testName: String, userID: String) -> ABTestVariant {
        let variants = ["control", "variant_a", "variant_b"]
        let variantName = variants.randomElement() ?? "control"
        
        let variant = ABTestVariant(testName: testName, variantName: variantName, userID: userID)
        testVariants.append(variant)
        saveToDisk()
        return variant
    }
    
    func getVariant(for testName: String) -> ABTestVariant? {
        testVariants.first { $0.testName == testName }
    }
    
    func variantPayload(for testName: String) -> [String: String] {
        getVariant(for: testName)?.payload ?? [:]
    }
    
    // MARK: - Remote Config
    
    func fetchRemoteConfig() async {
        // In production, fetch from Firebase Remote Config
        // For now, use defaults
        await MainActor.run {
            remoteConfig = .default
        }
    }
    
    // MARK: - Lifecycle Events
    
    func trackLifecycleEvent(_ eventType: LifecycleEvent.EventType, userID: String, metadata: [String: String] = [:]) {
        let event = LifecycleEvent(eventType: eventType, userID: userID, metadata: metadata)
        lifecycleEvents.append(event)
        saveToDisk()
        
        // Trigger appropriate upsell
        triggerUpsell(for: event)
    }
    
    private func triggerUpsell(for event: LifecycleEvent) {
        switch event.eventType {
        case .day3Engagement:
            NotificationCenter.default.post(name: .upsellTriggered, object: nil, userInfo: ["type": "engagement_3day", "message": "You've captured clips! Upgrade for unlimited."])
        case .day14Retention:
            NotificationCenter.default.post(name: .upsellTriggered, object: nil, userInfo: ["type": "retention_14day", "message": "Your archive is growing! Get unlimited storage."])
        case .storageWarning:
            NotificationCenter.default.post(name: .upsellTriggered, object: nil, userInfo: ["type": "storage_warning", "message": "80% storage used. Upgrade or auto-compress."])
        case .annualRenewalReminder:
            NotificationCenter.default.post(name: .upsellTriggered, object: nil, userInfo: ["type": "annual_reminder", "message": "Renewing in 30 days. Switch to annual and save!"])
        case .churnRisk:
            NotificationCenter.default.post(name: .upsellTriggered, object: nil, userInfo: ["type": "churn_prevention", "message": "We're sorry to see you go. Here's a special offer."])
        case .subscriptionCanceled:
            NotificationCenter.default.post(name: .upsellTriggered, object: nil, userInfo: ["type": "cancellation_survey", "message": "What are you leaving for?"])
        }
    }
    
    // MARK: - Analytics
    
    func updateAnalytics(mrr: Double, activeSubs: Int, churnRate: Double) {
        analytics = SubscriptionAnalytics(
            mrr: mrr,
            arr: mrr * 12,
            churnRate: churnRate,
            ltv: mrr > 0 ? mrr / (churnRate > 0 ? churnRate : 0.01) : 0,
            trialToPaidRate: 0.25,
            activeSubscriptions: activeSubs,
            cancelledSubscriptions: 0
        )
    }
    
    // MARK: - Subscription Actions
    
    func subscribe(to tier: BlinkSubscriptionTier, billing: BillingType = .monthly) async -> Bool {
        // Simulate subscription
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        await MainActor.run {
            currentTier = tier
            saveToDisk()
        }
        return true
    }
    
    func cancelSubscription() async {
        await MainActor.run {
            currentTier = .free
            saveToDisk()
        }
    }
    
    enum BillingType {
        case monthly, annual, lifetime
    }
    
    // MARK: - Persistence
    
    private func saveToDisk() {
        if let data = try? JSONEncoder().encode(currentTier) {
            userDefaults.set(data, forKey: "blink_current_tier")
        }
        if let data = try? JSONEncoder().encode(testVariants) {
            userDefaults.set(data, forKey: "blink_ab_variants")
        }
        if let data = try? JSONEncoder().encode(lifecycleEvents) {
            userDefaults.set(data, forKey: "blink_lifecycle_events")
        }
    }
    
    private func loadFromDisk() {
        if let data = userDefaults.data(forKey: "blink_current_tier"),
           let decoded = try? JSONDecoder().decode(BlinkSubscriptionTier.self, from: data) {
            currentTier = decoded
        }
        if let data = userDefaults.data(forKey: "blink_ab_variants"),
           let decoded = try? JSONDecoder().decode([ABTestVariant].self, from: data) {
            testVariants = decoded
        }
        if let data = userDefaults.data(forKey: "blink_lifecycle_events"),
           let decoded = try? JSONDecoder().decode([LifecycleEvent].self, from: data) {
            lifecycleEvents = decoded
        }
    }
}

extension Notification.Name {
    static let upsellTriggered = Notification.Name("upsellTriggered")
}
