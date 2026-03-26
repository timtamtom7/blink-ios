import Foundation
import Combine

/// R15: Cross-Platform Sync and Export Hub Service
final class CrossPlatformSyncService: ObservableObject {
    static let shared = CrossPlatformSyncService()
    
    @Published var registeredDevices: [CrossPlatformDevice] = []
    @Published var unifiedTimeline: [UnifiedTimelineEntry] = []
    @Published var syncConflicts: [SyncConflict] = []
    @Published var exportJobs: [ExportJob] = []
    @Published var googlePhotosIntegration: GooglePhotosIntegration = GooglePhotosIntegration()
    @Published var isSyncing = false
    
    private let userDefaults = UserDefaults.standard
    private var syncTimer: Timer?
    
    private init() { loadFromDisk() }
    
    // MARK: - Device Registration
    
    func registerDevice(name: String, platform: CrossPlatformDevice.Platform) -> CrossPlatformDevice {
        let device = CrossPlatformDevice(deviceName: name, platform: platform)
        registeredDevices.append(device)
        saveToDisk()
        return device
    }
    
    func unregisterDevice(_ deviceID: UUID) {
        registeredDevices.removeAll { $0.id == deviceID }
        saveToDisk()
    }
    
    func setPrimaryDevice(_ deviceID: UUID) {
        for i in registeredDevices.indices {
            registeredDevices[i].isPrimary = (registeredDevices[i].id == deviceID)
        }
        saveToDisk()
    }
    
    // MARK: - Sync
    
    func startSync() async {
        await MainActor.run { isSyncing = true }
        
        // Simulate sync operation
        try? await Task.sleep(nanoseconds: 2_000_000_000)
        
        // Update last sync time
        await MainActor.run {
            for i in registeredDevices.indices {
                registeredDevices[i].lastSyncAt = Date()
            }
            isSyncing = false
        }
        
        saveToDisk()
    }
    
    func resolveConflict(_ conflictID: UUID, resolution: SyncConflict.Resolution) {
        guard let index = syncConflicts.firstIndex(where: { $0.id == conflictID }) else { return }
        syncConflicts[index].resolution = resolution
        saveToDisk()
    }
    
    // MARK: - Export Hub
    
    func createExportJob(name: String, clipIDs: [UUID], format: ExportFormat) -> ExportJob {
        let job = ExportJob(name: name, clipIDs: clipIDs, format: format, status: .pending)
        exportJobs.append(job)
        saveToDisk()
        processExportJob(job.id)
        return job
    }
    
    private func processExportJob(_ jobID: UUID) {
        guard let index = exportJobs.firstIndex(where: { $0.id == jobID }) else { return }
        
        exportJobs[index].status = .processing
        exportJobs[index].startedAt = Date()
        
        // Simulate export processing
        Task {
            for i in 1...10 {
                try? await Task.sleep(nanoseconds: 500_000_000)
                await MainActor.run {
                    if let idx = self.exportJobs.firstIndex(where: { $0.id == jobID }) {
                        self.exportJobs[idx].progress = Double(i) / 10.0
                    }
                }
            }
            
            await MainActor.run {
                if let idx = self.exportJobs.firstIndex(where: { $0.id == jobID }) {
                    self.exportJobs[idx].status = .completed
                    self.exportJobs[idx].completedAt = Date()
                    self.exportJobs[idx].progress = 1.0
                    self.exportJobs[idx].outputURL = "file://export/\(jobID.uuidString)"
                }
            }
            self.saveToDisk()
        }
    }
    
    func cancelExportJob(_ jobID: UUID) {
        exportJobs.removeAll { $0.id == jobID }
        saveToDisk()
    }
    
    // MARK: - Google Photos
    
    func enableGooglePhotosBackup(autoBackup: Bool, folderName: String = "Blink") {
        googlePhotosIntegration.isEnabled = true
        googlePhotosIntegration.autoBackup = autoBackup
        googlePhotosIntegration.backupFolderName = folderName
        saveToDisk()
    }
    
    func disableGooglePhotosBackup() {
        googlePhotosIntegration.isEnabled = false
        googlePhotosIntegration.autoBackup = false
        saveToDisk()
    }
    
    // MARK: - Persistence
    
    private func saveToDisk() {
        if let data = try? JSONEncoder().encode(registeredDevices) {
            userDefaults.set(data, forKey: "blink_devices")
        }
        if let data = try? JSONEncoder().encode(unifiedTimeline) {
            userDefaults.set(data, forKey: "blink_unified_timeline")
        }
        if let data = try? JSONEncoder().encode(syncConflicts) {
            userDefaults.set(data, forKey: "blink_sync_conflicts")
        }
        if let data = try? JSONEncoder().encode(exportJobs) {
            userDefaults.set(data, forKey: "blink_export_jobs")
        }
        if let data = try? JSONEncoder().encode(googlePhotosIntegration) {
            userDefaults.set(data, forKey: "blink_gphotos_integration")
        }
    }
    
    private func loadFromDisk() {
        if let data = userDefaults.data(forKey: "blink_devices"),
           let decoded = try? JSONDecoder().decode([CrossPlatformDevice].self, from: data) {
            registeredDevices = decoded
        }
        if let data = userDefaults.data(forKey: "blink_unified_timeline"),
           let decoded = try? JSONDecoder().decode([UnifiedTimelineEntry].self, from: data) {
            unifiedTimeline = decoded
        }
        if let data = userDefaults.data(forKey: "blink_sync_conflicts"),
           let decoded = try? JSONDecoder().decode([SyncConflict].self, from: data) {
            syncConflicts = decoded
        }
        if let data = userDefaults.data(forKey: "blink_export_jobs"),
           let decoded = try? JSONDecoder().decode([ExportJob].self, from: data) {
            exportJobs = decoded
        }
        if let data = userDefaults.data(forKey: "blink_gphotos_integration"),
           let decoded = try? JSONDecoder().decode(GooglePhotosIntegration.self, from: data) {
            googlePhotosIntegration = decoded
        }
    }
}
