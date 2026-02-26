import SwiftUI

struct ScheduleModePickerView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedModeId: UUID?

    var onEditMode: ((BlockingMode) -> Void)? = nil
    var onCreateMode: (() -> Void)? = nil

    var body: some View {
        ZStack {
            CTRLColors.surface1.ignoresSafeArea()

            VStack(alignment: .leading, spacing: CTRLSpacing.lg) {
                // Header
                HStack {
                    Text("select mode")
                        .font(CTRLFonts.h2)
                        .foregroundColor(CTRLColors.textPrimary)

                    Spacer()

                    Button(action: { dismiss() }) {
                        Text("done")
                            .font(CTRLFonts.bodyFont)
                            .fontWeight(.medium)
                            .foregroundColor(CTRLColors.accent)
                    }
                }
                .padding(.horizontal, CTRLSpacing.screenPadding)
                .padding(.top, CTRLSpacing.md)

                // Mode List
                VStack(spacing: CTRLSpacing.sm) {
                    ForEach(appState.modes) { mode in
                        let isSelected = selectedModeId == mode.id

                        ModeCard(
                            mode: mode,
                            isSelected: isSelected,
                            isLocked: false,
                            selectionDisabled: false,
                            onTap: {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                selectedModeId = mode.id
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                    dismiss()
                                }
                            },
                            onEdit: onEditMode != nil ? {
                                dismiss()
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    onEditMode?(mode)
                                }
                            } : nil
                        )
                    }

                    // Create mode row (only when callback provided)
                    if let onCreateMode = onCreateMode,
                       appState.modes.count < AppConstants.maxModes {
                        Button(action: {
                            dismiss()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                onCreateMode()
                            }
                        }) {
                            HStack(spacing: CTRLSpacing.sm) {
                                Image(systemName: "plus")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(CTRLColors.textTertiary)

                                Text("create mode")
                                    .font(CTRLFonts.bodyFont)
                                    .foregroundColor(CTRLColors.textTertiary)

                                Spacer()
                            }
                            .padding(.horizontal, CTRLSpacing.md)
                            .frame(height: 56)
                            .background(
                                RoundedRectangle(cornerRadius: CTRLSpacing.buttonRadius)
                                    .fill(CTRLColors.surface2.opacity(0.3))
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, CTRLSpacing.screenPadding)

                Spacer()
            }
        }
    }
}
