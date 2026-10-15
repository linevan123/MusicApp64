import SwiftUI
import AVFoundation

@main
struct BounceApp: App {
    init() {
        // Enforce background audio playback capability
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, policy: .longFormAudio, options: [])
            try session.setActive(true)
        } catch {
            print("AVAudioSession initialization warning: \(error)")
        }
    }
    
    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme(.dark) // Brutalist dark-mode by default
        }
    }
}
