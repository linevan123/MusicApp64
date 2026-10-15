import Foundation

/// Supabase configuration constants and environment credentials.
/// In production, replace `projectURL` and `anonKey` with your Supabase project settings.
public enum SupabaseConfig {
    // Default placeholder configuration.
    // Replace with your real Supabase project values from:
    // https://supabase.com/dashboard/project/<project-id>/settings/api
    public static var projectURL: URL = URL(string: "https://your-project-ref.supabase.co")!
    public static var anonKey: String = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.your-anon-key-here"
    
    // Custom Edge Functions base URL
    public static var functionsURL: URL {
        projectURL.appendingPathComponent("functions/v1")
    }
    
    // Edge function endpoints
    public static var shareResolveURL: URL {
        functionsURL.appendingPathComponent("share-resolve")
    }
    
    public static var shareCommentURL: URL {
        functionsURL.appendingPathComponent("share-comment")
    }
    
    // Configured check
    public static var isConfigured: Bool {
        !anonKey.contains("your-anon-key-here")
    }
}
