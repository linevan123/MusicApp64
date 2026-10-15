import SwiftUI

/// High-contrast Brutalist Waveform Scrubber.
/// Displays normalized peak amplitudes, interactive drag-to-scrub needle,
/// and timestamped comment pins placed directly along the timeline.
public struct WaveformScrubberView: View {
    public let amplitudes: [Float]
    public let duration: Double
    public let currentTime: Double
    public let progress: Double
    public let comments: [Comment]
    public let onScrub: (Double) -> Void
    public let onScrubEnd: () -> Void
    public let onCommentTap: ((Comment) -> Void)?
    
    @State private var isDragging: Bool = false
    @State private var dragProgress: Double = 0.0
    @State private var selectedComment: Comment?
    
    public init(
        amplitudes: [Float],
        duration: Double,
        currentTime: Double,
        progress: Double,
        comments: [Comment] = [],
        onScrub: @escaping (Double) -> Void,
        onScrubEnd: @escaping () -> Void,
        onCommentTap: ((Comment) -> Void)? = nil
    ) {
        self.amplitudes = amplitudes.isEmpty ? WaveformExtractor.generatePlaceholder(bars: 100) : amplitudes
        self.duration = max(0.01, duration)
        self.currentTime = currentTime
        self.progress = progress
        self.comments = comments
        self.onScrub = onScrub
        self.onScrubEnd = onScrubEnd
        self.onCommentTap = onCommentTap
    }
    
    private var activeProgress: Double {
        isDragging ? dragProgress : progress
    }
    
    public var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let height = geo.size.height
            let barCount = amplitudes.count
            let barSpacing: CGFloat = 2.0
            let totalSpacing = barSpacing * CGFloat(max(1, barCount - 1))
            let barWidth = max(2.0, (width - totalSpacing) / CGFloat(barCount))
            
            ZStack(alignment: .leading) {
                // Background track container
                Rectangle()
                    .fill(BounceTheme.surface)
                
                // 1. Unplayed waveform bars (darker neutral)
                HStack(alignment: .center, spacing: barSpacing) {
                    ForEach(0..<barCount, id: \.self) { index in
                        let amp = CGFloat(amplitudes[index])
                        let barHeight = max(4.0, height * amp)
                        Rectangle()
                            .fill(BounceTheme.waveformUnplayed)
                            .frame(width: barWidth, height: barHeight)
                    }
                }
                .frame(width: width, height: height)
                
                // 2. Played waveform bars (Electric Lime with clip)
                HStack(alignment: .center, spacing: barSpacing) {
                    ForEach(0..<barCount, id: \.self) { index in
                        let amp = CGFloat(amplitudes[index])
                        let barHeight = max(4.0, height * amp)
                        Rectangle()
                            .fill(BounceTheme.waveformPlayed)
                            .frame(width: barWidth, height: barHeight)
                    }
                }
                .frame(width: width, height: height)
                .mask(
                    HStack {
                        Rectangle()
                            .frame(width: max(0, width * CGFloat(activeProgress)))
                        Spacer(minLength: 0)
                    }
                )
                
                // 3. Timestamped Comment Pins
                ForEach(comments) { comment in
                    let commentRatio = CGFloat(min(1.0, max(0.0, comment.timestampSeconds / duration)))
                    let pinX = commentRatio * width
                    
                    VStack(spacing: 2) {
                        Button {
                            BounceTheme.haptic(style: .light)
                            selectedComment = (selectedComment?.id == comment.id) ? nil : comment
                            onCommentTap?(comment)
                        } label: {
                            Circle()
                                .fill(BounceTheme.commentPin)
                                .frame(width: 8, height: 8)
                                .overlay(
                                    Circle()
                                        .stroke(Color.black, lineWidth: 1.5)
                                )
                        }
                        
                        Rectangle()
                            .fill(BounceTheme.commentPin.opacity(0.7))
                            .frame(width: 1.5, height: height - 10)
                    }
                    .position(x: pinX, y: height / 2)
                    .zIndex(2)
                }
                
                // 4. Scrubber Playhead Needle
                Rectangle()
                    .fill(BounceTheme.waveformScrubberPin)
                    .frame(width: 2.5, height: height + 10)
                    .position(x: CGFloat(activeProgress) * width, y: height / 2)
                    .shadow(color: Color.black.opacity(0.8), radius: 2)
                    .zIndex(3)
                
                // 5. Active comment tooltip if selected
                if let comment = selectedComment {
                    let commentRatio = CGFloat(min(1.0, max(0.0, comment.timestampSeconds / duration)))
                    let pinX = min(max(70, commentRatio * width), width - 70)
                    
                    VStack(alignment: .leading, spacing: 3) {
                        HStack {
                            Text(comment.authorName)
                                .font(BounceTheme.mono(10, weight: .bold))
                                .foregroundColor(BounceTheme.commentPin)
                            Spacer()
                            Text(comment.formattedTimestamp)
                                .font(BounceTheme.mono(9))
                                .foregroundColor(BounceTheme.textSecondary)
                        }
                        Text(comment.body)
                            .font(BounceTheme.sans(11))
                            .foregroundColor(BounceTheme.textPrimary)
                            .lineLimit(2)
                    }
                    .padding(8)
                    .frame(width: 150)
                    .background(BounceTheme.surfaceElevated)
                    .overlay(Rectangle().stroke(BounceTheme.commentPin, lineWidth: 1))
                    .position(x: pinX, y: 25)
                    .zIndex(4)
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if !isDragging {
                            isDragging = true
                            BounceTheme.haptic(style: .selection)
                        }
                        let newProgress = min(1.0, max(0.0, Double(value.location.x / width)))
                        dragProgress = newProgress
                        onScrub(newProgress)
                    }
                    .onEnded { _ in
                        isDragging = false
                        BounceTheme.haptic(style: .light)
                        onScrubEnd()
                    }
            )
        }
    }
}
