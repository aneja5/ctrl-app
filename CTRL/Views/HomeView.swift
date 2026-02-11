import SwiftUI
import Combine

struct HomeView: View {

    // MARK: - Environment

    @EnvironmentObject var appState: AppState
    @ObservedObject var nfcManager: NFCManager
    @ObservedObject var blockingManager: BlockingManager

    // MARK: - State

    @State private var showWrongTokenAlert = false
    @State private var showSettings = false
    @State private var currentTime = Date()

    // MARK: - Body

    var body: some View {
        ZStack {
            CTRLColors.background
                .ignoresSafeArea()

            VStack(spacing: 0) {

                // MARK: Top Bar

                topBar
                    .padding(.horizontal, 24)
                    .padding(.top, 8)

                Spacer()

                // MARK: Main Action Button

                actionButton

                // MARK: Mode Selector

                modeSelector

                Spacer()

                // MARK: Status Card

                statusCard
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
            }
        }
        .alert("Wrong Token", isPresented: $showWrongTokenAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("This token doesn't match your paired token. Use the same token you set up during onboarding.")
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .environmentObject(appState)
                .environmentObject(nfcManager)
                .environmentObject(blockingManager)
        }
        .task {
            let authorized = await blockingManager.requestAuthorization()
            appState.isAuthorized = authorized
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            Text("CTRL")
                .font(CTRLFonts.caption())
                .foregroundColor(CTRLColors.textSecondary)
                .textCase(.uppercase)
                .tracking(2)

            Spacer()

            Button {
                showSettings = true
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 18))
                    .foregroundColor(CTRLColors.textSecondary)
            }
        }
    }

    // MARK: - Action Button

    private var actionButton: some View {
        VStack(spacing: 24) {
            Button(action: performNFCScan) {
                ZStack {
                    // Main circle
                    Circle()
                        .fill(blockingManager.isBlocking
                              ? CTRLColors.accent
                              : Color.clear)
                        .frame(width: 160, height: 160)

                    Circle()
                        .stroke(CTRLColors.accent, lineWidth: blockingManager.isBlocking ? 0 : 3)
                        .frame(width: 160, height: 160)

                    // Lock icon
                    Image(systemName: blockingManager.isBlocking ? "lock.fill" : "lock.open")
                        .font(.system(size: 50))
                        .foregroundColor(blockingManager.isBlocking
                                         ? CTRLColors.background
                                         : CTRLColors.accent)
                }
            }
            .disabled(!nfcManager.isAvailable || nfcManager.isScanning)

            // Label
            VStack(spacing: 8) {
                Text(blockingManager.isBlocking ? "Tap to Unlock" : "Tap to Focus")
                    .font(CTRLFonts.title())
                    .foregroundColor(CTRLColors.textPrimary)

                Text(blockingManager.isBlocking
                     ? "\(appState.activeMode?.appCount ?? 0) app\(appState.activeMode?.appCount == 1 ? "" : "s") blocked"
                     : "\(appState.activeMode?.appCount ?? 0) app\(appState.activeMode?.appCount == 1 ? "" : "s") selected")
                    .font(CTRLFonts.body())
                    .foregroundColor(CTRLColors.textSecondary)
            }

            // Scanning indicator
            if nfcManager.isScanning {
                HStack(spacing: 8) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: CTRLColors.accent))
                    Text("Scanning...")
                        .font(CTRLFonts.caption())
                        .foregroundColor(CTRLColors.textSecondary)
                }
            }
        }
    }

    // MARK: - Status Card

    private var statusCard: some View {
        VStack(spacing: 12) {
            // Status row
            HStack(spacing: 10) {
                Circle()
                    .fill(blockingManager.isBlocking ? CTRLColors.success : CTRLColors.textMuted)
                    .frame(width: 8, height: 8)

                Text(blockingManager.isBlocking ? "Focus Mode Active" : "Ready")
                    .font(CTRLFonts.headline())
                    .foregroundColor(CTRLColors.textPrimary)

                Spacer()
            }

            // Focus time display
            HStack(spacing: 8) {
                Image(systemName: "clock")
                    .font(.system(size: 13))
                    .foregroundColor(CTRLColors.accent)

                Text(formattedFocusTime)
                    .font(CTRLFonts.mono())
                    .foregroundColor(CTRLColors.textPrimary)

                Spacer()

                Text("Total Focus")
                    .font(CTRLFonts.caption())
                    .foregroundColor(CTRLColors.textMuted)
            }

            // Token ID
            if let tokenID = appState.pairedTokenID {
                HStack {
                    Image(systemName: "wave.3.right")
                        .font(.system(size: 11))
                        .foregroundColor(CTRLColors.textMuted)

                    Text(tokenID)
                        .font(CTRLFonts.mono())
                        .foregroundColor(CTRLColors.textMuted)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    Spacer()
                }
            }
        }
        .padding(16)
        .ctrlCard()
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { time in
            if blockingManager.isBlocking {
                currentTime = time
            }
        }
    }

    // MARK: - Mode Selector

    private var modeSelector: some View {
        VStack(spacing: 4) {
            Menu {
                ForEach(appState.modes) { mode in
                    Button(action: {
                        if !blockingManager.isBlocking {
                            appState.setActiveMode(id: mode.id)
                        }
                    }) {
                        HStack {
                            Text(mode.name)
                            if appState.activeModeId == mode.id {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                    .disabled(blockingManager.isBlocking && appState.activeModeId != mode.id)
                }
            } label: {
                HStack(spacing: 8) {
                    Text(appState.activeMode?.name ?? "Select Mode")
                        .font(.headline)
                        .foregroundColor(CTRLColors.textPrimary)

                    Image(systemName: "chevron.down")
                        .font(.caption)
                        .foregroundColor(CTRLColors.textSecondary)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(CTRLColors.cardBackground)
                .cornerRadius(25)
            }
            .disabled(blockingManager.isBlocking)
            .opacity(blockingManager.isBlocking ? 0.5 : 1.0)

            if blockingManager.isBlocking {
                Text("Unlock to change mode")
                    .font(.caption)
                    .foregroundColor(CTRLColors.textMuted)
                    .padding(.top, 4)
            }
        }
        .padding(.top, 16)
    }

    // MARK: - Helpers

    private var formattedFocusTime: String {
        let total = appState.totalBlockedSeconds + appState.currentSessionSeconds
        // Use currentTime to force SwiftUI refresh
        let _ = currentTime
        let hours = Int(total) / 3600
        let minutes = (Int(total) % 3600) / 60
        let seconds = Int(total) % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }

    // MARK: - Actions

    private func performNFCScan() {
        let feedback = UIImpactFeedbackGenerator(style: .medium)
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
                        blockingManager.toggleBlocking(for: mode.appSelection)
                    } else {
                        blockingManager.toggleBlocking(for: appState.selectedApps)
                    }
                    appState.isBlocking = blockingManager.isBlocking

                    // Start or stop focus timer
                    if !wasBlocking && blockingManager.isBlocking {
                        appState.startBlockingTimer()
                    } else if wasBlocking && !blockingManager.isBlocking {
                        appState.stopBlockingTimer()
                    }
                }

            case .failure(let error):
                if case NFCError.userCancelled = error {
                    return
                }
                let errorFeedback = UINotificationFeedbackGenerator()
                errorFeedback.notificationOccurred(.error)
                print("Scan failed: \(error.localizedDescription)")
            }
        }
    }
}
