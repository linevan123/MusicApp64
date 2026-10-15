import Foundation

public struct SharedPayload: Codable {
    public let kind: String // "track" or "project"
    public let link: SharedLinkInfo
    public let owner: SharedOwnerInfo
    public let project: SharedProjectInfo
    public let tracks: [SharedTrackItem]
    public let urlsExpireAt: String
    
    enum CodingKeys: String, CodingKey {
        case kind
        case link
        case owner
        case project
        case tracks
        case urlsExpireAt = "urls_expire_at"
    }
}

public struct SharedLinkInfo: Codable {
    public let id: UUID
    public let label: String?
    public let allowDownload: Bool
    public let allowComments: Bool
    public let expiresAt: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case label
        case allowDownload = "allow_download"
        case allowComments = "allow_comments"
        case expiresAt = "expires_at"
    }
}

public struct SharedOwnerInfo: Codable {
    public let username: String
}

public struct SharedProjectInfo: Codable {
    public let id: UUID
    public let title: String
    public let coverURL: URL?
    
    enum CodingKeys: String, CodingKey {
        case id
        case title
        case coverURL = "cover_url"
    }
}

public struct SharedTrackItem: Identifiable, Codable, Equatable {
    public let id: UUID
    public let title: String
    public let duration: Double
    public let waveformData: [Float]
    public let format: String?
    public let sampleRate: Int?
    public let bitDepth: Int?
    public let bpm: Double?
    public let musicalKey: String?
    public let streamURL: URL
    public let downloadURL: URL?
    
    enum CodingKeys: String, CodingKey {
        case id
        case title
        case duration
        case waveformData = "waveform_data"
        case format
        case sampleRate = "sample_rate"
        case bitDepth = "bit_depth"
        case bpm
        case musicalKey = "musical_key"
        case streamURL = "stream_url"
        case downloadURL = "download_url"
    }
    
    public func toTrack(projectId: UUID, ownerId: UUID = UUID()) -> Track {
        Track(
            id: id,
            projectId: projectId,
            ownerId: ownerId,
            title: title,
            audioFilePath: "",
            duration: duration,
            waveformData: waveformData,
            format: format,
            sampleRate: sampleRate,
            bitDepth: bitDepth,
            channels: 2,
            bpm: bpm,
            musicalKey: musicalKey,
            position: 0,
            streamURL: streamURL,
            downloadURL: downloadURL
        )
    }
}
