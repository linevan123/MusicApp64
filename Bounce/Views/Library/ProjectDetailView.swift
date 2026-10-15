import SwiftUI

public struct ProjectDetailView: View {
    public let project: Project
    @ObservedObject var projectService = ProjectService.shared
    @ObservedObject var player = AudioPlayerService.shared
    
    @State private var showImportAudioSheet: Bool = false
    @State private var showProjectShareSheet: Bool = false
    @State private var trackToShare: Track?
    
    public init(project: Project) {
        self.project = project
    }
    
    private var currentProject: Project {
        projectService.projects.first(where: { $0.id == project.id }) ?? project
    }
    
    private var tracks: [Track] {
        currentProject.tracks ?? []
    }
    
    public var body: some View {
        ZStack {
            BounceTheme.background.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 20) {
                    // Project Header & Action Banner
                    projectHeader
                    
                    // Track List Header
                    HStack {
                        Text("TRACKS (\(tracks.count))")
                            .font(BounceTheme.mono(11, weight: .bold))
                            .foregroundColor(BounceTheme.textSecondary)
                            .tracking(1.5)
                        
                        Spacer()
                        
                        Button {
                            showImportAudioSheet = true
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "plus")
                                Text("ADD BOUNCE")
                            }
                            .font(BounceTheme.mono(10, weight: .bold))
                            .foregroundColor(BounceTheme.accent)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(BounceTheme.surface)
                            .overlay(Rectangle().stroke(BounceTheme.accent.opacity(0.6), lineWidth: 1))
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    
                    // Track List
                    if tracks.isEmpty {
                        emptyTracksView
                    } else {
                        LazyVStack(spacing: 8) {
                            ForEach(Array(tracks.enumerated()), id: \.element.id) { index, track in
                                trackRow(track: track, index: index)
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }
                .padding(.bottom, 120) // spacing for mini player
            }
        }
        .navigationTitle(currentProject.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showProjectShareSheet = true
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundColor(BounceTheme.accent)
                }
            }
        }
        .sheet(isPresented: $showImportAudioSheet) {
            AudioImportView(projectId: currentProject.id, projectTitle: currentProject.title)
        }
        .sheet(isPresented: $showProjectShareSheet) {
            ShareSheetView(projectId: currentProject.id, title: currentProject.title)
        }
        .sheet(item: $trackToShare) { track in
            ShareSheetView(projectId: currentProject.id, trackId: track.id, title: track.title)
        }
    }
    
    // MARK: - Project Header
    private var projectHeader: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 16) {
                // Brutalist Cover Box
                ZStack {
                    Rectangle()
                        .fill(BounceTheme.surfaceElevated)
                        .frame(width: 80, height: 80)
                        .overlay(Rectangle().stroke(BounceTheme.surfaceBorder, lineWidth: 1))
                    
                    Image(systemName: "folder.fill")
                        .font(.system(size: 32))
                        .foregroundColor(BounceTheme.accent)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("PROJECT / FOLDER")
                        .font(BounceTheme.mono(9, weight: .bold))
                        .foregroundColor(BounceTheme.textMuted)
                        .tracking(1.5)
                    
                    Text(currentProject.title)
                        .font(BounceTheme.mono(18, weight: .bold))
                        .foregroundColor(BounceTheme.textPrimary)
                        .lineLimit(2)
                    
                    HStack(spacing: 6) {
                        Text("\(tracks.count) TRACKS")
                            .font(BounceTheme.mono(10))
                            .foregroundColor(BounceTheme.textSecondary)
                        Text("·")
                            .foregroundColor(BounceTheme.textMuted)
                        Text(Track.formatSeconds(currentProject.totalDuration))
                            .font(BounceTheme.mono(10))
                            .foregroundColor(BounceTheme.textSecondary)
                    }
                }
                
                Spacer()
            }
            
            // Buttons: Play All (Gapless) & Share Link
            HStack(spacing: 12) {
                Button {
                    guard !tracks.isEmpty else { return }
                    BounceTheme.haptic(style: .medium)
                    player.play(
                        tracks: tracks,
                        startingAt: 0,
                        projectTitle: currentProject.title,
                        ownerName: AuthService.shared.currentUser?.username ?? "prodbyevan!"
                    )
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 13, weight: .bold))
                        Text("PLAY ALL (GAPLESS)")
                            .font(BounceTheme.mono(11, weight: .bold))
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(BrutalistButtonStyle(isPrimary: true))
                .disabled(tracks.isEmpty)
                
                Button {
                    showProjectShareSheet = true
                } label: {
                    Image(systemName: "link")
                        .font(.system(size: 14, weight: .bold))
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(BrutalistButtonStyle(isPrimary: false))
            }
        }
        .padding(20)
        .background(BounceTheme.surface)
        .overlay(Rectangle().stroke(BounceTheme.surfaceBorder, lineWidth: 1))
        .padding(.horizontal, 20)
        .padding(.top, 16)
    }
    
    // MARK: - Track Row
    private func trackRow(track: Track, index: Int) -> some View {
        let isCurrent = player.currentTrack?.id == track.id
        
        return Button {
            BounceTheme.haptic(style: .selection)
            player.play(
                tracks: tracks,
                startingAt: index,
                projectTitle: currentProject.title,
                ownerName: AuthService.shared.currentUser?.username ?? "prodbyevan!"
            )
        } label: {
            HStack(spacing: 12) {
                // Index / Play indicator
                ZStack {
                    if isCurrent && player.isPlaying {
                        Image(systemName: "waveform")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(BounceTheme.accent)
                    } else {
                        Text(String(format: "%02d", index + 1))
                            .font(BounceTheme.mono(11, weight: .semibold))
                            .foregroundColor(isCurrent ? BounceTheme.accent : BounceTheme.textMuted)
                    }
                }
                .frame(width: 24)
                
                // Track Info & Mini Waveform
                VStack(alignment: .leading, spacing: 4) {
                    Text(track.title)
                        .font(BounceTheme.mono(13, weight: .bold))
                        .foregroundColor(isCurrent ? BounceTheme.accent : BounceTheme.textPrimary)
                        .lineLimit(1)
                    
                    HStack(spacing: 6) {
                        Text(track.audioBadge)
                            .font(BounceTheme.mono(9, weight: .semibold))
                            .foregroundColor(BounceTheme.accent)
                        
                        if let meta = track.metadataBadge {
                            Text("·")
                                .foregroundColor(BounceTheme.textMuted)
                            Text(meta)
                                .font(BounceTheme.mono(9))
                                .foregroundColor(BounceTheme.textSecondary)
                        }
                    }
                }
                
                Spacer()
                
                // Duration & Share Button
                HStack(spacing: 12) {
                    Text(track.formattedDuration)
                        .font(BounceTheme.mono(11))
                        .foregroundColor(BounceTheme.textSecondary)
                    
                    Button {
                        trackToShare = track
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 13))
                            .foregroundColor(BounceTheme.textMuted)
                            .frame(width: 32, height: 32)
                    }
                }
            }
            .padding(14)
            .background(isCurrent ? BounceTheme.surfaceElevated : BounceTheme.surface)
            .overlay(
                Rectangle()
                    .stroke(isCurrent ? BounceTheme.accent.opacity(0.8) : BounceTheme.surfaceBorder, lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Empty State
    private var emptyTracksView: some View {
        VStack(spacing: 14) {
            Image(systemName: "waveform.badge.plus")
                .font(.system(size: 40))
                .foregroundColor(BounceTheme.textMuted)
                .padding(.top, 24)
            
            Text("NO AUDIO BOUNCES YET")
                .font(BounceTheme.mono(12, weight: .bold))
                .foregroundColor(BounceTheme.textSecondary)
            
            Text("Import 24-bit WAVs, FLACs, or MP3s straight from your Files app or iCloud Drive.")
                .font(BounceTheme.sans(12))
                .foregroundColor(BounceTheme.textMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            Button("IMPORT AUDIO FILE") {
                showImportAudioSheet = true
            }
            .buttonStyle(BrutalistButtonStyle(isPrimary: true))
            .padding(.top, 8)
        }
        .padding(.vertical, 32)
    }
}
