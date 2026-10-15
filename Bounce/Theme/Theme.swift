import SwiftUI

// MARK: - Brutalist Dark Mode Design System
// Aesthetic inspired by [untitled], Samply, and hardware audio samplers.
// Monochromatic base with ultra-high-contrast typography and electric neon accents.

public enum BounceTheme {
    // MARK: - Colors
    public static let background = Color(hex: "0A0A0A")
    public static let surface = Color(hex: "141414")
    public static let surfaceElevated = Color(hex: "1F1F1F")
    public static let surfaceBorder = Color(hex: "2B2B2B")
    
    public static let textPrimary = Color(hex: "FFFFFF")
    public static let textSecondary = Color(hex: "8A8A8E")
    public static let textMuted = Color(hex: "4D4D52")
    
    // Electric audio green (DAW / Sampler level meter aesthetic)
    public static let accent = Color(hex: "CCFF00")
    public static let accentMuted = Color(hex: "88AA00")
    public static let alert = Color(hex: "FF3B30")
    
    // Waveform colors
    public static let waveformPlayed = Color(hex: "CCFF00")
    public static let waveformUnplayed = Color(hex: "333336")
    public static let waveformScrubberPin = Color(hex: "FFFFFF")
    public static let commentPin = Color(hex: "00F0FF")
    
    // MARK: - Typography & Fonts
    public static func mono(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
    
    public static func sans(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .default)
    }
    
    // MARK: - Haptic Feedback
    public static func haptic(style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred()
    }
    
    public static func notificationHaptic(type: UINotificationFeedbackGenerator.FeedbackType) {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(type)
    }
}

// MARK: - Color Hex Initializer
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Brutalist Button Style
struct BrutalistButtonStyle: ButtonStyle {
    var isPrimary: Bool = true
    var isDestructive: Bool = false
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(BounceTheme.mono(13, weight: .bold))
            .tracking(1.0)
            .textCase(.uppercase)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                backgroundColor(isPressed: configuration.isPressed)
            )
            .foregroundColor(foregroundColor(isPressed: configuration.isPressed))
            .overlay(
                Rectangle()
                    .stroke(borderColor, lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
    
    private func backgroundColor(isPressed: Bool) -> Color {
        if isDestructive {
            return isPressed ? BounceTheme.alert.opacity(0.8) : BounceTheme.alert
        }
        if isPrimary {
            return isPressed ? BounceTheme.accent.opacity(0.85) : BounceTheme.accent
        }
        return isPressed ? BounceTheme.surfaceElevated : BounceTheme.surface
    }
    
    private func foregroundColor(isPressed: Bool) -> Color {
        if isDestructive || isPrimary {
            return Color.black
        }
        return BounceTheme.textPrimary
    }
    
    private var borderColor: Color {
        if isDestructive { return BounceTheme.alert }
        if isPrimary { return BounceTheme.accent }
        return BounceTheme.surfaceBorder
    }
}

// MARK: - Brutalist Card Modifier
struct BrutalistCardModifier: ViewModifier {
    var backgroundColor: Color = BounceTheme.surface
    var borderColor: Color = BounceTheme.surfaceBorder
    var cornerRadius: CGFloat = 0 // Brutalist sharp edges by default
    
    func makeBody(content: Content) -> some View {
        content
            .background(backgroundColor)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(borderColor, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }
}

extension View {
    func brutalistCard(
        background: Color = BounceTheme.surface,
        border: Color = BounceTheme.surfaceBorder,
        radius: CGFloat = 0
    ) -> some View {
        self.modifier(BrutalistCardModifier(backgroundColor: background, borderColor: border, cornerRadius: radius))
    }
}
