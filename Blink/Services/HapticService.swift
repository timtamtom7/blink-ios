import UIKit

/// Centralized haptic feedback service for Blink.
/// Provides tactile responses for key interactions throughout the app.
final class HapticService {
    static let shared = HapticService()

    private let lightImpact = UIImpactFeedbackGenerator(style: .light)
    private let mediumImpact = UIImpactFeedbackGenerator(style: .medium)
    private let heavyImpact = UIImpactFeedbackGenerator(style: .heavy)
    private let rigidImpact = UIImpactFeedbackGenerator(style: .rigid)
    private let softImpact = UIImpactFeedbackGenerator(style: .soft)
    private let notification = UINotificationFeedbackGenerator()
    private let selection = UISelectionFeedbackGenerator()

    private init() {
        prepareAll()
    }

    // MARK: - Prepare (pre-warm for low latency)

    private func prepareAll() {
        lightImpact.prepare()
        mediumImpact.prepare()
        heavyImpact.prepare()
        rigidImpact.prepare()
        softImpact.prepare()
        notification.prepare()
        selection.prepare()
    }

    // MARK: - Recording Actions

    /// Light tap when user taps the record button (before countdown starts).
    func recordButtonTap() {
        lightImpact.impactOccurred(intensity: 0.7)
    }

    /// Strong feedback when recording actually starts (after countdown).
    func recordingStarted() {
        heavyImpact.impactOccurred(intensity: 1.0)
    }

    /// Medium feedback when recording stops.
    func recordingStopped() {
        mediumImpact.impactOccurred(intensity: 0.9)
    }

    /// Warning feedback when max duration is approaching (at 5 seconds remaining).
    func durationWarning() {
        notification.notificationOccurred(.warning)
    }

    /// Error feedback when recording fails.
    func recordingFailed() {
        notification.notificationOccurred(.error)
    }

    // MARK: - Countdown

    /// Selection tick for each second of the countdown (3, 2, 1).
    func countdownTick() {
        selection.selectionChanged()
    }

    /// Strong tick on the final "GO" moment (or when recording starts).
    func countdownComplete() {
        rigidImpact.impactOccurred(intensity: 1.0)
    }

    // MARK: - Clip Saved

    /// Success feedback when a clip is saved.
    func clipSaved() {
        notification.notificationOccurred(.success)
    }

    // MARK: - Navigation & Selection

    /// Light tap for button presses.
    func buttonTap() {
        lightImpact.impactOccurred(intensity: 0.6)
    }

    /// Medium tap for significant actions (delete, share, etc.).
    func actionTap() {
        mediumImpact.impactOccurred(intensity: 0.8)
    }

    /// Selection change (tab switches, toggles).
    func selectionChanged() {
        selection.selectionChanged()
    }

    // MARK: - Trim

    /// Feedback when trim handles are moved.
    func trimHandleMoved() {
        lightImpact.impactOccurred(intensity: 0.5)
    }

    /// Success feedback when trim is saved.
    func trimSaved() {
        notification.notificationOccurred(.success)
    }

    // MARK: - Delete

    /// Destructive action feedback.
    func deleteAction() {
        notification.notificationOccurred(.error)
    }

    // MARK: - Playback

    /// Feedback when playback speed changes.
    func speedChanged() {
        selection.selectionChanged()
    }

    // MARK: - App Lock

    /// Feedback when biometric auth succeeds.
    func biometricSuccess() {
        notification.notificationOccurred(.success)
    }

    /// Feedback when biometric or passcode auth fails.
    func biometricFailed() {
        notification.notificationOccurred(.error)
    }

    // MARK: - Error

    /// General error feedback.
    func error() {
        notification.notificationOccurred(.error)
    }
}
