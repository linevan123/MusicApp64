import SwiftUI

public struct ShareSheetView: View {
    public let projectId: UUID?
    public let trackId: UUID?
    public let title: String
    
    @ObservedObject var shareService = ShareService.shared
    @Environment(\.dismiss) private var dismiss
    
    // Granular Settings
    @State private var allowDownload: Bool = false // false = "Stream Only"
    @State private var allowComments: Bool = true
    @State private var expirationChoice: ExpirationOption = .sevenDays
    @State private var collaboratorLabel: String = ""
    
    // Result State
    @State private var generatedLink: ShareLink?
    @State private var isCopied: Bool = false
    @State private var isCreating: Bool = false
    
    public enum ExpirationOption: String, CaseIterable, Identifiable {
        case oneDay = "24 Hours"
        case sevenDays = "7 Days"
        case thirtyDays = "30 Days"
        case never = "Never"
        
        public var id: String { rawValue }
        
        public var days: Int? {
            switch self {
            case .oneDay: return 1
            case .sevenDays: return 7
            case .thirtyDays: return 30
            case .never: return nil
            }
        }
    }
    
    public init(projectId: UUID? = nil, trackId: UUID? = nil, title: String) {
        self.projectId = projectId
        self.trackId = trackId
        self.title = title
    }
    
    public var body: some View {
        NavigationStack {
            ZStack {
                BounceTheme.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Header
                        VStack(alignment: .leading, spacing: 4) {
                            Text("PRIVATE SHARE LINK")
                                .font(BounceTheme.mono(11, weight: .bold))
                                .foregroundColor(BounceTheme.accent)
                                .tracking(1.5)
                            
                            Text(title)
                                .font(BounceTheme.mono(16, weight: .bold))
                                .foregroundColor(BounceTheme.textPrimary)
                                .lineLimit(1)
                        }
                        
                        if let link = generatedLink {
                            // Link Generated Success State
                            generatedLinkSuccessView(link: link)
                        } else {
                            // Configuration Form
                            configurationSection
                            
                            // Generate Action Button
                            Button {
                                generateLink()
                            } label: {
                                if isCreating {
                                    ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .black))
                                        .frame(maxWidth: .infinity)
                                } else {
                                    Text("GENERATE PRIVATE LINK")
                                        .frame(maxWidth: .infinity)
                                }
                            }
                            .buttonStyle(BrutalistButtonStyle(isPrimary: true))
                            .disabled(isCreating)
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Share Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .foregroundColor(BounceTheme.textSecondary)
                }
            }
        }
    }
    
    // MARK: - Configuration Section
    private var configurationSection: some View {
        VStack(spacing: 20) {
            // Collaborator Label Field
            VStack(alignment: .leading, spacing: 6) {
                Text("COLLABORATOR / NOTE (OPTIONAL)")
                    .font(BounceTheme.mono(10, weight: .bold))
                    .foregroundColor(BounceTheme.textSecondary)
                
                TextField("e.g. For Carti Management / A&R Review", text: $collaboratorLabel)
                    .font(BounceTheme.sans(13))
                    .padding(12)
                    .background(BounceTheme.surface)
                    .foregroundColor(BounceTheme.textPrimary)
                    .overlay(Rectangle().stroke(BounceTheme.surfaceBorder, lineWidth: 1))
            }
            
            // "Stream Only" vs "Allow Download" Toggle
            VStack(alignment: .leading, spacing: 10) {
                Text("PERMISSIONS")
                    .font(BounceTheme.mono(10, weight: .bold))
                    .foregroundColor(BounceTheme.textSecondary)
                
                HStack(spacing: 12) {
                    permissionToggleCard(
                        title: "STREAM ONLY",
                        subtitle: "Preview in high-res without downloading",
                        icon: "headphones",
                        isSelected: !allowDownload
                    ) {
                        allowDownload = false
                    }
                    
                    permissionToggleCard(
                        title: "ALLOW DOWNLOAD",
                        subtitle: "Recipient can save original WAV/FLAC",
                        icon: "arrow.down.circle.fill",
                        isSelected: allowDownload
                    ) {
                        allowDownload = true
                    }
                }
            }
            
            // Allow Comments Toggle
            Toggle(isOn: $allowComments) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("ALLOW TIMESTAMPED COMMENTS")
                        .font(BounceTheme.mono(12, weight: .bold))
                        .foregroundColor(BounceTheme.textPrimary)
                    Text("Listeners can leave feedback directly on the audio waveform")
                        .font(BounceTheme.sans(11))
                        .foregroundColor(BounceTheme.textSecondary)
                }
            }
            .toggleStyle(SwitchToggleStyle(tint: BounceTheme.accent))
            .padding(14)
            .background(BounceTheme.surface)
            .overlay(Rectangle().stroke(BounceTheme.surfaceBorder, lineWidth: 1))
            
            // Expiration Selector
            VStack(alignment: .leading, spacing: 8) {
                Text("LINK EXPIRATION")
                    .font(BounceTheme.mono(10, weight: .bold))
                    .foregroundColor(BounceTheme.textSecondary)
                
                HStack(spacing: 8) {
                    ForEach(ExpirationOption.allCases) { opt in
                        Button {
                            BounceTheme.haptic(style: .light)
                            expirationChoice = opt
                        } label: {
                            Text(opt.rawValue.uppercased())
                                .font(BounceTheme.mono(10, weight: .bold))
                                .foregroundColor(expirationChoice == opt ? .black : BounceTheme.textPrimary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(expirationChoice == opt ? BounceTheme.accent : BounceTheme.surface)
                                .overlay(
                                    Rectangle()
                                        .stroke(expirationChoice == opt ? BounceTheme.accent : BounceTheme.surfaceBorder, lineWidth: 1)
                                )
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Permission Card Helper
    private func permissionToggleCard(
        title: String,
        subtitle: String,
        icon: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: {
            BounceTheme.haptic(style: .selection)
            action()
        }) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: icon)
                        .font(.system(size: 16))
                        .foregroundColor(isSelected ? BounceTheme.accent : BounceTheme.textMuted)
                    Spacer()
                    if isSelected {
                        Image(systemName: "checkmark.square.fill")
                            .font(.system(size: 14))
                            .foregroundColor(BounceTheme.accent)
                    }
                }
                
                Text(title)
                    .font(BounceTheme.mono(11, weight: .bold))
                    .foregroundColor(BounceTheme.textPrimary)
                
                Text(subtitle)
                    .font(BounceTheme.sans(10))
                    .foregroundColor(BounceTheme.textSecondary)
                    .lineLimit(2)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? BounceTheme.surfaceElevated : BounceTheme.surface)
            .overlay(
                Rectangle()
                    .stroke(isSelected ? BounceTheme.accent : BounceTheme.surfaceBorder, lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Generated Link Success View
    private func generatedLinkSuccessView(link: ShareLink) -> some View {
        let urlString = link.shareURL().absoluteString
        
        return VStack(spacing: 20) {
            ZStack {
                Rectangle()
                    .fill(BounceTheme.surfaceElevated)
                    .frame(height: 120)
                    .overlay(Rectangle().stroke(BounceTheme.accent, lineWidth: 1))
                
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(BounceTheme.accent)
                    
                    Text("SECURE LINK ACTIVE")
                        .font(BounceTheme.mono(13, weight: .bold))
                        .foregroundColor(BounceTheme.textPrimary)
                    
                    Text(link.allowDownload ? "Permission: Download Allowed" : "Permission: Stream Only")
                        .font(BounceTheme.mono(10))
                        .foregroundColor(BounceTheme.textSecondary)
                }
            }
            
            // Link Box with Copy Button
            HStack {
                Text(urlString)
                    .font(BounceTheme.mono(12))
                    .foregroundColor(BounceTheme.textPrimary)
                    .lineLimit(1)
                
                Spacer()
                
                Button {
                    UIPasteboard.general.string = urlString
                    BounceTheme.notificationHaptic(type: .success)
                    isCopied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        isCopied = false
                    }
                } label: {
                    Text(isCopied ? "COPIED!" : "COPY")
                        .font(BounceTheme.mono(11, weight: .bold))
                        .foregroundColor(.black)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(isCopied ? Color.green : BounceTheme.accent)
                }
            }
            .padding(12)
            .background(BounceTheme.surface)
            .overlay(Rectangle().stroke(BounceTheme.surfaceBorder, lineWidth: 1))
            
            // Share Sheet Trigger
            ShareLink(item: link.shareURL(), message: Text("Listen to '\(title)' by prodbyevan! on Bounce")) {
                HStack(spacing: 8) {
                    Image(systemName: "square.and.arrow.up")
                    Text("OPEN IOS SHARE SHEET")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(BrutalistButtonStyle(isPrimary: false))
            
            Button("DONE") {
                dismiss()
            }
            .buttonStyle(BrutalistButtonStyle(isPrimary: true))
        }
    }
    
    // MARK: - Actions
    private func generateLink() {
        isCreating = true
        Task {
            let label = collaboratorLabel.isEmpty ? nil : collaboratorLabel
            let link = await shareService.createShareLink(
                projectId: projectId,
                trackId: trackId,
                label: label,
                allowDownload: allowDownload,
                allowComments: allowComments,
                expiresInDays: expirationChoice.days
            )
            self.generatedLink = link
            self.isCreating = false
        }
    }
}
