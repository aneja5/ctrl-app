import SwiftUI
import FamilyControls

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var blockingManager: BlockingManager
    @StateObject private var nfcManager = NFCManager()
    @Environment(\.dismiss) private var dismiss

    @State private var modeToEdit: BlockingMode? = nil
    @State private var showOverrideConfirm = false
    @State private var showUnpairConfirm = false

    var body: some View {
        ZStack {
            CTRLColors.base.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: CTRLSpacing.xl) {
                    // Header
                    header
                        .padding(.top, CTRLSpacing.md)

                    // Modes Section
                    modesSection

                    // Override Section
                    overrideSection

                    // Token Section
                    tokenSection

                    // System Section
                    systemSection

                    Spacer(minLength: 60)
                }
                .padding(.horizontal, CTRLSpacing.screenPadding)
            }
        }
        .sheet(item: $modeToEdit) { mode in
            EditModeView(mode: mode)
                .environmentObject(appState)
                .presentationBackground(CTRLColors.base)
        }
        .alert("Override Session", isPresented: $showOverrideConfirm) {
            Button("Cancel", role: .cancel) { }
            Button("Override", role: .destructive) {
                if appState.useEmergencyUnlock() {
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.warning)
                    appState.stopBlockingTimer()
                    blockingManager.deactivateBlocking()
                }
            }
        } message: {
            Text("End session without token? \(appState.emergencyUnlocksRemaining) overrides remaining.")
        }
        .alert("Unpair Token", isPresented: $showUnpairConfirm) {
            Button("Cancel", role: .cancel) { }
            Button("Unpair", role: .destructive) {
                appState.unpairToken()
            }
        } message: {
            Text("You'll need to pair a token again to use CTRL.")
        }
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
                                .padding(.leading, CTRLSpacing.screenPadding + 3)
                        }
                    }

                    if appState.modes.count < 6 {
                        CTRLDivider()
                            .padding(.leading, CTRLSpacing.screenPadding + 3)

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

        return HStack(spacing: 0) {
            // Active Indicator
            Rectangle()
                .fill(isActive ? CTRLColors.accent.opacity(0.7) : Color.clear)
                .frame(width: 3)

            // Mode Info
            VStack(alignment: .leading, spacing: CTRLSpacing.micro) {
                Text(mode.name.lowercased())
                    .font(CTRLFonts.bodyFont)
                    .foregroundColor(isActive ? CTRLColors.textPrimary : CTRLColors.textSecondary)

                Text("\(mode.appCount) app\(mode.appCount == 1 ? "" : "s") in scope")
                    .font(CTRLFonts.micro)
                    .foregroundColor(CTRLColors.textTertiary)
            }
            .padding(.leading, CTRLSpacing.md)

            Spacer()

            // Edit Button (disabled for active mode during session)
            Button(action: { modeToEdit = mode }) {
                Image(systemName: "pencil")
                    .font(.system(size: 14))
                    .foregroundColor(editDisabled ? CTRLColors.textTertiary.opacity(0.3) : CTRLColors.textTertiary)
            }
            .disabled(editDisabled)
            .padding(.trailing, CTRLSpacing.md)
        }
        .frame(height: 68)
        .contentShape(Rectangle())
        .onTapGesture {
            if !blockingManager.isBlocking {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                appState.setActiveMode(id: mode.id)
            }
        }
    }

    private var addModeRow: some View {
        Button(action: {
            if let newMode = appState.addMode(name: "New Mode") {
                modeToEdit = newMode
            }
        }) {
            HStack(spacing: 0) {
                Rectangle()
                    .fill(Color.clear)
                    .frame(width: 3)

                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(CTRLColors.textTertiary)
                    .padding(.leading, CTRLSpacing.md)

                Text("add mode")
                    .font(CTRLFonts.bodyFont)
                    .foregroundColor(CTRLColors.textTertiary)
                    .padding(.leading, CTRLSpacing.sm)

                Spacer()
            }
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

                        Text("\(appState.emergencyUnlocksRemaining) of 5")
                            .font(CTRLFonts.bodyFont)
                            .foregroundColor(CTRLColors.textPrimary)
                            .monospacedDigit()
                    }

                    if blockingManager.isBlocking && !appState.strictModeEnabled && appState.emergencyUnlocksRemaining > 0 {
                        CTRLDivider()

                        Button(action: { showOverrideConfirm = true }) {
                            Text("end session without token")
                                .font(CTRLFonts.bodySmall)
                                .foregroundColor(CTRLColors.accent)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Token Section

    private var tokenSection: some View {
        VStack(alignment: .leading, spacing: CTRLSpacing.sm) {
            CTRLSectionHeader(title: "Token")

            SurfaceCard(padding: 0, cornerRadius: CTRLSpacing.cardRadius) {
                VStack(spacing: 0) {
                    // Paired
                    HStack {
                        Text("paired")
                            .font(CTRLFonts.bodyFont)
                            .foregroundColor(CTRLColors.textSecondary)

                        Spacer()

                        Text(truncatedTokenID)
                            .font(CTRLFonts.micro)
                            .foregroundColor(CTRLColors.textTertiary)
                            .monospaced()
                    }
                    .padding(CTRLSpacing.cardPadding)

                    CTRLDivider()
                        .padding(.leading, CTRLSpacing.cardPadding)

                    // Re-pair
                    Button(action: repairToken) {
                        HStack {
                            Text("re-pair token")
                                .font(CTRLFonts.bodyFont)
                                .foregroundColor(CTRLColors.textPrimary)
                            Spacer()
                        }
                        .padding(CTRLSpacing.cardPadding)
                    }
                    .disabled(blockingManager.isBlocking)

                    CTRLDivider()
                        .padding(.leading, CTRLSpacing.cardPadding)

                    // Unpair
                    Button(action: { showUnpairConfirm = true }) {
                        HStack {
                            Text("unpair token")
                                .font(CTRLFonts.bodyFont)
                                .foregroundColor(CTRLColors.destructive)
                            Spacer()
                        }
                        .padding(CTRLSpacing.cardPadding)
                    }
                    .disabled(blockingManager.isBlocking)
                }
            }
            .opacity(blockingManager.isBlocking ? 0.5 : 1.0)
        }
    }

    private var truncatedTokenID: String {
        guard let tokenID = appState.pairedTokenID else { return "—" }
        if tokenID.count > 12 {
            return "···" + String(tokenID.suffix(8))
        }
        return tokenID
    }

    private func repairToken() {
        nfcManager.scan { result in
            switch result {
            case .success(let tagID):
                appState.pairToken(id: tagID)
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            case .failure(let error):
                print("[Settings] Re-pair failed: \(error)")
            }
        }
    }

    // MARK: - System Section

    private var systemSection: some View {
        VStack(alignment: .leading, spacing: CTRLSpacing.sm) {
            CTRLSectionHeader(title: "System")

            SurfaceCard(padding: 0, cornerRadius: CTRLSpacing.cardRadius) {
                VStack(spacing: 0) {
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
                    .padding(CTRLSpacing.cardPadding)

                    CTRLDivider()
                        .padding(.leading, CTRLSpacing.cardPadding)

                    // Website
                    Link(destination: URL(string: "https://getctrl.in")!) {
                        HStack {
                            Text("website")
                                .font(CTRLFonts.bodyFont)
                                .foregroundColor(CTRLColors.textPrimary)

                            Spacer()

                            Text("getctrl.in")
                                .font(CTRLFonts.micro)
                                .foregroundColor(CTRLColors.textTertiary)

                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 10))
                                .foregroundColor(CTRLColors.textTertiary)
                        }
                        .padding(CTRLSpacing.cardPadding)
                    }

                    CTRLDivider()
                        .padding(.leading, CTRLSpacing.cardPadding)

                    // Privacy
                    Link(destination: URL(string: "https://getctrl.in/privacy")!) {
                        HStack {
                            Text("privacy")
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
}
