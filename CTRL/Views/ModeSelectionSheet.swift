import SwiftUI

struct ModeSelectionSheet: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var blockingManager: BlockingManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            CTRLColors.surface1.ignoresSafeArea()

            VStack(alignment: .leading, spacing: CTRLSpacing.lg) {
                // Header
                Text("select mode")
                    .font(CTRLFonts.h2)
                    .foregroundColor(CTRLColors.textPrimary)
                    .padding(.horizontal, CTRLSpacing.screenPadding)
                    .padding(.top, CTRLSpacing.md)

                // Mode List
                VStack(spacing: CTRLSpacing.sm) {
                    ForEach(appState.modes) { mode in
                        ModeCard(
                            mode: mode,
                            isSelected: appState.activeModeId == mode.id,
                            onTap: {
                                selectMode(mode)
                            }
                        )
                    }
                }
                .padding(.horizontal, CTRLSpacing.screenPadding)

                Spacer()
            }
        }
    }

    private func selectMode(_ mode: BlockingMode) {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()

        appState.setActiveMode(id: mode.id)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            dismiss()
        }
    }
}

// MARK: - Mode Card

struct ModeCard: View {
    let mode: BlockingMode
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 0) {
                // Bronze indicator bar (only when selected)
                Rectangle()
                    .fill(isSelected ? CTRLColors.accent : Color.clear)
                    .frame(width: 3)
                    .cornerRadius(1.5)

                // Content
                VStack(alignment: .leading, spacing: CTRLSpacing.xs) {
                    Text(mode.name.lowercased())
                        .font(CTRLFonts.bodyFont)
                        .fontWeight(isSelected ? .medium : .regular)
                        .foregroundColor(isSelected ? CTRLColors.textPrimary : CTRLColors.textSecondary)

                    Text(modeDescription(for: mode.name))
                        .font(CTRLFonts.bodySmall)
                        .foregroundColor(CTRLColors.textTertiary)
                        .lineLimit(1)
                }
                .padding(.leading, CTRLSpacing.md)

                Spacer()

                // App count
                Text("\(mode.appCount) APPS")
                    .font(CTRLFonts.captionFont)
                    .tracking(1)
                    .foregroundColor(CTRLColors.textTertiary)
                    .padding(.trailing, CTRLSpacing.md)
            }
            .frame(height: 72)
            .background(
                RoundedRectangle(cornerRadius: CTRLSpacing.buttonRadius)
                    .fill(isSelected ? CTRLColors.surface2 : CTRLColors.surface2.opacity(0.5))
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func modeDescription(for name: String) -> String {
        switch name.lowercased() {
        case "work":
            return "deep focus for tasks"
        case "study":
            return "learning and research"
        case "sleep":
            return "wind down before rest"
        case "focus":
            return "general focus session"
        default:
            return "custom focus mode"
        }
    }
}

// MARK: - Preview

struct ModeSelectionSheet_Previews: PreviewProvider {
    static var previews: some View {
        ModeSelectionSheet()
            .environmentObject(AppState.shared)
            .environmentObject(BlockingManager())
    }
}
