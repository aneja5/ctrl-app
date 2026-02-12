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
                    .fill(isSelected ? CTRLColors.accent.opacity(0.7) : Color.clear)
                    .frame(width: 3)
                    .cornerRadius(1.5)

                // Content
                Text(mode.name.lowercased())
                    .font(CTRLFonts.bodyFont)
                    .fontWeight(isSelected ? .medium : .regular)
                    .foregroundColor(isSelected ? CTRLColors.textPrimary : CTRLColors.textSecondary)
                    .padding(.leading, CTRLSpacing.md)

                Spacer()

                // App count
                Text("\(mode.appCount) \(mode.appCount == 1 ? "APP" : "APPS")")
                    .font(CTRLFonts.captionFont)
                    .tracking(1)
                    .foregroundColor(CTRLColors.textTertiary)
                    .padding(.trailing, CTRLSpacing.md)
            }
            .frame(height: 56)
            .background(
                RoundedRectangle(cornerRadius: CTRLSpacing.buttonRadius)
                    .fill(isSelected ? CTRLColors.surface2 : CTRLColors.surface2.opacity(0.5))
            )
        }
        .buttonStyle(PlainButtonStyle())
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
