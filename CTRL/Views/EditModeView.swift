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
        ZStack {
            CTRLColors.base.ignoresSafeArea()

            VStack(spacing: CTRLSpacing.xl) {
                // Header
                header
                    .padding(.top, CTRLSpacing.md)

                // Mode Name
                nameSection

                // App Selection
                appsSection

                Spacer()
            }
            .padding(.horizontal, CTRLSpacing.screenPadding)
        }
        .onAppear {
            modeName = mode.name
            appSelection = mode.appSelection
        }
        .familyActivityPicker(isPresented: $showAppPicker, selection: $appSelection)
        .alert("Duplicate Name", isPresented: $showDuplicateNameAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("A mode with this name already exists. Please choose a different name.")
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Button(action: { dismiss() }) {
                Text("cancel")
                    .font(CTRLFonts.bodyFont)
                    .foregroundColor(CTRLColors.textSecondary)
            }

            Spacer()

            Text("edit mode")
                .font(CTRLFonts.h2)
                .foregroundColor(CTRLColors.textPrimary)

            Spacer()

            Button(action: saveMode) {
                Text("save")
                    .font(CTRLFonts.bodyFont)
                    .fontWeight(.medium)
                    .foregroundColor(modeName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? CTRLColors.textTertiary.opacity(0.5) : CTRLColors.accent)
            }
            .disabled(modeName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    // MARK: - Name Section

    private var nameSection: some View {
        VStack(alignment: .leading, spacing: CTRLSpacing.sm) {
            CTRLSectionHeader(title: "Name")

            SurfaceCard(padding: CTRLSpacing.md, cornerRadius: CTRLSpacing.buttonRadius) {
                TextField("", text: $modeName)
                    .font(CTRLFonts.bodyFont)
                    .foregroundColor(CTRLColors.textPrimary)
                    .ctrlPlaceholder(when: modeName.isEmpty) {
                        Text("mode name")
                            .font(CTRLFonts.bodyFont)
                            .foregroundColor(CTRLColors.textTertiary)
                    }
            }
        }
    }

    // MARK: - Apps Section

    private var appsSection: some View {
        VStack(alignment: .leading, spacing: CTRLSpacing.sm) {
            CTRLSectionHeader(title: "Apps in Scope")

            Button(action: { showAppPicker = true }) {
                SurfaceCard(padding: CTRLSpacing.md, cornerRadius: CTRLSpacing.buttonRadius) {
                    HStack {
                        Text(appCount > 0 ? "\(appCount) app\(appCount == 1 ? "" : "s") selected" : "select apps")
                            .font(CTRLFonts.bodyFont)
                            .foregroundColor(appCount > 0 ? CTRLColors.textPrimary : CTRLColors.textTertiary)

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(CTRLColors.textTertiary)
                    }
                }
            }
            .buttonStyle(PlainButtonStyle())
        }
    }

    private var appCount: Int {
        appSelection.applicationTokens.count + appSelection.categoryTokens.count
    }

    // MARK: - Actions

    private func saveMode() {
        let trimmed = modeName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        // Check for duplicate names
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

        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        dismiss()
    }
}

// MARK: - Placeholder Extension

extension View {
    func ctrlPlaceholder<Content: View>(
        when shouldShow: Bool,
        alignment: Alignment = .leading,
        @ViewBuilder placeholder: () -> Content
    ) -> some View {
        ZStack(alignment: alignment) {
            placeholder().opacity(shouldShow ? 1 : 0)
            self
        }
    }
}
