# Bounce · High-Fidelity Audio Sharing for Music Producers

**Bounce** is a native iOS application built in SwiftUI with a Supabase BaaS backend, engineered specifically for music producers (e.g. exporting bounces from FL Studio under monikers like `"prodbyevan!"`) to securely share lossless tracks, beat packs, and album stems via private links without messy Google Drive folders or iMessage compression.

The visual identity and user experience closely mirror apps like **[untitled]** and **Samply**: minimalist, brutalist, OLED dark-mode by default, with custom typography, high-contrast accents, visual waveform scrubbers, gapless playback, and timestamped collaborative feedback pins.

---

## Architecture Overview

```
                      ┌────────────────────────────────────────┐
                      │             Bounce iOS App             │
                      │  (SwiftUI + AVFoundation + Accelerate) │
                      └────┬──────────────────────────────┬────┘
                           │                              │
         [Authenticated Creator: RLS]          [Guest Listener: Zero Auth]
                           │                              │
                           ▼                              ▼
             ┌─────────────────────────┐    ┌─────────────────────────┐
             │ Supabase DB & Storage   │    │ Supabase Edge Functions │
             │ • profiles, projects,   │    │ • share-resolve         │
             │   tracks, share_links   │    │ • share-comment         │
             │ • private 'audio' bucket│    │ (Validates token, mints │
             │ • private 'covers' buck.│    │  short-lived signed URLs│
             └─────────────────────────┘    └─────────────────────────┘
```

---

## Key Features

### 1. Minimalist Brutalist UI & Tab Navigation
- **OLED Dark Theme**: Jet black surfaces (`#0A0A0A`, `#141414`), 1px borders, high-contrast monospace metadata (BPM, key, sample rate, bit depth), and level-meter electric neon accents (`#CCFF00`).
- **Tab-Based Navigation**:
  1. **Library**: Projects, beat packs, stems folders, search, and audio import.
  2. **Shared Links**: Active links, view counts, permissions, and revocation.
  3. **Profile**: Producer moniker (`prodbyevan!`), storage vault usage, and DAW export guide.
- **Persistent Floating Mini Player**: Always accessible above the tab bar, keeping audio controls unbroken while browsing folders.

### 2. Advanced Audio Player Engine
- **Gapless Playback**: Powered by `AVQueuePlayer` and pre-buffered `AVPlayerItem` instances, enabling continuous transitions between tracks without stutter or latency.
- **Background Audio**: Integrated with `AVAudioSession` (`.playback`, `.longFormAudio`), `MPNowPlayingInfoCenter` (elapsed time, duration, track info, artwork), and `MPRemoteCommandCenter` (play, pause, next, previous, and lock-screen scrub commands).
- **Interactive Waveform Scrubber**: Dual-state amplitude bars (unplayed neutral vs played electric lime) with drag-to-scrub gestures and precision needle tracking.
- **On-Device Waveform Extraction**: `WaveformExtractor` reads uncompressed PCM buffers via `AVAssetReader` to compute peak RMS values on upload without waiting for server processing.

### 3. Granular Sharing & Zero-Friction Guest Listening
- **No Forced Sign-Up**: Listeners opening a link can immediately stream lossless audio, scrub waveforms, and leave notes without creating an account.
- **Granular Link Settings**:
  - **"Stream Only" vs. "Allow Download"**: Downloads use `Content-Disposition` signed URLs.
  - **Link Expiration**: 24 Hours, 7 Days, 30 Days, or Never.
  - **Comments Toggle**: Enable or disable feedback per link.
  - **Deep Linking**: Opens universal URLs (`https://bounce.app/s/:token` or `bounce://s/:token`) directly in the app.

### 4. Timestamped Waveform Collaboration
- Listeners and collaborators can drop feedback pins directly onto the waveform.
- Tapping any pin or comment jumps playback to the exact second.
- Comment input automatically syncs to the current playhead timestamp.

---

## Project Structure

```
├── Package.swift                                # Swift Package definition (iOS 16+)
├── Bounce/
│   ├── BounceApp.swift                          # @main entry point with background audio init
│   ├── Info.plist                               # UIBackgroundModes (audio), deep link schemes
│   │
│   ├── Theme/
│   │   └── Theme.swift                          # Brutalist dark theme, colors, fonts, haptics
│   │
│   ├── Models/
│   │   ├── Profile.swift                        # User / Producer profile model
│   │   ├── Project.swift                        # Project / Folder model
│   │   ├── Track.swift                          # Track model with waveform amplitudes
│   │   ├── ShareLink.swift                      # Granular share link model
│   │   ├── Comment.swift                        # Timestamped waveform comment model
│   │   └── SharedPayload.swift                  # share-resolve DTO
│   │
│   ├── AudioEngine/
│   │   ├── AudioPlayerService.swift             # AVQueuePlayer, background session & lock-screen
│   │   └── WaveformExtractor.swift              # PCM audio peak extraction via AVAssetReader
│   │
│   ├── Services/
│   │   ├── SupabaseConfig.swift                 # Backend URLs, keys, and endpoint constants
│   │   ├── AuthService.swift                    # Sign up, sign in, username checks, demo mode
│   │   ├── ProjectService.swift                 # Project organization, seed data, DB sync
│   │   ├── AudioUploadService.swift             # Audio inspector (bit depth/sample rate), upload
│   │   └── ShareService.swift                   # Link creator, guest resolver, comments
│   │
│   └── Views/
│       ├── RootView.swift                       # Navigation flow & deep-link coordinator
│       ├── Navigation/
│       │   └── MainTabView.swift                # 3-tab layout + docked Mini Player
│       ├── Auth/
│       │   └── AuthView.swift                   # Brutalist creator login & signup
│       ├── Library/
│       │   ├── LibraryView.swift                # Project list, search, new folder modal
│       │   ├── ProjectDetailView.swift          # Gapless playback cue, track list, add bounce
│       │   └── AudioImportView.swift            # Lossless audio importer & waveform preview
│       ├── Player/
│       │   ├── MiniPlayerView.swift             # Docked mini player with micro scrubber
│       │   ├── FullPlayerView.swift             # Full player sheet with waveform & DAW badges
│       │   └── WaveformScrubberView.swift       # Interactive scrubber with comment pins
│       ├── Sharing/
│       │   ├── ShareSheetView.swift             # Stream-Only toggle, expiration picker, copy
│       │   ├── SharedLinksView.swift            # Active links monitor & test guest mode
│       │   └── PublicPlayerView.swift           # Guest listener player (no login required)
│       ├── Comments/
│       │   └── CommentsDrawer.swift             # Pinned timestamp comments sheet
│       └── Profile/
│           └── ProfileView.swift                # Producer stats, storage meter, DAW guide
│
└── supabase/
    ├── config.toml                              # Local Supabase CLI configuration
    ├── migrations/
    │   └── 20261014000000_initial_schema.sql    # Tables, RLS policies, private storage buckets
    └── functions/
        ├── _shared/                             # Deno HTTP, CORS, and admin client helpers
        ├── share-resolve/index.ts               # Guest share resolver & signed URL minter
        └── share-comment/index.ts               # Timestamped comments endpoint
```

---

## Database & Storage Setup

1. **Deploy Migration**:
   ```bash
   cd supabase
   supabase db push
   # or run the SQL in migrations/20261014000000_initial_schema.sql via Supabase Dashboard SQL Editor
   ```

2. **Deploy Edge Functions**:
   ```bash
   supabase functions deploy share-resolve --no-verify-jwt
   supabase functions deploy share-comment --no-verify-jwt
   ```

3. **Configure the iOS Client**:
   Open [SupabaseConfig.swift](file:///c:/Users/evanh/OneDrive/Documentos/App/Bounce/Services/SupabaseConfig.swift) and set:
   ```swift
   public static var projectURL = URL(string: "https://your-project-ref.supabase.co")!
   public static var anonKey = "your-anon-publishable-key"
   ```
   *(Note: If left unconfigured, the app runs in full offline demo mode with seeded sample projects, tracks, waveforms, and comments for `"prodbyevan!"`)*

---

## Running the iOS App

- Open the folder in **Xcode** (or double click `Package.swift`).
- Select an **iOS 16+ Simulator** (e.g. iPhone 15 / 16 Pro) or physical iPhone.
- Press **Run** (`⌘R`).
- The app launches directly into the demo studio with pre-loaded beats (*VALERIA*, *OVERDRIVE_BOUNCE*, *Late Night Miami*).
- Tap any track to hear gapless playback, lock the device to test background audio controls, drag the waveform scrubber, and test sharing links!
