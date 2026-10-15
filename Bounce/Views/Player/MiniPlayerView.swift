import SwiftUI

/// Compact Floating Brutalist Mini Player docked above the tab bar.
/// Allows uninterrupted playback control while browsing the app.
public struct MiniPlayerView: View {
    @ObservedObject var player = AudioPlayerService.shared
    public let onExpand: () -> Void
    
    public init(onExpand: @escaping () -> Void) {
        self.onExpand = onExpand
    }
    
    public var body: some View {
        if let track = player.currentTrack {
            VStack(spacing: 0) {
                // Top micro progress line
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(BounceTheme.surfaceBorder)
                        Rectangle()
                            .fill(BounceTheme.accent)
                            .frame(width: geo.size.width * CGFloat(player.progress))
                    }
                }
                .frame(height: 2)
                
                // Player Content Bar
                HStack(spacing: 12) {
                    // Tap target for full player
                    Button {
                        onExpand()
                    } label: {
                        HStack(spacing: 12) {
                            // Brutalist Audio Icon / Monogram
                            ZStack {
                                Rectangle()
                                    .fill(BounceTheme.surfaceElevated)
                                    .frame(width: 44, height: 44)
                                    .overlay(Rectangle().stroke(BounceTheme.surfaceBorder, lineWidth: 1))
                                
                                Image(systemName: "waveform")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(player.isPlaying ? BounceTheme.accent : BounceTheme.textSecondary)
                            }
                            
                            // Track Info
                            VStack(alignment: .leading, spacing: 2) {
                                Text(track.title)
                                    .font(BounceTheme.mono(13, weight: .bold))
                                    .foregroundColor(BounceTheme.textPrimary)
                                    .lineLimit(1)
                                
                                HStack(spacing: 6) {
                                    Text(track.audioBadge)
                                        .font(BounceTheme.mono(9, weight: .semibold))
                                        .foregroundColor(BounceTheme.accent)
                                    
                                    Text("·")
                                        .foregroundColor(BounceTheme.textMuted)
                                    
                                    Text("\(Track.formatSeconds(player.currentTime)) / \(track.formattedDuration)")
                                        .font(BounceTheme.mono(9))
                                        .foregroundColor(BounceTheme.textSecondary)
                                }
                            }
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Spacer()
                    
                    // Transport Controls
                    HStack(spacing: 8) {
                        // Play / Pause
                        Button {
                            BounceTheme.haptic(style: .medium)
                            player.togglePlayPause()
                        } label: {
                            Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.black)
                                .frame(width: 36, height: 36)
                                .background(BounceTheme.accent)
                                .overlay(Rectangle().stroke(BounceTheme.accent, lineWidth: 1))
                        }
                        
                        // Next Track (gapless)
                        Button {
                            BounceTheme.haptic(style: .light)
                            player.next()
                        } label: {
                            Image(systemName: "forward.end.fill")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(BounceTheme.textPrimary)
                                .frame(width: 36, height: 36)
                                .background(BounceTheme.surfaceElevated)
                                .overlay(Rectangle().stroke(BounceTheme.surfaceBorder, lineWidth: 1))
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(BounceTheme.surface)
                .overlay(Rectangle().stroke(BounceTheme.surfaceBorder, lineWidth: 1))
            }
            .padding(.horizontal, 8)
            .shadow(color: Color.black.opacity(0.8), radius: 10, y: 4)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
}
