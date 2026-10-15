import SwiftUI

/// Full-screen Brutalist Audio Player.
/// Aesthetic inspired by [untitled] and hardware DAWs:
/// High-contrast typography, interactive waveform scrubber, lock-to-timestamp comments.
public struct FullPlayerView: View {
    @ObservedObject var player = AudioPlayerService.shared
    @ObservedObject var shareService = ShareService.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var showCommentsSheet: Bool = false
    @State private var showShareSheet: Bool = false
    @State private var showPlaylistQueue: Bool = false
    
    public init() {}
    
    public var body: some View {
        ZStack {
            BounceTheme.background.ignoresSafeArea()
            
            if let track = player.currentTrack {
                VStack(spacing: 0) {
                    // Top Bar
                    topBar(track: track)
                    
                    ScrollView {
                        VStack(spacing: 24) {
                            // Cover Art / Visual Canvas
                            coverArtCanvas(track: track)
                                .padding(.top, 8)
                            
                            // Track Meta & Audio Badges
                            trackHeader(track: track)
                                .padding(.horizontal, 24)
                            
                            // Visual Waveform Scrubber
                            waveformSection(track: track)
                                .padding(.horizontal, 24)
                            
                            // Time Indicators
                            timeLabels(track: track)
                                .padding(.horizontal, 24)
                            
                            // Transport Controls
                            transportControls
                                .padding(.horizontal, 24)
                                .padding(.top, 8)
                            
                            // Bottom Action Utilities
                            actionUtilities(track: track)
                                .padding(.horizontal, 24)
                                .padding(.top, 12)
                        }
                        .padding(.bottom, 40)
                    }
                }
            } else {
                VStack(spacing: 16) {
                    Text("NO TRACK LOADED")
                        .font(BounceTheme.mono(14, weight: .bold))
                        .foregroundColor(BounceTheme.textSecondary)
                    Button("CLOSE") { dismiss() }
                        .buttonStyle(BrutalistButtonStyle(isPrimary: false))
                }
            }
        }
        .sheet(isPresented: $showCommentsSheet) {
            if let track = player.currentTrack {
                CommentsDrawer(track: track)
            }
        }
        .sheet(isPresented: $showShareSheet) {
            if let track = player.currentTrack {
                ShareSheetView(projectId: track.projectId, trackId: track.id, title: track.title)
            }
        }
    }
    
    // MARK: - Top Bar
    private func topBar(track: Track) -> some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(BounceTheme.textPrimary)
                    .frame(width: 40, height: 40)
                    .background(BounceTheme.surface)
                    .overlay(Rectangle().stroke(BounceTheme.surfaceBorder, lineWidth: 1))
            }
            
            Spacer()
            
            VStack(spacing: 2) {
                Text(player.currentProjectTitle.uppercased())
                    .font(BounceTheme.mono(10, weight: .bold))
                    .foregroundColor(BounceTheme.textSecondary)
                    .tracking(1.5)
                    .lineLimit(1)
                
                HStack(spacing: 4) {
                    Circle()
                        .fill(BounceTheme.accent)
                        .frame(width: 4, height: 4)
                    Text("GAPLESS ENGINE ACTIVE")
                        .font(BounceTheme.mono(8, weight: .semibold))
                        .foregroundColor(BounceTheme.accent)
                }
            }
            
            Spacer()
            
            Button {
                showShareSheet = true
            } label: {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(BounceTheme.textPrimary)
                    .frame(width: 40, height: 40)
                    .background(BounceTheme.surface)
                    .overlay(Rectangle().stroke(BounceTheme.surfaceBorder, lineWidth: 1))
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
    
    // MARK: - Cover Canvas
    private func coverArtCanvas(track: Track) -> some View {
        ZStack {
            Rectangle()
                .fill(BounceTheme.surface)
                .frame(height: 260)
                .overlay(Rectangle().stroke(BounceTheme.surfaceBorder, lineWidth: 1))
            
            // Industrial background grid lines
            VStack(spacing: 20) {
                ForEach(0..<10) { _ in
                    Divider().background(BounceTheme.surfaceBorder.opacity(0.3))
                }
            }
            .frame(height: 260)
            .clipped()
            
            // Center Monogram / DAW Bounce Stamp
            VStack(spacing: 8) {
                Image(systemName: "waveform.circle.fill")
                    .font(.system(size: 64, weight: .light))
                    .foregroundColor(BounceTheme.accent)
                
                Text(player.currentOwnerName.isEmpty ? "prodbyevan!" : player.currentOwnerName)
                    .font(BounceTheme.mono(12, weight: .bold))
                    .foregroundColor(BounceTheme.textPrimary)
                    .tracking(2.0)
                
                Text("BOUNCE MASTER")
                    .font(BounceTheme.mono(9))
                    .foregroundColor(BounceTheme.textSecondary)
            }
        }
        .padding(.horizontal, 24)
    }
    
    // MARK: - Track Header
    private func trackHeader(track: Track) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(track.title)
                .font(BounceTheme.mono(18, weight: .bold))
                .foregroundColor(BounceTheme.textPrimary)
                .multilineTextAlignment(.leading)
            
            HStack(spacing: 8) {
                // Audio format badge (WAV 24-bit / 48kHz)
                Text(track.audioBadge)
                    .font(BounceTheme.mono(10, weight: .bold))
                    .foregroundColor(BounceTheme.accent)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(BounceTheme.surfaceElevated)
                    .overlay(Rectangle().stroke(BounceTheme.accent.opacity(0.5), lineWidth: 1))
                
                // BPM & Key
                if let bpmKey = track.metadataBadge {
                    Text(bpmKey)
                        .font(BounceTheme.mono(10, weight: .bold))
                        .foregroundColor(BounceTheme.textSecondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(BounceTheme.surfaceElevated)
                        .overlay(Rectangle().stroke(BounceTheme.surfaceBorder, lineWidth: 1))
                }
                
                Spacer()
            }
        }
    }
    
    // MARK: - Waveform Section
    private func waveformSection(track: Track) -> some View {
        let comments = shareService.mockComments[track.id] ?? []
        return VStack(spacing: 6) {
            WaveformScrubberView(
                amplitudes: track.waveformData,
                duration: track.duration,
                currentTime: player.currentTime,
                progress: player.progress,
                comments: comments,
                onScrub: { newProgress in
                    player.scrub(to: newProgress)
                },
                onScrubEnd: {
                    player.finishScrubbing()
                },
                onCommentTap: { _ in
                    showCommentsSheet = true
                }
            )
            .frame(height: 72)
            .overlay(Rectangle().stroke(BounceTheme.surfaceBorder, lineWidth: 1))
        }
    }
    
    // MARK: - Time Labels
    private func timeLabels(track: Track) -> some View {
        HStack {
            Text(Track.formatSeconds(player.currentTime))
                .font(BounceTheme.mono(12, weight: .bold))
                .foregroundColor(BounceTheme.textPrimary)
            
            Spacer()
            
            let remaining = max(0, track.duration - player.currentTime)
            Text("-\(Track.formatSeconds(remaining))")
                .font(BounceTheme.mono(12))
                .foregroundColor(BounceTheme.textSecondary)
        }
    }
    
    // MARK: - Transport Controls
    private var transportControls: some View {
        HStack(spacing: 24) {
            // Previous Track
            Button {
                BounceTheme.haptic(style: .medium)
                player.previous()
            } label: {
                Image(systemName: "backward.end.fill")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(BounceTheme.textPrimary)
                    .frame(width: 52, height: 52)
                    .background(BounceTheme.surface)
                    .overlay(Rectangle().stroke(BounceTheme.surfaceBorder, lineWidth: 1))
            }
            
            // Play / Pause (Large Focal Point)
            Button {
                BounceTheme.haptic(style: .heavy)
                player.togglePlayPause()
            } label: {
                Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(.black)
                    .frame(width: 72, height: 72)
                    .background(BounceTheme.accent)
                    .overlay(Rectangle().stroke(BounceTheme.accent, lineWidth: 1))
            }
            
            // Next Track (Gapless)
            Button {
                BounceTheme.haptic(style: .medium)
                player.next()
            } label: {
                Image(systemName: "forward.end.fill")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(BounceTheme.textPrimary)
                    .frame(width: 52, height: 52)
                    .background(BounceTheme.surface)
                    .overlay(Rectangle().stroke(BounceTheme.surfaceBorder, lineWidth: 1))
            }
        }
    }
    
    // MARK: - Action Utilities
    private func actionUtilities(track: Track) -> some View {
        let comments = shareService.mockComments[track.id] ?? []
        return HStack(spacing: 12) {
            // Timestamp Comments Button
            Button {
                showCommentsSheet = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "bubble.left.and.text.bubble.right.fill")
                        .font(.system(size: 13))
                    Text("COMMENTS (\(comments.count))")
                        .font(BounceTheme.mono(11, weight: .bold))
                }
                .foregroundColor(BounceTheme.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(BounceTheme.surface)
                .overlay(Rectangle().stroke(BounceTheme.surfaceBorder, lineWidth: 1))
            }
            
            // Share Link Button
            Button {
                showShareSheet = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "link")
                        .font(.system(size: 13))
                    Text("SHARE LINK")
                        .font(BounceTheme.mono(11, weight: .bold))
                }
                .foregroundColor(BounceTheme.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(BounceTheme.surface)
                .overlay(Rectangle().stroke(BounceTheme.surfaceBorder, lineWidth: 1))
            }
        }
    }
}
