import Foundation
import Combine

/// R20: Blink 2.0 Service — The Memory OS
final class Blink2Service: ObservableObject {
    static let shared = Blink2Service()
    
    @Published var memoryStreams: [MemoryStream] = []
    @Published var memoryPeople: [MemoryPerson] = []
    @Published var placeMemories: [PlaceMemory] = []
    @Published var unifiedCaptures: [UnifiedCapture] = []
    @Published var aiMemoryMovies: [AIMemoryMovie] = []
    @Published var liveCaptions: [LiveCaption] = []
    @Published var creators: [BlinkCreator] = []
    @Published var premieres: [BlinkPremiere] = []
    @Published var isProUser: Bool = false
    
    private let userDefaults = UserDefaults.standard
    
    private init() { loadFromDisk() }
    
    // MARK: - Memory Streams
    
    func createMemoryStream(name: String, filterType: MemoryStream.FilterType, clipIDs: [UUID] = [], theme: String? = nil) -> MemoryStream {
        let stream = MemoryStream(name: name, filterType: filterType, clipIDs: clipIDs, theme: theme)
        memoryStreams.append(stream)
        saveToDisk()
        return stream
    }
    
    func refreshStream(_ streamID: UUID) {
        guard let index = memoryStreams.firstIndex(where: { $0.id == streamID }) else { return }
        memoryStreams[index].lastUpdated = Date()
        saveToDisk()
    }
    
    // MARK: - Memory People
    
    func createMemoryPerson(name: String, faceClipIDs: [UUID] = []) -> MemoryPerson {
        let person = MemoryPerson(name: name, faceClipIDs: faceClipIDs, clipCount: faceClipIDs.count, thumbnailClipID: faceClipIDs.first)
        memoryPeople.append(person)
        saveToDisk()
        return person
    }
    
    func favoritePerson(_ personID: UUID) {
        if let index = memoryPeople.firstIndex(where: { $0.id == personID }) {
            memoryPeople[index].isFavorite.toggle()
            saveToDisk()
        }
    }
    
    // MARK: - Place Memories
    
    func createPlaceMemory(placeName: String, latitude: Double, longitude: Double, clipIDs: [UUID] = []) -> PlaceMemory {
        let place = PlaceMemory(placeName: placeName, latitude: latitude, longitude: longitude, clipIDs: clipIDs, clipCount: clipIDs.count, thumbnailClipID: clipIDs.first)
        placeMemories.append(place)
        saveToDisk()
        return place
    }
    
    // MARK: - Unified Capture
    
    func capture(type: UnifiedCapture.CaptureType, duration: TimeInterval? = nil, textContent: String? = nil) -> UnifiedCapture {
        let capture = UnifiedCapture(captureType: type, duration: duration, textContent: textContent)
        unifiedCaptures.append(capture)
        saveToDisk()
        return capture
    }
    
    // MARK: - AI Memory Movies
    
    func generateMemoryMovie(prompt: String, clipIDs: [UUID]) -> AIMemoryMovie {
        let movie = AIMemoryMovie(naturalLanguagePrompt: prompt, clipIDs: clipIDs, status: .queued)
        aiMemoryMovies.append(movie)
        saveToDisk()
        
        // Simulate generation
        Task {
            await MainActor.run {
                if let index = self.aiMemoryMovies.firstIndex(where: { $0.id == movie.id }) {
                    self.aiMemoryMovies[index].status = .generating
                }
            }
            
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            
            await MainActor.run {
                if let index = self.aiMemoryMovies.firstIndex(where: { $0.id == movie.id }) {
                    self.aiMemoryMovies[index].status = .completed
                    self.aiMemoryMovies[index].duration = Double(clipIDs.count) * 5.0
                }
                self.saveToDisk()
            }
        }
        
        return movie
    }
    
    // MARK: - Live Captions
    
    func addLiveCaption(clipID: UUID, segments: [LiveCaption.CaptionSegment], language: String = "en") {
        let caption = LiveCaption(clipID: clipID, segments: segments, language: language)
        liveCaptions.append(caption)
        saveToDisk()
    }
    
    // MARK: - Blink Pro
    
    func upgradeToPro() async -> Bool {
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        await MainActor.run {
            isProUser = true
            saveToDisk()
        }
        return true
    }
    
    // MARK: - Creators
    
    func registerCreator(name: String) -> BlinkCreator {
        let creator = BlinkCreator(creatorName: name)
        creators.append(creator)
        saveToDisk()
        return creator
    }
    
    func addStyle(to creatorID: UUID, style: BlinkCreator.MemoryStyle) {
        guard let index = creators.firstIndex(where: { $0.id == creatorID }) else { return }
        creators[index].presetStyles.append(style)
        saveToDisk()
    }
    
    // MARK: - Premieres
    
    func schedulePremiere(clipID: UUID, at date: Date) -> BlinkPremiere {
        let premiere = BlinkPremiere(clipID: clipID, scheduledAt: date)
        premieres.append(premiere)
        saveToDisk()
        return premiere
    }
    
    // MARK: - Persistence
    
    private func saveToDisk() {
        if let data = try? JSONEncoder().encode(memoryStreams) {
            userDefaults.set(data, forKey: "blink2_streams")
        }
        if let data = try? JSONEncoder().encode(memoryPeople) {
            userDefaults.set(data, forKey: "blink2_people")
        }
        if let data = try? JSONEncoder().encode(placeMemories) {
            userDefaults.set(data, forKey: "blink2_places")
        }
        if let data = try? JSONEncoder().encode(unifiedCaptures) {
            userDefaults.set(data, forKey: "blink2_captures")
        }
        if let data = try? JSONEncoder().encode(aiMemoryMovies) {
            userDefaults.set(data, forKey: "blink2_movies")
        }
        if let data = try? JSONEncoder().encode(liveCaptions) {
            userDefaults.set(data, forKey: "blink2_captions")
        }
        if let data = try? JSONEncoder().encode(creators) {
            userDefaults.set(data, forKey: "blink2_creators")
        }
        if let data = try? JSONEncoder().encode(premieres) {
            userDefaults.set(data, forKey: "blink2_premieres")
        }
        userDefaults.set(isProUser, forKey: "blink2_is_pro")
    }
    
    private func loadFromDisk() {
        if let data = userDefaults.data(forKey: "blink2_streams"),
           let decoded = try? JSONDecoder().decode([MemoryStream].self, from: data) {
            memoryStreams = decoded
        }
        if let data = userDefaults.data(forKey: "blink2_people"),
           let decoded = try? JSONDecoder().decode([MemoryPerson].self, from: data) {
            memoryPeople = decoded
        }
        if let data = userDefaults.data(forKey: "blink2_places"),
           let decoded = try? JSONDecoder().decode([PlaceMemory].self, from: data) {
            placeMemories = decoded
        }
        if let data = userDefaults.data(forKey: "blink2_captures"),
           let decoded = try? JSONDecoder().decode([UnifiedCapture].self, from: data) {
            unifiedCaptures = decoded
        }
        if let data = userDefaults.data(forKey: "blink2_movies"),
           let decoded = try? JSONDecoder().decode([AIMemoryMovie].self, from: data) {
            aiMemoryMovies = decoded
        }
        if let data = userDefaults.data(forKey: "blink2_captions"),
           let decoded = try? JSONDecoder().decode([LiveCaption].self, from: data) {
            liveCaptions = decoded
        }
        if let data = userDefaults.data(forKey: "blink2_creators"),
           let decoded = try? JSONDecoder().decode([BlinkCreator].self, from: data) {
            creators = decoded
        }
        if let data = userDefaults.data(forKey: "blink2_premieres"),
           let decoded = try? JSONDecoder().decode([BlinkPremiere].self, from: data) {
            premieres = decoded
        }
        isProUser = userDefaults.bool(forKey: "blink2_is_pro")
    }
}
