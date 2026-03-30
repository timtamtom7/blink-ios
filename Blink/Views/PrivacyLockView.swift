import SwiftUI

// MARK: - Privacy Lock View

struct PrivacyLockView: View {
    @ObservedObject private var privacy = PrivacyService.shared
    @State private var passcode: String = ""
    @State private var confirmPasscode: String = ""
    @State private var isSettingUp: Bool = false
    @State private var showSetup: Bool = false
    @State private var isConfirming: Bool = false
    @State private var wrongPasscode: Bool = false
    @State private var isAuthenticating: Bool = false
    @State private var biometricTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            Theme.background
                .ignoresSafeArea()

            VStack(spacing: 40) {
                Spacer()

                // Lock icon
                lockIcon

                // Title
                VStack(spacing: 8) {
                    Text(lockTitle)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(Theme.textPrimary)

                    Text(lockSubtitle)
                        .font(.system(size: 15))
                        .foregroundColor(Theme.textTertiary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                // Passcode dots
                passcodeDots
                    .padding(.top, 8)

                // Keypad
                numericKeypad

                Spacer()
            }
        }
        .onAppear {
            if !isSettingUp {
                attemptBiometric()
            }
        }
    }

    private var lockTitle: String {
        if isSettingUp {
            return isConfirming ? "Confirm passcode" : "Create passcode"
        }
        return "Blink is locked"
    }

    private var lockSubtitle: String {
        if isSettingUp {
            return isConfirming ? "Enter your 6-digit passcode again" : "Enter a 6-digit passcode to lock your app"
        }
        return "Unlock to view your memories"
    }

    private var lockIcon: some View {
        ZStack {
            Circle()
                .fill(Theme.accent.opacity(0.15))
                .frame(width: 100, height: 100)

            Image(systemName: privacy.biometricType.iconName)
                .font(.system(size: 40))
                .foregroundColor(Theme.accent)
        }
    }

    private var passcodeDots: some View {
        HStack(spacing: 16) {
            ForEach(0..<6, id: \.self) { index in
                Circle()
                    .fill(index < currentPasscode.count ? Theme.accent : Theme.backgroundQuaternary)
                    .frame(width: 14, height: 14)
                    .scaleEffect(index < currentPasscode.count ? 1.2 : 1.0)
            }
        }
        .overlay {
            if wrongPasscode {
                Text("Wrong passcode")
                    .font(.system(size: 12))
                    .foregroundColor(Theme.accent)
                    .offset(y: 30)
            }
        }
    }

    private var currentPasscode: String {
        isConfirming ? confirmPasscode : passcode
    }

    private var numericKeypad: some View {
        VStack(spacing: 16) {
            ForEach(keypadRows, id: \.self) { row in
                HStack(spacing: 32) {
                    ForEach(row, id: \.self) { key in
                        keyButton(for: key)
                    }
                }
            }
        }
    }

    private var keypadRows: [[String]] {
        [
            ["1", "2", "3"],
            ["4", "5", "6"],
            ["7", "8", "9"],
            ["", "0", "⌫"]
        ]
    }

    @ViewBuilder
    private func keyButton(for key: String) -> some View {
        if key.isEmpty {
            Color.clear
                .frame(width: 72, height: 72)
        } else if key == "⌫" {
            Button {
                deleteDigit()
            } label: {
                Image(systemName: "delete.left")
                    .font(.system(size: 22))
                    .foregroundColor(Theme.textPrimary)
                    .frame(width: 72, height: 72)
            }
        } else {
            Button {
                addDigit(key)
            } label: {
                Text(key)
                    .font(.system(size: 28, weight: .medium, design: .rounded))
                    .foregroundColor(Theme.textPrimary)
                    .frame(width: 72, height: 72)
                    .background(Circle().fill(Theme.backgroundTertiary))
            }
        }
    }

    private func addDigit(_ digit: String) {
        wrongPasscode = false
        if isConfirming {
            if confirmPasscode.count < 6 {
                confirmPasscode += digit
                if confirmPasscode.count == 6 {
                    verifyConfirm()
                }
            }
        } else if isSettingUp {
            if passcode.count < 6 {
                passcode += digit
                if passcode.count == 6 {
                    isConfirming = true
                }
            }
        } else {
            if passcode.count < 6 {
                passcode += digit
                if passcode.count == 6 {
                    verifyPasscode()
                }
            }
        }
    }

    private func deleteDigit() {
        if isConfirming {
            if !confirmPasscode.isEmpty {
                confirmPasscode.removeLast()
            }
        } else {
            if !passcode.isEmpty {
                passcode.removeLast()
            }
        }
    }

    private func verifyPasscode() {
        if privacy.verifyPasscode(passcode) {
            privacy.unlockApp()
        } else {
            wrongPasscode = true
            passcode = ""
            shakeAnimation()
        }
    }

    private func verifyConfirm() {
        if passcode == confirmPasscode {
            if privacy.setPasscode(passcode) {
                // Passcode set, but app is now locked
                // User needs to unlock with biometrics or passcode
                isSettingUp = false
                isConfirming = false
                passcode = ""
                confirmPasscode = ""
                attemptBiometric()
            }
        } else {
            wrongPasscode = true
            confirmPasscode = ""
            shakeAnimation()
        }
    }

    private func attemptBiometric() {
        guard privacy.isBiometricEnabled else { return }
        guard privacy.biometricType != .none else { return }

        isAuthenticating = true
        biometricTask = Task {
            let success = await privacy.unlockWithBiometrics()
            await MainActor.run {
                isAuthenticating = false
                if !success {
                    // Biometric failed, user must enter passcode
                }
            }
        }
    }

    private func shakeAnimation() {
        // Simple wrong-passcode feedback - passcode dots will shake via wrongPasscode flag
    }
}

// MARK: - Privacy Lock Button Graphic

struct PrivacyLockButtonGraphic: View {
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Theme.accent.opacity(0.15))
                    .frame(width: 44, height: 44)

                Image(systemName: "lock.fill")
                    .font(.system(size: 18))
                    .foregroundColor(Theme.accent)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("App Lock")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Theme.textPrimary)

                Text("Require passcode to open Blink")
                    .font(.system(size: 11))
                    .foregroundColor(Theme.textTertiary)
            }

            Spacer()
        }
        .padding(12)
        .background(Theme.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadiusMedium))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cornerRadiusMedium)
                .stroke(Theme.accent.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Lock Individual Clip View

struct LockClipView: View {
    let entry: VideoEntry
    @ObservedObject private var privacy = PrivacyService.shared
    @Environment(\.dismiss) private var dismiss
    @State private var isLocked: Bool = false
    @State private var showPasscodeSheet = false

    var body: some View {
        VStack(spacing: 24) {
            // Lock icon
            ZStack {
                Circle()
                    .fill(Theme.accent.opacity(0.15))
                    .frame(width: 80, height: 80)

                Image(systemName: isLocked ? "lock.fill" : "lock.open.fill")
                    .font(.system(size: 32))
                    .foregroundColor(Theme.accent)
            }

            VStack(spacing: 8) {
                Text(isLocked ? "Clip locked" : "Clip unlocked")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(Theme.textPrimary)

                Text(isLocked ? "This clip is hidden from Year in Review and On This Day." : "This clip appears in your year highlights.")
                    .font(.system(size: 14))
                    .foregroundColor(Theme.textTertiary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            // Toggle
            Toggle(isOn: $isLocked) {
                HStack {
                    Image(systemName: isLocked ? "eye.slash.fill" : "eye.fill")
                        .foregroundColor(Theme.accent)
                    Text(isLocked ? "Hide from highlights" : "Show in highlights")
                        .font(.system(size: 15))
                        .foregroundColor(Theme.textPrimary)
                }
            }
            .tint(Theme.accent)
            .padding(.horizontal, 32)

            Button {
                dismiss()
            } label: {
                Text("Done")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(Theme.accent)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadiusMedium))
            }
            .padding(.horizontal, 32)
        }
        .padding(.vertical, 32)
        .background(Theme.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadiusLarge))
        .padding(.horizontal, 32)
    }
}

// MARK: - Privacy Icon Graphic

struct PrivacyLockIconGraphic: View {
    @State private var isAnimating = false
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    var body: some View {
        ZStack {
            // Outer circle
            Circle()
                .stroke(Theme.accent.opacity(0.3), lineWidth: 2)
                .frame(width: 80, height: 80)

            // Inner filled circle
            Circle()
                .fill(Theme.accent.opacity(0.15))
                .frame(width: 60, height: 60)
                .scaleEffect(isAnimating ? 1.1 : 1.0)

            // Lock icon
            Image(systemName: "lock.fill")
                .font(.system(size: 24))
                .foregroundColor(Theme.accent)
        }
        .onAppear {
            if !reduceMotion {
                isAnimating = true
            }
        }
        .animation(reduceMotion ? .none : .easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: isAnimating)
    }
}

#Preview("Privacy Lock") {
    PrivacyLockView()
        .preferredColorScheme(.dark)
}
