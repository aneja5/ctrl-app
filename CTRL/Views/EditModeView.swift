import SwiftUI
import FamilyControls
import ManagedSettings

struct EditModeView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    let mode: BlockingMode

    @State private var modeName: String = ""
    @State private var appSelection: FamilyActivitySelection = FamilyActivitySelection()
    @State private var showAppPicker: Bool = false
    @State private var showDuplicateNameAlert = false
    @State private var showDeleteConfirm = false

    private var canDelete: Bool {
        appState.modes.count > 1
    }

    var body: some View {
        ZStack {
            CTRLColors.base.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: CTRLSpacing.xl) {
                    // Header
                    header
                        .padding(.top, CTRLSpacing.md)

                    // Mode Name
                    nameSection

                    // App Selection
                    appsSection

                    // Selected Apps List
                    if appCount > 0 {
                        selectedAppsList
                    }

                    Spacer(minLength: 60)

                    // Delete Button (only if more than 1 mode)
                    if canDelete {
                        deleteSection
                            .padding(.bottom, CTRLSpacing.xl)
                    }
                }
                .padding(.horizontal, CTRLSpacing.screenPadding)
            }
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
        .alert("Delete Mode", isPresented: $showDeleteConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                appState.deleteMode(id: mode.id)
                dismiss()
            }
        } message: {
            Text("Delete \"\(mode.name)\"? This cannot be undone.")
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

                        Image(systemName: "plus.circle")
                            .font(.system(size: 18, weight: .regular))
                            .foregroundColor(CTRLColors.accent)
                    }
                }
            }
            .buttonStyle(PlainButtonStyle())
        }
    }

    // MARK: - Selected Apps List

    private var selectedAppsList: some View {
        VStack(alignment: .leading, spacing: CTRLSpacing.sm) {
            SurfaceCard(padding: 0, cornerRadius: CTRLSpacing.buttonRadius) {
                VStack(spacing: 0) {
                    // Apps
                    let apps = Array(appSelection.applicationTokens)
                    ForEach(Array(apps.enumerated()), id: \.offset) { index, token in
                        HStack(spacing: CTRLSpacing.md) {
                            Label(token)
                                .labelStyle(.iconOnly)
                                .saturation(0.25)
                                .brightness(-0.1)
                                .scaleEffect(1.5)
                                .frame(width: 32, height: 32)

                            Label(token)
                                .labelStyle(.titleOnly)
                                .font(CTRLFonts.bodyFont)
                                .foregroundColor(CTRLColors.textPrimary)
                                .lineLimit(1)

                            Spacer()

                            Button(action: { removeApp(token) }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 18))
                                    .foregroundColor(CTRLColors.textTertiary)
                            }
                        }
                        .padding(.horizontal, CTRLSpacing.md)
                        .padding(.vertical, CTRLSpacing.sm)

                        if index < apps.count - 1 || !appSelection.categoryTokens.isEmpty {
                            CTRLDivider()
                                .padding(.leading, CTRLSpacing.md + 32 + CTRLSpacing.md)
                        }
                    }

                    // Categories
                    let categories = Array(appSelection.categoryTokens)
                    ForEach(Array(categories.enumerated()), id: \.offset) { index, token in
                        HStack(spacing: CTRLSpacing.md) {
                            Label(token)
                                .labelStyle(.iconOnly)
                                .saturation(0.25)
                                .brightness(-0.1)
                                .scaleEffect(1.5)
                                .frame(width: 32, height: 32)

                            Label(token)
                                .labelStyle(.titleOnly)
                                .font(CTRLFonts.bodyFont)
                                .foregroundColor(CTRLColors.textPrimary)
                                .lineLimit(1)

                            Spacer()

                            Text("CATEGORY")
                                .font(CTRLFonts.micro)
                                .tracking(1)
                                .foregroundColor(CTRLColors.textTertiary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(CTRLColors.surface2)
                                .cornerRadius(4)

                            Button(action: { removeCategory(token) }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 18))
                                    .foregroundColor(CTRLColors.textTertiary)
                            }
                        }
                        .padding(.horizontal, CTRLSpacing.md)
                        .padding(.vertical, CTRLSpacing.sm)

                        if index < categories.count - 1 {
                            CTRLDivider()
                                .padding(.leading, CTRLSpacing.md + 32 + CTRLSpacing.md)
                        }
                    }
                }
            }
        }
    }

    private var appCount: Int {
        appSelection.applicationTokens.count + appSelection.categoryTokens.count
    }

    // MARK: - Delete Section

    private var deleteSection: some View {
        Button(action: { showDeleteConfirm = true }) {
            Text("delete mode")
                .font(CTRLFonts.bodyFont)
                .foregroundColor(CTRLColors.destructive)
        }
    }

    // MARK: - Actions

    private func removeApp(_ token: ApplicationToken) {
        appSelection.applicationTokens.remove(token)
    }

    private func removeCategory(_ token: ActivityCategoryToken) {
        appSelection.categoryTokens.remove(token)
    }

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
