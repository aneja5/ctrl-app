import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var blockingManager: BlockingManager
    @EnvironmentObject var scheduleManager: ScheduleManager

    // Single alert state to prevent hierarchy conflicts
    enum ActiveAlert: Identifiable {
        case override, signOut, deleteData, strictMode
        var id: Int {
            switch self {
            case .override: return 0
            case .signOut: return 1
            case .deleteData: return 2
            case .strictMode: return 3
            }
        }
    }
    @State private var activeAlert: ActiveAlert? = nil
    @State private var isDeletingData = false
    @State private var expandedFAQ: String? = nil
    @State private var resetCountdown: String = ""

    var body: some View {
        NavigationStack {
        ZStack {
            CTRLColors.base.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: CTRLSpacing.xl) {
                    // Header
                    header
                        .padding(.top, CTRLSpacing.md)

                    // Account
                    accountSection

                    // Session
                    sessionSection

                    // Override
                    overrideSection

                    // FAQ
                    faqSection

                    // Cloud Sync
                    cloudSyncSection

                    // Support
                    supportSection

                    // Footer
                    footerSection

                    Spacer(minLength: 80)
                }
                .padding(.horizontal, CTRLSpacing.screenPadding)
            }
        }
        .alert(
            activeAlert == .override ? "override session" :
            activeAlert == .signOut ? "sign out?" :
            activeAlert == .strictMode ? "enable strict mode?" : "delete cloud data?",
            isPresented: Binding(
                get: { activeAlert != nil },
                set: { if !$0 { activeAlert = nil } }
            ),
            presenting: activeAlert
        ) { alert in
            switch alert {
            case .override:
                Button("cancel", role: .cancel) { }
                Button("override", role: .destructive) {
                    if appState.useEmergencyUnlock() {
                        let generator = UINotificationFeedbackGenerator()
                        generator.notificationOccurred(.warning)
                        appState.stopBlockingTimer()
                        if blockingManager.isBlocking {
                            blockingManager.deactivateBlocking()
                        }
                        if FeatureFlags.schedulesEnabled && scheduleManager.activeScheduleId != nil {
                            scheduleManager.endActiveSession()
                        }
                    }
                }
            case .signOut:
                Button("cancel", role: .cancel) { }
                Button("sign out", role: .destructive) {
                    performSignOut()
                }
            case .deleteData:
                Button("cancel", role: .cancel) { }
                Button("delete everything", role: .destructive) {
                    performDeleteData()
                }
            case .strictMode:
                Button("cancel", role: .cancel) { }
                Button("enable", role: .destructive) {
                    let generator = UIImpactFeedbackGenerator(style: .medium)
                    generator.impactOccurred()
                    appState.strictModeEnabled = true
                    appState.saveState()
                    Task { @MainActor in
                        CloudSyncManager.shared.syncToCloud(appState: appState)
                    }
                }
            }
        } message: { alert in
            switch alert {
            case .override:
                Text("end session without your ctrl? \(appState.emergencyUnlocksRemaining) overrides remaining.")
            case .signOut:
                Text("you'll need to sign in again. your modes and history will be kept on this device.")
            case .deleteData:
                Text("this will permanently delete your email and all synced data from our servers. your local modes and history will be kept on this device.")
            case .strictMode:
                Text("during strict mode sessions, you won't be able to delete or install apps on your device. you can still use emergency overrides. are you sure?")
            }
        }
        .navigationBarHidden(true)
        } // NavigationStack
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text("settings")
                .font(CTRLFonts.ritualSection)
                .foregroundColor(CTRLColors.textPrimary)

            Spacer()
        }
    }

    // MARK: - Account Section

    private var accountSection: some View {
        VStack(alignment: .leading, spacing: CTRLSpacing.sm) {
            CTRLSectionHeader(title: "Account")

            SurfaceCard(padding: 0, cornerRadius: CTRLSpacing.cardRadius) {
                VStack(spacing: 0) {
                    // Email row
                    HStack {
                        Text("email")
                            .font(CTRLFonts.bodyFont)
                            .foregroundColor(CTRLColors.textSecondary)

                        Spacer()

                        Text(appState.userEmail ?? "—")
                            .font(CTRLFonts.bodyFont)
                            .foregroundColor(CTRLColors.textTertiary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    .padding(CTRLSpacing.md)

                    CTRLDivider()

                    // Sign Out row
                    Button(action: signOut) {
                        HStack {
                            Text("sign out")
                                .font(CTRLFonts.bodyFont)
                                .foregroundColor(CTRLColors.destructive)

                            Spacer()
                        }
                        .padding(CTRLSpacing.md)
                    }
                    .disabled(blockingManager.isBlocking)
                    .opacity(blockingManager.isBlocking ? 0.4 : 1.0)
                }
            }
        }
    }

    // MARK: - Session Section

    private var sessionSection: some View {
        VStack(alignment: .leading, spacing: CTRLSpacing.sm) {
            CTRLSectionHeader(title: "Session")

            SurfaceCard(padding: 0, cornerRadius: CTRLSpacing.cardRadius) {
                VStack(spacing: 0) {
                    // Strict mode toggle row
                    HStack {
                        VStack(alignment: .leading, spacing: CTRLSpacing.micro) {
                            Text("strict mode")
                                .font(CTRLFonts.bodyFont)
                                .foregroundColor(CTRLColors.textPrimary)

                            Text("prevents app deletion and installation during sessions")
                                .font(CTRLFonts.bodySmall)
                                .foregroundColor(CTRLColors.textTertiary)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Spacer()

                        Toggle("", isOn: Binding(
                            get: { appState.strictModeEnabled },
                            set: { newValue in
                                if newValue {
                                    activeAlert = .strictMode
                                } else {
                                    let generator = UIImpactFeedbackGenerator(style: .light)
                                    generator.impactOccurred()
                                    appState.strictModeEnabled = false
                                    appState.saveState()
                                    Task { @MainActor in
                                        CloudSyncManager.shared.syncToCloud(appState: appState)
                                    }
                                }
                            }
                        ))
                        .labelsHidden()
                        .tint(CTRLColors.accent)
                        .disabled(blockingManager.isBlocking)
                    }
                    .padding(CTRLSpacing.md)
                    .opacity(blockingManager.isBlocking ? 0.5 : 1.0)

                    if blockingManager.isBlocking {
                        CTRLDivider()

                        Text("can't change during an active session")
                            .font(CTRLFonts.micro)
                            .foregroundColor(CTRLColors.textTertiary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, CTRLSpacing.md)
                            .padding(.vertical, CTRLSpacing.sm)
                    }
                }
            }
        }
    }

    // MARK: - Override Section

    private var overrideSection: some View {
        VStack(alignment: .leading, spacing: CTRLSpacing.sm) {
            CTRLSectionHeader(title: "Override")

            SurfaceCard(padding: CTRLSpacing.cardPadding, cornerRadius: CTRLSpacing.cardRadius) {
                VStack(spacing: CTRLSpacing.md) {
                    HStack {
                        Text("remaining")
                            .font(CTRLFonts.bodyFont)
                            .foregroundColor(CTRLColors.textSecondary)

                        Spacer()

                        Text("\(appState.emergencyUnlocksRemaining)/5")
                            .font(CTRLFonts.bodyFont)
                            .foregroundColor(CTRLColors.textPrimary)
                            .monospacedDigit()
                    }

                    if appState.emergencyUnlocksRemaining < 5 {
                        HStack {
                            Text("resets in")
                                .font(CTRLFonts.bodyFont)
                                .foregroundColor(CTRLColors.textSecondary)

                            Spacer()

                            Text(resetCountdown)
                                .font(CTRLFonts.bodySmall)
                                .foregroundColor(CTRLColors.textTertiary)
                                .monospacedDigit()
                        }
                        .onAppear { updateResetCountdown() }
                        .onReceive(Timer.publish(every: 60, on: .main, in: .common).autoconnect()) { _ in
                            updateResetCountdown()
                        }
                    }

                    if (blockingManager.isBlocking || (FeatureFlags.schedulesEnabled && scheduleManager.activeScheduleId != nil)) && appState.emergencyUnlocksRemaining > 0 {
                        CTRLDivider()

                        Button(action: { activeAlert = .override }) {
                            Text("end session without ctrl")
                                .font(CTRLFonts.bodySmall)
                                .foregroundColor(CTRLColors.accent)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
            }
        }
    }

    private func updateResetCountdown() {
        guard let resetDate = appState.nextOverrideResetDate() else {
            resetCountdown = ""
            return
        }

        let components = Calendar.current.dateComponents([.day, .hour, .minute], from: Date(), to: resetDate)
        let d = components.day ?? 0
        let h = components.hour ?? 0
        let m = components.minute ?? 0

        resetCountdown = String(format: "%02dd %02dh %02dm", d, h, m)
    }

    // MARK: - FAQ Section

    private var faqSection: some View {
        VStack(alignment: .leading, spacing: CTRLSpacing.sm) {
            CTRLSectionHeader(title: "FAQ")

            SurfaceCard(padding: 0, cornerRadius: CTRLSpacing.cardRadius) {
                VStack(spacing: 0) {
                    faqRow(
                        id: "what",
                        question: "What is CTRL?",
                        answer: "CTRL helps you create focus time by pausing distracting apps. Tap your CTRL on your phone to start a session, tap again to end it. A simple, physical way to set boundaries."
                    )

                    CTRLDivider()

                    faqRow(
                        id: "device",
                        question: "How does the device work?",
                        answer: "Your CTRL has a secure chip inside. When you tap it on your phone, the app checks it's genuine and starts or ends your focus session. Everything happens on your device. No internet needed."
                    )

                    CTRLDivider()

                    faqRow(
                        id: "share",
                        question: "Can I share it with others?",
                        answer: "Sure. Any genuine CTRL works with any account. You can pass it around to roommates, family, or friends so multiple people can use it across their phones."
                    )

                    CTRLDivider()

                    faqRow(
                        id: "lost",
                        question: "What if I lose my CTRL?",
                        answer: "Just order a new one from getctrl.in. There's no pairing step. Any authentic CTRL will work instantly with your app."
                    )

                    CTRLDivider()

                    faqRow(
                        id: "override",
                        question: "What are emergency overrides?",
                        answer: "You have 5 emergency unlocks each month in case something urgent comes up. They reset monthly from the day you signed up. Use them only when you really need to."
                    )

                    CTRLDivider()

                    faqRow(
                        id: "privacy",
                        question: "Is my data private?",
                        answer: "Which apps you choose to pause and how you use them stays only on your phone. We never see your app list, your browsing, or anything else."
                    )
                }
            }
        }
    }

    private func faqRow(id: String, question: String, answer: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: {
                withAnimation(.easeOut(duration: 0.2)) {
                    if expandedFAQ == id {
                        expandedFAQ = nil
                    } else {
                        expandedFAQ = id
                    }
                }
            }) {
                HStack {
                    Text(question)
                        .font(CTRLFonts.bodyFont)
                        .foregroundColor(CTRLColors.textPrimary)
                        .multilineTextAlignment(.leading)

                    Spacer()

                    Image(systemName: expandedFAQ == id ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(CTRLColors.textTertiary)
                }
                .padding(CTRLSpacing.md)
            }

            if expandedFAQ == id {
                Text(answer)
                    .font(CTRLFonts.bodySmall)
                    .foregroundColor(CTRLColors.textSecondary)
                    .padding(.horizontal, CTRLSpacing.md)
                    .padding(.bottom, CTRLSpacing.md)
                    .transition(.opacity)
            }
        }
    }

    // MARK: - Cloud Sync Section

    private var cloudSyncSection: some View {
        VStack(alignment: .leading, spacing: CTRLSpacing.sm) {
            CTRLSectionHeader(title: "Cloud Sync")

            SurfaceCard(padding: 0, cornerRadius: CTRLSpacing.cardRadius) {
                VStack(spacing: 0) {
                    // What syncs
                    VStack(alignment: .leading, spacing: CTRLSpacing.xs) {
                        Text("synced across devices")
                            .font(CTRLFonts.bodyFont)
                            .foregroundColor(CTRLColors.textSecondary)

                        Text("mode names, focus history, emergency overrides, app selections (encrypted)")
                            .font(CTRLFonts.bodySmall)
                            .foregroundColor(CTRLColors.textTertiary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(CTRLSpacing.md)

                    CTRLDivider()

                    // Encryption explanation
                    VStack(alignment: .leading, spacing: CTRLSpacing.xs) {
                        Text("end-to-end encrypted")
                            .font(CTRLFonts.bodyFont)
                            .foregroundColor(CTRLColors.textSecondary)

                        Text("your app selections are encrypted on-device before syncing — we never see your app list")
                            .font(CTRLFonts.bodySmall)
                            .foregroundColor(CTRLColors.textTertiary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(CTRLSpacing.md)

                    CTRLDivider()

                    // Delete button
                    Button(action: { activeAlert = .deleteData }) {
                        HStack {
                            Text("delete my email & data")
                                .font(CTRLFonts.bodyFont)
                                .foregroundColor(CTRLColors.destructive)

                            Spacer()

                            if isDeletingData {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: CTRLColors.destructive))
                            }
                        }
                        .padding(CTRLSpacing.md)
                    }
                    .disabled(isDeletingData || blockingManager.isBlocking)
                    .opacity(blockingManager.isBlocking ? 0.4 : 1.0)
                }
            }
        }
    }

    // MARK: - Support Section

    private var supportSection: some View {
        VStack(alignment: .leading, spacing: CTRLSpacing.sm) {
            CTRLSectionHeader(title: "Support")

            SurfaceCard(padding: 0, cornerRadius: CTRLSpacing.cardRadius) {
                VStack(spacing: 0) {
                    // Contact Us
                    Link(destination: URL(string: "mailto:hello@getctrl.in")!) {
                        HStack {
                            Text("contact us")
                                .font(CTRLFonts.bodyFont)
                                .foregroundColor(CTRLColors.textPrimary)

                            Spacer()

                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 10))
                                .foregroundColor(CTRLColors.textTertiary)
                        }
                        .padding(CTRLSpacing.cardPadding)
                    }

                    CTRLDivider()
                        .padding(.leading, CTRLSpacing.cardPadding)

                    // Website
                    Link(destination: URL(string: "https://www.getctrl.in")!) {
                        HStack {
                            Text("website")
                                .font(CTRLFonts.bodyFont)
                                .foregroundColor(CTRLColors.textPrimary)

                            Spacer()

                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 10))
                                .foregroundColor(CTRLColors.textTertiary)
                        }
                        .padding(CTRLSpacing.cardPadding)
                    }

                    CTRLDivider()
                        .padding(.leading, CTRLSpacing.cardPadding)

                    // Privacy Policy
                    Link(destination: URL(string: "https://www.getctrl.in/privacy")!) {
                        HStack {
                            Text("privacy policy")
                                .font(CTRLFonts.bodyFont)
                                .foregroundColor(CTRLColors.textPrimary)

                            Spacer()

                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 10))
                                .foregroundColor(CTRLColors.textTertiary)
                        }
                        .padding(CTRLSpacing.cardPadding)
                    }
                }
            }
        }
    }

    // MARK: - Footer

    private var footerSection: some View {
        VStack(spacing: CTRLSpacing.sm) {
            // Version
            HStack {
                Text("version")
                    .font(CTRLFonts.bodyFont)
                    .foregroundColor(CTRLColors.textSecondary)

                Spacer()

                Text("1.0.0")
                    .font(CTRLFonts.bodyFont)
                    .foregroundColor(CTRLColors.textTertiary)
            }

            // Tagline
            Text("made with intent")
                .font(CTRLFonts.bodySmall)
                .foregroundColor(CTRLColors.textTertiary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, CTRLSpacing.sm)
        }
    }

    // MARK: - Actions

    private func signOut() {
        activeAlert = .signOut
    }

    private func performSignOut() {
        Task {
            do {
                try await SupabaseManager.shared.signOut()
                await MainActor.run {
                    // Clear auth state only
                    appState.userEmail = nil
                    appState.hasCompletedOnboarding = false
                    appState.saveState()

                    // Modes, focus history, app selections remain intact
                }
            } catch {
                #if DEBUG
                print("[Settings] Sign out failed: \(error)")
                #endif
            }
        }
    }

    private func performDeleteData() {
        isDeletingData = true
        Task {
            do {
                try await CloudSyncManager.shared.deleteCloudData()
                try await SupabaseManager.shared.signOut()
                await MainActor.run {
                    isDeletingData = false
                    appState.userEmail = nil
                    appState.hasCompletedOnboarding = false
                    appState.saveState()
                }
            } catch {
                await MainActor.run {
                    isDeletingData = false
                }
                #if DEBUG
                print("[Settings] Delete data failed: \(error)")
                #endif
            }
        }
    }
}
