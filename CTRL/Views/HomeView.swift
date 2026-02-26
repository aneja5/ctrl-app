import SwiftUI
import FamilyControls

struct HomeView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var nfcManager: NFCManager
    @EnvironmentObject var blockingManager: BlockingManager
    @EnvironmentObject var scheduleManager: ScheduleManager

    @State private var showInvalidTagAlert = false
    @State private var showNFCUnavailableAlert = false
    @State private var currentTime = Date()
    @State private var showModeSheet = false
    @State private var ritualGlowPulse: CGFloat = 0
    @State private var timerScale: CGFloat = 1.0
    @State private var timerOpacity: Double = 1.0
    @State private var showFirstTimeAppPicker = false
    @State private var showPermissionAlert = false
    @State private var showScheduledSessionAlert = false
    @State private var editingModeFromSheet: EditModeItem? = nil
    @State private var isLongPressing = false
    @State private var showManualStartAlert = false
    @State private var showCountdownUnlock = false
    @State private var breakPillExpanded = false
    @State private var showOverrideEarnedToast = false
    @Environment(\.scenePhase) private var scenePhase

    // Sheet item — unique ID forces fresh EditModeView each time
    struct EditModeItem: Identifiable {
        let id = UUID()
        let mode: BlockingMode?
        let isNew: Bool
        let viewOnly: Bool
    }

    private var isInSession: Bool {
        if featureEnabled(.schedules) {
            return blockingManager.isBlocking || scheduleManager.activeScheduleId != nil
        }
        return blockingManager.isBlocking
    }

    /// True when the session is from a schedule (not a manual NFC lock-in)
    private var isScheduledSession: Bool {
        guard featureEnabled(.schedules) else { return false }
        return scheduleManager.activeScheduleId != nil && !blockingManager.isBlocking
    }

    /// The active schedule (if any)
    private var activeSchedule: FocusSchedule? {
        guard let idString = scheduleManager.activeScheduleId,
              let uuid = UUID(uuidString: idString) else { return nil }
        return appState.schedules.first(where: { $0.id == uuid })
    }

    /// Mode name for the current session (manual or scheduled)
    private var sessionModeName: String {
        if let schedule = activeSchedule {
            return appState.modes.first(where: { $0.id == schedule.modeId })?.name.lowercased() ?? "focus"
        }
        return appState.activeMode?.name.lowercased() ?? "focus"
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

                // Top spacer — pushes content cluster above center
                Spacer()
                    .frame(minHeight: 60)

                // ── CONTENT CLUSTER (fixed internal layout) ──

                // Status text — fixed position, property-driven (no if/else swap)
                Text(appState.isOnBreak ? "on break" : (isInSession ? "in session" : "unlocked"))
                    .font(CTRLFonts.display)
                    .tracking(2)
                    .foregroundColor(appState.isOnBreak ? CTRLColors.textSecondary : (isInSession ? CTRLColors.accent : CTRLColors.textPrimary))
                    .contentTransition(.interpolate)
                    .animation(.easeInOut(duration: 0.35), value: isInSession)
                    .animation(.easeInOut(duration: 0.35), value: appState.isOnBreak)

                // Mode selector — same position in both states
                modeSelector
                    .padding(.top, CTRLSpacing.sm)

                // Timer area — fixed height, content fades in/out
                ZStack {
                    if isInSession {
                        sessionTimerContent
                            .transition(.opacity.animation(.easeInOut(duration: 0.3)))
                    }
                }
                .frame(height: 80)
                .padding(.top, CTRLSpacing.xs)

                // Break pill — only during sessions
                ZStack {
                    if featureEnabled(.breaks) && isInSession {
                        BreakPillView(
                            isExpanded: $breakPillExpanded,
                            onStartBreak: { breakOption in startBreak(breakOption) },
                            onEndBreak: { endBreak() }
                        )
                        .environmentObject(appState)
                    }
                }
                .frame(minHeight: 44)
                .padding(.top, CTRLSpacing.xs)
                .animation(.easeInOut(duration: 0.25), value: appState.earnedBreaks.count)
                .animation(.easeInOut(duration: 0.25), value: appState.isOnBreak)

                // ── END CONTENT CLUSTER ──

                // Bottom spacer — less than top (pushes cluster above center)
                Spacer()
                    .frame(minHeight: 40)

                // Primary action — single button, property-driven (hidden during break)
                primaryAction
                    .padding(.horizontal, CTRLSpacing.screenPadding + 20)
                    .padding(.bottom, CTRLSpacing.md)
                    .opacity(appState.isOnBreak ? 0 : 1)
                    .allowsHitTesting(!appState.isOnBreak)
                    .animation(.easeInOut(duration: 0.25), value: appState.isOnBreak)

                // Manual end session text — always in layout, opacity-driven (hidden during break)
                Button(action: { showCountdownUnlock = true }) {
                    Text("end session")
                        .font(.caption)
                        .foregroundColor(Color.white.opacity(0.35))
                }
                .opacity(isInSession && appState.sessionStartMethod == .manual && !appState.isOnBreak ? 1 : 0)
                .allowsHitTesting(isInSession && appState.sessionStartMethod == .manual && !appState.isOnBreak)
                .frame(height: 20)
                .padding(.top, CTRLSpacing.xs)

                // Tab bar clearance
                Spacer()
                    .frame(height: 100)
            }

            // Override earned toast
            VStack {
                if showOverrideEarnedToast {
                    Text("override earned \u{2014} 7 days of focus")
                        .font(CTRLFonts.bodySmall)
                        .foregroundColor(CTRLColors.accent)
                        .padding(.horizontal, CTRLSpacing.md)
                        .padding(.vertical, CTRLSpacing.sm)
                        .background(Capsule().fill(CTRLColors.surface1))
                        .overlay(Capsule().stroke(CTRLColors.accent.opacity(0.3), lineWidth: 1))
                        .transition(.opacity.combined(with: .move(edge: .top)))
                        .padding(.top, CTRLSpacing.xl + 30)
                }
                Spacer()
            }
            .allowsHitTesting(false)
            .animation(.easeInOut(duration: 0.4), value: showOverrideEarnedToast)

        }
        .alert("not a genuine ctrl", isPresented: $showInvalidTagAlert) {
            Button("ok", role: .cancel) { }
            Button("get yours") {
                if let url = URL(string: "https://www.getctrl.in") {
                    UIApplication.shared.open(url)
                }
            }
        } message: {
            Text("only official ctrl devices can start your focus sessions. get yours at getctrl.in")
        }
        .alert("nfc not available", isPresented: $showNFCUnavailableAlert) {
            Button("ok", role: .cancel) { }
        } message: {
            Text("nfc isn't available on this device. ctrl requires nfc to work with your tag.")
        }
        .alert("screen time required", isPresented: $showPermissionAlert) {
            Button("open settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("ok", role: .cancel) { }
        } message: {
            Text("ctrl needs screen time permission to block apps. enable it in settings to start a session.")
        }
        .alert("scheduled session active", isPresented: $showScheduledSessionAlert) {
            Button("ok", role: .cancel) { }
        } message: {
            Text("you're in a scheduled session. end it first to start a manual session.")
        }
        .alert("start without tag?", isPresented: $showManualStartAlert) {
            Button("cancel", role: .cancel) { }
            Button("start session") {
                startManualSession()
            }
        } message: {
            Text("you can start now, but you'll need to tap your ctrl tag to end the session.")
        }
        .fullScreenCover(isPresented: $showCountdownUnlock) {
            CountdownUnlockView(onComplete: {
                appState.stopBlockingTimer()
                blockingManager.deactivateBlocking()
                appState.isBlocking = blockingManager.isBlocking
                checkOverrideEarnedNotification()
            })
        }
        .alert("app blocking improved", isPresented: $appState.showReselectionAlert) {
            Button("open modes") {
                showModeSheet = true
            }
            Button("later", role: .cancel) { }
        } message: {
            Text("please re-select apps for your modes to ensure all apps are blocked correctly. tap a mode and hit save.")
        }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            if isInSession {
                currentTime = Date()
            }
        }
        // Periodic schedule re-check: catches windows that start/end while app is in foreground
        .onReceive(Timer.publish(every: 60, on: .main, in: .common).autoconnect()) { _ in
            if featureEnabled(.schedules) {
                scheduleManager.syncScheduleShields()
                // Schedule just activated — start the timer
                if scheduleManager.activeScheduleId != nil && !appState.isInSession {
                    appState.startBlockingTimer()
                }
                // Schedule just ended naturally — stop the timer
                if scheduleManager.activeScheduleId == nil && !blockingManager.isBlocking && appState.isInSession {
                    appState.stopBlockingTimer()
                    checkOverrideEarnedNotification()
                }
            }
        }
        .task {
            let authorized = await blockingManager.requestAuthorization()
            appState.isAuthorized = authorized

            if featureEnabled(.schedules) {
                // Primary activation: sync schedule shields on launch
                scheduleManager.syncScheduleShields()
                scheduleManager.scheduleImminentSync(for: appState.schedules)

                // Sync timer state with schedule state
                if scheduleManager.activeScheduleId != nil && !appState.isInSession {
                    if scheduleManager.isActiveScheduleSkippedToday() {
                        scheduleManager.clearActiveSchedule()
                    } else {
                        appState.startBlockingTimer()
                    }
                }
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                // Catch up break countdown after backgrounding (timer may have missed ticks)
                if appState.isOnBreak, let breakStart = appState.breakStartDate {
                    let elapsed = Int(Date().timeIntervalSince(breakStart))
                    let remaining = appState.breakTotalDuration - elapsed
                    if remaining <= 0 {
                        endBreak()
                    } else {
                        appState.breakSecondsRemaining = remaining
                    }
                }

                if featureEnabled(.schedules) {
                    // Primary activation: sync schedule shields on every foreground
                    scheduleManager.syncScheduleShields()
                    scheduleManager.scheduleImminentSync(for: appState.schedules)
                    scheduleManager.logExtensionDebugInfo()

                    // Sync timer with schedule state
                    if scheduleManager.activeScheduleId != nil && !appState.isInSession {
                        if scheduleManager.isActiveScheduleSkippedToday() {
                            scheduleManager.clearActiveSchedule()
                        } else {
                            appState.startBlockingTimer()
                        }
                    }
                    // If scheduled session ended while backgrounded but timer is still running, stop it
                    if scheduleManager.activeScheduleId == nil && !blockingManager.isBlocking && appState.isInSession {
                        appState.stopBlockingTimer()
                    }
                }

                // Check for override earned notification (may have been set while backgrounded)
                checkOverrideEarnedNotification()
            }
            if newPhase == .background {
                if featureEnabled(.schedules) {
                    // Sync shields before backgrounding (catches schedule windows that started while app was open)
                    scheduleManager.syncScheduleShields()
                    // Sync timer if schedule just activated
                    if scheduleManager.activeScheduleId != nil && !appState.isInSession {
                        appState.startBlockingTimer()
                    }
                    // Schedule BGTask fallback for next transition
                    scheduleManager.scheduleNextBGTask(schedules: appState.schedules)
                }
            }
        }
        .onChange(of: appState.breakSecondsRemaining) { oldValue, newValue in
            if oldValue > 0 && newValue <= 0 && appState.isOnBreak {
                // Break expired — auto-resume blocking
                endBreak()
                UINotificationFeedbackGenerator().notificationOccurred(.warning)
            }
        }
        .sheet(isPresented: $showModeSheet) {
            ModeSelectionSheet(
                lockedModeId: activeSessionModeId,
                onEditMode: { mode in
                    let isActiveMode = mode.id == activeSessionModeId
                    editingModeFromSheet = EditModeItem(mode: mode, isNew: false, viewOnly: isActiveMode)
                },
                onCreateMode: {
                    editingModeFromSheet = EditModeItem(mode: nil, isNew: true, viewOnly: false)
                },
                onSetupMode: { mode in
                    editingModeFromSheet = EditModeItem(mode: mode, isNew: false, viewOnly: false)
                }
            )
                .environmentObject(appState)
                .environmentObject(blockingManager)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
                .presentationBackground(CTRLColors.surface1)
        }
        .sheet(item: $editingModeFromSheet) { item in
            EditModeView(
                mode: item.mode,
                isNewMode: item.isNew,
                viewOnly: item.viewOnly,
                onSave: { savedMode in
                    if item.isNew {
                        appState.addMode(savedMode)
                        appState.setActiveMode(id: savedMode.id)
                    } else {
                        appState.updateMode(savedMode)
                    }
                },
                onDelete: { modeToDelete in
                    let affected = appState.deleteMode(modeToDelete)
                    if featureEnabled(.schedules) {
                        for schedule in affected {
                            scheduleManager.unregisterSchedule(schedule)
                        }
                    }
                },
                onCancel: { }
            )
            .environmentObject(appState)
            .presentationBackground(CTRLColors.base)
        }
        .sheet(isPresented: $showFirstTimeAppPicker) {
            AppSelectionView(
                modeName: appState.activeMode?.name ?? "Focus",
                onContinue: { selection in
                    // Save to active mode
                    if let mode = appState.activeMode {
                        var updated = mode
                        updated.appSelection = selection
                        appState.updateMode(updated)
                        appState.saveSelectedApps(selection)
                    }
                    showFirstTimeAppPicker = false
                    // Now trigger NFC scan to start session
                    triggerNFCScan()
                }
            )
            .presentationBackground(CTRLColors.base)
        }
    }

    // MARK: - Session Timer Content (fixed-height container)

    /// Timer + badges shown inside the fixed-height ZStack during sessions.
    private var sessionTimerContent: some View {
        VStack(spacing: CTRLSpacing.micro) {
            Text(formatSessionTime())
                .font(CTRLFonts.timer)
                .foregroundColor(CTRLColors.textPrimary)
                .monospacedDigit()
                .scaleEffect(timerScale)
                .opacity(appState.isOnBreak ? 0.4 : timerOpacity)

            // Session type badges
            HStack(spacing: CTRLSpacing.xs) {
                if blockingManager.strictModeActive {
                    Text("strict")
                        .font(CTRLFonts.micro)
                        .tracking(1.5)
                        .foregroundColor(CTRLColors.accent)
                        .padding(.horizontal, CTRLSpacing.sm)
                        .padding(.vertical, CTRLSpacing.micro)
                        .background(
                            Capsule()
                                .fill(CTRLColors.accent.opacity(0.12))
                        )
                        .overlay(
                            Capsule()
                                .stroke(CTRLColors.accent.opacity(0.25), lineWidth: 0.5)
                        )
                        .transition(.opacity.combined(with: .scale(scale: 0.9)))
                }

                if featureEnabled(.schedules) && scheduleManager.activeScheduleId != nil {
                    Text("scheduled")
                        .font(CTRLFonts.micro)
                        .tracking(1.5)
                        .foregroundColor(CTRLColors.textTertiary)
                        .padding(.horizontal, CTRLSpacing.sm)
                        .padding(.vertical, CTRLSpacing.micro)
                        .background(
                            Capsule()
                                .fill(CTRLColors.surface2)
                        )
                        .transition(.opacity.combined(with: .scale(scale: 0.9)))
                }
            }
        }
    }

    // MARK: - Primary Action (single button, property-driven)

    private var primaryAction: some View {
        Text(isInSession ? "end session" : "lock in")
            .font(CTRLFonts.bodyFont)
            .fontWeight(.medium)
            .foregroundColor(isInSession ? CTRLColors.accent : CTRLColors.base)
            .frame(maxWidth: .infinity)
            .frame(height: CTRLSpacing.buttonHeight)
            .background(
                RoundedRectangle(cornerRadius: CTRLSpacing.buttonRadius)
                    .fill(isInSession ? CTRLColors.surface2 : CTRLColors.accent)
            )
            .overlay(
                RoundedRectangle(cornerRadius: CTRLSpacing.buttonRadius)
                    .stroke(
                        isInSession ? CTRLColors.accentMuted.opacity(0.6) : Color.clear,
                        lineWidth: isInSession ? 1.5 : 0
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: CTRLSpacing.buttonRadius))
            .scaleEffect(isLongPressing ? 0.97 : 1.0)
            .opacity(nfcManager.isScanning ? 0.5 : 1.0)
            .animation(.easeOut(duration: 0.15), value: isLongPressing)
            .animation(.easeInOut(duration: 0.35), value: isInSession)
            .onTapGesture {
                guard !nfcManager.isScanning else { return }
                if isInSession {
                    triggerNFCScan()
                } else {
                    handleLockIn()
                }
            }
            .onLongPressGesture(minimumDuration: 0.8, pressing: { isPressing in
                guard !isInSession else { return }
                isLongPressing = isPressing
            }, perform: {
                guard !isInSession else { return }
                completeLongPress()
            })
    }

    // MARK: - Mode Selector (below Lock In)

    /// The mode ID currently in use during a session (manual or scheduled)
    private var activeSessionModeId: UUID? {
        guard isInSession else { return nil }
        if let schedule = activeSchedule {
            return schedule.modeId
        }
        return appState.activeModeId
    }

    private var modeSelector: some View {
        Button(action: { showModeSheet = true }) {
            HStack(spacing: CTRLSpacing.sm) {
                Text(isInSession ? sessionModeName : (appState.activeMode?.name.lowercased() ?? "select mode"))
                    .font(CTRLFonts.bodySmall)
                    .foregroundColor(CTRLColors.textSecondary)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Image(systemName: "chevron.down")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(CTRLColors.textTertiary)
                    .rotationEffect(.degrees(showModeSheet ? -180 : 0))
                    .animation(.easeOut(duration: 0.25), value: showModeSheet)
            }
            .padding(.horizontal, CTRLSpacing.md)
            .padding(.vertical, CTRLSpacing.sm)
            .background(
                Capsule()
                    .fill(CTRLColors.surface1)
            )
            .overlay(
                Capsule()
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )
        }
        .buttonStyle(ModeSelectorButtonStyle())
        .disabled(isScheduledSession)
        .opacity(isScheduledSession ? 0.5 : 1.0)
    }


    // MARK: - Helpers

    private func formatSessionTime() -> String {
        // Use currentTime to force SwiftUI refresh
        let _ = currentTime

        // Timed scheduled sessions: countdown to end time
        if let schedule = activeSchedule, !schedule.requireNFCToEnd {
            let calendar = Calendar.current
            let now = Date()
            let endHour = schedule.endTime.hour ?? 0
            let endMinute = schedule.endTime.minute ?? 0

            // Build today's end time
            var endDate = calendar.date(bySettingHour: endHour, minute: endMinute, second: 0, of: now) ?? now

            // Handle midnight crossing: if end time already passed today, it's tomorrow
            if endDate <= now {
                endDate = calendar.date(byAdding: .day, value: 1, to: endDate) ?? endDate
            }

            let remaining = max(0, Int(endDate.timeIntervalSince(now)))
            let hours = remaining / 3600
            let minutes = (remaining % 3600) / 60
            let secs = remaining % 60

            if hours > 0 {
                return String(format: "%d:%02d:%02d", hours, minutes, secs)
            } else {
                return String(format: "%d:%02d", minutes, secs)
            }
        }

        // Default: elapsed focus time (NFC sessions, manual sessions)
        // During a break, show paused focus time; otherwise show focus time excluding breaks
        let seconds = appState.isOnBreak
            ? appState.focusSecondsExcludingBreaks
            : max(0, Int(appState.currentSessionSeconds) - appState.totalBreakSecondsTaken)
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let secs = seconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        } else {
            return String(format: "%d:%02d", minutes, secs)
        }
    }

    // MARK: - Break Management

    private func startBreak(_ breakOption: BreakOption) {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        appState.startBreak(breakOption)
        // Unblock apps during break
        blockingManager.deactivateBlocking()
        appState.isBlocking = blockingManager.isBlocking
        breakPillExpanded = false
    }

    private func endBreak() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        appState.endBreak()
        // Re-block apps after break
        if let mode = appState.activeMode {
            blockingManager.activateBlocking(for: mode.appSelection, strictMode: appState.strictModeEnabled)
        }
        appState.isBlocking = blockingManager.isBlocking
    }

    // MARK: - Override Earned Toast

    private func checkOverrideEarnedNotification() {
        if appState.pendingOverrideEarnedNotification {
            appState.pendingOverrideEarnedNotification = false
            withAnimation { showOverrideEarnedToast = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                withAnimation { showOverrideEarnedToast = false }
            }
        }
    }

    // MARK: - Long Press

    private func completeLongPress() {
        isLongPressing = false
        guard featureEnabled(.manualSessions) else { return }
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        showManualStartAlert = true
    }

    private func startManualSession() {
        guard appState.hasScreenTimePermission else {
            showPermissionAlert = true
            return
        }

        guard let mode = appState.activeMode else { return }
        let hasApps = !mode.appSelection.applicationTokens.isEmpty ||
                      !mode.appSelection.categoryTokens.isEmpty
        guard hasApps else {
            showFirstTimeAppPicker = true
            return
        }

        blockingManager.activateBlocking(for: mode.appSelection, strictMode: appState.strictModeEnabled)
        appState.startBlockingTimer(method: .manual)
        appState.isBlocking = blockingManager.isBlocking

        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    // MARK: - Actions

    /// Checks if the active mode has apps before starting NFC.
    /// If no apps are selected, shows the app picker first.
    private func handleLockIn() {
        // Immediate haptic feedback on tap
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        // Block manual lock-in during a scheduled session
        if featureEnabled(.schedules) && scheduleManager.activeScheduleId != nil && !blockingManager.isBlocking {
            showScheduledSessionAlert = true
            return
        }

        // Check Screen Time permission first
        guard appState.hasScreenTimePermission else {
            showPermissionAlert = true
            return
        }

        guard let mode = appState.activeMode else { return }
        let hasApps = !mode.appSelection.applicationTokens.isEmpty ||
                      !mode.appSelection.categoryTokens.isEmpty
        if !hasApps {
            showFirstTimeAppPicker = true
        } else {
            triggerNFCScan()
        }
    }

    private func triggerNFCScan() {
        nfcManager.scan { result in
            switch result {
            case .success(_):
                // Valid ctrl scanned
                let generator = UIImpactFeedbackGenerator(style: isInSession ? .light : .medium)
                generator.impactOccurred()

                if isInSession {
                    // End any active break first
                    if appState.isOnBreak {
                        appState.endBreak()
                    }
                    // End session (manual or scheduled)
                    appState.stopBlockingTimer()
                    if blockingManager.isBlocking {
                        blockingManager.deactivateBlocking()
                    }
                    if featureEnabled(.schedules) {
                        if scheduleManager.activeScheduleId != nil {
                            // endActiveSession marks as skipped + calls syncScheduleShields for handoff
                            scheduleManager.endActiveSession()
                        } else {
                            // Manual-only session ended — check for pending schedules
                            scheduleManager.syncScheduleShields()
                        }
                        // Check if handoff activated a new overlapping schedule
                        if scheduleManager.activeScheduleId != nil {
                            appState.startBlockingTimer()
                        }
                    }
                    checkOverrideEarnedNotification()
                } else {
                    // Start session — apps already verified by handleLockIn()
                    if let mode = appState.activeMode {
                        blockingManager.activateBlocking(for: mode.appSelection, strictMode: appState.strictModeEnabled)
                    } else {
                        blockingManager.activateBlocking(for: appState.selectedApps, strictMode: appState.strictModeEnabled)
                    }
                    appState.startBlockingTimer()
                }
                appState.isBlocking = blockingManager.isBlocking

            case .failure(let error):
                if case NFCError.userCancelled = error {
                    return
                }
                if case NFCError.notAvailable = error {
                    showNFCUnavailableAlert = true
                    return
                }
                if case NFCError.invalidTag = error {
                    showInvalidTagAlert = true
                    UINotificationFeedbackGenerator().notificationOccurred(.error)
                }
            }
        }
    }
}
