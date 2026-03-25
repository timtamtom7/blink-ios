import SwiftUI

/// R10: Subscriptions page with tier comparison
struct SubscriptionsView: View {
    @StateObject private var subscriptionService = SubscriptionService.shared
    @State private var selectedPlan: SubscriptionPlan?
    @State private var showUpgradeConfirmation = false

    enum SubscriptionPlan: String, CaseIterable {
        case memories = "Memories"
        case archive = "Archive"

        var price: String {
            switch self {
            case .memories: return "$4.99"
            case .archive: return "$9.99"
            }
        }

        var period: String {
            "/month"
        }

        var features: [String] {
            switch self {
            case .memories:
                return [
                    "Unlimited clips",
                    "60-second videos",
                    "Cloud backup",
                    "1-year storage",
                    "AI highlights",
                    "Priority support"
                ]
            case .archive:
                return [
                    "Everything in Memories",
                    "Unlimited duration",
                    "Export all clips",
                    "Lifetime storage",
                    "Monthly highlights reel",
                    "Family sharing (up to 6)"
                ]
            }
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "0a0a0a")
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        headerSection

                        // Plan cards
                        plansSection

                        // FAQ
                        faqSection
                    }
                    .padding(16)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("Subscribe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color(hex: "0a0a0a"), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .alert("Upgrade to \(selectedPlan?.rawValue ?? "")?", isPresented: $showUpgradeConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Subscribe") {
                    if let plan = selectedPlan {
                        subscriptionService.setTier(plan == .memories ? .memories : .archive)
                    }
                }
            } message: {
                Text("You'll be charged \(selectedPlan?.price ?? "") per month. Cancel anytime.")
            }
        }
    }

    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "crown.fill")
                .font(.system(size: 48))
                .foregroundColor(Color(hex: "ffd700"))

            VStack(spacing: 8) {
                Text("Unlock Your Memories")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(Color(hex: "f5f5f5"))

                Text("Choose a plan to get unlimited clips, cloud backup, and advanced AI features.")
                    .font(.system(size: 15))
                    .foregroundColor(Color(hex: "8a8a8a"))
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.vertical, 20)
    }

    private var plansSection: some View {
        VStack(spacing: 12) {
            ForEach(SubscriptionPlan.allCases, id: \.self) { plan in
                planCard(plan)
            }
        }
    }

    private func planCard(_ plan: SubscriptionPlan) -> some View {
        Button {
            selectedPlan = plan
            showUpgradeConfirmation = true
        } label: {
            VStack(spacing: 0) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(plan.rawValue)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(Color(hex: "f5f5f5"))

                        HStack(spacing: 4) {
                            Text(plan.price)
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(Color(hex: "ff3b30"))
                            Text(plan.period)
                                .font(.system(size: 14))
                                .foregroundColor(Color(hex: "8a8a8a"))
                        }
                    }

                    Spacer()

                    if isCurrentPlan(plan) {
                        Text("Current")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(Color(hex: "34c759"))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color(hex: "34c759").opacity(0.15))
                            .clipShape(Capsule())
                    }
                }
                .padding(16)

                Divider().background(Color(hex: "2a2a2a"))

                // Features
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(plan.features, id: \.self) { feature in
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(Color(hex: "34c759"))

                            Text(feature)
                                .font(.system(size: 14))
                                .foregroundColor(Color(hex: "c0c0c0"))
                        }
                    }
                }
                .padding(16)
            }
            .background(Color(hex: "141414"))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isCurrentPlan(plan) ? Color(hex: "34c759").opacity(0.3) : Color.clear, lineWidth: 1)
            )
        }
    }

    private func isCurrentPlan(_ plan: SubscriptionPlan) -> Bool {
        switch (plan, subscriptionService.currentTier) {
        case (.memories, .memories), (.archive, .archive): return true
        default: return false
        }
    }

    private var faqSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("FAQ")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(Color(hex: "f5f5f5"))

            VStack(spacing: 0) {
                faqRow(question: "Can I cancel anytime?", answer: "Yes, you can cancel your subscription at any time. Your access will continue until the end of the billing period.")
                Divider().background(Color(hex: "2a2a2a"))
                faqRow(question: "What happens to my clips if I cancel?", answer: "Your clips are stored locally on your device. With Cloud Backup, your memories are safely stored until you delete them.")
                Divider().background(Color(hex: "2a2a2a"))
                faqRow(question: "Is there a free trial?", answer: "Yes, new subscribers get a 7-day free trial to experience all premium features.")
            }
            .background(Color(hex: "141414"))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }

    private func faqRow(question: String, answer: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(question)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(Color(hex: "f5f5f5"))

            Text(answer)
                .font(.system(size: 13))
                .foregroundColor(Color(hex: "8a8a8a"))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
    }
}

#Preview {
    SubscriptionsView()
        .preferredColorScheme(.dark)
}
