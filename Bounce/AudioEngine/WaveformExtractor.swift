import Foundation
import AVFoundation
import Accelerate

/// High-speed on-device audio peak extractor.
/// Samples uncompressed PCM buffers via AVAssetReader and computes normalized
/// RMS amplitude points (0.0 ... 1.0) for visual scrubbers and database persistence.
public enum WaveformExtractor {
    
    public enum ExtractionError: Error, LocalizedError {
        case fileUnreadable
        case noAudioTrackFound
        case readerFailed(String)
        
        public var errorDescription: String? {
            switch self {
            case .fileUnreadable:
                return "The audio file could not be read."
            case .noAudioTrackFound:
                return "No valid audio track was detected in this file."
            case .readerFailed(let msg):
                return "Waveform extraction failed: \(msg)"
            }
        }
    }
    
    /// Asynchronously extracts `sampleCount` peak points from a local audio file URL.
    /// Returns an array of normalized Floats between 0.05 and 1.0.
    public static func extractAmplitudes(
        from url: URL,
        targetSamples: Int = 120
    ) async throws -> [Float] {
        return try await Task.detached(priority: .userInitiated) {
            let asset = AVURLAsset(url: url, options: [AVURLAssetPreferPreciseDurationAndTimingKey: true])
            
            guard let track = try await asset.loadTracks(withMediaType: .audio).first else {
                throw ExtractionError.noAudioTrackFound
            }
            
            let reader: AVAssetReader
            do {
                reader = try AVAssetReader(asset: asset)
            } catch {
                throw ExtractionError.readerFailed(error.localizedDescription)
            }
            
            // Request 16-bit Linear PCM uncompressed
            let outputSettings: [String: Any] = [
                AVFormatIDKey: kAudioFormatLinearPCM,
                AVLinearPCMBitDepthKey: 16,
                AVLinearPCMIsBigEndianKey: false,
                AVLinearPCMIsFloatKey: false,
                AVLinearPCMIsNonInterleaved: false
            ]
            
            let output = AVAssetReaderTrackOutput(track: track, outputSettings: outputSettings)
            output.alwaysCopiesSampleData = false
            reader.add(output)
            
            guard reader.startReading() else {
                throw ExtractionError.readerFailed(reader.error?.localizedDescription ?? "Unknown reader error")
            }
            
            var sampleData = Data()
            while reader.status == .reading {
                if let sampleBuffer = output.copyNextSampleBuffer() {
                    if let blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) {
                        let length = CMBlockBufferGetDataLength(blockBuffer)
                        var buffer = [UInt8](repeating: 0, count: length)
                        CMBlockBufferCopyDataBytes(blockBuffer, atOffset: 0, dataLength: length, destination: &buffer)
                        sampleData.append(contentsOf: buffer)
                    }
                }
            }
            
            if reader.status == .failed {
                throw ExtractionError.readerFailed(reader.error?.localizedDescription ?? "Read failed")
            }
            
            // Process 16-bit signed integer PCM
            let totalBytes = sampleData.count
            let totalSamples = totalBytes / 2 // 2 bytes per 16-bit sample
            guard totalSamples > targetSamples else {
                return [Float](repeating: 0.5, count: max(10, targetSamples))
            }
            
            var rawSamples = [Int16](repeating: 0, count: totalSamples)
            sampleData.withUnsafeBytes { rawBuffer in
                if let baseAddress = rawBuffer.baseAddress {
                    let ptr = baseAddress.assumingMemoryBound(to: Int16.self)
                    rawSamples.withUnsafeMutableBufferPointer { destPtr in
                        _ = destPtr.baseAddress.map {
                            memcpy($0, ptr, totalBytes)
                        }
                    }
                }
            }
            
            let step = max(1, totalSamples / targetSamples)
            var peaks: [Float] = []
            peaks.reserveCapacity(targetSamples)
            
            var maxObservedPeak: Float = 0.001
            
            for i in 0..<targetSamples {
                let startIndex = i * step
                let endIndex = min(startIndex + step, totalSamples)
                guard startIndex < endIndex else { break }
                
                var maxSample: Int16 = 0
                for s in startIndex..<endIndex {
                    let absVal = abs(rawSamples[s])
                    if absVal > maxSample {
                        maxSample = absVal
                    }
                }
                
                let normalized = Float(maxSample) / Float(Int16.max)
                if normalized > maxObservedPeak {
                    maxObservedPeak = normalized
                }
                peaks.append(normalized)
            }
            
            // Normalize relative to maximum observed amplitude and enforce floor
            let gainFactor = 1.0 / max(0.2, maxObservedPeak)
            let processed = peaks.map { val -> Float in
                let amplified = min(1.0, val * gainFactor)
                return max(0.08, amplified) // keep subtle floor for aesthetics
            }
            
            return processed
        }.value
    }
    
    /// Fallback synthetic waveform generator for quick previews
    public static func generatePlaceholder(bars: Int = 120, seed: Int = 42) -> [Float] {
        var result: [Float] = []
        var x = Double(seed)
        for i in 0..<bars {
            let progress = Double(i) / Double(bars)
            let envelope = sin(progress * .pi)
            x += 0.35
            let noise = abs(sin(x) * cos(x * 1.7))
            let val = Float(envelope * 0.7 + noise * 0.3)
            result.append(max(0.12, min(0.98, val)))
        }
        return result
    }
}
