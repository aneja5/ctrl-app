import SwiftUI

struct NewDeviceWelcomeView: View {
    @EnvironmentObject var appState: AppState
    var onContinue: () -> Void

    /// Whether any restored mode has app selections (encrypted sync succeeded)
    private var hasRestoredApps: Bool {
        appState.modes.contains { $0.appCount > 0 }
    }

    var body: some View {
        ZStack {
            CTRLColors.base.ignoresSafeArea()

            VStack(spacing: 0) {
                // Wordmark
                Text("ctrl")
                    .font(CTRLFonts.ritualWhisper)
                    .foregroundColor(CTRLColors.textTertiary)
                    .tracking(3)
                    .padding(.top, CTRLSpacing.xl)

                Spacer()

                // Welcome message
                VStack(spacing: CTRLSpacing.sm) {
                    Text("welcome back")
                        .font(.custom("Georgia", size: 28))
                        .foregroundColor(CTRLColors.textPrimary)

                    Text("we restored your data")
                        .font(CTRLFonts.bodySmall)
                        .foregroundColor(CTRLColors.textSecondary)
                }

                Spacer()
                    .frame(height: CTRLSpacing.xxl)

                // Restored data summary
                SurfaceCard(padding: CTRLSpacing.cardPadding, cornerRadius: CTRLSpacing.cardRadius) {
                    VStack(alignment: .leading, spacing: CTRLSpacing.md) {
                        // Modes
                        if !appState.modes.isEmpty {
                            VStack(alignment: .leading, spacing: CTRLSpacing.xs) {
                                Text("modes")
                                    .font(CTRLFonts.captionFont)
                                    .tracking(2)
                                    .foregroundColor(CTRLColors.textTertiary)

                                ForEach(appState.modes) { mode in
                                    HStack {
                                        Text(mode.name.lowercased())
                                            .font(CTRLFonts.bodyFont)
                                            .foregroundColor(CTRLColors.textPrimary)

                                        Spacer()

                                        if mode.appCount > 0 {
                                            Text(mode.appSelection.displayCount)
                                                .font(CTRLFonts.bodySmall)
                                                .foregroundColor(CTRLColors.textTertiary)
                                        }
                                    }
                                }
                            }

                            CTRLDivider()
                        }

                        // Focus history summary
                        if !appState.focusHistory.isEmpty {
                            VStack(alignment: .leading, spacing: CTRLSpacing.xs) {
                                Text("focus history")
                                    .font(CTRLFonts.captionFont)
                                    .tracking(2)
                                    .foregroundColor(CTRLColors.textTertiary)

                                let totalSeconds = appState.focusHistory.reduce(0) { $0 + $1.totalSeconds }
                                Text("\(AppState.formatTime(totalSeconds)) total")
                                    .font(CTRLFonts.bodyFont)
                                    .foregroundColor(CTRLColors.textPrimary)

                                Text("\(appState.focusHistory.count) days tracked")
                                    .font(CTRLFonts.bodySmall)
                                    .foregroundColor(CTRLColors.textSecondary)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, CTRLSpacing.screenPadding)

                Spacer()
                    .frame(height: CTRLSpacing.lg)

                // Privacy note — conditional based on whether encrypted sync worked
                if hasRestoredApps {
                    Text("your app selections were securely\ntransferred using end-to-end encryption.")
                        .font(CTRLFonts.bodySmall)
                        .foregroundColor(CTRLColors.textTertiary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, CTRLSpacing.screenPadding)
                } else {
                    Text("app selections stay on your original phone\nfor privacy. you'll pick apps again on\nyour first lock-in.")
                        .font(CTRLFonts.bodySmall)
                        .foregroundColor(CTRLColors.textTertiary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, CTRLSpacing.screenPadding)
                }

                Spacer()

                // Continue button
                Button(action: {
                    appState.isReturningFromNewDevice = false
                    onContinue()
                }) {
                    Text("continue")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(CTRLColors.base)
                        .frame(maxWidth: .infinity)
                        .frame(height: CTRLSpacing.buttonHeight)
                        .background(
                            RoundedRectangle(cornerRadius: CTRLSpacing.buttonRadius)
                                .fill(CTRLColors.accent)
                        )
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.horizontal, CTRLSpacing.screenPadding)
                .padding(.bottom, CTRLSpacing.xxl)
            }
        }
    }
}
