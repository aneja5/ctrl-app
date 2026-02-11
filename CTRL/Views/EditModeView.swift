import SwiftUI
import FamilyControls

struct EditModeView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    let mode: BlockingMode

    @State private var modeName: String = ""
    @State private var appSelection: FamilyActivitySelection = FamilyActivitySelection()
    @State private var showAppPicker: Bool = false
    @State private var showDuplicateNameAlert = false

    var body: some View {
        NavigationView {
            ZStack {
                CTRLColors.background.ignoresSafeArea()

                VStack(spacing: 24) {
                    // Mode name field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Mode Name")
                            .font(.caption)
                            .foregroundColor(CTRLColors.textSecondary)

                        TextField("Enter name", text: $modeName)
                            .padding()
                            .background(CTRLColors.cardBackground)
                            .cornerRadius(12)
                            .foregroundColor(CTRLColors.textPrimary)
                    }
                    .padding(.horizontal)

                    // App selection
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Blocked Apps")
                            .font(.caption)
                            .foregroundColor(CTRLColors.textSecondary)
                            .padding(.horizontal)

                        Button(action: { showAppPicker = true }) {
                            HStack {
                                Label("Select Apps", systemImage: "square.grid.2x2")
                                Spacer()
                                Text("\(appCount) apps")
                                    .foregroundColor(CTRLColors.textSecondary)
                                Image(systemName: "chevron.right")
                                    .foregroundColor(CTRLColors.textSecondary)
                            }
                            .padding()
                            .background(CTRLColors.cardBackground)
                            .cornerRadius(12)
                            .foregroundColor(CTRLColors.textPrimary)
                        }
                        .padding(.horizontal)
                    }

                    Spacer()
                }
                .padding(.top, 24)
            }
            .navigationTitle("Edit Mode")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(CTRLColors.textSecondary)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveMode()
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(CTRLColors.accent)
                    .disabled(modeName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .toolbarColorScheme(.dark, for: .navigationBar)
            .familyActivityPicker(isPresented: $showAppPicker, selection: $appSelection)
        }
        .onAppear {
            modeName = mode.name
            appSelection = mode.appSelection
        }
        .alert("Duplicate Name", isPresented: $showDuplicateNameAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("A mode with this name already exists. Please choose a different name.")
        }
    }

    private var appCount: Int {
        appSelection.applicationTokens.count + appSelection.categoryTokens.count
    }

    private func saveMode() {
        let trimmed = modeName.trimmingCharacters(in: .whitespacesAndNewlines)
        let nameChanged = trimmed.lowercased() != mode.name.lowercased()
        let isDuplicate = nameChanged && appState.modes.contains { $0.name.lowercased() == trimmed.lowercased() }

        if isDuplicate {
            showDuplicateNameAlert = true
            return
        }

        var updatedMode = mode
        updatedMode.name = trimmed
        updatedMode.appSelection = appSelection
        appState.updateMode(updatedMode)

        // If this is the active mode, update selectedApps too
        if appState.activeModeId == mode.id {
            appState.saveSelectedApps(appSelection)
        }

        dismiss()
    }
}
