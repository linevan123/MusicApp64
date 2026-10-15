import Foundation

public struct Comment: Identifiable, Codable, Equatable, Hashable {
    public let id: UUID
    public let trackId: UUID
    public let userId: UUID?
    public let guestName: String?
    public let authorName: String
    public let timestampSeconds: Double
    public let body: String
    public let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case trackId = "track_id"
        case userId = "user_id"
        case guestName = "guest_name"
        case authorName = "author_name"
        case timestampSeconds = "timestamp_seconds"
        case body
        case createdAt = "created_at"
    }
    
    public init(
        id: UUID = UUID(),
        trackId: UUID,
        userId: UUID? = nil,
        guestName: String? = nil,
        authorName: String,
        timestampSeconds: Double,
        body: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.trackId = trackId
        self.userId = userId
        self.guestName = guestName
        self.authorName = authorName
        self.timestampSeconds = timestampSeconds
        self.body = body
        self.createdAt = createdAt
    }
    
    public var formattedTimestamp: String {
        Track.formatSeconds(timestampSeconds)
    }
    
    public var isGuest: Bool {
        userId == nil
    }
}
