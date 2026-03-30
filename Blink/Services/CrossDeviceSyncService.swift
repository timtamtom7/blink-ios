import Foundation
import Network

/// R8: Cross-device sync service for iPad, macOS, Apple Watch
final class CrossDeviceSyncService: ObservableObject {
    static let shared = CrossDeviceSyncService()

    @Published private(set) var isSyncing = false
    @Published private(set) var lastSyncDate: Date?
    @Published private(set) var syncProgress: Double = 0
    @Published private(set) var connectedDevices: [Device] = []
    @Published private(set) var pendingChanges: Int = 0
    @Published private(set) var isConnected = true

    private let networkMonitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "com.blink.sync.networkmonitor")

    struct Device: Identifiable, Codable {
        let id: UUID
        let name: String
        let type: DeviceType
        let lastSeen: Date
        var isConnected: Bool

        enum DeviceType: String, Codable {
            case iPhone
            case iPad
            case mac
            case appleWatch
        }
    }

    enum SyncError: Error, LocalizedError {
        case networkUnavailable
        case authFailed
        case syncFailed
        case deviceNotFound

        var errorDescription: String? {
            switch self {
            case .networkUnavailable: return "No network connection available."
            case .authFailed: return "Authentication failed. Please sign in again."
            case .syncFailed: return "Sync failed. Please try again."
            case .deviceNotFound: return "Device not found."
            }
        }
    }

    private let userDefaults = UserDefaults.standard
    private let syncQueue = DispatchQueue(label: "com.blink.sync", qos: .utility)

    private init() {
        loadLastSyncDate()
        loadConnectedDevices()
        startNetworkMonitoring()
    }

    deinit {
        networkMonitor.cancel()
    }

    private func startNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor [weak self] in
                self?.isConnected = path.status == .satisfied
            }
        }
        networkMonitor.start(queue: monitorQueue)
    }

    // MARK: - Sync Operations

    @MainActor
    func syncAll() async throws {
        guard isConnected else {
            throw SyncError.networkUnavailable
        }
        guard !isSyncing else { return }
        isSyncing = true
        syncProgress = 0

        do {
            // Simulate sync steps
            syncProgress = 0.2
            try await Task.sleep(nanoseconds: 500_000_000)

            syncProgress = 0.5
            try await uploadPendingChanges()

            syncProgress = 0.8
            try await downloadRemoteChanges()

            syncProgress = 1.0
            lastSyncDate = Date()
            saveLastSyncDate()
            isSyncing = false
        } catch {
            isSyncing = false
            throw error
        }
    }

    private func uploadPendingChanges() async throws {
        // Upload new clips, edits, deletions
        try await Task.sleep(nanoseconds: 300_000_000)
    }

    private func downloadRemoteChanges() async throws {
        // Download changes from other devices
        try await Task.sleep(nanoseconds: 300_000_000)
    }

    // MARK: - Device Management

    func registerDevice(_ device: Device) {
        if let index = connectedDevices.firstIndex(where: { $0.id == device.id }) {
            connectedDevices[index] = device
        } else {
            connectedDevices.append(device)
        }
        saveConnectedDevices()
    }

    func removeDevice(_ device: Device) {
        connectedDevices.removeAll { $0.id == device.id }
        saveConnectedDevices()
    }

    // MARK: - Persistence

    private func saveLastSyncDate() {
        userDefaults.set(lastSyncDate, forKey: "blink_last_sync")
    }

    private func loadLastSyncDate() {
        lastSyncDate = userDefaults.object(forKey: "blink_last_sync") as? Date
    }

    private func saveConnectedDevices() {
        if let data = try? JSONEncoder().encode(connectedDevices) {
            userDefaults.set(data, forKey: "blink_connected_devices")
        }
    }

    private func loadConnectedDevices() {
        if let data = userDefaults.data(forKey: "blink_connected_devices"),
           let devices = try? JSONDecoder().decode([Device].self, from: data) {
            connectedDevices = devices
        }
    }

    // MARK: - Helpers

    var lastSyncText: String {
        guard let date = lastSyncDate else { return "Never synced" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return "Synced \(formatter.localizedString(for: date, relativeTo: Date()))"
    }
}
