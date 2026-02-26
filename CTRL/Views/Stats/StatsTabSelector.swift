import SwiftUI

// MARK: - Stats Tab Enum

enum StatsTab: String, CaseIterable {
    case week
    case month
    case lifetime

    var isEnabled: Bool {
        switch self {
        case .week: return featureEnabled(.weeklyStats)
        case .month: return featureEnabled(.monthlyStats)
        case .lifetime: return featureEnabled(.lifetimeStats)
        }
    }
}

// MARK: - Tab Selector View

struct StatsTabSelector: View {
    @Binding var selected: StatsTab

    var body: some View {
        HStack(spacing: 0) {
            ForEach(StatsTab.allCases.filter(\.isEnabled), id: \.self) { tab in
                Button(action: {
                    withAnimation(.easeOut(duration: 0.2)) {
                        selected = tab
                    }
                }) {
                    Text(tab.rawValue)
                        .font(CTRLFonts.captionFont)
                        .tracking(1.5)
                        .foregroundColor(selected == tab ? CTRLColors.textPrimary : Color.white.opacity(0.4))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, CTRLSpacing.sm)
                        .background(
                            RoundedRectangle(cornerRadius: CTRLSpacing.buttonRadius - 4)
                                .fill(selected == tab ? CTRLColors.accent.opacity(0.15) : Color.clear)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: CTRLSpacing.buttonRadius)
                .fill(CTRLColors.surface1)
        )
    }
}
