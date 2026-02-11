import SwiftUI

struct HomeView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var nfcManager: NFCManager
    @EnvironmentObject var blockingManager: BlockingManager

    @State private var showWrongTokenAlert = false
    @State private var currentTime = Date()
    @State private var showModeSheet = false
    @State private var showActivity = false
    @State private var showSettings = false

    private var isInSession: Bool {
        blockingManager.isBlocking
    }

    var body: some View {
        ZStack {
            // Background — warm charcoal
            CTRLColors.base.ignoresSafeArea()

            // Bronze glow when in session
            if isInSession {
                BronzeGlow()
                    .offset(y: -80)
                    .opacity(0.6)
                    .transition(.opacity)
            }

            VStack(spacing: 0) {
                Spacer()

                // Ritual State Display
                stateDisplay

                Spacer()

                // Today Stats (only when unlocked)
                if !isInSession {
                    todayStats
                        .padding(.bottom, CTRLSpacing.lg)
                }

                // Primary CTA
                primaryAction
                    .padding(.horizontal, CTRLSpacing.screenPadding * 2)

                // Mode Selector Pill
                modeSelector
                    .padding(.top, CTRLSpacing.md)

                Spacer()
                    .frame(height: 60)

                // Floating Dock
                floatingDock
                    .padding(.horizontal, CTRLSpacing.screenPadding)
                    .padding(.bottom, CTRLSpacing.md)
            }
        }
        .alert("Wrong Token", isPresented: $showWrongTokenAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("This token doesn't match your paired token. Use the same token you set up during onboarding.")
        }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            if isInSession {
                currentTime = Date()
            }
        }
        .task {
            let authorized = await blockingManager.requestAuthorization()
            appState.isAuthorized = authorized
        }
        .sheet(isPresented: $showModeSheet) {
            ModeSelectionSheet()
                .environmentObject(appState)
                .environmentObject(blockingManager)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
                .presentationBackground(CTRLColors.surface1)
        }
        .sheet(isPresented: $showActivity) {
            ActivityView()
                .environmentObject(appState)
                .presentationBackground(CTRLColors.base)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .environmentObject(appState)
                .environmentObject(blockingManager)
                .presentationBackground(CTRLColors.base)
        }
    }

    // MARK: - Ritual State Display

    private var stateDisplay: some View {
        VStack(spacing: CTRLSpacing.md) {
            if isInSession {
                // In Session — serif ritual state
                BreathingDot()
                    .padding(.bottom, CTRLSpacing.xs)

                Text("in session")
                    .font(CTRLFonts.display)
                    .tracking(2)
                    .foregroundColor(CTRLColors.accent)

                Text(formatSessionTime())
                    .font(CTRLFonts.timer)
                    .foregroundColor(CTRLColors.textPrimary)
                    .monospacedDigit()

                Text(appState.activeMode?.name.lowercased() ?? "focus")
                    .font(CTRLFonts.captionFont)
                    .tracking(2)
                    .foregroundColor(CTRLColors.textTertiary)

            } else {
                // Unlocked — serif ritual state
                Text("unlocked")
                    .font(CTRLFonts.display)
                    .tracking(2)
                    .foregroundColor(CTRLColors.textPrimary)

                Text(scopeDescription)
                    .font(CTRLFonts.captionFont)
                    .tracking(1)
                    .foregroundColor(CTRLColors.textTertiary)
                    .padding(.top, CTRLSpacing.micro)
            }
        }
        .animation(.easeOut(duration: 0.3), value: isInSession)
    }

    private var scopeDescription: String {
        let count = appState.activeMode?.appCount ?? 0
        return "\(count) app\(count == 1 ? "" : "s") in scope"
    }

    // MARK: - Today Stats

    private var todayStats: some View {
        HStack(spacing: CTRLSpacing.lg) {
            VStack(spacing: 4) {
                Text(formatTodayTime())
                    .font(CTRLFonts.bodyFont)
                    .foregroundColor(CTRLColors.textSecondary)
                    .monospacedDigit()

                Text("today")
                    .font(CTRLFonts.micro)
                    .foregroundColor(CTRLColors.textTertiary)
            }
        }
    }

    // MARK: - Primary Action

    private var primaryAction: some View {
        Group {
            if isInSession {
                Button(action: triggerNFCScan) {
                    Text("End Session")
                }
                .buttonStyle(CTRLSecondaryButtonStyle(accentBorder: true))
            } else {
                Button(action: triggerNFCScan) {
                    Text("Lock In")
                }
                .buttonStyle(CTRLPrimaryButtonStyle(isActive: true))
            }
        }
        .disabled(!nfcManager.isAvailable || nfcManager.isScanning)
    }

    // MARK: - Mode Selector Pill

    private var modeSelector: some View {
        Button(action: {
            if !isInSession {
                showModeSheet = true
            }
        }) {
            HStack(spacing: CTRLSpacing.xs) {
                Text(appState.activeMode?.name.lowercased() ?? "select mode")
                    .font(CTRLFonts.captionFont)
                    .foregroundColor(CTRLColors.textSecondary)

                if !isInSession {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(CTRLColors.textTertiary)
                }
            }
            .padding(.horizontal, CTRLSpacing.md)
            .padding(.vertical, CTRLSpacing.xs)
            .background(
                Capsule()
                    .fill(CTRLColors.surface1)
            )
        }
        .buttonStyle(CTRLGhostButtonStyle())
        .disabled(isInSession)
        .opacity(isInSession ? 0.3 : 1.0)
    }

    // MARK: - Floating Dock

    private var floatingDock: some View {
        SurfaceCard(padding: CTRLSpacing.md, cornerRadius: 28, elevation: 1) {
            HStack(spacing: CTRLSpacing.md) {
                // Activity Button
                Button(action: { showActivity = true }) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(CTRLColors.textTertiary)
                        .frame(width: 32, height: 32)
                }

                Spacer()

                // Dock Status
                HStack(spacing: CTRLSpacing.xs) {
                    Circle()
                        .fill(isInSession ? CTRLColors.accent : CTRLColors.textTertiary)
                        .frame(width: 6, height: 6)

                    if isInSession {
                        Text(formatSessionTime())
                            .font(CTRLFonts.captionFont)
                            .foregroundColor(CTRLColors.textPrimary)
                            .monospacedDigit()

                        Text("session")
                            .font(CTRLFonts.micro)
                            .foregroundColor(CTRLColors.textTertiary)
                    } else {
                        Text(formatTodayTime())
                            .font(CTRLFonts.captionFont)
                            .foregroundColor(CTRLColors.textSecondary)
                            .monospacedDigit()

                        Text("today")
                            .font(CTRLFonts.micro)
                            .foregroundColor(CTRLColors.textTertiary)
                    }
                }

                Spacer()

                // Settings Button
                Button(action: { showSettings = true }) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(CTRLColors.textTertiary)
                        .frame(width: 32, height: 32)
                }
            }
        }
    }

    // MARK: - Helpers

    private func formatSessionTime() -> String {
        // Use currentTime to force SwiftUI refresh
        let _ = currentTime
        let seconds = Int(appState.currentSessionSeconds)
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let secs = seconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        } else {
            return String(format: "%d:%02d", minutes, secs)
        }
    }

    private func formatTodayTime() -> String {
        let seconds = Int(appState.todayFocusSeconds)
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60

        if hours > 0 {
            return String(format: "%dh %dm", hours, minutes)
        } else if minutes > 0 {
            return String(format: "%dm", minutes)
        } else {
            return "0m"
        }
    }

    // MARK: - Actions

    private func triggerNFCScan() {
        let feedback = UIImpactFeedbackGenerator(style: isInSession ? .light : .medium)
        feedback.prepare()

        nfcManager.scan { result in
            switch result {
            case .success(let tagID):
                // Verify token matches paired token
                guard let pairedID = appState.pairedTokenID, tagID == pairedID else {
                    let errorFeedback = UINotificationFeedbackGenerator()
                    errorFeedback.notificationOccurred(.error)
                    showWrongTokenAlert = true
                    return
                }

                feedback.impactOccurred()

                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    let wasBlocking = blockingManager.isBlocking
                    if let mode = appState.activeMode {
                        blockingManager.toggleBlocking(for: mode.appSelection, strictMode: appState.strictModeEnabled)
                    } else {
                        blockingManager.toggleBlocking(for: appState.selectedApps, strictMode: appState.strictModeEnabled)
                    }
                    appState.isBlocking = blockingManager.isBlocking

                    // Start or stop focus timer
                    if !wasBlocking && blockingManager.isBlocking {
                        appState.startBlockingTimer()
                    } else if wasBlocking && !blockingManager.isBlocking {
                        appState.stopBlockingTimer()
                    }
                }

                // Double haptic for end session
                if !blockingManager.isBlocking {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        let light = UIImpactFeedbackGenerator(style: .light)
                        light.impactOccurred()
                    }
                }

            case .failure(let error):
                if case NFCError.userCancelled = error {
                    return
                }
                let errorFeedback = UINotificationFeedbackGenerator()
                errorFeedback.notificationOccurred(.error)
                print("[HomeView] NFC scan failed: \(error.localizedDescription)")
            }
        }
    }
}
