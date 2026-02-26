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
    @State private var emergencyExpanded: Bool = false
    @State private var showDeleteError = false

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
                    if featureEnabled(.strictMode) {
                        sessionSection
                    }

                    // Override
                    if featureEnabled(.emergencyOverrides) {
                        overrideSection
                    }

                    // FAQ
                    faqSection

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
            activeAlert == .override ? "use emergency override?" :
            activeAlert == .signOut ? "sign out?" :
            activeAlert == .strictMode ? "enable strict mode?" : "delete all data?",
            isPresented: Binding(
                get: { activeAlert != nil },
                set: { if !$0 { activeAlert = nil } }
            ),
            presenting: activeAlert
        ) { alert in
            switch alert {
            case .override:
                Button("cancel", role: .cancel) { }
                Button("use override", role: .destructive) {
                    if appState.useEmergencyUnlock() {
                        let generator = UINotificationFeedbackGenerator()
                        generator.notificationOccurred(.warning)
                        appState.stopBlockingTimer()
                        if blockingManager.isBlocking {
                            blockingManager.deactivateBlocking()
                        }
                        if featureEnabled(.schedules) && scheduleManager.activeScheduleId != nil {
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
                    if featureEnabled(.cloudSync) {
                        Task { @MainActor in
                            CloudSyncManager.shared.syncToCloud(appState: appState)
                        }
                    }
                }
            }
        } message: { alert in
            switch alert {
            case .override:
                Text("this will end your session immediately. you have \(appState.emergencyUnlocksRemaining) remaining. using one resets your 7-day earn-back progress.")
            case .signOut:
                Text("your modes and stats are safely synced to the cloud. sign back in anytime to pick up where you left off.")
            case .deleteData:
                Text("this permanently erases your account, email, and all data from our servers and this device. this cannot be undone.")
            case .strictMode:
                Text("while in a session, you won't be able to delete apps from your device. you can still use emergency overrides if needed.")
            }
        }
        .alert("couldn't delete data", isPresented: $showDeleteError) {
            Button("try again") { performDeleteData() }
            Button("cancel", role: .cancel) { }
        } message: {
            Text("check your internet connection and try again.")
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
                                    if featureEnabled(.cloudSync) {
                                        Task { @MainActor in
                                            CloudSyncManager.shared.syncToCloud(appState: appState)
                                        }
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

                        Text("strict mode can't be changed during a session")
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

            SurfaceCard(padding: 0, cornerRadius: CTRLSpacing.cardRadius) {
                VStack(spacing: 0) {
                    // Collapsed header — tap to expand
                    Button(action: {
                        withAnimation(.easeOut(duration: 0.2)) {
                            emergencyExpanded.toggle()
                        }
                    }) {
                        HStack(spacing: CTRLSpacing.sm) {
                            Image(systemName: "shield.lefthalf.filled")
                                .font(.system(size: 16))
                                .foregroundColor(overrideColor)

                            Text("emergency overrides")
                                .font(CTRLFonts.bodyFont)
                                .foregroundColor(CTRLColors.textPrimary)

                            Spacer()

                            Text("\(appState.emergencyUnlocksRemaining)")
                                .font(CTRLFonts.bodyFont)
                                .foregroundColor(overrideColor)
                                .monospacedDigit()

                            Image(systemName: emergencyExpanded ? "chevron.up" : "chevron.down")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(CTRLColors.textTertiary)
                        }
                        .padding(CTRLSpacing.cardPadding)
                    }
                    .buttonStyle(PlainButtonStyle())

                    if emergencyExpanded {
                        CTRLDivider()
                            .padding(.horizontal, CTRLSpacing.cardPadding)

                        VStack(alignment: .leading, spacing: CTRLSpacing.md) {
                            // 5-dot visualization
                            HStack(spacing: CTRLSpacing.xs) {
                                ForEach(0..<AppConstants.maxOverrides, id: \.self) { index in
                                    Circle()
                                        .fill(index < appState.emergencyUnlocksRemaining ? overrideColor : CTRLColors.surface2)
                                        .frame(width: 10, height: 10)
                                        .overlay(
                                            Circle()
                                                .stroke(index < appState.emergencyUnlocksRemaining ? overrideColor.opacity(0.5) : CTRLColors.border, lineWidth: 1)
                                        )
                                }
                                Spacer()
                            }

                            // Earn-back progress (only if below max and has used an override)
                            if appState.emergencyUnlocksRemaining < AppConstants.maxOverrides,
                               appState.lastOverrideUsedDate != nil {
                                VStack(alignment: .leading, spacing: CTRLSpacing.micro) {
                                    GeometryReader { geo in
                                        ZStack(alignment: .leading) {
                                            RoundedRectangle(cornerRadius: 3)
                                                .fill(CTRLColors.surface2)
                                                .frame(height: 6)

                                            RoundedRectangle(cornerRadius: 3)
                                                .fill(CTRLColors.accent)
                                                .frame(
                                                    width: geo.size.width * CGFloat(appState.overrideEarnBackDays) / CGFloat(AppConstants.earnBackStreakDays),
                                                    height: 6
                                                )
                                        }
                                    }
                                    .frame(height: 6)

                                    Text(earnBackLabel)
                                        .font(CTRLFonts.micro)
                                        .foregroundColor(CTRLColors.textTertiary)
                                }
                            } else if appState.emergencyUnlocksRemaining >= AppConstants.maxOverrides {
                                Text("fully stocked")
                                    .font(CTRLFonts.micro)
                                    .foregroundColor(CTRLColors.textTertiary)
                            }

                            // Explanation
                            Text("earn overrides back by focusing 10+ min for 7 consecutive days after using one.")
                                .font(CTRLFonts.bodySmall)
                                .foregroundColor(CTRLColors.textTertiary)
                                .fixedSize(horizontal: false, vertical: true)

                            // Use override button (only during session, when overrides > 0)
                            if (blockingManager.isBlocking || (featureEnabled(.schedules) && scheduleManager.activeScheduleId != nil)) && appState.emergencyUnlocksRemaining > 0 {
                                CTRLDivider()

                                Button(action: { activeAlert = .override }) {
                                    Text("use emergency override")
                                        .font(CTRLFonts.bodySmall)
                                        .foregroundColor(CTRLColors.accent)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                        }
                        .padding(CTRLSpacing.cardPadding)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
            }
        }
    }

    private var overrideColor: Color {
        switch appState.emergencyUnlocksRemaining {
        case 0: return CTRLColors.destructive
        case 1: return Color.orange
        default: return CTRLColors.accent
        }
    }

    private var earnBackLabel: String {
        let days = appState.overrideEarnBackDays
        let remaining = AppConstants.earnBackStreakDays - days
        if days == 0 {
            return "focus 7 days to earn another"
        } else if remaining == 1 {
            return "\(days) of 7 days — 1 more to go"
        } else {
            return "\(days) of 7 days to earn another"
        }
    }

    // MARK: - FAQ Section

    private var faqSection: some View {
        VStack(alignment: .leading, spacing: CTRLSpacing.sm) {
            CTRLSectionHeader(title: "FAQ")

            SurfaceCard(padding: 0, cornerRadius: CTRLSpacing.cardRadius) {
                VStack(spacing: 0) {
                    faqRow(
                        id: "what",
                        question: "what is ctrl?",
                        answer: "ctrl helps you take back your time by pausing distracting apps. tap your tag to start a focus session, tap again to end it. a simple, physical ritual to set boundaries."
                    )

                    CTRLDivider()

                    faqRow(
                        id: "end",
                        question: "how do I end a session?",
                        answer: "tap your ctrl tag on your phone again — the app will end the session and unblock your apps instantly. if you started without a tag, you can use the 60-second countdown or an emergency override in settings."
                    )

                    CTRLDivider()

                    faqRow(
                        id: "notag",
                        question: "can I use ctrl without the tag?",
                        answer: "yes. long-press the lock in button to start a session without your tag. you'll still need to tap your tag to end it, or use the countdown timer."
                    )

                    CTRLDivider()

                    faqRow(
                        id: "modes",
                        question: "what are modes?",
                        answer: "modes let you block different apps for different situations. focus for work, sleep for bedtime, detox for a full break. pick the one that fits your moment."
                    )

                    CTRLDivider()

                    faqRow(
                        id: "strict",
                        question: "what is strict mode?",
                        answer: "when enabled, you can't delete apps from your phone during a session. it's an extra layer for when you really need to stay locked in. toggle it in settings."
                    )

                    CTRLDivider()

                    faqRow(
                        id: "override",
                        question: "what are emergency overrides?",
                        answer: "a safety net for when you truly need out. you start with 3 and can earn up to 5. use one and it ends your session immediately. earn them back by focusing 10+ minutes a day, 7 days in a row."
                    )

                    CTRLDivider()

                    faqRow(
                        id: "device",
                        question: "how does the tag work?",
                        answer: "your ctrl has a secure chip inside. when you tap it on your phone, the app verifies it's genuine and starts or ends your session. everything happens on-device. no internet needed."
                    )

                    CTRLDivider()

                    faqRow(
                        id: "offline",
                        question: "does ctrl work offline?",
                        answer: "yes. blocking and sessions work entirely on your device. your stats sync to the cloud when you're back online."
                    )

                    CTRLDivider()

                    faqRow(
                        id: "privacy",
                        question: "is my data private?",
                        answer: "your app selections never leave your phone. we encrypt them on-device before syncing anything. we never see which apps you block, your browsing, or anything personal."
                    )

                    CTRLDivider()

                    faqRow(
                        id: "lost",
                        question: "what if I lose my tag?",
                        answer: "order a new one from getctrl.in. there's no pairing — any genuine ctrl tag works instantly with your account."
                    )

                    CTRLDivider()

                    faqRow(
                        id: "share",
                        question: "can I share my tag?",
                        answer: "yes. any genuine ctrl works with any account. share it with friends or family — everyone's stats and modes stay separate since they sign in with their own email."
                    )

                    CTRLDivider()

                    faqRow(
                        id: "newphone",
                        question: "how do I get my data on a new phone?",
                        answer: "just sign in with the same email. your modes, stats, and settings sync automatically from the cloud."
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
            // Delete data
            SurfaceCard(padding: 0, cornerRadius: CTRLSpacing.cardRadius) {
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
            .padding(.top, CTRLSpacing.xs)

            #if DEBUG
            Button(action: {
                appState.injectDemoData()
            }) {
                Text("inject demo data")
                    .font(CTRLFonts.bodySmall)
                    .foregroundColor(CTRLColors.accent)
            }
            .padding(.top, CTRLSpacing.xs)
            #endif

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
                    // Deactivate blocking before wiping state to prevent brick scenario
                    if appState.isInSession {
                        appState.stopBlockingTimer()
                    }
                    blockingManager.deactivateBlocking()
                    appState.resetLocalData()
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
                    // Deactivate blocking before wiping state to prevent brick scenario
                    if appState.isInSession {
                        appState.stopBlockingTimer()
                    }
                    blockingManager.deactivateBlocking()
                    appState.resetLocalData()
                }
            } catch {
                await MainActor.run {
                    isDeletingData = false
                    showDeleteError = true
                }
                #if DEBUG
                print("[Settings] Delete data failed: \(error)")
                #endif
            }
        }
    }
}
