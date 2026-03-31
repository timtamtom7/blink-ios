import SwiftUI

// MARK: - Blink Theme
// iOS 26 Liquid Glass Design System for blink-ios

enum Theme {
    // MARK: - Colors

    /// Primary brand accent — Blink Red
    static let accent = Color(hex: "ff3b30")

    /// Background: primary (app background)
    static let background = Color(hex: "0a0a0a")

    /// Background: secondary (cards, elevated surfaces)
    static let backgroundSecondary = Color(hex: "141414")

    /// Background: tertiary (inputs, tertiary surfaces)
    static let backgroundTertiary = Color(hex: "1e1e1e")

    /// Background: quaternary (keypads, deep surfaces)
    static let backgroundQuaternary = Color(hex: "2a2a2a")

    /// Text: primary (headings, titles)
    static let textPrimary = Color(hex: "f5f5f5")

    /// Text: secondary (body, descriptions) — WCAG AA ≥ 4.5:1 on #0a0a0a
    static let textSecondary = Color(hex: "AAAAAA")

    /// Text: tertiary (captions, metadata) — WCAG AA ≥ 4.5:1 on #141414
    static let textTertiary = Color(hex: "888888")

    /// Text: quaternary (disabled, placeholders) — WCAG AA ≥ 4.5:1 on #0a0a0a
    static let textQuaternary = Color(hex: "AAAAAA")

    /// Text: inverse (on colored backgrounds)
    static let textInverse = Color.white

    /// Separator / divider color
    static let separator = Color(hex: "2a2a2a")

    /// Success / positive
    static let success = Color(hex: "34c759")

    /// Warning / caution
    static let warning = Color(hex: "ffcc00")

    /// Destructive / error
    static let destructive = Color(hex: "ff3b30")

    // MARK: - Corner Radius Tokens

    /// Small radius — tags, badges, small cards (8pt)
    static let cornerRadiusSmall: CGFloat = 8

    /// Medium radius — standard cards, buttons, inputs (12pt)
    static let cornerRadiusMedium: CGFloat = 12

    /// Large radius — modals, sheets, hero cards (16pt)
    static let cornerRadiusLarge: CGFloat = 16

    /// Pill / capsule radius — chips, pills, full-round buttons
    static let cornerRadiusPill: CGFloat = 9999

    // MARK: - Font Tokens (WCAG AA compliant minimum: 11pt / .caption2)

    /// Large title
    static let fontLargeTitle = Font.system(size: 28, weight: .bold, design: .default)

    /// Title 1
    static let fontTitle1 = Font.system(size: 22, weight: .bold, design: .default)

    /// Title 2
    static let fontTitle2 = Font.system(size: 20, weight: .bold, design: .default)

    /// Title 3
    static let fontTitle3 = Font.system(size: 18, weight: .bold, design: .default)

    /// Headline
    static let fontHeadline = Font.system(size: 17, weight: .semibold, design: .default)

    /// Body
    static let fontBody = Font.system(size: 15, weight: .regular, design: .default)

    /// Callout
    static let fontCallout = Font.system(size: 14, weight: .regular, design: .default)

    /// Subheadline
    static let fontSubheadline = Font.system(size: 13, weight: .medium, design: .default)

    /// Footnote
    static let fontFootnote = Font.system(size: 13, weight: .regular, design: .default)

    /// Caption 1
    static let fontCaption1 = Font.system(size: 12, weight: .regular, design: .default)

    /// Caption 2 — WCAG AA minimum (11pt)
    static let fontCaption2 = Font.system(size: 11, weight: .regular, design: .default)

    /// Caption 2 bold — badges, counts
    static let fontCaption2Bold = Font.system(size: 11, weight: .bold, design: .default)

    /// Monospace caption — timestamps, durations
    static let fontMonoCaption = Font.system(size: 11, weight: .medium, design: .monospaced)

    /// Monospace body — time displays
    static let fontMonoBody = Font.system(size: 13, weight: .medium, design: .monospaced)

    // MARK: - Button Fonts (Dynamic Type)

    /// Primary button font — uses Dynamic Type headline
    static let primaryButtonFont: Font = BlinkFontStyle.headline.font

    /// Secondary button font — uses Dynamic Type body
    static let secondaryButtonFont: Font = BlinkFontStyle.body.font

    // MARK: - Spacing

    static let spacing2: CGFloat = 2
    static let spacing4: CGFloat = 4
    static let spacing6: CGFloat = 6
    static let spacing8: CGFloat = 8
    static let spacing12: CGFloat = 12
    static let spacing14: CGFloat = 14
    static let spacing16: CGFloat = 16
    static let spacing20: CGFloat = 20
    static let spacing24: CGFloat = 24
    static let spacing28: CGFloat = 28
    static let spacing32: CGFloat = 32
    static let spacing40: CGFloat = 40
    static let spacing48: CGFloat = 48

    // MARK: - Shadows

    static let shadowSmall = (color: Color.black.opacity(0.15), radius: CGFloat(4), x: CGFloat(0), y: CGFloat(2))
    static let shadowMedium = (color: Color.black.opacity(0.2), radius: CGFloat(8), x: CGFloat(0), y: CGFloat(4))
    static let shadowLarge = (color: Color.black.opacity(0.3), radius: CGFloat(16), x: CGFloat(0), y: CGFloat(8))

    // MARK: - Icon Sizes

    static let iconSmall: CGFloat = 12
    static let iconMedium: CGFloat = 16
    static let iconLarge: CGFloat = 20
    static let iconXLarge: CGFloat = 24
    static let icon2XLarge: CGFloat = 32
    static let icon3XLarge: CGFloat = 40
    static let icon4XLarge: CGFloat = 48
    static let icon5XLarge: CGFloat = 56
    static let icon6XLarge: CGFloat = 64
}

// MARK: - Haptic Feedback

enum HapticFeedback {
    /// Light — button taps, selections
    case light
    /// Medium — action confirmations
    case medium
    /// Heavy — destructive actions, important events
    case heavy
    /// Delicate — subtle UI interactions
    case delicate
    /// Success — operation completed
    case success
    /// Warning — caution notification
    case warning
    /// Error — error notification
    case error

    @MainActor
    func trigger() {
        let service = UIImpactFeedbackGenerator(style: impactStyle)
        service.prepare()
        service.impactOccurred()

        if let notificationType = notificationType {
            let notification = UINotificationFeedbackGenerator()
            notification.prepare()
            notification.notificationOccurred(notificationType)
        }
    }

    @MainActor
    static func trigger(_ type: HapticFeedback) {
        type.trigger()
    }

    private var impactStyle: UIImpactFeedbackGenerator.FeedbackStyle {
        switch self {
        case .light: return .light
        case .medium: return .medium
        case .heavy: return .heavy
        case .delicate: return .soft
        default: return .medium
        }
    }

    private var notificationType: UINotificationFeedbackGenerator.FeedbackType? {
        switch self {
        case .success: return .success
        case .warning: return .warning
        case .error: return .error
        default: return nil
        }
    }
}

// MARK: - View Extension for Haptics

extension View {
    /// Adds haptic feedback on tap gesture
    func hapticOnTap(_ style: HapticFeedback = .light, action: @escaping () -> Void) -> some View {
        self.onTapGesture {
            Task { @MainActor in
                HapticFeedback.trigger(style)
            }
            action()
        }
    }
}

// MARK: - Standard Button Styles

/// Primary action button — filled accent color
struct BlinkPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.primaryButtonFont)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(
                isEnabled
                    ? LinearGradient(colors: [Theme.accent, Color(hex: "cc2f26")], startPoint: .top, endPoint: .bottom)
                    : LinearGradient(colors: [Color(hex: "333333"), Color(hex: "222222")], startPoint: .top, endPoint: .bottom)
            )
            .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadiusMedium))
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

/// Secondary action button — outlined / ghost style
struct BlinkSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.secondaryButtonFont)
            .foregroundColor(Theme.accent)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(
                RoundedRectangle(cornerRadius: Theme.cornerRadiusMedium)
                    .fill(Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.cornerRadiusMedium)
                            .stroke(Theme.accent, lineWidth: 1.5)
                    )
            )
            .opacity(configuration.isPressed ? 0.7 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

/// Tertiary / destructive button — plain text style
struct BlinkTertiaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .medium))
            .foregroundColor(Theme.textTertiary)
            .opacity(configuration.isPressed ? 0.6 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

/// Card button — for tappable card rows
struct BlinkCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(Theme.backgroundSecondary)
            .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadiusMedium))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cornerRadiusMedium)
                    .stroke(Theme.accent.opacity(0.3), lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.99 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

/// Small pill button — for inline actions
struct BlinkPillButtonStyle: ButtonStyle {
    var color: Color = Theme.accent

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(color)
            .clipShape(Capsule())
            .opacity(configuration.isPressed ? 0.7 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Font Extension for Dynamic Type

/// Dynamic Type-enabled font styles that scale with user accessibility settings.
/// Use these instead of fixed-size Font.system() calls.
enum BlinkFontStyle {
    case largeTitle, title, title2, title3
    case headline, body, callout, subheadline, footnote
    case caption, caption2

    var font: Font {
        switch self {
        case .largeTitle: return .largeTitle
        case .title: return .title
        case .title2: return .title2
        case .title3: return .title3
        case .headline: return .headline
        case .body: return .body
        case .callout: return .callout
        case .subheadline: return .subheadline
        case .footnote: return .footnote
        case .caption: return .caption
        case .caption2: return .caption2
        }
    }
}

extension Font {
    /// Returns a Dynamic Type-enabled font (delegates to BlinkFontStyle)
    static func blinkText(_ style: BlinkFontStyle) -> Font {
        style.font
    }
}

// MARK: - Blur / Material Styles

/// iOS 26 Liquid Glass ultra-thin material
struct GlassBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial)
            .background(Color.black.opacity(0.5))
    }
}

extension View {
    func glassBackground() -> some View {
        modifier(GlassBackground())
    }
}
