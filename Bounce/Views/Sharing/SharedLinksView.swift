import SwiftUI

public struct SharedLinksView: View {
    @ObservedObject var shareService = ShareService.shared
    
    @State private var selectedLinkToTest: ShareLink?
    @State private var copiedLinkId: UUID?
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            ZStack {
                BounceTheme.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Header
                        VStack(alignment: .leading, spacing: 4) {
                            Text("ACTIVE SHARE LINKS (\(shareService.activeLinks.count))")
                                .font(BounceTheme.mono(11, weight: .bold))
                                .foregroundColor(BounceTheme.accent)
                                .tracking(1.5)
                            
                            Text("Monitor views, downloads, and revocations for links sent to artists and collaborators.")
                                .font(BounceTheme.sans(12))
                                .foregroundColor(BounceTheme.textSecondary)
                        }
                        
                        if shareService.activeLinks.isEmpty {
                            emptyView
                        } else {
                            LazyVStack(spacing: 12) {
                                ForEach(shareService.activeLinks) { link in
                                    linkCard(link)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 120) // space for mini player
                }
            }
            .navigationTitle("Shared Links")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(item: $selectedLinkToTest) { link in
                PublicPlayerView(shareToken: link.token)
            }
        }
    }
    
    // MARK: - Link Card
    private func linkCard(_ link: ShareLink) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Status and Views Row
            HStack {
                HStack(spacing: 6) {
                    Circle()
                        .fill(statusColor(link))
                        .frame(width: 6, height: 6)
                    Text(statusText(link))
                        .font(BounceTheme.mono(10, weight: .bold))
                        .foregroundColor(statusColor(link))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(BounceTheme.surfaceElevated)
                .overlay(Rectangle().stroke(statusColor(link).opacity(0.4), lineWidth: 1))
                
                Spacer()
                
                HStack(spacing: 4) {
                    Image(systemName: "eye.fill")
                        .font(.system(size: 10))
                    Text("\(link.viewCount) VIEWS")
                        .font(BounceTheme.mono(10, weight: .semibold))
                }
                .foregroundColor(BounceTheme.textSecondary)
            }
            
            // Label / Title
            VStack(alignment: .leading, spacing: 4) {
                if let label = link.label, !label.isEmpty {
                    Text(label)
                        .font(BounceTheme.mono(13, weight: .bold))
                        .foregroundColor(BounceTheme.textPrimary)
                }
                
                Text(link.shareURL().absoluteString)
                    .font(BounceTheme.mono(11))
                    .foregroundColor(BounceTheme.textSecondary)
                    .lineLimit(1)
            }
            
            // Badges Row (Stream Only vs Download, Comments, Expiration)
            HStack(spacing: 8) {
                Text(link.allowDownload ? "DOWNLOAD ALLOWED" : "STREAM ONLY")
                    .font(BounceTheme.mono(9, weight: .bold))
                    .foregroundColor(link.allowDownload ? BounceTheme.accent : BounceTheme.textMuted)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(BounceTheme.surfaceElevated)
                
                if link.allowComments {
                    Text("COMMENTS ON")
                        .font(BounceTheme.mono(9, weight: .bold))
                        .foregroundColor(BounceTheme.commentPin)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(BounceTheme.surfaceElevated)
                }
                
                if let exp = link.expiresAt {
                    Text("EXPIRES \(formattedDate(exp))")
                        .font(BounceTheme.mono(9))
                        .foregroundColor(BounceTheme.textSecondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(BounceTheme.surfaceElevated)
                }
            }
            
            Divider().background(BounceTheme.surfaceBorder)
            
            // Action Buttons
            HStack(spacing: 8) {
                // Copy Link
                Button {
                    UIPasteboard.general.string = link.shareURL().absoluteString
                    BounceTheme.notificationHaptic(type: .success)
                    copiedLinkId = link.id
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        if copiedLinkId == link.id { copiedLinkId = nil }
                    }
                } label: {
                    Text(copiedLinkId == link.id ? "COPIED" : "COPY LINK")
                        .font(BounceTheme.mono(10, weight: .bold))
                        .foregroundColor(BounceTheme.textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(BounceTheme.surfaceElevated)
                        .overlay(Rectangle().stroke(BounceTheme.surfaceBorder, lineWidth: 1))
                }
                
                // Test Guest Player
                Button {
                    selectedLinkToTest = link
                } label: {
                    Text("TEST AS GUEST")
                        .font(BounceTheme.mono(10, weight: .bold))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(BounceTheme.accent)
                }
                
                // Revoke Link Button
                if link.isValid {
                    Button {
                        Task {
                            await shareService.revokeShareLink(id: link.id)
                        }
                    } label: {
                        Text("REVOKE")
                            .font(BounceTheme.mono(10, weight: .bold))
                            .foregroundColor(BounceTheme.alert)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(BounceTheme.surfaceElevated)
                            .overlay(Rectangle().stroke(BounceTheme.alert.opacity(0.5), lineWidth: 1))
                    }
                }
            }
        }
        .padding(14)
        .background(BounceTheme.surface)
        .overlay(Rectangle().stroke(BounceTheme.surfaceBorder, lineWidth: 1))
    }
    
    // MARK: - Helpers
    private func statusColor(_ link: ShareLink) -> Color {
        if link.isRevoked { return BounceTheme.alert }
        if link.isExpired { return BounceTheme.textMuted }
        return BounceTheme.accent
    }
    
    private func statusText(_ link: ShareLink) -> String {
        if link.isRevoked { return "REVOKED" }
        if link.isExpired { return "EXPIRED" }
        return "ACTIVE"
    }
    
    private func formattedDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f.string(from: date).uppercased()
    }
    
    private var emptyView: some View {
        VStack(spacing: 12) {
            Image(systemName: "link.badge.plus")
                .font(.system(size: 40))
                .foregroundColor(BounceTheme.textMuted)
                .padding(.top, 32)
            
            Text("NO SHARED LINKS YET")
                .font(BounceTheme.mono(12, weight: .bold))
                .foregroundColor(BounceTheme.textSecondary)
            
            Text("Generate private links for entire projects or individual beats from your library.")
                .font(BounceTheme.sans(12))
                .foregroundColor(BounceTheme.textMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }
}
