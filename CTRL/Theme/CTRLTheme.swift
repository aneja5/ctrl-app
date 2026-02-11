import SwiftUI

// MARK: - Color System (Nocturnal Library)

struct CTRLColors {
    // Backgrounds
    static let base = Color(hex: "14110F")                 // Deep warm charcoal
    static let surface1 = Color(hex: "1E1915")             // Elevated surface (cards)
    static let surface2 = Color(hex: "221D18")             // Higher elevation (modals)

    // Border (use sparingly - prefer surface separation)
    static let border = Color(hex: "2A241E")               // Near-invisible

    // Text
    static let textPrimary = Color(hex: "E8E0D8")          // Warm white
    static let textSecondary = Color(hex: "A89F94")        // Muted warm gray
    static let textTertiary = Color(hex: "6F675E")         // Subtle hints

    // Accent - Bronze (use sparingly)
    static let accent = Color(hex: "A68A64")               // Muted bronze
    static let accentHover = Color(hex: "B8965E")          // Hover/pressed
    static let accentGlow = Color(hex: "A68A64").opacity(0.10)  // Subtle glow

    // Semantic
    static let destructive = Color(hex: "8B5A5A")          // Muted rose
    static let success = Color(hex: "6B8B6A")              // Muted sage
    static let warning = Color(hex: "A68A64")              // Use bronze

    // MARK: - Compatibility Aliases

    static let background = base
    static let glassFill = surface1
    static let glassBorder = border
    static let glassStroke = border
    static let glassFillHover = surface2
    static let glassFillActive = surface2
    static let surface = surface1
    static let surfaceLight = surface2
    static let surfaceBorder = border
    static let divider = border
    static let shadow = Color.black.opacity(0.4)
    static let cardBackground = surface1
    static let textMuted = textTertiary
    static let white = Color(hex: "E8E0D8")
    static let accentLight = Color(hex: "A68A64").opacity(0.15)
    static let danger = destructive
}

// MARK: - Hex Color Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)

        let r, g, b: UInt64
        switch hex.count {
        case 6:
            (r, g, b) = (int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (r, g, b) = (0, 0, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: 1
        )
    }
}

// MARK: - Typography System

struct CTRLFonts {
    // Display - Ritual states ONLY (Serif)
    // Used for: "unlocked", "in session" on Home
    static let display = Font.custom("Georgia", size: 44).weight(.regular)

    // Timer - Session time (Monospace)
    static let timer = Font.system(size: 40, weight: .medium, design: .monospaced)

    // H1 - Screen titles (Sans)
    static let h1 = Font.system(size: 28, weight: .semibold, design: .default)

    // H2 - Section headers (Sans)
    static let h2 = Font.system(size: 18, weight: .semibold, design: .default)

    // Title - Card titles (named titleFont to avoid conflict with title() wrapper)
    static let titleFont = Font.system(size: 16, weight: .medium, design: .default)

    // Body - Primary content (named bodyFont to avoid conflict with body() wrapper)
    static let bodyFont = Font.system(size: 16, weight: .regular, design: .default)

    // Body Small - Descriptions (Sans)
    static let bodySmall = Font.system(size: 14, weight: .regular, design: .default)

    // Caption - UPPERCASE labels (named captionFont to avoid conflict with caption() wrapper)
    static let captionFont = Font.system(size: 12, weight: .medium, design: .default)

    // Micro - Smallest text
    static let micro = Font.system(size: 11, weight: .medium, design: .default)

    // MARK: - Compatibility Aliases (function wrappers for call-site compatibility)

    static func largeTitle() -> Font { h1 }
    static func title() -> Font { titleFont }
    static func headline() -> Font { titleFont }
    static func body() -> Font { bodyFont }
    static func caption() -> Font { captionFont }
    static func mono() -> Font { .system(size: 15, weight: .regular, design: .monospaced) }
}

// MARK: - Spacing System (8pt grid)

struct CTRLSpacing {
    static let micro: CGFloat = 4
    static let xs: CGFloat = 8
    static let sm: CGFloat = 12
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
    static let xxl: CGFloat = 48

    static let screenPadding: CGFloat = 20
    static let cardPadding: CGFloat = 20
    static let cardRadius: CGFloat = 20
    static let buttonRadius: CGFloat = 16
    static let buttonHeight: CGFloat = 56
}

// MARK: - Surface Card Component (replaces GlassCard)

struct SurfaceCard<Content: View>: View {
    let padding: CGFloat
    let cornerRadius: CGFloat
    let elevation: Int  // 1 = surface1, 2 = surface2
    @ViewBuilder let content: Content

    init(
        padding: CGFloat = CTRLSpacing.cardPadding,
        cornerRadius: CGFloat = CTRLSpacing.cardRadius,
        elevation: Int = 1,
        @ViewBuilder content: () -> Content
    ) {
        self.padding = padding
        self.cornerRadius = cornerRadius
        self.elevation = elevation
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(elevation == 1 ? CTRLColors.surface1 : CTRLColors.surface2)
            )
    }
}

// MARK: - Legacy GlassCard (alias for migration)

struct GlassCard<Content: View>: View {
    let padding: CGFloat
    let cornerRadius: CGFloat
    @ViewBuilder let content: Content

    init(
        padding: CGFloat = CTRLSpacing.cardPadding,
        cornerRadius: CGFloat = CTRLSpacing.cardRadius,
        @ViewBuilder content: () -> Content
    ) {
        self.padding = padding
        self.cornerRadius = cornerRadius
        self.content = content()
    }

    var body: some View {
        SurfaceCard(padding: padding, cornerRadius: cornerRadius, elevation: 1) {
            content
        }
    }
}

// MARK: - Button Styles

struct CTRLPrimaryButtonStyle: ButtonStyle {
    let isActive: Bool

    init(isActive: Bool = true) {
        self.isActive = isActive
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(CTRLFonts.bodyFont)
            .fontWeight(.medium)
            .foregroundColor(isActive ? CTRLColors.base : CTRLColors.textPrimary)
            .frame(maxWidth: .infinity)
            .frame(height: CTRLSpacing.buttonHeight)
            .background(
                RoundedRectangle(cornerRadius: CTRLSpacing.buttonRadius)
                    .fill(isActive ? CTRLColors.accent : CTRLColors.surface1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: CTRLSpacing.buttonRadius)
                    .stroke(isActive ? Color.clear : CTRLColors.border, lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct CTRLSecondaryButtonStyle: ButtonStyle {
    let accentBorder: Bool

    init(accentBorder: Bool = false) {
        self.accentBorder = accentBorder
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(CTRLFonts.bodyFont)
            .fontWeight(.medium)
            .foregroundColor(CTRLColors.textPrimary)
            .frame(maxWidth: .infinity)
            .frame(height: CTRLSpacing.buttonHeight)
            .background(
                RoundedRectangle(cornerRadius: CTRLSpacing.buttonRadius)
                    .fill(CTRLColors.surface1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: CTRLSpacing.buttonRadius)
                    .stroke(accentBorder ? CTRLColors.accent : CTRLColors.border, lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

// Legacy alias - CTRLGlassButtonStyle maps to CTRLSecondaryButtonStyle
struct CTRLGlassButtonStyle: ButtonStyle {
    var accentBorder: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        CTRLSecondaryButtonStyle(accentBorder: accentBorder)
            .makeBody(configuration: configuration)
    }
}

struct CTRLGhostButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(CTRLFonts.bodySmall)
            .foregroundColor(CTRLColors.textSecondary)
            .opacity(configuration.isPressed ? 0.6 : 1.0)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Divider

struct CTRLDivider: View {
    var body: some View {
        Rectangle()
            .fill(CTRLColors.border)
            .frame(height: 1)
    }
}

// MARK: - Section Header (UPPERCASE, tracked)

struct CTRLSectionHeader: View {
    let title: String

    var body: some View {
        Text(title.uppercased())
            .font(CTRLFonts.captionFont)
            .tracking(2)
            .foregroundColor(CTRLColors.textTertiary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, CTRLSpacing.micro)
            .padding(.bottom, CTRLSpacing.sm)
    }
}

// MARK: - Breathing Dot (for active session)

struct BreathingDot: View {
    @State private var scale: CGFloat = 1.0

    var body: some View {
        Circle()
            .fill(CTRLColors.accent)
            .frame(width: 8, height: 8)
            .scaleEffect(scale)
            .onAppear {
                withAnimation(
                    .easeInOut(duration: 2)
                    .repeatForever(autoreverses: true)
                ) {
                    scale = 1.4
                }
            }
    }
}

// MARK: - Bronze Glow (for active session)

struct BronzeGlow: View {
    var body: some View {
        Circle()
            .fill(
                RadialGradient(
                    gradient: Gradient(colors: [
                        CTRLColors.accent.opacity(0.08),
                        CTRLColors.accent.opacity(0.03),
                        Color.clear
                    ]),
                    center: .center,
                    startRadius: 0,
                    endRadius: 180
                )
            )
            .frame(width: 360, height: 360)
            .blur(radius: 40)
    }
}

// MARK: - Legacy AccentGlow (alias for migration)

struct AccentGlow: View {
    let radius: CGFloat

    init(radius: CGFloat = 200) {
        self.radius = radius
    }

    var body: some View {
        BronzeGlow()
    }
}
