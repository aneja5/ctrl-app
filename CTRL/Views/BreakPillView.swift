import SwiftUI

struct BreakPillView: View {
    @EnvironmentObject var appState: AppState
    @Binding var isExpanded: Bool
    let onStartBreak: (BreakOption) -> Void
    let onEndBreak: () -> Void

    var body: some View {
        if appState.isOnBreak {
            // State C: Break active — countdown
            breakActiveView
        } else if !appState.earnedBreaks.isEmpty {
            if isExpanded {
                // State B: Expanded — show break options
                breakOptionsView
            } else {
                // State A: Collapsed pill — "break earned"
                breakEarnedPill
            }
        }
    }

    // MARK: - State A: Collapsed pill

    private var breakEarnedPill: some View {
        Button(action: { withAnimation(.easeOut(duration: 0.2)) { isExpanded = true } }) {
            HStack(spacing: CTRLSpacing.xs) {
                Circle()
                    .fill(CTRLColors.accent)
                    .frame(width: 6, height: 6)

                Text("break earned")
                    .font(CTRLFonts.micro)
                    .tracking(1)
                    .foregroundColor(CTRLColors.accent)
            }
            .padding(.horizontal, CTRLSpacing.sm)
            .padding(.vertical, CTRLSpacing.xs)
            .background(
                Capsule()
                    .fill(CTRLColors.accent.opacity(0.1))
            )
            .overlay(
                Capsule()
                    .stroke(CTRLColors.accent.opacity(0.2), lineWidth: 0.5)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .transition(.opacity.combined(with: .scale(scale: 0.9)))
    }

    // MARK: - State B: Expanded options

    private var breakOptionsView: some View {
        VStack(spacing: CTRLSpacing.xs) {
            ForEach(appState.earnedBreaks) { breakOption in
                Button(action: { onStartBreak(breakOption) }) {
                    Text("take \(breakOption.durationMinutes) min break")
                        .font(CTRLFonts.bodySmall)
                        .foregroundColor(CTRLColors.accent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, CTRLSpacing.sm)
                        .background(
                            RoundedRectangle(cornerRadius: CTRLSpacing.buttonRadius)
                                .fill(CTRLColors.accent.opacity(0.1))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: CTRLSpacing.buttonRadius)
                                .stroke(CTRLColors.accent.opacity(0.2), lineWidth: 0.5)
                        )
                }
                .buttonStyle(PlainButtonStyle())
            }

            Button(action: { withAnimation(.easeOut(duration: 0.2)) { isExpanded = false } }) {
                Text("not now")
                    .font(CTRLFonts.micro)
                    .foregroundColor(CTRLColors.textTertiary)
            }
            .padding(.top, CTRLSpacing.micro)
        }
        .padding(.horizontal, CTRLSpacing.screenPadding + 20)
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    // MARK: - State C: Break active

    private var breakActiveView: some View {
        VStack(spacing: CTRLSpacing.xs) {
            HStack(spacing: CTRLSpacing.xs) {
                Circle()
                    .fill(CTRLColors.accent)
                    .frame(width: 6, height: 6)

                Text("break \(formatBreakTime())")
                    .font(CTRLFonts.micro)
                    .tracking(1)
                    .monospacedDigit()
                    .foregroundColor(CTRLColors.accent)
            }
            .padding(.horizontal, CTRLSpacing.sm)
            .padding(.vertical, CTRLSpacing.xs)
            .background(
                Capsule()
                    .fill(CTRLColors.accent.opacity(0.15))
            )
            .overlay(
                Capsule()
                    .stroke(CTRLColors.accent.opacity(0.3), lineWidth: 0.5)
            )

            Button(action: onEndBreak) {
                Text("end break")
                    .font(CTRLFonts.micro)
                    .foregroundColor(CTRLColors.textTertiary)
            }
        }
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
    }

    private func formatBreakTime() -> String {
        let mins = appState.breakSecondsRemaining / 60
        let secs = appState.breakSecondsRemaining % 60
        return String(format: "%d:%02d", mins, secs)
    }
}
