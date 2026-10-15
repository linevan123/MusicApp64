import Foundation

public struct ShareLink: Identifiable, Codable, Equatable, Hashable {
    public let id: UUID
    public let ownerId: UUID
    public let token: String
    public var projectId: UUID?
    public var trackId: UUID?
    public var label: String?
    public var allowDownload: Bool
    public var allowComments: Bool
    public var expiresAt: Date?
    public var revokedAt: Date?
    public var viewCount: Int
    public var lastViewedAt: Date?
    public let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case ownerId = "owner_id"
        case token
        case projectId = "project_id"
        case trackId = "track_id"
        case label
        case allowDownload = "allow_download"
        case allowComments = "allow_comments"
        case expiresAt = "expires_at"
        case revokedAt = "revoked_at"
        case viewCount = "view_count"
        case lastViewedAt = "last_viewed_at"
        case createdAt = "created_at"
    }
    
    public init(
        id: UUID = UUID(),
        ownerId: UUID,
        token: String,
        projectId: UUID? = nil,
        trackId: UUID? = nil,
        label: String? = nil,
        allowDownload: Bool = false,
        allowComments: Bool = true,
        expiresAt: Date? = nil,
        revokedAt: Date? = nil,
        viewCount: Int = 0,
        lastViewedAt: Date? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.ownerId = ownerId
        self.token = token
        self.projectId = projectId
        self.trackId = trackId
        self.label = label
        self.allowDownload = allowDownload
        self.allowComments = allowComments
        self.expiresAt = expiresAt
        self.revokedAt = revokedAt
        self.viewCount = viewCount
        self.lastViewedAt = lastViewedAt
        self.createdAt = createdAt
    }
    
    public var isRevoked: Bool {
        revokedAt != nil
    }
    
    public var isExpired: Bool {
        if let exp = expiresAt {
            return exp <= Date()
        }
        return false
    }
    
    public var isValid: Bool {
        !isRevoked && !isExpired
    }
    
    public func shareURL(baseURL: String = "https://bounce.app") -> URL {
        URL(string: "\(baseURL)/s/\(token)")!
    }
}
