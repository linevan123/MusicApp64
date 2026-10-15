import SwiftUI

public struct MainTabView: View {
    @State private var selectedTab: TabItem = .library
    @State private var showFullPlayer: Bool = false
    @ObservedObject var player = AudioPlayerService.shared
    
    public enum TabItem: String, CaseIterable {
        case library = "Library"
        case shared = "Shared Links"
        case profile = "Profile"
        
        var icon: String {
            switch self {
            case .library: return "waveform.badge.magnifyingglass"
            case .shared: return "link"
            case .profile: return "person.crop.square"
            }
        }
    }
    
    public init() {
        // Configure standard tab bar appearance for dark brutalist aesthetic
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(BounceTheme.background)
        appearance.shadowColor = UIColor(BounceTheme.surfaceBorder)
        
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
    
    public var body: some View {
        ZStack(alignment: .bottom) {
            // Main Tab Screens
            TabView(selection: $selectedTab) {
                LibraryView()
                    .tabItem {
                        Label(TabItem.library.rawValue, systemImage: TabItem.library.icon)
                    }
                    .tag(TabItem.library)
                
                SharedLinksView()
                    .tabItem {
                        Label(TabItem.shared.rawValue, systemImage: TabItem.shared.icon)
                    }
                    .tag(TabItem.shared)
                
                ProfileView()
                    .tabItem {
                        Label(TabItem.profile.rawValue, systemImage: TabItem.profile.icon)
                    }
                    .tag(TabItem.profile)
            }
            .accentColor(BounceTheme.accent)
            
            // Persistent Floating Mini Player above the tab bar
            if player.currentTrack != nil {
                MiniPlayerView {
                    showFullPlayer = true
                }
                .padding(.bottom, 52) // sits above standard iOS tab bar
                .animation(.spring(response: 0.35, dampingFraction: 0.8), value: player.currentTrack?.id)
            }
        }
        .sheet(isPresented: $showFullPlayer) {
            FullPlayerView()
        }
    }
}
