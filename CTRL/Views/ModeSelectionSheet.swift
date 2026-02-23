import SwiftUI

struct ModeSelectionSheet: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var blockingManager: BlockingManager
    @Environment(\.dismiss) private var dismiss

    /// The mode ID currently in use during a session (nil if not in session).
    /// This mode can't be selected or edited — only viewed.
    var lockedModeId: UUID? = nil
    var onEditMode: ((BlockingMode) -> Void)? = nil
    var onCreateMode: (() -> Void)? = nil

    private var isInSession: Bool { lockedModeId != nil }

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
                        let isThisModeLocked = mode.id == lockedModeId
                        ModeCard(
                            mode: mode,
                            isSelected: appState.activeModeId == mode.id,
                            isLocked: isThisModeLocked,
                            selectionDisabled: isInSession,
                            onTap: {
                                if !isInSession {
                                    selectMode(mode)
                                }
                            },
                            onEdit: {
                                dismiss()
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    onEditMode?(mode)
                                }
                            }
                        )
                    }

                    // Create mode row
                    if appState.modes.count < AppState.maxModes {
                        Button(action: {
                            dismiss()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                onCreateMode?()
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
    let isLocked: Bool          // This specific mode is in use (view-only)
    var selectionDisabled: Bool = false  // All mode selection is disabled (in session)
    let onTap: () -> Void
    var onEdit: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 0) {
            // Mode info (tappable for selection)
            Button(action: onTap) {
                HStack(spacing: CTRLSpacing.md) {
                    // Mode name
                    Text(mode.name.lowercased())
                        .font(CTRLFonts.bodyFont)
                        .fontWeight(isSelected ? .medium : .regular)
                        .foregroundColor(isSelected ? CTRLColors.textPrimary : CTRLColors.textSecondary)

                    Spacer()

                    // Warning icon for modes needing re-selection
                    if mode.needsReselection {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 11))
                            .foregroundColor(.orange.opacity(0.8))
                    }

                    // App count
                    Text(mode.appSelection.displayCount)
                        .font(CTRLFonts.captionFont)
                        .tracking(1)
                        .foregroundColor(CTRLColors.textTertiary)
                }
                .padding(.leading, CTRLSpacing.md)
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(selectionDisabled)

            // Edit/view icon
            if let onEdit = onEdit {
                Button(action: onEdit) {
                    Image(systemName: isLocked ? "eye" : "pencil")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(CTRLColors.textTertiary)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .frame(height: 56)
        .padding(.trailing, CTRLSpacing.xs)
        .background(
            RoundedRectangle(cornerRadius: CTRLSpacing.buttonRadius)
                .fill(isSelected ? CTRLColors.accent.opacity(0.1) : CTRLColors.surface2.opacity(0.5))
        )
        .overlay(
            RoundedRectangle(cornerRadius: CTRLSpacing.buttonRadius)
                .stroke(isSelected ? CTRLColors.accent.opacity(0.2) : Color.clear, lineWidth: 1)
        )
    }
}
