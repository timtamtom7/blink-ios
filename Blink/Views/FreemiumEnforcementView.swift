import SwiftUI

/// Shown when freemium limits prevent recording:
/// - Free plan daily limit reached
/// - Free plan duration exceeded
struct FreemiumEnforcementView: View {
    let reason: String
    let onUpgrade: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.85)
                .ignoresSafeArea()
                .background(.ultraThinMaterial)

            // Dismiss button top-right
            VStack {
                HStack {
                    Spacer()
                    Button {
                        onDismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(BlinkFontStyle.footnote.font)
                            .foregroundColor(Color(hex: "8a8a8a"))
                            .frame(width: 28, height: 28)
                            .background(Color(hex: "2a2a2a"))
                            .clipShape(Circle())
                    }
                    .accessibilityLabel("Dismiss")
                    .accessibilityHint("Closes the upgrade prompt")
                }
                Spacer()
            }
            .padding(.top, 60)
            .padding(.horizontal, 24)

            VStack(spacing: 24) {
                // Icon
                ZStack {
                    Circle()
                        .fill(Color(hex: "ff3b30").opacity(0.15))
                        .frame(width: 80, height: 80)

                    Image(systemName: "crown.fill")
                        .font(BlinkFontStyle.lockIconMedium.font)
                        .foregroundColor(Color(hex: "ff3b30"))
                }

                VStack(spacing: 10) {
                    Text("You've captured today's moment")
                        .font(BlinkFontStyle.title.font)
                        .foregroundColor(Color(hex: "f5f5f5"))

                    Text("Capture one moment a day, free forever — no credit card needed. Upgrade to unlock unlimited recordings.")
                        .font(BlinkFontStyle.body.font)
                        .foregroundColor(Color(hex: "8a8a8a"))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                }

                VStack(spacing: 12) {
                    Button {
                        onUpgrade()
                    } label: {
                        HStack {
                            Image(systemName: "crown.fill")
                                .font(BlinkFontStyle.callout.font)
                            Text("Upgrade to Memories")
                                .font(BlinkFontStyle.title3.font)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Color(hex: "ff3b30"))
                        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadiusMedium))
                    }
                    .accessibilityLabel("Upgrade to Memories")
                    .accessibilityHint("Opens the subscription plan to upgrade your account")

                    Button {
                        onDismiss()
                    } label: {
                        Text("Maybe Later")
                            .font(BlinkFontStyle.body.font)
                            .foregroundColor(Color(hex: "8a8a8a"))
                    }
                    .accessibilityLabel("Maybe Later")
                    .accessibilityHint("Dismisses this screen and continues with the free plan")

                    Text("Come back tomorrow — free forever")
                        .font(BlinkFontStyle.footnote.font)
                        .foregroundColor(Color(hex: "8a8a8a").opacity(0.7))
                }
                .padding(.horizontal, 24)
            }
            .padding(.vertical, 40)
        }
    }
}

/// Duration limit overlay when free user tries to record beyond 30s.
struct DurationLimitBanner: View {
    let maxDuration: TimeInterval
    let onUpgrade: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "clock.badge.exclamationmark")
                    .font(BlinkFontStyle.callout.font)
                    .foregroundColor(Color(hex: "ff3b30"))

                Text("Free clips are capped at \(Int(maxDuration)) seconds")
                    .font(BlinkFontStyle.subheadline.font)
                    .foregroundColor(Color(hex: "f5f5f5"))

                Spacer()

                Button("Upgrade") {
                    onUpgrade()
                }
                .font(BlinkFontStyle.footnote.font)
                .foregroundColor(Color(hex: "ff3b30"))
                .accessibilityLabel("Upgrade")
                .accessibilityHint("Opens the subscription plan to upgrade your account")
            }

            Text("Upgrade to Memories for up to 60-second clips")
                .font(BlinkFontStyle.caption.font)
                .foregroundColor(Color(hex: "8a8a8a"))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .background(Color(hex: "1e1e1e"))
        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadiusMedium))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Duration limit: Free clips are capped at \(Int(maxDuration)) seconds. Upgrade to Memories for up to 60-second clips")
    }
}

/// Inline upgrade nudge shown in the calendar/record view for free users.
struct FreePlanNudgeView: View {
    let clipCount: Int
    let onUpgrade: () -> Void

    var body: some View {
        Button(action: onUpgrade) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color(hex: "ff3b30").opacity(0.15))
                        .frame(width: 40, height: 40)

                    Text("\(clipCount)")
                        .font(BlinkFontStyle.body.font)
                        .foregroundColor(Color(hex: "ff3b30"))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Free Plan")
                        .font(BlinkFontStyle.body.font)
                        .foregroundColor(Color(hex: "f5f5f5"))

                    Text(clipCount == 0
                        ? "Record your first clip today"
                        : "1 clip/day • 30s limit • 30-day storage")
                        .font(BlinkFontStyle.caption.font)
                        .foregroundColor(Color(hex: "8a8a8a"))
                }

                Spacer()

                Text("Upgrade")
                    .font(BlinkFontStyle.callout.font)
                    .foregroundColor(Color(hex: "ff3b30"))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color(hex: "ff3b30").opacity(0.15))
                    .clipShape(Capsule())
                    .accessibilityLabel("Upgrade")
                    .accessibilityHint("Opens the subscription plan to upgrade your account")
            }
            .padding(12)
            .background(Color(hex: "141414"))
            .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadiusMedium))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cornerRadiusMedium)
                    .stroke(Color(hex: "ff3b30").opacity(0.3), lineWidth: 1)
            )
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Free plan: \(clipCount) clip recorded today. \(clipCount == 0 ? "Record your first clip today" : "1 clip per day, 30 second limit, 30 day storage")")
        .accessibilityHint("Double tap to upgrade to Memories")
    }
}

#Preview("Freemium Enforcement") {
    FreemiumEnforcementView(
        reason: "You've used your daily clip on the Free plan. Upgrade to record unlimited moments.",
        onUpgrade: {},
        onDismiss: {}
    )
    .preferredColorScheme(.dark)
}

struct FreemiumPreviews: PreviewProvider {
    static var previews: some View {
        VStack {
            DurationLimitBanner(maxDuration: 30) {}
            Spacer()
        }
        .padding()
        .background(Color(hex: "0a0a0a"))
        .preferredColorScheme(.dark)
    }
}
