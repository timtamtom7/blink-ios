import SwiftUI

struct PricingView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var selectedTier: SubscriptionTier = .free
    @State private var showAlreadySubscribed = false

    enum SubscriptionTier: String, CaseIterable {
        case free = "Free"
        case memories = "Memories"
        case archive = "Archive"

        var price: String {
            switch self {
            case .free: return "Free"
            case .memories: return "$4.99"
            case .archive: return "$9.99"
            }
        }

        var period: String {
            switch self {
            case .free: return ""
            case .memories, .archive: return "/month"
            }
        }

        var tagline: String {
            switch self {
            case .free: return "Just enough to start"
            case .memories: return "Your life, uncapped"
            case .archive: return "Everything. Forever."
            }
        }

        var features: [String] {
            switch self {
            case .free:
                return [
                    "1 clip per day",
                    "30 seconds max",
                    "Local storage only",
                    "30-day clip retention",
                    "Basic calendar view"
                ]
            case .memories:
                return [
                    "Unlimited clips",
                    "60-second videos",
                    "Cloud backup",
                    "1-year clip retention",
                    "Priority support"
                ]
            case .archive:
                return [
                    "Everything in Memories",
                    "Unlimited duration",
                    "Export all clips",
                    "Lifetime storage",
                    "Monthly highlight reel",
                    "Priority support"
                ]
            }
        }

        var isPopular: Bool {
            self == .memories
        }

        var accentColor: Color {
            switch self {
            case .free: return Color(hex: "8a8a8a")
            case .memories: return Color(hex: "ff3b30")
            case .archive: return Color(hex: "f5f5f5")
            }
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "0a0a0a")
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 32) {
                        headerSection

                        VStack(spacing: 16) {
                            ForEach(SubscriptionTier.allCases, id: \.self) { tier in
                                TierCard(
                                    tier: tier,
                                    isSelected: selectedTier == tier,
                                    onSelect: { selectedTier = tier }
                                )
                            }
                        }
                        .padding(.horizontal, 16)

                        subscribeButton

                        Text("Cancel anytime. No commitments.")
                            .font(.system(size: 12))
                            .foregroundColor(Color(hex: "8a8a8a"))
                    }
                    .padding(.vertical, 24)
                }
            }
            .navigationTitle("Choose Your Plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color(hex: "0a0a0a"), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Color(hex: "8a8a8a"))
                    }
                }
            }
        }
        .onAppear {
            // Pre-select based on current "subscription" — for now default to Free
            selectedTier = .free
        }
    }

    private var headerSection: some View {
        VStack(spacing: 12) {
            Text("Your year deserves more")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(Color(hex: "f5f5f5"))

            Text("Start free. Upgrade when you're ready.")
                .font(.system(size: 15))
                .foregroundColor(Color(hex: "8a8a8a"))
        }
    }

    private var subscribeButton: some View {
        Button {
            handleSubscribe()
        } label: {
            HStack {
                if selectedTier == .free {
                    Text("Get Started")
                        .font(.system(size: 17, weight: .semibold))
                } else {
                    Text("Subscribe to \(selectedTier.rawValue)")
                        .font(.system(size: 17, weight: .semibold))
                    Text("— \(selectedTier.price)\(selectedTier.period)")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(
                selectedTier == .free
                    ? LinearGradient(colors: [Color(hex: "333333"), Color(hex: "222222")], startPoint: .top, endPoint: .bottom)
                    : LinearGradient(colors: [Color(hex: "ff3b30"), Color(hex: "cc2f26")], startPoint: .top, endPoint: .bottom)
            )
            .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadiusMedium))
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    private func handleSubscribe() {
        if selectedTier == .free {
            dismiss()
        } else {
            // In a real app, this would trigger StoreKit
            // For now, just dismiss with a placeholder
            dismiss()
        }
    }
}

struct TierCard: View {
    let tier: PricingView.SubscriptionTier
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Text(tier.rawValue)
                                .font(.system(size: 17, weight: .bold))
                                .foregroundColor(tier == .free ? Color(hex: "8a8a8a") : Color(hex: "f5f5f5"))

                            if tier.isPopular {
                                Text("POPULAR")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color(hex: "ff3b30"))
                                    .clipShape(Capsule())
                            }
                        }

                        Text(tier.tagline)
                            .font(.system(size: 13))
                            .foregroundColor(Color(hex: "8a8a8a"))
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text(tier.price)
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(tier == .free ? Color(hex: "8a8a8a") : Color(hex: "f5f5f5"))
                        if tier != .free {
                            Text(tier.period)
                                .font(.system(size: 11))
                                .foregroundColor(Color(hex: "8a8a8a"))
                        }
                    }
                }
                .padding(16)

                Divider()
                    .background(Color(hex: "2a2a2a"))

                VStack(alignment: .leading, spacing: 8) {
                    ForEach(tier.features, id: \.self) { feature in
                        HStack(spacing: 10) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(tier == .free ? Color(hex: "8a8a8a") : Color(hex: "ff3b30"))

                            Text(feature)
                                .font(.system(size: 13))
                                .foregroundColor(Color(hex: "c0c0c0"))
                        }
                    }
                }
                .padding(16)
            }
            .background(Color(hex: "141414"))
            .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadiusLarge))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cornerRadiusLarge)
                    .stroke(isSelected ? tier.accentColor : Color.clear, lineWidth: 1.5)
            )
        }
    }
}

#Preview {
    PricingView()
        .preferredColorScheme(.dark)
}
