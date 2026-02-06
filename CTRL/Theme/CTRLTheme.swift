import SwiftUI

// MARK: - Colors

struct CTRLColors {
    static let background = Color(red: 0.051, green: 0.051, blue: 0.051)       // #0D0D0D
    static let cardBackground = Color(red: 0.102, green: 0.102, blue: 0.102)   // #1A1A1A
    static let accent = Color(red: 0.0, green: 0.831, blue: 0.667)             // #00D4AA
    static let accentDim = Color(red: 0.0, green: 0.639, blue: 0.522)          // #00A385
    static let textPrimary = Color.white                                        // #FFFFFF
    static let textSecondary = Color(red: 0.557, green: 0.557, blue: 0.576)    // #8E8E93
    static let textMuted = Color(red: 0.282, green: 0.282, blue: 0.290)        // #48484A
    static let success = Color(red: 0.188, green: 0.820, blue: 0.345)          // #30D158
    static let warning = Color(red: 1.0, green: 0.624, blue: 0.039)            // #FF9F0A
    static let danger = Color(red: 1.0, green: 0.271, blue: 0.227)             // #FF453A
}

// MARK: - Fonts

struct CTRLFonts {
    static func largeTitle() -> Font {
        .system(size: 34, weight: .bold, design: .rounded)
    }

    static func title() -> Font {
        .system(size: 24, weight: .semibold, design: .rounded)
    }

    static func headline() -> Font {
        .system(size: 17, weight: .semibold)
    }

    static func body() -> Font {
        .system(size: 17, weight: .regular)
    }

    static func caption() -> Font {
        .system(size: 13, weight: .regular)
    }

    static func mono() -> Font {
        .system(size: 15, weight: .regular, design: .monospaced)
    }
}

// MARK: - Card Style Modifier

struct CTRLCardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(CTRLColors.cardBackground)
            .cornerRadius(16)
    }
}

// MARK: - View Extension

extension View {
    func ctrlCard() -> some View {
        modifier(CTRLCardStyle())
    }
}
