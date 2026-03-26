import Foundation
import Combine
import Network
import CoreLocation

/// R13: Apple Ecosystem Service — watchOS, visionOS, tvOS, iPad multi-cam
final class AppleEcosystemService: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let shared = AppleEcosystemService()
    
    @Published var watchClips: [WatchClip] = []
    @Published var spatialMemories: [SpatialMemory] = []
    @Published var familyRooms: [AppleTVFamilyRoom] = []
    @Published var multiCamSessions: [MultiCamSession] = []
    @Published var remoteCommand: RemoteRecordCommand?
    @Published var isSearchingForDevices = false
    @Published var discoveredDevices: [String] = [] // Device names/IPs
    
    private let userDefaults = UserDefaults.standard
    private let locationManager = CLLocationManager()
    private var browser: NWBrowser?
    private var cancellables = Set<AnyCancellable>()
    
    private override init() {
        super.init()
        locationManager.delegate = self
        loadFromDisk()
    }
    
    // MARK: - watchOS
    
    func generateWatchClip(for clipID: UUID) -> WatchClip {
        let clip = WatchClip(originalClipID: clipID, duration: 10)
        watchClips.append(clip)
        saveToDisk()
        return clip
    }
    
    func setMemoryOfTheDay(clipID: UUID) {
        // Clear previous
        for i in watchClips.indices {
            watchClips[i].isMemoryOfTheDay = false
        }
        // Set new
        if let index = watchClips.firstIndex(where: { $0.originalClipID == clipID }) {
            watchClips[index].isMemoryOfTheDay = true
        }
        saveToDisk()
    }
    
    func recentWatchClips(days: Int = 3) -> [WatchClip] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        return watchClips.filter { $0.recordedAt >= cutoff }.sorted { $0.recordedAt > $1.recordedAt }
    }
    
    func handleRemoteCommand(_ command: RemoteRecordCommand) {
        remoteCommand = command
        NotificationCenter.default.post(name: .remoteRecordCommand, object: nil, userInfo: ["command": command])
    }
    
    // MARK: - visionOS Spatial
    
    func createSpatialMemory(clipID: UUID, location: CLLocation? = nil) -> SpatialMemory {
        var spatial = SpatialMemory(clipID: clipID)
        if let loc = location {
            spatial.latitude = loc.coordinate.latitude
            spatial.longitude = loc.coordinate.longitude
        }
        spatialMemories.append(spatial)
        saveToDisk()
        return spatial
    }
    
    func enableMemoryRoom(for clipID: UUID) {
        if let index = spatialMemories.firstIndex(where: { $0.clipID == clipID }) {
            spatialMemories[index].memoryRoomEnabled = true
            saveToDisk()
        }
    }
    
    // MARK: - Apple TV Family Room
    
    func setupFamilyRoom(memberIDs: [String], screensaverSource: AppleTVFamilyRoom.ScreensaverSource) -> AppleTVFamilyRoom {
        let room = AppleTVFamilyRoom(familyMemberIDs: memberIDs, screensaverSource: screensaverSource)
        familyRooms.append(room)
        saveToDisk()
        return room
    }
    
    func syncFamilyRoom(_ roomID: UUID) {
        if let index = familyRooms.firstIndex(where: { $0.id == roomID }) {
            familyRooms[index].lastSyncAt = Date()
            saveToDisk()
        }
    }
    
    func familyRoomScreensaverClips(for roomID: UUID) -> [UUID] {
        guard let room = familyRooms.first(where: { $0.id == roomID }) else { return [] }
        let allEntries = VideoStore.shared.entries
        switch room.screensaverSource {
        case .aiCurated:
            return Array(allEntries.prefix(20).map { $0.id })
        case .recentClips:
            return Array(allEntries.prefix(20).map { $0.id })
        case .specificAlbums:
            return SharedAlbumService.shared.sharedAlbums.first { _ in true }?.clipIDs ?? []
        case .onThisDay:
            return SharedAlbumService.shared.sharedAlbums.first { _ in true }?.onThisDayClipIDs ?? []
        }
    }
    
    // MARK: - iPad Multi-Cam
    
    func startMultiCamSession() -> MultiCamSession {
        let session = MultiCamSession(status: .searching)
        multiCamSessions.append(session)
        searchForLocalDevices()
        saveToDisk()
        return session
    }
    
    func connectDeviceToSession(_ sessionID: UUID, deviceID: String) {
        guard let index = multiCamSessions.firstIndex(where: { $0.id == sessionID }) else { return }
        if !multiCamSessions[index].connectedDeviceIDs.contains(deviceID) {
            multiCamSessions[index].connectedDeviceIDs.append(deviceID)
            multiCamSessions[index].status = .connected
        }
        saveToDisk()
    }
    
    func endMultiCamSession(_ sessionID: UUID) {
        guard let index = multiCamSessions.firstIndex(where: { $0.id == sessionID }) else { return }
        multiCamSessions[index].endedAt = Date()
        multiCamSessions[index].status = .completed
        saveToDisk()
    }
    
    // MARK: - Local Network Discovery
    
    private func searchForLocalDevices() {
        isSearchingForDevices = true
        discoveredDevices = []
        
        browser = NWBrowser(for: .bonjour(type: "_blink._tcp", domain: nil), using: .tcp)
        browser?.browseResultsChangedHandler = { [weak self] results, _ in
            let devices = results.compactMap { result -> String? in
                switch result.endpoint {
                case .service(let name, _, _, _):
                    return name
                default:
                    return nil
                }
            }
            DispatchQueue.main.async {
                self?.discoveredDevices = devices
            }
        }
        browser?.start(queue: .main)
        
        // Stop after 10 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) { [weak self] in
            self?.browser?.cancel()
            self?.isSearchingForDevices = false
        }
    }
    
    // MARK: - Persistence
    
    private func saveToDisk() {
        if let data = try? JSONEncoder().encode(watchClips) {
            userDefaults.set(data, forKey: "blink_watch_clips")
        }
        if let data = try? JSONEncoder().encode(spatialMemories) {
            userDefaults.set(data, forKey: "blink_spatial_memories")
        }
        if let data = try? JSONEncoder().encode(familyRooms) {
            userDefaults.set(data, forKey: "blink_family_rooms")
        }
        if let data = try? JSONEncoder().encode(multiCamSessions) {
            userDefaults.set(data, forKey: "blink_multicam_sessions")
        }
    }
    
    private func loadFromDisk() {
        if let data = userDefaults.data(forKey: "blink_watch_clips"),
           let decoded = try? JSONDecoder().decode([WatchClip].self, from: data) {
            watchClips = decoded
        }
        if let data = userDefaults.data(forKey: "blink_spatial_memories"),
           let decoded = try? JSONDecoder().decode([SpatialMemory].self, from: data) {
            spatialMemories = decoded
        }
        if let data = userDefaults.data(forKey: "blink_family_rooms"),
           let decoded = try? JSONDecoder().decode([AppleTVFamilyRoom].self, from: data) {
            familyRooms = decoded
        }
        if let data = userDefaults.data(forKey: "blink_multicam_sessions"),
           let decoded = try? JSONDecoder().decode([MultiCamSession].self, from: data) {
            multiCamSessions = decoded
        }
    }
    
    // MARK: - CLLocationManagerDelegate
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        // Handle location updates for spatial memories
    }
}

extension Notification.Name {
    static let remoteRecordCommand = Notification.Name("remoteRecordCommand")
}
