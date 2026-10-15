import SwiftUI

/// Public / Guest Listener Experience.
/// No account or login required. Resolves share token via edge function,
/// provides gapless streaming, waveform scrubbing, download button (if permitted),
/// and allows leaving timestamped comments.
public struct PublicPlayerView: View {
    public let shareToken: String
    
    @ObservedObject var shareService = ShareService.shared
    @ObservedObject var player = AudioPlayerService.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var payload: SharedPayload?
    @State private var isLoading: Bool = true
    @State private var errorMessage: String?
    @State private var showCommentsDrawer: Bool = false
    
    public init(shareToken: String) {
        self.shareToken = shareToken
    }
    
    public var body: some View {
        NavigationStack {
            ZStack {
                BounceTheme.background.ignoresSafeArea()
                
                if isLoading {
                    loadingView
                } else if let error = errorMessage {
                    errorStateView(error: error)
                } else if let payload = payload {
                    contentView(payload: payload)
                }
            }
            .navigationTitle("Bounce Link")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundColor(BounceTheme.textSecondary)
                }
            }
            .task {
                await loadSharedContent()
            }
            .sheet(isPresented: $showCommentsDrawer) {
                if let track = player.currentTrack {
                    CommentsDrawer(track: track, shareToken: shareToken)
                }
            }
        }
    }
    
    // MARK: - Loading View
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: BounceTheme.accent))
            Text("RESOLVING PRIVATE LINK...")
                .font(BounceTheme.mono(11, weight: .bold))
                .foregroundColor(BounceTheme.textSecondary)
        }
    }
    
    // MARK: - Error View
    private func errorStateView(error: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.octagon.fill")
                .font(.system(size: 40))
                .foregroundColor(BounceTheme.alert)
            
            Text("LINK UNAVAILABLE")
                .font(BounceTheme.mono(14, weight: .bold))
                .foregroundColor(BounceTheme.textPrimary)
            
            Text(error)
                .font(BounceTheme.sans(12))
                .foregroundColor(BounceTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            Button("DISMISS") {
                dismiss()
            }
            .buttonStyle(BrutalistButtonStyle(isPrimary: false))
            .padding(.top, 8)
        }
    }
    
    // MARK: - Main Content View
    private func contentView(payload: SharedPayload) -> some View {
        let tracks = payload.tracks.map { $0.toTrack(projectId: payload.project.id) }
        
        return ScrollView {
            VStack(spacing: 24) {
                // Shared Banner
                VStack(spacing: 8) {
                    HStack {
                        HStack(spacing: 6) {
                            Circle().fill(BounceTheme.accent).frame(width: 6, height: 6)
                            Text("SHARED BY \(payload.owner.username.uppercased())")
                                .font(BounceTheme.mono(10, weight: .bold))
                                .foregroundColor(BounceTheme.accent)
                        }
                        Spacer()
                        Text(payload.link.allowDownload ? "DOWNLOAD ALLOWED" : "STREAM ONLY")
                            .font(BounceTheme.mono(9, weight: .bold))
                            .foregroundColor(payload.link.allowDownload ? BounceTheme.accent : BounceTheme.textMuted)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(BounceTheme.surfaceElevated)
                    }
                    
                    Text(payload.project.title)
                        .font(BounceTheme.mono(20, weight: .bold))
                        .foregroundColor(BounceTheme.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    if let label = payload.link.label {
                        Text(label)
                            .font(BounceTheme.sans(12))
                            .foregroundColor(BounceTheme.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(16)
                .background(BounceTheme.surface)
                .overlay(Rectangle().stroke(BounceTheme.surfaceBorder, lineWidth: 1))
                .padding(.horizontal, 20)
                
                // Active Track Scrubber Section
                if let currentTrack = player.currentTrack {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(currentTrack.title)
                            .font(BounceTheme.mono(16, weight: .bold))
                            .foregroundColor(BounceTheme.textPrimary)
                        
                        // Scrubber with comment pins
                        WaveformScrubberView(
                            amplitudes: currentTrack.waveformData,
                            duration: currentTrack.duration,
                            currentTime: player.currentTime,
                            progress: player.progress,
                            comments: shareService.mockComments[currentTrack.id] ?? [],
                            onScrub: { newProg in player.scrub(to: newProg) },
                            onScrubEnd: { player.finishScrubbing() },
                            onCommentTap: { _ in showCommentsDrawer = true }
                        )
                        .frame(height: 70)
                        .overlay(Rectangle().stroke(BounceTheme.surfaceBorder, lineWidth: 1))
                        
                        // Time Indicators
                        HStack {
                            Text(Track.formatSeconds(player.currentTime))
                                .font(BounceTheme.mono(11, weight: .bold))
                                .foregroundColor(BounceTheme.textPrimary)
                            Spacer()
                            Text(currentTrack.formattedDuration)
                                .font(BounceTheme.mono(11))
                                .foregroundColor(BounceTheme.textSecondary)
                        }
                        
                        // Player Controls
                        HStack(spacing: 16) {
                            Button {
                                player.previous()
                            } label: {
                                Image(systemName: "backward.end.fill")
                                    .font(.system(size: 16, weight: .bold))
                                    .frame(width: 44, height: 44)
                                    .background(BounceTheme.surfaceElevated)
                                    .foregroundColor(BounceTheme.textPrimary)
                            }
                            
                            Button {
                                player.togglePlayPause()
                            } label: {
                                Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                                    .font(.system(size: 20, weight: .bold))
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 44)
                                    .background(BounceTheme.accent)
                                    .foregroundColor(.black)
                            }
                            
                            Button {
                                player.next()
                            } label: {
                                Image(systemName: "forward.end.fill")
                                    .font(.system(size: 16, weight: .bold))
                                    .frame(width: 44, height: 44)
                                    .background(BounceTheme.surfaceElevated)
                                    .foregroundColor(BounceTheme.textPrimary)
                            }
                        }
                        .padding(.top, 4)
                        
                        // Collaboration & Download Row
                        HStack(spacing: 10) {
                            if payload.link.allowComments {
                                Button {
                                    showCommentsDrawer = true
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: "bubble.left.fill")
                                        Text("COMMENTS & NOTES")
                                    }
                                    .font(BounceTheme.mono(11, weight: .bold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(BounceTheme.surfaceElevated)
                                    .foregroundColor(BounceTheme.textPrimary)
                                    .overlay(Rectangle().stroke(BounceTheme.surfaceBorder, lineWidth: 1))
                                }
                            }
                            
                            if payload.link.allowDownload, let dl = currentTrack.downloadURL {
                                Link(destination: dl) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "arrow.down.to.line.compact")
                                        Text("DOWNLOAD WAV")
                                    }
                                    .font(BounceTheme.mono(11, weight: .bold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(BounceTheme.accent)
                                    .foregroundColor(.black)
                                }
                            }
                        }
                    }
                    .padding(16)
                    .background(BounceTheme.surface)
                    .overlay(Rectangle().stroke(BounceTheme.surfaceBorder, lineWidth: 1))
                    .padding(.horizontal, 20)
                }
                
                // Track list (gapless cue)
                VStack(alignment: .leading, spacing: 10) {
                    Text("TRACK LIST (\(tracks.count))")
                        .font(BounceTheme.mono(11, weight: .bold))
                        .foregroundColor(BounceTheme.textSecondary)
                        .padding(.horizontal, 20)
                    
                    LazyVStack(spacing: 8) {
                        ForEach(Array(tracks.enumerated()), id: \.element.id) { idx, t in
                            Button {
                                player.play(
                                    tracks: tracks,
                                    startingAt: idx,
                                    projectTitle: payload.project.title,
                                    ownerName: payload.owner.username
                                )
                            } label: {
                                HStack(spacing: 12) {
                                    Text(String(format: "%02d", idx + 1))
                                        .font(BounceTheme.mono(10))
                                        .foregroundColor(BounceTheme.textMuted)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(t.title)
                                            .font(BounceTheme.mono(13, weight: .bold))
                                            .foregroundColor(player.currentTrack?.id == t.id ? BounceTheme.accent : BounceTheme.textPrimary)
                                            .lineLimit(1)
                                        Text(t.audioBadge)
                                            .font(BounceTheme.mono(9))
                                            .foregroundColor(BounceTheme.textSecondary)
                                    }
                                    
                                    Spacer()
                                    
                                    Text(t.formattedDuration)
                                        .font(BounceTheme.mono(11))
                                        .foregroundColor(BounceTheme.textSecondary)
                                }
                                .padding(12)
                                .background(BounceTheme.surface)
                                .overlay(Rectangle().stroke(BounceTheme.surfaceBorder, lineWidth: 1))
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
            .padding(.vertical, 16)
        }
    }
    
    // MARK: - Actions
    private func loadSharedContent() async {
        isLoading = true
        errorMessage = nil
        do {
            let res = try await shareService.resolveSharedLink(token: shareToken)
            self.payload = res
            self.isLoading = false
            
            // Auto cue tracks into player
            let tracks = res.tracks.map { $0.toTrack(projectId: res.project.id) }
            if let first = tracks.first, player.currentTrack == nil {
                player.play(
                    tracks: tracks,
                    startingAt: 0,
                    projectTitle: res.project.title,
                    ownerName: res.owner.username
                )
            }
        } catch {
            self.errorMessage = error.localizedDescription
            self.isLoading = false
        }
    }
}
