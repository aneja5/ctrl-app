import SwiftUI

struct CountdownUnlockView: View {
    let onComplete: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase

    @State private var remainingSeconds = 60
    @State private var countdownTimer: Timer? = nil

    var body: some View {
        ZStack {
            CTRLColors.base.ignoresSafeArea()

            VStack(spacing: CTRLSpacing.xl) {
                Spacer()

                Text("ending session")
                    .font(CTRLFonts.display)
                    .tracking(2)
                    .foregroundColor(CTRLColors.textPrimary)

                Text(formatCountdown())
                    .font(.system(size: 56, weight: .medium, design: .monospaced))
                    .foregroundColor(CTRLColors.accent)
                    .monospacedDigit()
                    .contentTransition(.numericText())

                Text("keep this screen open")
                    .font(CTRLFonts.bodySmall)
                    .foregroundColor(CTRLColors.textTertiary)

                Spacer()

                Button(action: cancelCountdown) {
                    Text("cancel")
                }
                .buttonStyle(CTRLSecondaryButtonStyle())
                .padding(.horizontal, CTRLSpacing.screenPadding + 20)
                .padding(.bottom, CTRLSpacing.xl)
            }
        }
        .onAppear {
            startCountdown()
        }
        .onDisappear {
            countdownTimer?.invalidate()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase != .active {
                cancelCountdown()
            }
        }
    }

    private func formatCountdown() -> String {
        let minutes = remainingSeconds / 60
        let seconds = remainingSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private func startCountdown() {
        remainingSeconds = 60
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if remainingSeconds > 0 {
                withAnimation(.default) {
                    remainingSeconds -= 1
                }
            }
            if remainingSeconds == 0 {
                countdownTimer?.invalidate()
                UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                onComplete()
                dismiss()
            }
        }
    }

    private func cancelCountdown() {
        countdownTimer?.invalidate()
        countdownTimer = nil
        dismiss()
    }
}
