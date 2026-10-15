import Foundation
import AVFoundation
import MediaPlayer
import Combine

/// Advanced Gapless Audio Player Service.
/// Implements AVQueuePlayer with pre-buffering, background audio session lifecycle,
/// lock screen / Now Playing integration, and precise waveform scrubbing.
@MainActor
public final class AudioPlayerService: NSObject, ObservableObject {
    public static let shared = AudioPlayerService()
    
    // MARK: - Published State
    @Published public private(set) var currentTrack: Track?
    @Published public private(set) var isPlaying: Bool = false
    @Published public private(set) var isBuffering: Bool = false
    @Published public private(set) var currentTime: Double = 0.0
    @Published public private(set) var duration: Double = 0.0
    @Published public private(set) var progress: Double = 0.0
    @Published public private(set) var playlist: [Track] = []
    @Published public private(set) var currentIndex: Int = 0
    
    // Scrubbing State
    @Published public var isScrubbing: Bool = false
    @Published public var scrubTime: Double = 0.0
    
    // Metadata for lock screen
    public var currentProjectTitle: String = ""
    public var currentOwnerName: String = ""
    
    // MARK: - Audio Engine Properties
    private var queuePlayer: AVQueuePlayer?
    private var playerItems: [AVPlayerItem] = []
    private var timeObserverToken: Any?
    private var statusObserverToken: NSKeyValueObservation?
    private var timeControlObserver: NSKeyValueObservation?
    private var currentItemObserver: NSKeyValueObservation?
    
    override private init() {
        super.init()
        setupAudioSession()
        setupRemoteCommands()
    }
    
    deinit {
        cleanup()
    }
    
    // MARK: - Audio Session Configuration
    private func setupAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, policy: .longFormAudio, options: [])
            try session.setActive(true)
        } catch {
            print("Failed to configure AVAudioSession for playback: \(error.localizedDescription)")
        }
        
        // Listen for audio session interruptions (phone calls, alarms, etc.)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAudioInterruption),
            name: AVAudioSession.interruptionNotification,
            object: nil
        )
    }
    
    @objc private func handleAudioInterruption(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }
        
        Task { @MainActor in
            switch type {
            case .began:
                self.isPlaying = false
            case .ended:
                if let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt {
                    let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                    if options.contains(.shouldResume) {
                        self.resume()
                    }
                }
            @unknown default:
                break
            }
        }
    }
    
    // MARK: - Lock Screen & Control Center (MPRemoteCommandCenter)
    private func setupRemoteCommands() {
        let commandCenter = MPRemoteCommandCenter.shared()
        
        commandCenter.playCommand.isEnabled = true
        commandCenter.playCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in self?.resume() }
            return .success
        }
        
        commandCenter.pauseCommand.isEnabled = true
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in self?.pause() }
            return .success
        }
        
        commandCenter.togglePlayPauseCommand.isEnabled = true
        commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in self?.togglePlayPause() }
            return .success
        }
        
        commandCenter.nextTrackCommand.isEnabled = true
        commandCenter.nextTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in self?.next() }
            return .success
        }
        
        commandCenter.previousTrackCommand.isEnabled = true
        commandCenter.previousTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in self?.previous() }
            return .success
        }
        
        commandCenter.changePlaybackPositionCommand.isEnabled = true
        commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let positionEvent = event as? MPChangePlaybackPositionCommandEvent else {
                return .commandFailed
            }
            Task { @MainActor [weak self] in
                self?.seek(to: positionEvent.positionTime)
            }
            return .success
        }
    }
    
    private func updateNowPlayingInfo() {
        guard let track = currentTrack else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            return
        }
        
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: track.title,
            MPMediaItemPropertyArtist: currentOwnerName.isEmpty ? "Bounce Producer" : currentOwnerName,
            MPMediaItemPropertyAlbumTitle: currentProjectTitle.isEmpty ? "Project" : currentProjectTitle,
            MPMediaItemPropertyPlaybackDuration: max(duration, track.duration),
            MPNowPlayingInfoPropertyElapsedPlaybackTime: currentTime,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0
        ]
        
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
    
    // MARK: - Playback Queue Management (Gapless)
    
    /// Starts playback of a list of tracks gaplessly from a given index
    public func play(
        tracks: [Track],
        startingAt index: Int = 0,
        projectTitle: String = "",
        ownerName: String = ""
    ) {
        guard !tracks.isEmpty, tracks.indices.contains(index) else { return }
        
        cleanup()
        
        self.playlist = tracks
        self.currentIndex = index
        self.currentProjectTitle = projectTitle
        self.currentOwnerName = ownerName
        
        // Build AVPlayerItems for gapless AVQueuePlayer
        let itemsToQueue = tracks[index...].compactMap { track -> AVPlayerItem? in
            guard let url = track.streamURL else { return nil }
            let asset = AVURLAsset(url: url, options: [AVURLAssetPreferPreciseDurationAndTimingKey: true])
            return AVPlayerItem(asset: asset)
        }
        
        guard let firstItem = itemsToQueue.first else { return }
        
        let player = AVQueuePlayer(items: itemsToQueue)
        player.actionAtItemEnd = .advance
        player.automaticallyWaitsToMinimizeStalling = true
        self.queuePlayer = player
        
        self.currentTrack = tracks[index]
        self.duration = tracks[index].duration
        self.currentTime = 0
        self.progress = 0
        
        attachObservers(for: player, item: firstItem)
        
        player.play()
        self.isPlaying = true
        updateNowPlayingInfo()
    }
    
    /// Plays a single track
    public func playSingle(track: Track, projectTitle: String = "", ownerName: String = "") {
        play(tracks: [track], startingAt: 0, projectTitle: projectTitle, ownerName: ownerName)
    }
    
    // MARK: - Observer Management
    private func attachObservers(for player: AVQueuePlayer, item: AVPlayerItem) {
        // Observe periodic time updates (every 50ms for smooth 60fps waveform scrubber movement)
        let interval = CMTime(seconds: 0.05, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserverToken = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self = self, !self.isScrubbing else { return }
            let seconds = CMTimeGetSeconds(time)
            guard !seconds.isNaN && !seconds.isInfinite else { return }
            
            self.currentTime = seconds
            if self.duration > 0 {
                self.progress = min(1.0, max(0.0, seconds / self.duration))
            }
        }
        
        // Observe item changes (automatic gapless transition)
        currentItemObserver = player.observe(\.currentItem, options: [.new]) { [weak self] player, change in
            guard let self = self else { return }
            Task { @MainActor [weak self] in
                self?.handleItemTransition()
            }
        }
        
        // Observe playback rate/time control status (buffering vs playing)
        timeControlObserver = player.observe(\.timeControlStatus, options: [.new]) { [weak self] player, _ in
            guard let self = self else { return }
            Task { @MainActor [weak self] in
                self?.isPlaying = (player.timeControlStatus == .playing)
                self?.isBuffering = (player.timeControlStatus == .waitingToPlayAtSpecifiedRate)
                self?.updateNowPlayingInfo()
            }
        }
        
        // Item completion notification
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playerItemDidReachEnd),
            name: .AVPlayerItemDidPlayToEndTime,
            object: nil
        )
    }
    
    @objc private func playerItemDidReachEnd(notification: Notification) {
        Task { @MainActor in
            // Handled automatically by AVQueuePlayer advancing
            self.updateNowPlayingInfo()
        }
    }
    
    private func handleItemTransition() {
        guard let player = queuePlayer, let currentItem = player.currentItem else {
            self.isPlaying = false
            return
        }
        
        // Advance current index if it progressed
        if currentIndex + 1 < playlist.count {
            currentIndex += 1
            let newTrack = playlist[currentIndex]
            self.currentTrack = newTrack
            self.duration = newTrack.duration
            self.currentTime = 0
            self.progress = 0
            BounceTheme.haptic(style: .light)
            updateNowPlayingInfo()
        }
    }
    
    // MARK: - Playback Controls
    public func togglePlayPause() {
        if isPlaying {
            pause()
        } else {
            resume()
        }
    }
    
    public func pause() {
        queuePlayer?.pause()
        isPlaying = false
        updateNowPlayingInfo()
    }
    
    public func resume() {
        queuePlayer?.play()
        isPlaying = true
        updateNowPlayingInfo()
    }
    
    public func next() {
        guard currentIndex + 1 < playlist.count else { return }
        play(
            tracks: playlist,
            startingAt: currentIndex + 1,
            projectTitle: currentProjectTitle,
            ownerName: currentOwnerName
        )
    }
    
    public func previous() {
        // If track has been playing for > 3 seconds, restart current track
        if currentTime > 3.0 {
            seek(to: 0)
            return
        }
        
        guard currentIndex > 0 else {
            seek(to: 0)
            return
        }
        
        play(
            tracks: playlist,
            startingAt: currentIndex - 1,
            projectTitle: currentProjectTitle,
            ownerName: currentOwnerName
        )
    }
    
    // MARK: - Waveform Scrubbing & Seeking
    public func startScrubbing() {
        isScrubbing = true
        scrubTime = currentTime
    }
    
    public func scrub(to progressValue: Double) {
        let clamped = min(1.0, max(0.0, progressValue))
        self.progress = clamped
        let target = clamped * max(duration, 0.01)
        self.scrubTime = target
    }
    
    public func finishScrubbing() {
        isScrubbing = false
        seek(to: scrubTime)
    }
    
    public func seek(to seconds: Double) {
        guard let player = queuePlayer else { return }
        let targetCMTime = CMTime(seconds: seconds, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        
        player.seek(to: targetCMTime, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.currentTime = seconds
                if self.duration > 0 {
                    self.progress = min(1.0, max(0.0, seconds / self.duration))
                }
                self.updateNowPlayingInfo()
            }
        }
    }
    
    // MARK: - Cleanup
    private func cleanup() {
        if let token = timeObserverToken, let player = queuePlayer {
            player.removeTimeObserver(token)
            timeObserverToken = nil
        }
        statusObserverToken?.invalidate()
        timeControlObserver?.invalidate()
        currentItemObserver?.invalidate()
        
        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: nil)
        
        queuePlayer?.pause()
        queuePlayer?.removeAllItems()
        queuePlayer = nil
    }
}
