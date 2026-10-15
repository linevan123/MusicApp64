import Foundation

public struct Profile: Identifiable, Codable, Equatable, Hashable {
    public let id: UUID
    public let email: String
    public var username: String
    public let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case email
        case username
        case createdAt = "created_at"
    }
    
    public init(id: UUID, email: String, username: String, createdAt: Date = Date()) {
        self.id = id
        self.email = email
        self.username = username
        self.createdAt = createdAt
    }
}
