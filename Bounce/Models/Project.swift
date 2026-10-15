import Foundation

public struct Project: Identifiable, Codable, Equatable, Hashable {
    public let id: UUID
    public let ownerId: UUID
    public var title: String
    public var coverArtPath: String?
    public var coverArtURL: URL?
    public let createdAt: Date
    public var updatedAt: Date
    
    // UI aggregates (populated by queries or local joins)
    public var tracks: [Track]?
    
    enum CodingKeys: String, CodingKey {
        case id
        case ownerId = "owner_id"
        case title
        case coverArtPath = "cover_art_path"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    public init(
        id: UUID = UUID(),
        ownerId: UUID,
        title: String,
        coverArtPath: String? = nil,
        coverArtURL: URL? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        tracks: [Track]? = nil
    ) {
        self.id = id
        self.ownerId = ownerId
        self.title = title
        self.coverArtPath = coverArtPath
        self.coverArtURL = coverArtURL
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.tracks = tracks
    }
    
    public var totalDuration: Double {
        tracks?.reduce(0) { $0 + $1.duration } ?? 0
    }
    
    public var trackCount: Int {
        tracks?.count ?? 0
    }
}
