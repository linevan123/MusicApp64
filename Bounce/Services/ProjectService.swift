import Foundation
import Combine

@MainActor
public final class ProjectService: ObservableObject {
    public static let shared = ProjectService()
    
    @Published public var projects: [Project] = []
    @Published public var isLoading: Bool = false
    @Published public var errorMessage: String?
    
    private init() {
        seedSampleDataIfNeeded()
    }
    
    // MARK: - Sample Producer Data
    public func seedSampleDataIfNeeded() {
        guard projects.isEmpty else { return }
        
        let ownerId = AuthService.shared.currentUser?.id ?? UUID()
        
        // Project 1: "Summer 2026 Beat Pack"
        let p1Id = UUID(uuidString: "A1111111-B222-C333-D444-E55555555551")!
        let t1 = Track(
            id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            projectId: p1Id,
            ownerId: ownerId,
            title: "VALERIA [142 BPM_F#min]",
            audioFilePath: "\(ownerId)/\(p1Id)/valeria.wav",
            duration: 164.5,
            waveformData: WaveformExtractor.generatePlaceholder(bars: 100, seed: 101),
            format: "wav",
            sampleRate: 48000,
            bitDepth: 24,
            channels: 2,
            bpm: 142,
            musicalKey: "F# Min",
            position: 0,
            streamURL: URL(string: "https://actions.google.com/sounds/v1/sports/skateboarding_half_pipe.ogg")
        )
        
        let t2 = Track(
            id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
            projectId: p1Id,
            ownerId: ownerId,
            title: "OVERDRIVE_BOUNCE [136 BPM_C#min]",
            audioFilePath: "\(ownerId)/\(p1Id)/overdrive.wav",
            duration: 148.0,
            waveformData: WaveformExtractor.generatePlaceholder(bars: 100, seed: 202),
            format: "wav",
            sampleRate: 48000,
            bitDepth: 24,
            channels: 2,
            bpm: 136,
            musicalKey: "C# Min",
            position: 1,
            streamURL: URL(string: "https://actions.google.com/sounds/v1/weather/light_rain.ogg")
        )
        
        let t3 = Track(
            id: UUID(uuidString: "33333333-3333-3333-3333-333333333333")!,
            projectId: p1Id,
            ownerId: ownerId,
            title: "LATE NIGHT MIAMI [128 BPM_Dmin]",
            audioFilePath: "\(ownerId)/\(p1Id)/late_night.wav",
            duration: 192.3,
            waveformData: WaveformExtractor.generatePlaceholder(bars: 100, seed: 303),
            format: "flac",
            sampleRate: 96000,
            bitDepth: 24,
            channels: 2,
            bpm: 128,
            musicalKey: "D Min",
            position: 2,
            streamURL: URL(string: "https://actions.google.com/sounds/v1/water/lapping_waves.ogg")
        )
        
        let p1 = Project(
            id: p1Id,
            ownerId: ownerId,
            title: "Summer 2026 Beat Pack",
            createdAt: Date().addingTimeInterval(-86400 * 3),
            updatedAt: Date().addingTimeInterval(-3600 * 2),
            tracks: [t1, t2, t3]
        )
        
        // Project 2: "Album Stems"
        let p2Id = UUID(uuidString: "B2222222-C333-D444-E555-F66666666662")!
        let s1 = Track(
            id: UUID(),
            projectId: p2Id,
            ownerId: ownerId,
            title: "Stem 01 - 808 Bass & Sub",
            audioFilePath: "\(ownerId)/\(p2Id)/stem_808.wav",
            duration: 210.0,
            waveformData: WaveformExtractor.generatePlaceholder(bars: 100, seed: 404),
            format: "wav",
            sampleRate: 48000,
            bitDepth: 32,
            channels: 2,
            bpm: 140,
            musicalKey: "A Min",
            position: 0,
            streamURL: URL(string: "https://actions.google.com/sounds/v1/sports/skateboarding_half_pipe.ogg")
        )
        
        let s2 = Track(
            id: UUID(),
            projectId: p2Id,
            ownerId: ownerId,
            title: "Stem 02 - Main Synths & Leads",
            audioFilePath: "\(ownerId)/\(p2Id)/stem_synths.wav",
            duration: 210.0,
            waveformData: WaveformExtractor.generatePlaceholder(bars: 100, seed: 505),
            format: "wav",
            sampleRate: 48000,
            bitDepth: 32,
            channels: 2,
            bpm: 140,
            musicalKey: "A Min",
            position: 1,
            streamURL: URL(string: "https://actions.google.com/sounds/v1/weather/light_rain.ogg")
        )
        
        let p2 = Project(
            id: p2Id,
            ownerId: ownerId,
            title: "Album Stems (Master Mix)",
            createdAt: Date().addingTimeInterval(-86400 * 7),
            updatedAt: Date().addingTimeInterval(-86400 * 1),
            tracks: [s1, s2]
        )
        
        self.projects = [p1, p2]
    }
    
    // MARK: - Fetch Projects
    public func fetchProjects() async {
        guard SupabaseConfig.isConfigured, let token = AuthService.shared.sessionToken else {
            return
        }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            let url = SupabaseConfig.projectURL.appendingPathComponent("rest/v1/projects?select=*,tracks(*)&order=updated_at.desc")
            var request = URLRequest(url: url)
            request.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                return
            }
            
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let loaded = try decoder.decode([Project].self, from: data)
            self.projects = loaded
        } catch {
            print("fetchProjects error: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Create Project
    public func createProject(title: String) async -> Project? {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        
        let ownerId = AuthService.shared.currentUser?.id ?? UUID()
        let newProject = Project(
            id: UUID(),
            ownerId: ownerId,
            title: trimmed,
            tracks: []
        )
        
        // Local immediate update
        projects.insert(newProject, at: 0)
        BounceTheme.haptic(style: .medium)
        
        guard SupabaseConfig.isConfigured, let token = AuthService.shared.sessionToken else {
            return newProject
        }
        
        do {
            let url = SupabaseConfig.projectURL.appendingPathComponent("rest/v1/projects")
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("return=representation", forHTTPHeaderField: "Prefer")
            
            let body: [String: Any] = [
                "id": newProject.id.uuidString,
                "owner_id": ownerId.uuidString,
                "title": trimmed
            ]
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            
            let (_, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, (200...201).contains(http.statusCode) {
                // created in DB
            }
        } catch {
            print("createProject DB error: \(error)")
        }
        
        return newProject
    }
    
    // MARK: - Delete Project
    public func deleteProject(id: UUID) async {
        projects.removeAll { $0.id == id }
        BounceTheme.haptic(style: .heavy)
        
        guard SupabaseConfig.isConfigured, let token = AuthService.shared.sessionToken else { return }
        
        let url = SupabaseConfig.projectURL.appendingPathComponent("rest/v1/projects?id=eq.\(id.uuidString)")
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        _ = try? await URLSession.shared.data(for: request)
    }
}
