import Foundation

public struct Track: Identifiable, Codable, Equatable, Hashable {
    public let id: UUID
    public let projectId: UUID
    public let ownerId: UUID
    public var title: String
    public let audioFilePath: String
    public var duration: Double
    public var waveformData: [Float]
    public var format: String?
    public var sampleRate: Int?
    public var bitDepth: Int?
    public var channels: Int?
    public var bpm: Double?
    public var musicalKey: String?
    public var position: Int
    public let createdAt: Date
    public var updatedAt: Date
    
    // Transient streaming & download signed URLs
    public var streamURL: URL?
    public var downloadURL: URL?
    
    enum CodingKeys: String, CodingKey {
        case id
        case projectId = "project_id"
        case ownerId = "owner_id"
        case title
        case audioFilePath = "audio_file_path"
        case duration
        case waveformData = "waveform_data"
        case format
        case sampleRate = "sample_rate"
        case bitDepth = "bit_depth"
        case channels
        case bpm
        case musicalKey = "musical_key"
        case position
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case streamURL = "stream_url"
        case downloadURL = "download_url"
    }
    
    public init(
        id: UUID = UUID(),
        projectId: UUID,
        ownerId: UUID,
        title: String,
        audioFilePath: String,
        duration: Double,
        waveformData: [Float] = [],
        format: String? = nil,
        sampleRate: Int? = nil,
        bitDepth: Int? = nil,
        channels: Int? = nil,
        bpm: Double? = nil,
        musicalKey: String? = nil,
        position: Int = 0,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        streamURL: URL? = nil,
        downloadURL: URL? = nil
    ) {
        self.id = id
        self.projectId = projectId
        self.ownerId = ownerId
        self.title = title
        self.audioFilePath = audioFilePath
        self.duration = duration
        self.waveformData = waveformData
        self.format = format
        self.sampleRate = sampleRate
        self.bitDepth = bitDepth
        self.channels = channels
        self.bpm = bpm
        self.musicalKey = musicalKey
        self.position = position
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.streamURL = streamURL
        self.downloadURL = downloadURL
    }
    
    // MARK: - Display Formatters
    public var formattedDuration: String {
        Self.formatSeconds(duration)
    }
    
    public static func formatSeconds(_ seconds: Double) -> String {
        guard !seconds.isNaN && !seconds.isInfinite && seconds >= 0 else { return "00:00" }
        let total = Int(seconds.rounded())
        let m = total / 60
        let s = total % 60
        return String(format: "%02d:%02d", m, s)
    }
    
    public var audioBadge: String {
        var parts: [String] = []
        if let fmt = format?.uppercased(), !fmt.isEmpty {
            parts.append(fmt)
        }
        if let bd = bitDepth, let sr = sampleRate {
            let srKhz = Double(sr) / 1000.0
            let srString = srKhz.truncatingRemainder(dividingBy: 1) == 0 ? String(format: "%.0fkHz", srKhz) : String(format: "%.1fkHz", srKhz)
            parts.append("\(bd)-bit / \(srString)")
        } else if let sr = sampleRate {
            let srKhz = Double(sr) / 1000.0
            parts.append(String(format: "%.1fkHz", srKhz))
        }
        return parts.isEmpty ? "LOSSLESS" : parts.joined(separator: " · ")
    }
    
    public var metadataBadge: String? {
        var parts: [String] = []
        if let bpm = bpm, bpm > 0 {
            parts.append(String(format: "%.0f BPM", bpm))
        }
        if let key = musicalKey, !key.isEmpty {
            parts.append(key)
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}
