import SwiftUI

/// Root view coordinator managing creator authentication state and deep link handling
/// for guest listeners opening private share links without an account.
public struct RootView: View {
    @ObservedObject var authService = AuthService.shared
    
    // Deep Link guest player presentation
    @State private var incomingShareToken: String?
    
    public init() {}
    
    public var body: some View {
        Group {
            if authService.isAuthenticated {
                MainTabView()
            } else {
                AuthView()
            }
        }
        .onOpenURL { url in
            handleIncomingURL(url)
        }
        .sheet(isPresented: Binding(
            get: { incomingShareToken != nil },
            set: { if !$0 { incomingShareToken = nil } }
        )) {
            if let token = incomingShareToken {
                PublicPlayerView(shareToken: token)
            }
        }
    }
    
    // MARK: - Deep Link Parser
    private func handleIncomingURL(_ url: URL) {
        // Formats handled:
        // bounce://s/{token}
        // bounce://share?token={token}
        // https://bounce.app/s/{token}
        
        if url.scheme == "bounce" {
            if url.host == "s" || url.pathComponents.contains("s") {
                let token = url.lastPathComponent
                if !token.isEmpty && token != "/" && token != "s" {
                    self.incomingShareToken = token
                    return
                }
            }
            if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
               let tokenItem = components.queryItems?.first(where: { $0.name == "token" })?.value {
                self.incomingShareToken = tokenItem
                return
            }
        } else if url.host?.contains("bounce") == true {
            let pathComps = url.pathComponents
            if let sIndex = pathComps.firstIndex(of: "s"), sIndex + 1 < pathComps.count {
                self.incomingShareToken = pathComps[sIndex + 1]
            }
        }
    }
}
