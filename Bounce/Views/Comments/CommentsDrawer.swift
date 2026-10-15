import SwiftUI

public struct CommentsDrawer: View {
    public let track: Track
    public let shareToken: String?
    @ObservedObject var player = AudioPlayerService.shared
    @ObservedObject var shareService = ShareService.shared
    @ObservedObject var authService = AuthService.shared
    
    @State private var commentText: String = ""
    @State private var guestName: String = ""
    @State private var isPosting: Bool = false
    @State private var comments: [Comment] = []
    @Environment(\.dismiss) private var dismiss
    
    public init(track: Track, shareToken: String? = nil) {
        self.track = track
        self.shareToken = shareToken
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("TIMESTAMPS & NOTES")
                        .font(BounceTheme.mono(11, weight: .bold))
                        .foregroundColor(BounceTheme.accent)
                        .tracking(1.5)
                    Text(track.title)
                        .font(BounceTheme.mono(14, weight: .bold))
                        .foregroundColor(BounceTheme.textPrimary)
                        .lineLimit(1)
                }
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(BounceTheme.textSecondary)
                        .padding(8)
                        .background(BounceTheme.surfaceElevated)
                        .overlay(Rectangle().stroke(BounceTheme.surfaceBorder, lineWidth: 1))
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 16)
            .background(BounceTheme.surface)
            
            Divider()
                .background(BounceTheme.surfaceBorder)
            
            // Comments List
            if comments.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "bubble.left.and.bubble.right")
                        .font(.system(size: 36))
                        .foregroundColor(BounceTheme.textMuted)
                    Text("NO COMMENTS YET")
                        .font(BounceTheme.mono(13, weight: .bold))
                        .foregroundColor(BounceTheme.textSecondary)
                    Text("Scrub to any drop or transition and leave a note.")
                        .font(BounceTheme.sans(12))
                        .foregroundColor(BounceTheme.textMuted)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                    Spacer()
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(comments) { comment in
                            commentRow(comment)
                        }
                    }
                    .padding(20)
                }
            }
            
            Divider()
                .background(BounceTheme.surfaceBorder)
            
            // Input Bar pinned to current playhead timestamp
            VStack(spacing: 10) {
                // Current timestamp badge
                HStack {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(BounceTheme.accent)
                            .frame(width: 6, height: 6)
                        Text("PINNED AT \(Track.formatSeconds(player.currentTime))")
                            .font(BounceTheme.mono(10, weight: .bold))
                            .foregroundColor(BounceTheme.accent)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(BounceTheme.surfaceElevated)
                    .overlay(Rectangle().stroke(BounceTheme.accent.opacity(0.4), lineWidth: 1))
                    
                    Spacer()
                    
                    Text("PRESS PLAYHEAD TO SYNC")
                        .font(BounceTheme.mono(9))
                        .foregroundColor(BounceTheme.textMuted)
                }
                
                // Guest name field if not signed in
                if authService.currentUser == nil {
                    TextField("Your Name / Moniker (e.g. Mike)", text: $guestName)
                        .font(BounceTheme.mono(12))
                        .padding(10)
                        .background(BounceTheme.surfaceElevated)
                        .foregroundColor(BounceTheme.textPrimary)
                        .overlay(Rectangle().stroke(BounceTheme.surfaceBorder, lineWidth: 1))
                }
                
                HStack(spacing: 10) {
                    TextField("Leave feedback or mix note...", text: $commentText)
                        .font(BounceTheme.sans(13))
                        .padding(10)
                        .background(BounceTheme.surfaceElevated)
                        .foregroundColor(BounceTheme.textPrimary)
                        .overlay(Rectangle().stroke(BounceTheme.surfaceBorder, lineWidth: 1))
                    
                    Button {
                        postComment()
                    } label: {
                        if isPosting {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .black))
                                .frame(width: 44, height: 40)
                                .background(BounceTheme.accent)
                        } else {
                            Text("POST")
                                .font(BounceTheme.mono(12, weight: .bold))
                                .foregroundColor(.black)
                                .frame(height: 40)
                                .padding(.horizontal, 16)
                                .background(commentText.isEmpty ? BounceTheme.accent.opacity(0.4) : BounceTheme.accent)
                        }
                    }
                    .disabled(commentText.isEmpty || isPosting)
                }
            }
            .padding(16)
            .background(BounceTheme.surface)
        }
        .background(BounceTheme.background.ignoresSafeArea())
        .task {
            loadComments()
        }
    }
    
    // MARK: - Comment Row
    private func commentRow(_ comment: Comment) -> some View {
        Button {
            BounceTheme.haptic(style: .medium)
            player.seek(to: comment.timestampSeconds)
        } label: {
            HStack(alignment: .top, spacing: 12) {
                // Timestamp jump button
                Text(comment.formattedTimestamp)
                    .font(BounceTheme.mono(11, weight: .bold))
                    .foregroundColor(BounceTheme.accent)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(BounceTheme.surfaceElevated)
                    .overlay(Rectangle().stroke(BounceTheme.surfaceBorder, lineWidth: 1))
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(comment.authorName)
                            .font(BounceTheme.mono(12, weight: .bold))
                            .foregroundColor(comment.isGuest ? BounceTheme.commentPin : BounceTheme.textPrimary)
                        
                        if comment.isGuest {
                            Text("GUEST")
                                .font(BounceTheme.mono(8, weight: .bold))
                                .foregroundColor(BounceTheme.commentPin)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .overlay(Rectangle().stroke(BounceTheme.commentPin.opacity(0.5), lineWidth: 0.8))
                        }
                        
                        Spacer()
                    }
                    
                    Text(comment.body)
                        .font(BounceTheme.sans(13))
                        .foregroundColor(BounceTheme.textSecondary)
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
                
                Image(systemName: "play.fill")
                    .font(.system(size: 8))
                    .foregroundColor(BounceTheme.textMuted)
                    .padding(.top, 6)
            }
            .padding(12)
            .background(BounceTheme.surface)
            .overlay(Rectangle().stroke(BounceTheme.surfaceBorder, lineWidth: 1))
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Actions
    private func loadComments() {
        if let token = shareToken {
            Task {
                if let loaded = try? await shareService.fetchComments(token: token, trackId: track.id) {
                    self.comments = loaded
                }
            }
        } else {
            self.comments = shareService.mockComments[track.id] ?? []
        }
    }
    
    private func postComment() {
        guard !commentText.isEmpty else { return }
        isPosting = true
        
        let token = shareToken ?? "demo-token"
        let timestamp = player.currentTime
        let name = guestName.isEmpty ? nil : guestName
        
        Task {
            do {
                let newComment = try await shareService.postComment(
                    token: token,
                    trackId: track.id,
                    timestampSeconds: timestamp,
                    body: commentText,
                    guestName: name
                )
                comments.append(newComment)
                comments.sort { $0.timestampSeconds < $1.timestampSeconds }
                commentText = ""
                isPosting = false
            } catch {
                isPosting = false
            }
        }
    }
}
