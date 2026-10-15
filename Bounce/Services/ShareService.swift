import Foundation
import Combine

@MainActor
public final class ShareService: ObservableObject {
    public static let shared = ShareService()
    
    @Published public var activeLinks: [ShareLink] = []
    @Published public var isLoading: Bool = false
    @Published public var errorMessage: String?
    
    // In-memory comments storage for offline demo
    @Published public var mockComments: [UUID: [Comment]] = [:]
    
    private init() {
        seedSampleShareLinks()
    }
    
    // MARK: - Sample Share Links
    private func seedSampleShareLinks() {
        let ownerId = AuthService.shared.currentUser?.id ?? UUID()
        let sampleTrackId = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
        let sampleProjectId = UUID(uuidString: "A1111111-B222-C333-D444-E55555555551")!
        
        let link1 = ShareLink(
            id: UUID(),
            ownerId: ownerId,
            token: "summer26-pack-artist-review",
            projectId: sampleProjectId,
            trackId: nil,
            label: "For Carti Management (Stream Only)",
            allowDownload: false,
            allowComments: true,
            expiresAt: Date().addingTimeInterval(86400 * 7),
            viewCount: 14,
            lastViewedAt: Date().addingTimeInterval(-3600 * 3)
        )
        
        let link2 = ShareLink(
            id: UUID(),
            ownerId: ownerId,
            token: "valeria-master-download",
            projectId: nil,
            trackId: sampleTrackId,
            label: "Valeria Lossless Bounce (Allow Download)",
            allowDownload: true,
            allowComments: true,
            expiresAt: Date().addingTimeInterval(86400 * 14),
            viewCount: 28,
            lastViewedAt: Date().addingTimeInterval(-1800)
        )
        
        self.activeLinks = [link1, link2]
        
        // Seed timestamped sample comments for track 1
        self.mockComments[sampleTrackId] = [
            Comment(
                id: UUID(),
                trackId: sampleTrackId,
                guestName: "Mike Dean",
                authorName: "Mike Dean",
                timestampSeconds: 14.2,
                body: "Sub 808 hits hard here. Filter could open slightly earlier.",
                createdAt: Date().addingTimeInterval(-3600 * 5)
            ),
            Comment(
                id: UUID(),
                trackId: sampleTrackId,
                guestName: "A&R Dave",
                authorName: "A&R Dave",
                timestampSeconds: 52.8,
                body: "This drop is insane!! Vocals will sit perfectly right on top of this lead.",
                createdAt: Date().addingTimeInterval(-3600 * 2)
            ),
            Comment(
                id: UUID(),
                trackId: sampleTrackId,
                guestName: "prodbyevan!",
                authorName: "prodbyevan!",
                timestampSeconds: 98.4,
                body: "Switched the hi-hat roll pattern on the 2nd hook per your note.",
                createdAt: Date().addingTimeInterval(-1800)
            )
        ]
    }
    
    // MARK: - Create Share Link
    public func createShareLink(
        projectId: UUID? = nil,
        trackId: UUID? = nil,
        label: String? = nil,
        allowDownload: Bool = false,
        allowComments: Bool = true,
        expiresInDays: Int? = 7
    ) async -> ShareLink? {
        let ownerId = AuthService.shared.currentUser?.id ?? UUID()
        let token = UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(18).lowercased()
        
        var expiresAt: Date? = nil
        if let days = expiresInDays, days > 0 {
            expiresAt = Calendar.current.date(byAdding: .day, value: days, to: Date())
        }
        
        let newLink = ShareLink(
            id: UUID(),
            ownerId: ownerId,
            token: String(token),
            projectId: projectId,
            trackId: trackId,
            label: label,
            allowDownload: allowDownload,
            allowComments: allowComments,
            expiresAt: expiresAt,
            viewCount: 0
        )
        
        activeLinks.insert(newLink, at: 0)
        BounceTheme.notificationHaptic(type: .success)
        
        guard SupabaseConfig.isConfigured, let authToken = AuthService.shared.sessionToken else {
            return newLink
        }
        
        do {
            let url = SupabaseConfig.projectURL.appendingPathComponent("rest/v1/share_links")
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
            request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            
            var body: [String: Any] = [
                "id": newLink.id.uuidString,
                "owner_id": ownerId.uuidString,
                "token": newLink.token,
                "allow_download": allowDownload,
                "allow_comments": allowComments
            ]
            if let p = projectId { body["project_id"] = p.uuidString }
            if let t = trackId { body["track_id"] = t.uuidString }
            if let l = label { body["label"] = l }
            if let exp = expiresAt {
                let formatter = ISO8601DateFormatter()
                body["expires_at"] = formatter.string(from: exp)
            }
            
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            _ = try await URLSession.shared.data(for: request)
        } catch {
            print("Failed to persist share link: \(error)")
        }
        
        return newLink
    }
    
    // MARK: - Revoke Link
    public func revokeShareLink(id: UUID) async {
        if let idx = activeLinks.firstIndex(where: { $0.id == id }) {
            var updated = activeLinks[idx]
            updated.revokedAt = Date()
            activeLinks[idx] = updated
        }
        BounceTheme.haptic(style: .heavy)
        
        guard SupabaseConfig.isConfigured, let authToken = AuthService.shared.sessionToken else { return }
        
        let url = SupabaseConfig.projectURL.appendingPathComponent("rest/v1/share_links?id=eq.\(id.uuidString)")
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let formatter = ISO8601DateFormatter()
        let body = ["revoked_at": formatter.string(from: Date())]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        _ = try? await URLSession.shared.data(for: request)
    }
    
    // MARK: - Public Resolver (No Account Required)
    public func resolveSharedLink(token: String) async throws -> SharedPayload {
        if !SupabaseConfig.isConfigured {
            // Provide offline demo payload
            let trackId = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
            let projId = UUID(uuidString: "A1111111-B222-C333-D444-E55555555551")!
            return SharedPayload(
                kind: "project",
                link: SharedLinkInfo(
                    id: UUID(),
                    label: "Demo Shared Link",
                    allowDownload: true,
                    allowComments: true,
                    expiresAt: nil
                ),
                owner: SharedOwnerInfo(username: "prodbyevan!"),
                project: SharedProjectInfo(id: projId, title: "Summer 2026 Beat Pack", coverURL: nil),
                tracks: [
                    SharedTrackItem(
                        id: trackId,
                        title: "VALERIA [142 BPM_F#min]",
                        duration: 164.5,
                        waveformData: WaveformExtractor.generatePlaceholder(bars: 100, seed: 101),
                        format: "wav",
                        sampleRate: 48000,
                        bitDepth: 24,
                        bpm: 142,
                        musicalKey: "F# Min",
                        streamURL: URL(string: "https://actions.google.com/sounds/v1/sports/skateboarding_half_pipe.ogg")!,
                        downloadURL: URL(string: "https://actions.google.com/sounds/v1/sports/skateboarding_half_pipe.ogg")!
                    )
                ],
                urlsExpireAt: ISO8601DateFormatter().string(from: Date().addingTimeInterval(7200))
            )
        }
        
        var request = URLRequest(url: SupabaseConfig.shareResolveURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        
        let body = ["token": token]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw NSError(domain: "ShareService", code: 500, userInfo: [NSLocalizedDescriptionKey: "Invalid network response"])
        }
        
        if http.statusCode == 410 {
            throw NSError(domain: "ShareService", code: 410, userInfo: [NSLocalizedDescriptionKey: "This share link has expired or was revoked."])
        }
        if http.statusCode == 404 {
            throw NSError(domain: "ShareService", code: 404, userInfo: [NSLocalizedDescriptionKey: "Share link not found."])
        }
        guard http.statusCode == 200 else {
            throw NSError(domain: "ShareService", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: "Could not load shared content."])
        }
        
        return try JSONDecoder().decode(SharedPayload.self, from: data)
    }
    
    // MARK: - Comments Management
    public func fetchComments(token: String, trackId: UUID) async throws -> [Comment] {
        if !SupabaseConfig.isConfigured {
            return mockComments[trackId] ?? []
        }
        
        var components = URLComponents(url: SupabaseConfig.shareCommentURL, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "token", value: token),
            URLQueryItem(name: "track_id", value: trackId.uuidString.lowercased())
        ]
        
        var request = URLRequest(url: components.url!)
        request.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            return []
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([Comment].self, from: data)
    }
    
    public func postComment(
        token: String,
        trackId: UUID,
        timestampSeconds: Double,
        body: String,
        guestName: String?
    ) async throws -> Comment {
        let trimmedBody = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedBody.isEmpty else {
            throw NSError(domain: "ShareService", code: 400, userInfo: [NSLocalizedDescriptionKey: "Comment body cannot be blank."])
        }
        
        if !SupabaseConfig.isConfigured {
            let author = AuthService.shared.currentUser?.username ?? guestName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Guest"
            let comment = Comment(
                id: UUID(),
                trackId: trackId,
                userId: AuthService.shared.currentUser?.id,
                guestName: AuthService.shared.currentUser == nil ? author : nil,
                authorName: author,
                timestampSeconds: timestampSeconds,
                body: trimmedBody
            )
            var current = mockComments[trackId] ?? []
            current.append(comment)
            current.sort { $0.timestampSeconds < $1.timestampSeconds }
            mockComments[trackId] = current
            BounceTheme.notificationHaptic(type: .success)
            return comment
        }
        
        var request = URLRequest(url: SupabaseConfig.shareCommentURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        
        if let userToken = AuthService.shared.sessionToken {
            request.setValue("Bearer \(userToken)", forHTTPHeaderField: "Authorization")
        }
        
        var jsonBody: [String: Any] = [
            "token": token,
            "track_id": trackId.uuidString.lowercased(),
            "timestamp_seconds": timestampSeconds,
            "body": trimmedBody
        ]
        if let g = guestName, !g.isEmpty {
            jsonBody["guest_name"] = g
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: jsonBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...201).contains(http.statusCode) else {
            let errObj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            let msg = (errObj?["error"] as? String) ?? "Failed to post comment"
            throw NSError(domain: "ShareService", code: 400, userInfo: [NSLocalizedDescriptionKey: msg])
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let comment = try decoder.decode(Comment.self, from: data)
        BounceTheme.notificationHaptic(type: .success)
        return comment
    }
}
