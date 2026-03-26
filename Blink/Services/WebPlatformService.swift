import Foundation
import Combine

/// R14: Web Platform and API Service
final class WebPlatformService: ObservableObject {
    static let shared = WebPlatformService()
    
    @Published var apiCredentials: BlinkAPICredentials?
    @Published var webSessions: [WebSession] = []
    @Published var sharedAlbumAccessLinks: [SharedAlbumWebAccess] = []
    @Published var scheduledExports: [ScheduledExport] = []
    
    private let userDefaults = UserDefaults.standard
    
    private init() { loadFromDisk() }
    
    // MARK: - Developer API
    
    func registerDeveloperAPP(tier: BlinkAPICredentials.APITier = .free) -> BlinkAPICredentials {
        let creds = BlinkAPICredentials(tier: tier)
        apiCredentials = creds
        saveToDisk()
        return creds
    }
    
    func apiRequest(endpoint: BlinkAPIConfig.Endpoint, method: String = "GET", clipID: UUID? = nil, body: Data? = nil) async throws -> Data {
        guard let credentials = apiCredentials else {
            throw APIError.notAuthenticated
        }
        
        let config = BlinkAPIConfig(credentials: credentials)
        guard let url = config.url(for: endpoint, clipID: clipID) else {
            throw APIError.invalidEndpoint
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(credentials.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.networkError
        }
        
        switch httpResponse.statusCode {
        case 200...299:
            return data
        case 401:
            throw APIError.notAuthenticated
        case 429:
            throw APIError.rateLimitExceeded
        default:
            throw APIError.serverError(httpResponse.statusCode)
        }
    
    }
    
    // MARK: - Web Sessions
    
    func createWebSession(userID: String, isPro: Bool = false) -> WebSession {
        let session = WebSession(userID: userID, isPro: isPro)
        webSessions.append(session)
        saveToDisk()
        return session
    }
    
    // MARK: - Shared Album Web Access
    
    func createSharedAlbumLink(albumID: UUID, allowDownload: Bool = false) -> SharedAlbumWebAccess {
        let access = SharedAlbumWebAccess(albumID: albumID, allowDownload: allowDownload)
        sharedAlbumAccessLinks.append(access)
        saveToDisk()
        return access
    }
    
    // MARK: - Scheduled Exports
    
    func createScheduledExport(name: String, frequency: ScheduledExport.Frequency, format: ExportFormat) -> ScheduledExport {
        let nextRun = calculateNextRun(frequency: frequency)
        let export = ScheduledExport(name: name, frequency: frequency, format: format, nextRunAt: nextRun)
        scheduledExports.append(export)
        saveToDisk()
        return export
    }
    
    func deleteScheduledExport(_ exportID: UUID) {
        scheduledExports.removeAll { $0.id == exportID }
        saveToDisk()
    }
    
    private func calculateNextRun(frequency: ScheduledExport.Frequency) -> Date {
        let calendar = Calendar.current
        switch frequency {
        case .weekly:
            return calendar.date(byAdding: .weekOfYear, value: 1, to: Date()) ?? Date()
        case .monthly:
            return calendar.date(byAdding: .month, value: 1, to: Date()) ?? Date()
        case .quarterly:
            return calendar.date(byAdding: .month, value: 3, to: Date()) ?? Date()
        case .yearly:
            return calendar.date(byAdding: .year, value: 1, to: Date()) ?? Date()
        }
    }
    
    // MARK: - Persistence
    
    private func saveToDisk() {
        if let data = try? JSONEncoder().encode(apiCredentials) {
            userDefaults.set(data, forKey: "blink_api_credentials")
        }
        if let data = try? JSONEncoder().encode(webSessions) {
            userDefaults.set(data, forKey: "blink_web_sessions")
        }
        if let data = try? JSONEncoder().encode(sharedAlbumAccessLinks) {
            userDefaults.set(data, forKey: "blink_shared_album_access")
        }
        if let data = try? JSONEncoder().encode(scheduledExports) {
            userDefaults.set(data, forKey: "blink_scheduled_exports")
        }
    }
    
    private func loadFromDisk() {
        if let data = userDefaults.data(forKey: "blink_api_credentials"),
           let decoded = try? JSONDecoder().decode(BlinkAPICredentials.self, from: data) {
            apiCredentials = decoded
        }
        if let data = userDefaults.data(forKey: "blink_web_sessions"),
           let decoded = try? JSONDecoder().decode([WebSession].self, from: data) {
            webSessions = decoded
        }
        if let data = userDefaults.data(forKey: "blink_shared_album_access"),
           let decoded = try? JSONDecoder().decode([SharedAlbumWebAccess].self, from: data) {
            sharedAlbumAccessLinks = decoded
        }
        if let data = userDefaults.data(forKey: "blink_scheduled_exports"),
           let decoded = try? JSONDecoder().decode([ScheduledExport].self, from: data) {
            scheduledExports = decoded
        }
    }
}

enum APIError: Error, LocalizedError {
    case notAuthenticated
    case invalidEndpoint
    case networkError
    case rateLimitExceeded
    case serverError(Int)
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated: return "Not authenticated. Please register for API access."
        case .invalidEndpoint: return "Invalid API endpoint."
        case .networkError: return "Network error occurred."
        case .rateLimitExceeded: return "Rate limit exceeded. Upgrade to Pro for more requests."
        case .serverError(let code): return "Server error: \(code)"
        }
    }
}
