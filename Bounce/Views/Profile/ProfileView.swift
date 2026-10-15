import SwiftUI

public struct ProfileView: View {
    @ObservedObject var authService = AuthService.shared
    @ObservedObject var projectService = ProjectService.shared
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            ZStack {
                BounceTheme.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Profile Banner
                        profileHeader
                        
                        // Storage & Vault Usage
                        storageSection
                        
                        // FL Studio / DAW Quick Guide
                        dawGuideSection
                        
                        // Backend Connection Status
                        backendStatusSection
                        
                        // Sign Out Button
                        Button {
                            BounceTheme.haptic(style: .medium)
                            authService.signOut()
                        } label: {
                            Text("SIGN OUT OF CREATOR ACCOUNT")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(BrutalistButtonStyle(isPrimary: false, isDestructive: true))
                        .padding(.top, 8)
                    }
                    .padding(20)
                    .padding(.bottom, 120) // space for mini player
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    // MARK: - Profile Header
    private var profileHeader: some View {
        HStack(spacing: 16) {
            ZStack {
                Rectangle()
                    .fill(BounceTheme.accent)
                    .frame(width: 64, height: 64)
                
                Text(authService.currentUser?.username.prefix(2).uppercased() ?? "EV")
                    .font(BounceTheme.mono(22, weight: .bold))
                    .foregroundColor(.black)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(authService.currentUser?.username ?? "prodbyevan!")
                    .font(BounceTheme.mono(18, weight: .bold))
                    .foregroundColor(BounceTheme.textPrimary)
                
                Text(authService.currentUser?.email ?? "evan@prodbyevan.com")
                    .font(BounceTheme.sans(12))
                    .foregroundColor(BounceTheme.textSecondary)
                
                Text("CREATOR ACCOUNT · VERIFIED")
                    .font(BounceTheme.mono(9, weight: .bold))
                    .foregroundColor(BounceTheme.accent)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(BounceTheme.surfaceElevated)
            }
            
            Spacer()
        }
        .padding(16)
        .background(BounceTheme.surface)
        .overlay(Rectangle().stroke(BounceTheme.surfaceBorder, lineWidth: 1))
    }
    
    // MARK: - Storage Section
    private var storageSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("LOSSLESS AUDIO VAULT")
                .font(BounceTheme.mono(10, weight: .bold))
                .foregroundColor(BounceTheme.textSecondary)
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("PRIVATE STORAGE")
                        .font(BounceTheme.mono(11, weight: .bold))
                        .foregroundColor(BounceTheme.textPrimary)
                    Spacer()
                    Text("1.42 GB / 50 GB")
                        .font(BounceTheme.mono(11))
                        .foregroundColor(BounceTheme.accent)
                }
                
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Rectangle().fill(BounceTheme.surfaceBorder)
                        Rectangle()
                            .fill(BounceTheme.accent)
                            .frame(width: geo.size.width * 0.05)
                    }
                }
                .frame(height: 6)
                
                Text("Supports uncompressed 24-bit / 48kHz & 96kHz WAV, FLAC, and Stems.")
                    .font(BounceTheme.sans(11))
                    .foregroundColor(BounceTheme.textMuted)
            }
            .padding(14)
            .background(BounceTheme.surface)
            .overlay(Rectangle().stroke(BounceTheme.surfaceBorder, lineWidth: 1))
        }
    }
    
    // MARK: - DAW Guide
    private var dawGuideSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("PRODUCER EXPORT WORKFLOW")
                .font(BounceTheme.mono(10, weight: .bold))
                .foregroundColor(BounceTheme.textSecondary)
            
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "slider.vertical.3")
                        .foregroundColor(BounceTheme.accent)
                    Text("FL Studio / Ableton / Logic")
                        .font(BounceTheme.mono(12, weight: .bold))
                        .foregroundColor(BounceTheme.textPrimary)
                }
                
                Text("Export master bounces directly into Files app or iCloud Drive as 24-bit WAV. Open Bounce, tap '+ ADD BOUNCE', and share high-res streaming links without iMessage compression or Google Drive clutter.")
                    .font(BounceTheme.sans(12))
                    .foregroundColor(BounceTheme.textSecondary)
                    .lineSpacing(2)
            }
            .padding(14)
            .background(BounceTheme.surface)
            .overlay(Rectangle().stroke(BounceTheme.surfaceBorder, lineWidth: 1))
        }
    }
    
    // MARK: - Backend Status
    private var backendStatusSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("BACKEND ENGINE")
                .font(BounceTheme.mono(10, weight: .bold))
                .foregroundColor(BounceTheme.textSecondary)
            
            HStack {
                Circle()
                    .fill(SupabaseConfig.isConfigured ? BounceTheme.accent : Color.orange)
                    .frame(width: 8, height: 8)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(SupabaseConfig.isConfigured ? "CONNECTED TO SUPABASE" : "RUNNING IN LOCAL DEMO MODE")
                        .font(BounceTheme.mono(11, weight: .bold))
                        .foregroundColor(BounceTheme.textPrimary)
                    
                    Text(SupabaseConfig.isConfigured ? SupabaseConfig.projectURL.absoluteString : "Ready for live Supabase credentials in SupabaseConfig.swift")
                        .font(BounceTheme.mono(9))
                        .foregroundColor(BounceTheme.textSecondary)
                        .lineLimit(1)
                }
                
                Spacer()
            }
            .padding(14)
            .background(BounceTheme.surface)
            .overlay(Rectangle().stroke(BounceTheme.surfaceBorder, lineWidth: 1))
        }
    }
}
