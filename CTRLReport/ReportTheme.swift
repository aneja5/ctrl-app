import SwiftUI

// MARK: - Report Colors
// Duplicated from CTRLTheme.swift since extensions run in a separate process
// and cannot import the main app module.

enum ReportColors {
    // Backgrounds
    static let base = Color(red: 0.078, green: 0.067, blue: 0.059)       // #14110F
    static let surface1 = Color(red: 0.118, green: 0.098, blue: 0.082)   // #1E1915
    static let surface2 = Color(red: 0.133, green: 0.114, blue: 0.094)   // #221D18

    // Text
    static let textPrimary = Color(red: 0.91, green: 0.88, blue: 0.85)   // #E8E0D8
    static let textSecondary = Color(red: 0.66, green: 0.62, blue: 0.58) // #A89F94
    static let textTertiary = Color(red: 0.48, green: 0.45, blue: 0.42)  // #7A726A

    // Accent
    static let accent = Color(red: 0.65, green: 0.54, blue: 0.39)        // #A68A64

    // Border
    static let border = Color(red: 0.165, green: 0.141, blue: 0.118)     // #2A241E
}

// MARK: - Report Fonts

enum ReportFonts {
    static let sectionHeader = Font.system(size: 12, weight: .medium)
    static let statValue = Font.system(size: 28, weight: .light)
    static let statLabel = Font.system(size: 12, weight: .medium)
    static let appName = Font.system(size: 14, weight: .regular)
    static let appDuration = Font.system(size: 14, weight: .medium, design: .monospaced)
    static let emptyState = Font.system(size: 13, weight: .regular)
    static let micro = Font.system(size: 11, weight: .medium)
}

// MARK: - Report Spacing

enum ReportSpacing {
    static let xs: CGFloat = 8
    static let sm: CGFloat = 12
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let cardPadding: CGFloat = 20
    static let cardRadius: CGFloat = 20
    static let buttonRadius: CGFloat = 16
}
