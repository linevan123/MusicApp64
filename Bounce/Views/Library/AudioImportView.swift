import SwiftUI
import UniformTypeIdentifiers

public struct AudioImportView: View {
    public let projectId: UUID
    public let projectTitle: String
    
    @ObservedObject var uploadService = AudioUploadService.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var showFilePicker: Bool = false
    @State private var selectedFileURL: URL?
    @State private var metadata: AudioUploadService.AudioMetadata?
    @State private var isInspecting: Bool = false
    
    @State private var trackTitle: String = ""
    @State private var bpmString: String = ""
    @State private var musicalKey: String = ""
    
    public init(projectId: UUID, projectTitle: String) {
        self.projectId = projectId
        self.projectTitle = projectTitle
    }
    
    public var body: some View {
        NavigationStack {
            ZStack {
                BounceTheme.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Header
                        VStack(alignment: .leading, spacing: 4) {
                            Text("IMPORT AUDIO BOUNCE")
                                .font(BounceTheme.mono(11, weight: .bold))
                                .foregroundColor(BounceTheme.accent)
                                .tracking(1.5)
                            Text("Into: \(projectTitle)")
                                .font(BounceTheme.sans(14))
                                .foregroundColor(BounceTheme.textSecondary)
                        }
                        
                        // File Selection Card
                        if let fileURL = selectedFileURL, let meta = metadata {
                            filePreviewCard(url: fileURL, meta: meta)
                            
                            // Editable Metadata Fields
                            metadataInputs
                            
                            // Upload Button
                            Button {
                                uploadBounce(fileURL: fileURL)
                            } label: {
                                if uploadService.isUploading {
                                    HStack(spacing: 12) {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .black))
                                        Text(uploadService.statusMessage.uppercased())
                                            .font(BounceTheme.mono(12, weight: .bold))
                                    }
                                    .frame(maxWidth: .infinity)
                                } else {
                                    Text("UPLOAD LOSSLESS BOUNCE")
                                        .frame(maxWidth: .infinity)
                                }
                            }
                            .buttonStyle(BrutalistButtonStyle(isPrimary: true))
                            .disabled(uploadService.isUploading)
                            
                            if uploadService.isUploading {
                                ProgressView(value: uploadService.uploadProgress)
                                    .accentColor(BounceTheme.accent)
                                    .padding(.top, 4)
                            }
                            
                        } else {
                            // File picker trigger
                            filePickerTrigger
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Add Audio")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(BounceTheme.textSecondary)
                }
            }
            .fileImporter(
                isPresented: $showFilePicker,
                allowedContentTypes: [
                    UTType.wav,
                    UTType.audio,
                    UTType.mp3,
                    UTType(filenameExtension: "flac") ?? .audio,
                    UTType(filenameExtension: "aiff") ?? .audio
                ],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    guard let url = urls.first else { return }
                    inspectSelectedFile(url: url)
                case .failure(let error):
                    print("File import failed: \(error)")
                }
            }
        }
    }
    
    // MARK: - Picker Trigger
    private var filePickerTrigger: some View {
        VStack(spacing: 16) {
            ZStack {
                Rectangle()
                    .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6]))
                    .foregroundColor(BounceTheme.surfaceBorder)
                    .frame(height: 200)
                    .background(BounceTheme.surface)
                
                VStack(spacing: 12) {
                    Image(systemName: "arrow.up.doc.fill")
                        .font(.system(size: 36))
                        .foregroundColor(BounceTheme.accent)
                    
                    Text("SELECT AUDIO FILE")
                        .font(BounceTheme.mono(13, weight: .bold))
                        .foregroundColor(BounceTheme.textPrimary)
                    
                    Text("WAV · FLAC · MP3 · AIFF up to 24-bit / 96kHz")
                        .font(BounceTheme.mono(11))
                        .foregroundColor(BounceTheme.textSecondary)
                }
            }
            .onTapGesture {
                showFilePicker = true
            }
            
            if isInspecting {
                HStack(spacing: 8) {
                    ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white))
                    Text("Analyzing audio and computing waveform...")
                        .font(BounceTheme.mono(11))
                        .foregroundColor(BounceTheme.textSecondary)
                }
                .padding(.top, 8)
            }
        }
    }
    
    // MARK: - File Preview Card
    private func filePreviewCard(url: URL, meta: AudioUploadService.AudioMetadata) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("FILE INSPECTOR")
                    .font(BounceTheme.mono(10, weight: .bold))
                    .foregroundColor(BounceTheme.accent)
                Spacer()
                Button("CHANGE") {
                    showFilePicker = true
                }
                .font(BounceTheme.mono(10, weight: .bold))
                .foregroundColor(BounceTheme.textSecondary)
            }
            
            Text(url.lastPathComponent)
                .font(BounceTheme.mono(14, weight: .bold))
                .foregroundColor(BounceTheme.textPrimary)
                .lineLimit(1)
            
            // Extracted Waveform Preview
            VStack(alignment: .leading, spacing: 4) {
                Text("EXTRACTED WAVEFORM")
                    .font(BounceTheme.mono(9))
                    .foregroundColor(BounceTheme.textMuted)
                
                WaveformScrubberView(
                    amplitudes: meta.waveform,
                    duration: meta.duration,
                    currentTime: 0,
                    progress: 0,
                    onScrub: { _ in },
                    onScrubEnd: { }
                )
                .frame(height: 48)
                .overlay(Rectangle().stroke(BounceTheme.surfaceBorder, lineWidth: 1))
            }
            
            // Audio Specs Grid
            HStack(spacing: 16) {
                specItem(label: "FORMAT", value: meta.format.uppercased())
                specItem(label: "BIT DEPTH", value: "\(meta.bitDepth)-bit")
                specItem(label: "SAMPLE RATE", value: "\(Double(meta.sampleRate)/1000.0)kHz")
                specItem(label: "DURATION", value: Track.formatSeconds(meta.duration))
            }
            .padding(.top, 4)
        }
        .padding(16)
        .background(BounceTheme.surface)
        .overlay(Rectangle().stroke(BounceTheme.surfaceBorder, lineWidth: 1))
    }
    
    private func specItem(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(BounceTheme.mono(8))
                .foregroundColor(BounceTheme.textMuted)
            Text(value)
                .font(BounceTheme.mono(11, weight: .bold))
                .foregroundColor(BounceTheme.textPrimary)
        }
    }
    
    // MARK: - Metadata Inputs
    private var metadataInputs: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text("TRACK TITLE")
                    .font(BounceTheme.mono(10, weight: .bold))
                    .foregroundColor(BounceTheme.textSecondary)
                TextField("Title", text: $trackTitle)
                    .font(BounceTheme.mono(13))
                    .padding(12)
                    .background(BounceTheme.surface)
                    .foregroundColor(BounceTheme.textPrimary)
                    .overlay(Rectangle().stroke(BounceTheme.surfaceBorder, lineWidth: 1))
            }
            
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("BPM (TEMPO)")
                        .font(BounceTheme.mono(10, weight: .bold))
                        .foregroundColor(BounceTheme.textSecondary)
                    TextField("140", text: $bpmString)
                        .keyboardType(.decimalPad)
                        .font(BounceTheme.mono(13))
                        .padding(12)
                        .background(BounceTheme.surface)
                        .foregroundColor(BounceTheme.textPrimary)
                        .overlay(Rectangle().stroke(BounceTheme.surfaceBorder, lineWidth: 1))
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    Text("KEY")
                        .font(BounceTheme.mono(10, weight: .bold))
                        .foregroundColor(BounceTheme.textSecondary)
                    TextField("F# Min", text: $musicalKey)
                        .font(BounceTheme.mono(13))
                        .padding(12)
                        .background(BounceTheme.surface)
                        .foregroundColor(BounceTheme.textPrimary)
                        .overlay(Rectangle().stroke(BounceTheme.surfaceBorder, lineWidth: 1))
                }
            }
        }
    }
    
    // MARK: - Actions
    private func inspectSelectedFile(url: URL) {
        isInspecting = true
        selectedFileURL = url
        trackTitle = url.deletingPathExtension().lastPathComponent
        
        Task {
            do {
                let meta = try await uploadService.inspectAudio(at: url)
                self.metadata = meta
                self.isInspecting = false
                BounceTheme.notificationHaptic(type: .success)
            } catch {
                self.isInspecting = false
                print("Inspection error: \(error)")
            }
        }
    }
    
    private func uploadBounce(fileURL: URL) {
        let bpm = Double(bpmString)
        let key = musicalKey.isEmpty ? nil : musicalKey
        
        Task {
            if let _ = await uploadService.uploadTrack(
                fileURL: fileURL,
                title: trackTitle,
                projectId: projectId,
                bpm: bpm,
                musicalKey: key
            ) {
                dismiss()
            }
        }
    }
}
