import SwiftUI
import FamilyControls

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var blockingManager: BlockingManager
    @Environment(\.dismiss) private var dismiss

    @State private var showEditModeSheet = false
    @State private var editingMode: BlockingMode? = nil
    @State private var isAddingNewMode = false
    @State private var showOverrideConfirm = false
    @State private var showSignOutAlert = false
    @State private var expandedFAQ: String? = nil

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

                    // Modes
                    modesSection

                    // Override
                    overrideSection

                    // FAQ
                    faqSection

                    // Support
                    supportSection

                    // Footer
                    footerSection

                    Spacer(minLength: 40)
                }
                .padding(.horizontal, CTRLSpacing.screenPadding)
            }
        }
        .sheet(isPresented: $showEditModeSheet) {
            EditModeView(
                mode: editingMode,
                isNewMode: isAddingNewMode,
                onSave: { savedMode in
                    if isAddingNewMode {
                        appState.addMode(savedMode)
                    } else {
                        appState.updateMode(savedMode)
                    }
                },
                onCancel: { }
            )
            .environmentObject(appState)
            .presentationBackground(CTRLColors.base)
        }
        .alert("override session", isPresented: $showOverrideConfirm) {
            Button("cancel", role: .cancel) { }
            Button("override", role: .destructive) {
                if appState.useEmergencyUnlock() {
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.warning)
                    appState.stopBlockingTimer()
                    blockingManager.deactivateBlocking()
                }
            }
        } message: {
            Text("end session without your ctrl? \(appState.emergencyUnlocksRemaining) overrides remaining.")
        }
        .alert("sign out?", isPresented: $showSignOutAlert) {
            Button("cancel", role: .cancel) { }
            Button("sign out", role: .destructive) {
                performSignOut()
            }
        } message: {
            Text("you'll need to sign in again. your modes and history will be kept on this device.")
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

            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(CTRLColors.textTertiary)
                    .frame(width: 36, height: 36)
                    .background(CTRLColors.surface1)
                    .clipShape(Circle())
            }
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
                }
            }
        }
    }

    // MARK: - Modes Section

    private var modesSection: some View {
        VStack(alignment: .leading, spacing: CTRLSpacing.sm) {
            CTRLSectionHeader(title: "Modes")

            SurfaceCard(padding: 0, cornerRadius: CTRLSpacing.cardRadius) {
                VStack(spacing: 0) {
                    ForEach(Array(appState.modes.enumerated()), id: \.element.id) { index, mode in
                        modeRow(mode: mode)

                        if index < appState.modes.count - 1 {
                            CTRLDivider()
                        }
                    }

                    if appState.modes.count < 6 {
                        CTRLDivider()

                        addModeRow
                    }
                }
            }
        }
    }

    private var isActiveModeLocked: Bool {
        blockingManager.isBlocking
    }

    private func modeRow(mode: BlockingMode) -> some View {
        let isActive = appState.activeModeId == mode.id
        let editDisabled = isActive && isActiveModeLocked

        return Button(action: {
            if !editDisabled {
                isAddingNewMode = false
                editingMode = mode
                showEditModeSheet = true
            }
        }) {
            HStack {
                // Mode Info
                VStack(alignment: .leading, spacing: CTRLSpacing.micro) {
                    Text(mode.name.lowercased())
                        .font(CTRLFonts.bodyFont)
                        .foregroundColor(isActive ? CTRLColors.textPrimary : CTRLColors.textSecondary)

                    Text("\(mode.appCount) \(mode.appCount == 1 ? "app" : "apps")")
                        .font(CTRLFonts.micro)
                        .tracking(1)
                        .foregroundColor(CTRLColors.textTertiary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(editDisabled ? CTRLColors.textTertiary.opacity(0.3) : CTRLColors.textTertiary)
            }
            .padding(.horizontal, CTRLSpacing.md)
            .frame(height: 68)
            .contentShape(Rectangle())
        }
        .disabled(editDisabled)
    }

    private var addModeRow: some View {
        Button(action: {
            isAddingNewMode = true
            editingMode = nil
            showEditModeSheet = true
        }) {
            HStack {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(CTRLColors.textTertiary)

                Text("add mode")
                    .font(CTRLFonts.bodyFont)
                    .foregroundColor(CTRLColors.textTertiary)
                    .padding(.leading, CTRLSpacing.sm)

                Spacer()
            }
            .padding(.horizontal, CTRLSpacing.md)
            .frame(height: 56)
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

                    if blockingManager.isBlocking && !appState.strictModeEnabled && appState.emergencyUnlocksRemaining > 0 {
                        CTRLDivider()

                        Button(action: { showOverrideConfirm = true }) {
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
                        answer: "You have 5 emergency unlocks each month in case something urgent comes up. They reset on the 1st. Use them only when you really need to."
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
        showSignOutAlert = true
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
                print("[Settings] Sign out failed: \(error)")
            }
        }
    }
}
