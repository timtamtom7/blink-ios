import SwiftUI

// MARK: - Passcode Setup View

struct PasscodeSetupView: View {
    let onComplete: () -> Void

    @ObservedObject private var privacy = PrivacyService.shared
    @Environment(\.dismiss) private var dismiss
    @State private var passcode: String = ""
    @State private var confirmPasscode: String = ""
    @State private var step: SetupStep = .enter
    @State private var wrongPasscode: Bool = false

    enum SetupStep {
        case enter
        case confirm
        case biometricPrompt
    }

    var body: some View {
        ZStack {
            Color(hex: "0a0a0a")
                .ignoresSafeArea()

            VStack(spacing: 40) {
                Spacer()

                // Header
                VStack(spacing: 8) {
                    Text(step == .confirm ? "Confirm Passcode" : "Create Passcode")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(Color(hex: "f5f5f5"))

                    Text(step == .confirm ? "Enter your passcode again" : "Enter a 6-digit passcode")
                        .font(.system(size: 15))
                        .foregroundColor(Color(hex: "8a8a8a"))
                }

                // Dots
                passcodeDots

                // Keypad
                numericKeypad

                Spacer()
            }
        }
    }

    private var currentPasscode: String {
        step == .confirm ? confirmPasscode : passcode
    }

    private var passcodeDots: some View {
        HStack(spacing: 16) {
            ForEach(0..<6, id: \.self) { index in
                Circle()
                    .fill(index < currentPasscode.count ? Color(hex: "ff3b30") : Color(hex: "2a2a2a"))
                    .frame(width: 14, height: 14)
                    .scaleEffect(index < currentPasscode.count ? 1.2 : 1.0)
                    .animation(.spring(response: 0.15, dampingFraction: 0.6), value: currentPasscode.count)
            }
        }
        .overlay {
            if wrongPasscode {
                Text(step == .confirm ? "Passcodes don't match" : "Try again")
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: "ff3b30"))
                    .offset(y: 30)
            }
        }
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
                    .foregroundColor(Color(hex: "f5f5f5"))
                    .frame(width: 72, height: 72)
            }
        } else {
            Button {
                addDigit(key)
            } label: {
                Text(key)
                    .font(.system(size: 28, weight: .medium, design: .rounded))
                    .foregroundColor(Color(hex: "f5f5f5"))
                    .frame(width: 72, height: 72)
                    .background(Circle().fill(Color(hex: "1e1e1e")))
            }
        }
    }

    private func addDigit(_ digit: String) {
        wrongPasscode = false
        if step == .confirm {
            if confirmPasscode.count < 6 {
                confirmPasscode += digit
                if confirmPasscode.count == 6 {
                    verifyConfirm()
                }
            }
        } else {
            if passcode.count < 6 {
                passcode += digit
                if passcode.count == 6 {
                    step = .confirm
                }
            }
        }
    }

    private func deleteDigit() {
        if step == .confirm {
            if !confirmPasscode.isEmpty {
                confirmPasscode.removeLast()
            }
        } else {
            if !passcode.isEmpty {
                passcode.removeLast()
            }
        }
    }

    private func verifyConfirm() {
        if passcode == confirmPasscode {
            if privacy.setPasscode(passcode) {
                // Ask about biometrics
                if privacy.biometricType != .none {
                    askBiometric()
                } else {
                    onComplete()
                }
            } else {
                wrongPasscode = true
                reset()
            }
        } else {
            wrongPasscode = true
            confirmPasscode = ""
        }
    }

    private func askBiometric() {
        // Automatically enable biometrics if available
        privacy.isBiometricEnabled = true
        onComplete()
    }

    private func reset() {
        passcode = ""
        confirmPasscode = ""
        step = .enter
    }
}

#Preview {
    PasscodeSetupView(onComplete: {})
        .preferredColorScheme(.dark)
}
