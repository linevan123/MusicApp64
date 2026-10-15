import Foundation
import AVFoundation
import Combine

@MainActor
public final class AudioUploadService: ObservableObject {
    public static let shared = AudioUploadService()
    
    @Published public var isUploading: Bool = false
    @Published public var uploadProgress: Double = 0.0
    @Published public var statusMessage: String = ""
    @Published public var errorMessage: String?
    
    public struct AudioMetadata {
        public let format: String
        public let duration: Double
        public let sampleRate: Int
        public let bitDepth: Int
        public let channels: Int
        public let fileSize: Int64
        public let waveform: [Float]
    }
    
    private init() {}
    
    // MARK: - Inspect Audio File
    public func inspectAudio(at localURL: URL) async throws -> AudioMetadata {
        let isAccessing = localURL.startAccessingSecurityScopedResource()
        defer {
            if isAccessing { localURL.stopAccessingSecurityScopedResource() }
        }
        
        let asset = AVURLAsset(url: localURL, options: [AVURLAssetPreferPreciseDurationAndTimingKey: true])
        let durationTime = try await asset.load(.duration)
        let durationSeconds = CMTimeGetSeconds(durationTime)
        
        guard let audioTrack = try await asset.loadTracks(withMediaType: .audio).first else {
            throw WaveformExtractor.ExtractionError.noAudioTrackFound
        }
        
        let formatDescriptions = try await audioTrack.load(.formatDescriptions)
        var sampleRate = 44100
        var bitDepth = 16
        var channels = 2
        
        if let desc = formatDescriptions.first {
            let basic = CMAudioFormatDescriptionGetStreamBasicDescription(desc)
            if let asbd = basic?.pointee {
                sampleRate = Int(asbd.mSampleRate)
                channels = Int(asbd.mChannelsPerFrame)
                bitDepth = Int(asbd.mBitsPerChannel > 0 ? asbd.mBitsPerChannel : 16)
            }
        }
        
        let ext = localURL.pathExtension.lowercased()
        let format = ["wav", "flac", "mp3", "aiff"].contains(ext) ? ext : "wav"
        
        let fileAttributes = try? FileManager.default.attributesOfItem(atPath: localURL.path)
        let fileSize = (fileAttributes?[.size] as? Int64) ?? 0
        
        // Extract high-res waveform amplitudes
        let waveform = try await WaveformExtractor.extractAmplitudes(from: localURL, targetSamples: 120)
        
        return AudioMetadata(
            format: format,
            duration: durationSeconds,
            sampleRate: sampleRate,
            bitDepth: bitDepth,
            channels: channels,
            fileSize: fileSize,
            waveform: waveform
        )
    }
    
    // MARK: - Upload Track to Project
    public func uploadTrack(
        fileURL: URL,
        title: String,
        projectId: UUID,
        bpm: Double? = nil,
        musicalKey: String? = nil
    ) async -> Track? {
        isUploading = true
        uploadProgress = 0.05
        statusMessage = "Analyzing audio & extracting waveform..."
        errorMessage = nil
        defer {
            isUploading = false
            uploadProgress = 1.0
            statusMessage = ""
        }
        
        do {
            let meta = try await inspectAudio(at: fileURL)
            uploadProgress = 0.35
            statusMessage = "Storing audio safely..."
            
            let ownerId = AuthService.shared.currentUser?.id ?? UUID()
            let trackId = UUID()
            let storagePath = "\(ownerId.uuidString.lowercased())/\(projectId.uuidString.lowercased())/\(trackId.uuidString.lowercased()).\(meta.format)"
            
            // Create track model
            var track = Track(
                id: trackId,
                projectId: projectId,
                ownerId: ownerId,
                title: title.isEmpty ? fileURL.deletingPathExtension().lastPathComponent : title,
                audioFilePath: storagePath,
                duration: meta.duration,
                waveformData: meta.waveform,
                format: meta.format,
                sampleRate: meta.sampleRate,
                bitDepth: meta.bitDepth,
                channels: meta.channels,
                bpm: bpm,
                musicalKey: musicalKey,
                position: 0,
                streamURL: fileURL // locally playable immediately
            )
            
            // If Supabase is configured, upload to storage bucket and insert row
            if SupabaseConfig.isConfigured, let token = AuthService.shared.sessionToken {
                let isAccessing = fileURL.startAccessingSecurityScopedResource()
                let fileData = try Data(contentsOf: fileURL)
                if isAccessing { fileURL.stopAccessingSecurityScopedResource() }
                
                uploadProgress = 0.60
                statusMessage = "Uploading lossless bounce (\(meta.format.uppercased()))..."
                
                // 1. Upload file to storage
                let storageURL = SupabaseConfig.projectURL.appendingPathComponent("storage/v1/object/audio/\(storagePath)")
                var storageReq = URLRequest(url: storageURL)
                storageReq.httpMethod = "POST"
                storageReq.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                storageReq.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
                let mimeType = mimeTypeFor(format: meta.format)
                storageReq.setValue(mimeType, forHTTPHeaderField: "Content-Type")
                storageReq.httpBody = fileData
                
                let (_, storageRes) = try await URLSession.shared.data(for: storageReq)
                guard let httpStorage = storageRes as? HTTPURLResponse, (200...201).contains(httpStorage.statusCode) else {
                    throw NSError(domain: "BounceStorage", code: 1, userInfo: [NSLocalizedDescriptionKey: "Storage upload failed"])
                }
                
                uploadProgress = 0.85
                statusMessage = "Finalizing track record..."
                
                // 2. Insert row in tracks table
                let dbURL = SupabaseConfig.projectURL.appendingPathComponent("rest/v1/tracks")
                var dbReq = URLRequest(url: dbURL)
                dbReq.httpMethod = "POST"
                dbReq.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                dbReq.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
                dbReq.setValue("application/json", forHTTPHeaderField: "Content-Type")
                
                let dbBody: [String: Any] = [
                    "id": track.id.uuidString,
                    "project_id": projectId.uuidString,
                    "owner_id": ownerId.uuidString,
                    "title": track.title,
                    "audio_file_path": storagePath,
                    "duration": track.duration,
                    "waveform_data": track.waveformData,
                    "format": meta.format,
                    "sample_rate": meta.sampleRate,
                    "bit_depth": meta.bitDepth,
                    "channels": meta.channels,
                    "file_size_bytes": meta.fileSize,
                    "bpm": bpm as Any,
                    "musical_key": musicalKey as Any
                ]
                dbReq.httpBody = try JSONSerialization.data(withJSONObject: dbBody)
                _ = try await URLSession.shared.data(for: dbReq)
            }
            
            // Update local project in ProjectService
            if let pIndex = ProjectService.shared.projects.firstIndex(where: { $0.id == projectId }) {
                var updated = ProjectService.shared.projects[pIndex]
                var trackList = updated.tracks ?? []
                track.position = trackList.count
                trackList.append(track)
                updated.tracks = trackList
                updated.updatedAt = Date()
                ProjectService.shared.projects[pIndex] = updated
            }
            
            BounceTheme.notificationHaptic(type: .success)
            return track
        } catch {
            errorMessage = error.localizedDescription
            BounceTheme.notificationHaptic(type: .error)
            return nil
        }
    }
    
    private func mimeTypeFor(format: String) -> String {
        switch format.lowercased() {
        case "wav": return "audio/wav"
        case "flac": return "audio/flac"
        case "mp3": return "audio/mpeg"
        case "aiff": return "audio/aiff"
        default: return "audio/wav"
        }
    }
}
