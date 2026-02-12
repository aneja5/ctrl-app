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
    @State private var ritualGlowPulse: CGFloat = 0
    @State private var timerScale: CGFloat = 1.0
    @State private var timerOpacity: Double = 1.0

    private var isInSession: Bool {
        blockingManager.isBlocking
    }

    var body: some View {
        ZStack {
            // Base background
            CTRLColors.base.ignoresSafeArea()

            // Bronze glow when in session
            if isInSession {
                BronzeGlow()
                    .offset(y: -60)
                    .transition(.opacity.animation(.easeOut(duration: 0.4)))
            }

            // Ritual glow pulse (fires on lock-in)
            Circle()
                .fill(
                    RadialGradient(
                        gradient: Gradient(colors: [
                            CTRLColors.accent.opacity(0.25),
                            CTRLColors.accent.opacity(0.08),
                            Color.clear
                        ]),
                        center: .center,
                        startRadius: 0,
                        endRadius: 220
                    )
                )
                .frame(width: 440, height: 440)
                .scaleEffect(ritualGlowPulse)
                .opacity(Double(ritualGlowPulse) > 0 ? Double(1.2 - ritualGlowPulse) : 0)
                .blur(radius: 30)
                .allowsHitTesting(false)

            VStack(spacing: 0) {
                // Wordmark at top
                Text("ctrl")
                    .font(CTRLFonts.ritualWhisper)
                    .foregroundColor(CTRLColors.textTertiary)
                    .tracking(3)
                    .padding(.top, CTRLSpacing.xl)

                Spacer()

                // State Display (Ritual Center)
                stateDisplay

                Spacer()

                // Mode Selector (above Lock In)
                if !isInSession {
                    modeSelector
                        .padding(.bottom, CTRLSpacing.lg)
                }

                // Primary Action
                primaryAction
                    .padding(.horizontal, CTRLSpacing.screenPadding + 20)

                // Breathing dot when in session
                if isInSession {
                    BreathingDot()
                        .padding(.top, CTRLSpacing.xl)
                }

                Spacer()
                    .frame(height: CTRLSpacing.xxl)

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
                .environmentObject(nfcManager)
                .presentationBackground(CTRLColors.base)
        }
    }

    // MARK: - Ritual State Display

    private var stateDisplay: some View {
        VStack(spacing: CTRLSpacing.md) {
            if isInSession {
                // In Session — serif ritual state
                Text("in session")
                    .font(CTRLFonts.display)
                    .tracking(2)
                    .foregroundColor(CTRLColors.accent)
                    .transition(.opacity.combined(with: .scale(scale: 0.97)))

                Text(formatSessionTime())
                    .font(CTRLFonts.timer)
                    .foregroundColor(CTRLColors.textPrimary)
                    .monospacedDigit()
                    .padding(.top, CTRLSpacing.xs)
                    .scaleEffect(timerScale)
                    .opacity(timerOpacity)

                Text(appState.activeMode?.name.lowercased() ?? "focus")
                    .font(CTRLFonts.bodySmall)
                    .foregroundColor(CTRLColors.textTertiary)
                    .padding(.top, CTRLSpacing.micro)
                    .opacity(timerOpacity)

            } else {
                // Unlocked — serif ritual state
                Text("unlocked")
                    .font(CTRLFonts.display)
                    .tracking(2)
                    .foregroundColor(CTRLColors.textPrimary)
                    .transition(.opacity.combined(with: .scale(scale: 0.97)))

                // Mode name under unlocked
                Text(appState.activeMode?.name.lowercased() ?? "focus")
                    .font(CTRLFonts.captionFont)
                    .tracking(1)
                    .foregroundColor(CTRLColors.textTertiary)
                    .padding(.top, CTRLSpacing.xs)
            }
        }
        .animation(.easeInOut(duration: 0.4), value: isInSession)
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

    // MARK: - Mode Selector (below Lock In)

    private var modeSelector: some View {
        Button(action: { showModeSheet = true }) {
            HStack(spacing: CTRLSpacing.xs) {
                Text(appState.activeMode?.name ?? "Select")
                    .font(CTRLFonts.bodySmall)
                    .foregroundColor(CTRLColors.textSecondary)

                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(CTRLColors.textTertiary)
            }
            .padding(.horizontal, CTRLSpacing.md)
            .padding(.vertical, CTRLSpacing.sm)
            .background(
                Capsule()
                    .fill(CTRLColors.surface1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Floating Dock (with today's time)

    private var floatingDock: some View {
        HStack {
            // Activity Button
            Button(action: { showActivity = true }) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 18, weight: .regular))
                    .foregroundColor(CTRLColors.textTertiary)
                    .frame(width: 44, height: 44)
            }

            Spacer()

            // Center: Always show today's total time
            VStack(spacing: 2) {
                Text(formatTodayTime())
                    .font(CTRLFonts.captionFont)
                    .foregroundColor(CTRLColors.textSecondary)
                    .monospacedDigit()

                Text("today")
                    .font(CTRLFonts.micro)
                    .foregroundColor(CTRLColors.textTertiary)
            }

            Spacer()

            // Settings Button
            Button(action: { showSettings = true }) {
                Image(systemName: "gearshape")
                    .font(.system(size: 18, weight: .regular))
                    .foregroundColor(CTRLColors.textTertiary)
                    .frame(width: 44, height: 44)
            }
        }
        .padding(CTRLSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: 28)
                .fill(CTRLColors.surface1.opacity(0.7))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28)
                .stroke(CTRLColors.border.opacity(0.3), lineWidth: 0.5)
        )
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
        let mediumHaptic = UIImpactFeedbackGenerator(style: .medium)
        let lightHaptic = UIImpactFeedbackGenerator(style: .light)
        mediumHaptic.prepare()
        lightHaptic.prepare()

        let wasInSession = isInSession

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

                // -- Haptic: medium thud (the "seal") --
                mediumHaptic.impactOccurred()

                // Prepare timer entrance state before toggling (lock-in only)
                if !wasInSession {
                    timerScale = 0.95
                    timerOpacity = 0
                }

                // -- Bronze glow pulse radiates from center (lock-in only) --
                if !wasInSession {
                    ritualGlowPulse = 0.3
                    withAnimation(.easeOut(duration: 0.6)) {
                        ritualGlowPulse = 1.2
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                        ritualGlowPulse = 0
                    }
                }

                // -- Cross-fade state (400ms ease) --
                withAnimation(.easeInOut(duration: 0.4)) {
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

                // -- Timer fades in with scale 0.95 → 1.0 (lock-in only) --
                if !wasInSession {
                    withAnimation(.easeOut(duration: 0.5).delay(0.15)) {
                        timerScale = 1.0
                        timerOpacity = 1.0
                    }
                }

                // -- Light haptic 100ms after medium --
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    lightHaptic.impactOccurred()
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
