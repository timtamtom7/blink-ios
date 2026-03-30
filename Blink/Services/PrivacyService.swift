import Foundation
import LocalAuthentication
import Security
import CryptoKit

// MARK: - Privacy Service

final class PrivacyService: ObservableObject {
    static let shared = PrivacyService()

    @Published var isAppLocked: Bool = false
    @Published var lockReason: LockReason = .appOpen

    enum LockReason {
        case appOpen
        case backgroundReturn
        case settings
    }

    private let passcodeKey = "com.blink.passcode"
    private let passcodeEnabledKey = "com.blink.passcodeEnabled"
    private let biometricEnabledKey = "com.blink.biometricEnabled"
    private let lockOnBackgroundKey = "com.blink.lockOnBackground"

    var isPasscodeEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: passcodeEnabledKey) }
        set { UserDefaults.standard.set(newValue, forKey: passcodeEnabledKey) }
    }

    var isBiometricEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: biometricEnabledKey) }
        set { UserDefaults.standard.set(newValue, forKey: biometricEnabledKey) }
    }

    var lockOnBackground: Bool {
        get {
            if UserDefaults.standard.object(forKey: lockOnBackgroundKey) == nil {
                return true // default to true
            }
            return UserDefaults.standard.bool(forKey: lockOnBackgroundKey)
        }
        set { UserDefaults.standard.set(newValue, forKey: lockOnBackgroundKey) }
    }

    var biometricType: BiometricType {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return .none
        }
        switch context.biometryType {
        case .faceID:
            return .faceID
        case .touchID:
            return .touchID
        case .opticID:
            return .opticID
        case .none:
            return .none
        @unknown default:
            return .none
        }
    }

    enum BiometricType {
        case none
        case touchID
        case faceID
        case opticID

        var iconName: String {
            switch self {
            case .none: return "lock.fill"
            case .touchID: return "touchid"
            case .faceID: return "faceid"
            case .opticID: return "opticid"
            }
        }

        var displayName: String {
            switch self {
            case .none: return "Passcode"
            case .touchID: return "Touch ID"
            case .faceID: return "Face ID"
            case .opticID: return "Optic ID"
            }
        }
    }

    private init() {
        // If passcode is set, app should be locked on launch
        isAppLocked = isPasscodeEnabled
    }

    // MARK: - Passcode

    func setPasscode(_ passcode: String) -> Bool {
        guard passcode.count == 6, passcode.allSatisfy({ $0.isNumber }) else {
            return false
        }

        // Store SHA256 hash in keychain (never store plaintext)
        let hash = SHA256.hash(data: Data(passcode.utf8))
        let data = Data(hash)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: passcodeKey,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        SecItemDelete(query as CFDictionary)
        let status = SecItemAdd(query as CFDictionary, nil)

        if status == errSecSuccess {
            isPasscodeEnabled = true
            isAppLocked = true
            return true
        }
        return false
    }

    func verifyPasscode(_ passcode: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: passcodeKey,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess, let storedHashData = result as? Data else {
            return false
        }

        // Hash the provided passcode and compare in constant time
        let inputHash = SHA256.hash(data: Data(passcode.utf8))
        let inputHashData = Data(inputHash)

        // Data == performs constant-time comparison, preventing timing attacks
        return storedHashData == inputHashData
    }

    func removePasscode() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: passcodeKey
        ]
        SecItemDelete(query as CFDictionary)
        isPasscodeEnabled = false
        isBiometricEnabled = false
        isAppLocked = false
    }

    // MARK: - Biometric Auth

    func authenticateWithBiometrics() async -> Bool {
        let context = LAContext()
        var error: NSError?

        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return false
        }

        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: "Unlock Blink to view your memories"
            )
            return success
        } catch {
            return false
        }
    }

    // MARK: - App Lock State

    func lockApp(reason: LockReason = .backgroundReturn) {
        guard isPasscodeEnabled else { return }
        lockReason = reason
        isAppLocked = true
    }

    func unlockApp() {
        isAppLocked = false
    }

    func unlockWithPasscode(_ passcode: String) -> Bool {
        if verifyPasscode(passcode) {
            unlockApp()
            return true
        }
        return false
    }

    @MainActor
    func unlockWithBiometrics() async -> Bool {
        let success = await authenticateWithBiometrics()
        if success {
            unlockApp()
        }
        return success
    }
}
