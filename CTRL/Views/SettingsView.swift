import SwiftUI
import FamilyControls

struct SettingsView: View {

    // MARK: - Environment

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var blockingManager: BlockingManager
    @StateObject private var nfcManager = NFCManager()

    // MARK: - State

    @State private var showRepairAlert = false
    @State private var showUnpairAlert = false
    @State private var showUnlockAlert = false
    @State private var showNoUnlocksAlert = false

    // Mode management state
    @State private var showAddModeAlert = false
    @State private var newModeName = ""
    @State private var modeToEdit: BlockingMode? = nil
    @State private var showDeleteConfirm = false
    @State private var modeToDelete: BlockingMode? = nil
    @State private var showDuplicateNameAlert = false
    @State private var currentTime = Date()
    @State private var showStats = false

    // MARK: - Body

    var body: some View {
        NavigationView {
            ZStack {
                CTRLColors.background
                    .ignoresSafeArea()

                List {
                    focusTimeSection
                    modesSection
                    tokenSection
                    emergencySection
                    aboutSection
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(CTRLColors.accent)
                }
            }
            .toolbarColorScheme(.dark, for: .navigationBar)
            .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
                if blockingManager.isBlocking {
                    currentTime = Date()
                }
            }
        }
        .alert("New Mode", isPresented: $showAddModeAlert) {
            TextField("Mode name", text: $newModeName)
            Button("Cancel", role: .cancel) { newModeName = "" }
            Button("Add") {
                let trimmed = newModeName.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    let isDuplicate = appState.modes.contains { $0.name.lowercased() == trimmed.lowercased() }
                    if isDuplicate {
                        newModeName = ""
                        showDuplicateNameAlert = true
                    } else if let newMode = appState.addMode(name: trimmed) {
                        appState.setActiveMode(id: newMode.id)
                        newModeName = ""
                    }
                }
            }
        } message: {
            Text("Enter a name for this mode")
        }
        .alert("Delete Mode?", isPresented: $showDeleteConfirm) {
            Button("Cancel", role: .cancel) { modeToDelete = nil }
            Button("Delete", role: .destructive) {
                if let mode = modeToDelete {
                    appState.deleteMode(id: mode.id)
                }
                modeToDelete = nil
            }
        } message: {
            Text("This will delete \"\(modeToDelete?.name ?? "")\" and its app list.")
        }
        .alert("Duplicate Name", isPresented: $showDuplicateNameAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("A mode with this name already exists. Please choose a different name.")
        }
        .sheet(item: $modeToEdit) { mode in
            EditModeView(mode: mode)
                .environmentObject(appState)
                .environmentObject(blockingManager)
        }
        .sheet(isPresented: $showStats) {
            StatsView()
                .environmentObject(appState)
        }
    }

    // MARK: - Section 0: Focus Time

    private var focusTimeSection: some View {
        Section("Focus Time") {
            HStack {
                Label("Today", systemImage: "sun.max")
                    .foregroundColor(CTRLColors.textPrimary)
                Spacer()
                let _ = currentTime
                Text(AppState.formatTime(appState.todayFocusSeconds))
                    .foregroundColor(CTRLColors.textSecondary)
                    .monospacedDigit()
            }

            HStack {
                Label("This Week", systemImage: "calendar")
                    .foregroundColor(CTRLColors.textPrimary)
                Spacer()
                let _ = currentTime
                Text(AppState.formatTime(appState.weekFocusSeconds))
                    .foregroundColor(CTRLColors.textSecondary)
                    .monospacedDigit()
            }

            HStack {
                Label("This Month", systemImage: "calendar.badge.clock")
                    .foregroundColor(CTRLColors.textPrimary)
                Spacer()
                let _ = currentTime
                Text(AppState.formatTime(appState.monthFocusSeconds))
                    .foregroundColor(CTRLColors.textSecondary)
                    .monospacedDigit()
            }

            Button {
                showStats = true
            } label: {
                HStack {
                    Label("View Stats", systemImage: "chart.bar")
                        .foregroundColor(CTRLColors.accent)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(CTRLColors.textMuted)
                }
            }
        }
        .listRowBackground(CTRLColors.cardBackground)
    }

    // MARK: - Section 1: Modes

    private var modesSection: some View {
        Section("Modes") {
            ForEach(appState.modes) { mode in
                let isActive = appState.activeModeId == mode.id
                let isLocked = blockingManager.isBlocking

                HStack {
                    // Radio button for active mode
                    Image(systemName: isActive ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(isActive ? CTRLColors.accent : CTRLColors.textSecondary)
                        .font(.system(size: 20))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(mode.name)
                            .font(CTRLFonts.headline())
                            .foregroundColor(CTRLColors.textPrimary)
                        Text("\(mode.appCount) app\(mode.appCount == 1 ? "" : "s")")
                            .font(CTRLFonts.caption())
                            .foregroundColor(CTRLColors.textSecondary)
                    }

                    Spacer()

                    // Edit button
                    Button(action: {
                        modeToEdit = mode
                    }) {
                        Image(systemName: "pencil")
                            .foregroundColor(CTRLColors.textSecondary)
                    }
                    .buttonStyle(.plain)
                    .disabled(isActive && isLocked)
                    .opacity(isActive && isLocked ? 0.4 : 1.0)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    if !isLocked {
                        appState.setActiveMode(id: mode.id)
                    }
                }
                .opacity(isLocked && !isActive ? 0.5 : 1.0)
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    if appState.modes.count > 1 && !(isActive && isLocked) {
                        Button(role: .destructive) {
                            modeToDelete = mode
                            showDeleteConfirm = true
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }

            // Add mode button
            if appState.modes.count < 6 {
                Button {
                    showAddModeAlert = true
                } label: {
                    Label("Add Mode", systemImage: "plus.circle")
                        .foregroundColor(CTRLColors.accent)
                }
                .disabled(blockingManager.isBlocking)
                .opacity(blockingManager.isBlocking ? 0.4 : 1.0)
            } else {
                Text("Maximum 6 modes reached")
                    .font(CTRLFonts.caption())
                    .foregroundColor(CTRLColors.textMuted)
            }
        }
        .listRowBackground(CTRLColors.cardBackground)
    }

    // MARK: - Section 2: Token

    private var tokenSection: some View {
        Section {
            // Paired token display
            HStack {
                Label("Paired Token", systemImage: "wave.3.right")
                    .foregroundColor(CTRLColors.textPrimary)

                Spacer()

                Text(truncatedTokenID)
                    .font(CTRLFonts.mono())
                    .foregroundColor(CTRLColors.textSecondary)
            }

            // Re-pair button
            Button {
                showRepairAlert = true
            } label: {
                Label("Re-pair Token", systemImage: "arrow.triangle.2.circlepath")
                    .foregroundColor(CTRLColors.accent)
            }
            .alert("Replace Token?", isPresented: $showRepairAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Re-pair") {
                    performRepairScan()
                }
            } message: {
                Text("This will replace your current token. You'll need to use the new token to lock and unlock apps.")
            }

            // Unpair button
            Button {
                showUnpairAlert = true
            } label: {
                Label("Unpair Token", systemImage: "xmark.circle")
                    .foregroundColor(CTRLColors.danger)
            }
            .alert("Unpair Token?", isPresented: $showUnpairAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Unpair", role: .destructive) {
                    appState.unpairToken()
                    dismiss()
                }
            } message: {
                Text("This will remove your paired token and reset the app. You'll need to go through setup again.")
            }
        } header: {
            Text("Token")
                .foregroundColor(CTRLColors.textSecondary)
        }
        .listRowBackground(CTRLColors.cardBackground)
    }

    // MARK: - Section 3: Emergency

    private var emergencySection: some View {
        Section {
            HStack {
                Label("Remaining", systemImage: "exclamationmark.shield")
                    .foregroundColor(CTRLColors.textPrimary)

                Spacer()

                Text("\(appState.emergencyUnlocksRemaining) / 5")
                    .font(CTRLFonts.body())
                    .foregroundColor(CTRLColors.textSecondary)
            }

            if blockingManager.isBlocking {
                Button {
                    performEmergencyUnlock()
                } label: {
                    Label("Unlock Now", systemImage: "lock.open")
                        .foregroundColor(CTRLColors.warning)
                }
            }
        } header: {
            Text("Emergency")
                .foregroundColor(CTRLColors.textSecondary)
        } footer: {
            Text("Emergency unlocks reset monthly. Use these if you don't have your token.")
                .foregroundColor(CTRLColors.textMuted)
        }
        .listRowBackground(CTRLColors.cardBackground)
        .alert("Apps Unlocked", isPresented: $showUnlockAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Emergency unlock used. \(appState.emergencyUnlocksRemaining) remaining this month.")
        }
        .alert("No Unlocks Remaining", isPresented: $showNoUnlocksAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("You've used all 5 emergency unlocks this month. Use your NFC token to unlock, or wait until next month.")
        }
    }

    // MARK: - Section 4: About

    private var aboutSection: some View {
        Section {
            HStack {
                Label("Version", systemImage: "info.circle")
                    .foregroundColor(CTRLColors.textPrimary)
                Spacer()
                Text("1.0.0")
                    .font(CTRLFonts.body())
                    .foregroundColor(CTRLColors.textSecondary)
            }

            Link(destination: URL(string: "https://getctrl.in")!) {
                HStack {
                    Label("Website", systemImage: "globe")
                        .foregroundColor(CTRLColors.textPrimary)
                    Spacer()
                    Text("getctrl.in")
                        .font(CTRLFonts.body())
                        .foregroundColor(CTRLColors.textSecondary)
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 11))
                        .foregroundColor(CTRLColors.textMuted)
                }
            }

            Link(destination: URL(string: "https://getctrl.in/privacy")!) {
                HStack {
                    Label("Privacy Policy", systemImage: "hand.raised")
                        .foregroundColor(CTRLColors.textPrimary)
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 11))
                        .foregroundColor(CTRLColors.textMuted)
                }
            }
        } header: {
            Text("About")
                .foregroundColor(CTRLColors.textSecondary)
        }
        .listRowBackground(CTRLColors.cardBackground)
    }

    // MARK: - Helpers

    private var truncatedTokenID: String {
        guard let id = appState.pairedTokenID else { return "—" }
        if id.count > 8 {
            return "..." + String(id.suffix(8))
        }
        return id
    }

    // MARK: - Actions

    private func performEmergencyUnlock() {
        if appState.useEmergencyUnlock() {
            appState.stopBlockingTimer()
            blockingManager.deactivateBlocking()
            appState.isBlocking = false
            let feedback = UINotificationFeedbackGenerator()
            feedback.notificationOccurred(.success)
            showUnlockAlert = true
        } else {
            let feedback = UINotificationFeedbackGenerator()
            feedback.notificationOccurred(.error)
            showNoUnlocksAlert = true
        }
    }

    private func performRepairScan() {
        nfcManager.scan { result in
            switch result {
            case .success(let tagID):
                appState.pairToken(id: tagID)
                let feedback = UINotificationFeedbackGenerator()
                feedback.notificationOccurred(.success)

            case .failure(let error):
                if case NFCError.userCancelled = error {
                    return
                }
                print("Re-pair scan failed: \(error.localizedDescription)")
            }
        }
    }
}
