import SwiftUI
import FamilyControls

struct EditModeView: View {

    // MARK: - Environment

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appState: AppState

    // MARK: - State

    @State private var modeName: String
    @State private var appSelection: FamilyActivitySelection
    @State private var showAppPicker = false
    @State private var showDuplicateNameAlert = false

    private let modeId: UUID
    private let originalName: String

    // MARK: - Init

    init(mode: BlockingMode) {
        self.modeId = mode.id
        self.originalName = mode.name
        _modeName = State(initialValue: mode.name)
        _appSelection = State(initialValue: mode.appSelection)
    }

    // MARK: - Body

    var body: some View {
        NavigationView {
            ZStack {
                CTRLColors.background
                    .ignoresSafeArea()

                List {
                    Section {
                        TextField("Mode name", text: $modeName)
                            .foregroundColor(CTRLColors.textPrimary)
                    } header: {
                        Text("Name")
                            .foregroundColor(CTRLColors.textSecondary)
                    }
                    .listRowBackground(CTRLColors.cardBackground)

                    Section {
                        Button {
                            showAppPicker = true
                        } label: {
                            HStack {
                                Label("Select Apps", systemImage: "square.grid.2x2")
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
                        Text("Apps")
                            .foregroundColor(CTRLColors.textSecondary)
                    }
                    .listRowBackground(CTRLColors.cardBackground)
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Edit Mode")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(CTRLColors.textSecondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        let trimmed = modeName.trimmingCharacters(in: .whitespacesAndNewlines)
                        let nameChanged = trimmed.lowercased() != originalName.lowercased()
                        let isDuplicate = nameChanged && appState.modes.contains { $0.name.lowercased() == trimmed.lowercased() }
                        if isDuplicate {
                            showDuplicateNameAlert = true
                        } else {
                            saveChanges()
                            dismiss()
                        }
                    }
                    .foregroundColor(CTRLColors.accent)
                    .disabled(modeName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .familyActivityPicker(
            isPresented: $showAppPicker,
            selection: $appSelection
        )
        .alert("Duplicate Name", isPresented: $showDuplicateNameAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("A mode with this name already exists. Please choose a different name.")
        }
    }

    // MARK: - Helpers

    private var appCount: Int {
        appSelection.applicationTokens.count + appSelection.categoryTokens.count
    }

    // MARK: - Actions

    private func saveChanges() {
        var updated = BlockingMode(name: modeName.trimmingCharacters(in: .whitespacesAndNewlines), appSelection: appSelection)
        updated.id = modeId
        appState.updateMode(updated)

        // Sync selectedApps if this is the active mode
        if appState.activeModeId == modeId {
            appState.selectedApps = appSelection
        }
    }
}
