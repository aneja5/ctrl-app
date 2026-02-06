import SwiftUI
import FamilyControls

struct SettingsView: View {

    // MARK: - Environment

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appState: AppState
    @StateObject private var nfcManager = NFCManager()

    // MARK: - State

    @State private var showAppPicker = false
    @State private var pickerSelection = FamilyActivitySelection()
    @State private var showRepairAlert = false
    @State private var showUnpairAlert = false

    // MARK: - Body

    var body: some View {
        NavigationView {
            ZStack {
                CTRLColors.background
                    .ignoresSafeArea()

                List {
                    blockedAppsSection
                    tokenSection
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
        }
        .familyActivityPicker(
            isPresented: $showAppPicker,
            selection: $pickerSelection
        )
        .onChange(of: pickerSelection) {
            appState.saveSelectedApps(pickerSelection)
        }
        .onAppear {
            pickerSelection = appState.selectedApps
        }
    }

    // MARK: - Section 1: Blocked Apps

    private var blockedAppsSection: some View {
        Section {
            Button {
                showAppPicker = true
            } label: {
                HStack {
                    Label("Manage Apps", systemImage: "square.grid.2x2")
                        .foregroundColor(CTRLColors.textPrimary)

                    Spacer()

                    Text("\(appCount)")
                        .font(CTRLFonts.body())
                        .foregroundColor(CTRLColors.textSecondary)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(CTRLColors.textMuted)
                }
            }
        } header: {
            Text("Blocked Apps")
                .foregroundColor(CTRLColors.textSecondary)
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

    // MARK: - Section 3: About

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

    private var appCount: Int {
        appState.selectedApps.applicationTokens.count + appState.selectedApps.categoryTokens.count
    }

    private var truncatedTokenID: String {
        guard let id = appState.pairedTokenID else { return "—" }
        if id.count > 8 {
            return "..." + String(id.suffix(8))
        }
        return id
    }

    // MARK: - Actions

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
