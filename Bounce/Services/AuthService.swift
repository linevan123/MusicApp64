import Foundation
import Combine

@MainActor
public final class AuthService: ObservableObject {
    public static let shared = AuthService()
    
    @Published public var currentUser: Profile?
    @Published public var sessionToken: String?
    @Published public var isAuthenticated: Bool = false
    @Published public var isLoading: Bool = false
    @Published public var errorMessage: String?
    
    private let userDefaultsSessionKey = "bounce_session_token"
    private let userDefaultsUserKey = "bounce_cached_profile"
    
    private init() {
        restoreSession()
    }
    
    // MARK: - Session Restoration
    public func restoreSession() {
        if let token = UserDefaults.standard.string(forKey: userDefaultsSessionKey),
           let data = UserDefaults.standard.data(forKey: userDefaultsUserKey),
           let profile = try? JSONDecoder().decode(Profile.self, from: data) {
            self.sessionToken = token
            self.currentUser = profile
            self.isAuthenticated = true
        } else {
            // Default demo creator for instant testing if unconfigured
            if !SupabaseConfig.isConfigured {
                setupDemoProducer()
            }
        }
    }
    
    public func setupDemoProducer() {
        let demo = Profile(
            id: UUID(uuidString: "8E3D7B1C-4B2E-4C5A-9D3E-1F2A3B4C5D6E")!,
            email: "evan@prodbyevan.com",
            username: "prodbyevan!",
            createdAt: Date()
        )
        self.currentUser = demo
        self.sessionToken = "demo-session-token-prodbyevan"
        self.isAuthenticated = true
        saveSession(token: "demo-session-token-prodbyevan", profile: demo)
    }
    
    // MARK: - Sign In
    public func signIn(email: String, password: String) async -> Bool {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        
        guard SupabaseConfig.isConfigured else {
            // Instant mock login
            let profile = Profile(
                id: UUID(),
                email: email,
                username: email.components(separatedBy: "@").first ?? "producer"
            )
            saveSession(token: "mock-jwt-token", profile: profile)
            return true
        }
        
        do {
            let url = SupabaseConfig.projectURL.appendingPathComponent("auth/v1/token?grant_type=password")
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
            
            let body = ["email": email, "password": password]
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                let errObj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
                let msg = (errObj?["error_description"] as? String) ?? (errObj?["msg"] as? String) ?? "Invalid credentials"
                errorMessage = msg
                return false
            }
            
            struct SupabaseAuthResponse: Codable {
                let access_token: String
                let user: SupabaseUser
            }
            struct SupabaseUser: Codable {
                let id: String
                let email: String
                let user_metadata: [String: String]?
            }
            
            let authData = try JSONDecoder().decode(SupabaseAuthResponse.self, from: data)
            guard let uid = UUID(uuidString: authData.user.id) else {
                errorMessage = "Invalid user identity"
                return false
            }
            
            let username = authData.user.user_metadata?["username"] ?? email.components(separatedBy: "@").first ?? "creator"
            let profile = Profile(id: uid, email: authData.user.email, username: username)
            
            saveSession(token: authData.access_token, profile: profile)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
    
    // MARK: - Sign Up
    public func signUp(email: String, password: String, username: String) async -> Bool {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        
        let trimmedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isValidUsername(trimmedUsername) else {
            errorMessage = "Username must be 2–32 characters and only contain letters, numbers, _, ., !, or -"
            return false
        }
        
        guard SupabaseConfig.isConfigured else {
            let profile = Profile(id: UUID(), email: email, username: trimmedUsername)
            saveSession(token: "mock-jwt-token", profile: profile)
            return true
        }
        
        do {
            let url = SupabaseConfig.projectURL.appendingPathComponent("auth/v1/signup")
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
            
            let body: [String: Any] = [
                "email": email,
                "password": password,
                "data": ["username": trimmedUsername]
            ]
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...201).contains(http.statusCode) else {
                let errObj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
                let msg = (errObj?["msg"] as? String) ?? "Failed to create account"
                errorMessage = msg
                return false
            }
            
            return await signIn(email: email, password: password)
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
    
    // MARK: - Sign Out
    public func signOut() {
        UserDefaults.standard.removeObject(forKey: userDefaultsSessionKey)
        UserDefaults.standard.removeObject(forKey: userDefaultsUserKey)
        self.sessionToken = nil
        self.currentUser = nil
        self.isAuthenticated = false
    }
    
    private func saveSession(token: String, profile: Profile) {
        self.sessionToken = token
        self.currentUser = profile
        self.isAuthenticated = true
        
        UserDefaults.standard.set(token, forKey: userDefaultsSessionKey)
        if let encoded = try? JSONEncoder().encode(profile) {
            UserDefaults.standard.set(encoded, forKey: userDefaultsUserKey)
        }
    }
    
    public func isValidUsername(_ candidate: String) -> Bool {
        let pattern = "^[A-Za-z0-9_.!-]{2,32}$"
        return candidate.range(of: pattern, options: .regularExpression) != nil
    }
}
