import SwiftUI

struct HomeView: View {

    // MARK: - Environment

    @EnvironmentObject var appState: AppState
    @ObservedObject var nfcManager: NFCManager
    @ObservedObject var blockingManager: BlockingManager

    // MARK: - State

    @State private var isPulsing = false
    @State private var showWrongTokenAlert = false
    @State private var showSettings = false

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

            // Restore blocking state if app was killed while blocking
            if appState.isBlocking && !blockingManager.isBlocking {
                print("[HomeView] Restoring blocking state from persistence")
                blockingManager.activateBlocking(for: appState.selectedApps)
            }
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
                    // Pulse ring (only when blocking)
                    if blockingManager.isBlocking {
                        Circle()
                            .stroke(CTRLColors.accent.opacity(0.3), lineWidth: 2)
                            .frame(width: 180, height: 180)
                            .scaleEffect(isPulsing ? 1.15 : 1.0)
                            .opacity(isPulsing ? 0.0 : 0.6)
                            .animation(
                                .easeOut(duration: 1.8).repeatForever(autoreverses: false),
                                value: isPulsing
                            )
                    }

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
            .onChange(of: blockingManager.isBlocking) {
                if blockingManager.isBlocking {
                    isPulsing = true
                } else {
                    isPulsing = false
                }
            }
            .onAppear {
                if blockingManager.isBlocking {
                    isPulsing = true
                }
            }

            // Label
            VStack(spacing: 8) {
                Text(blockingManager.isBlocking ? "Tap to Unlock" : "Tap to Focus")
                    .font(CTRLFonts.title())
                    .foregroundColor(CTRLColors.textPrimary)

                Text(blockingManager.isBlocking
                     ? "\(appCount) app\(appCount == 1 ? "" : "s") blocked"
                     : "\(appCount) app\(appCount == 1 ? "" : "s") selected")
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
    }

    // MARK: - Helpers

    private var appCount: Int {
        appState.selectedApps.applicationTokens.count + appState.selectedApps.categoryTokens.count
    }

    // MARK: - Actions

    private func performNFCScan() {
        let feedback = UIImpactFeedbackGenerator(style: .medium)
        feedback.prepare()

        nfcManager.scan { result in
            switch result {
            case .success(let tagID):
                // Verify token matches paired token
                if let pairedID = appState.pairedTokenID, tagID != pairedID {
                    let errorFeedback = UINotificationFeedbackGenerator()
                    errorFeedback.notificationOccurred(.error)
                    showWrongTokenAlert = true
                    return
                }

                feedback.impactOccurred()

                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    blockingManager.toggleBlocking(for: appState.selectedApps)
                    appState.isBlocking = blockingManager.isBlocking
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
