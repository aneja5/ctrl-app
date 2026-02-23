import SwiftUI
import FamilyControls
import ManagedSettings

struct EditModeView: View {
    // Input
    let mode: BlockingMode?  // nil if adding new
    let isNewMode: Bool
    var viewOnly: Bool = false
    var onSave: (BlockingMode) -> Void
    var onDelete: ((BlockingMode) -> Void)? = nil
    var onCancel: () -> Void

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appState: AppState

    // Local state — changes here don't affect original until Save
    @State private var modeName: String = ""
    @State private var appSelection: FamilyActivitySelection = FamilyActivitySelection(includeEntireCategory: true)
    @State private var showAppPicker: Bool = false
    @State private var showDuplicateNameAlert = false
    @State private var showDeleteConfirm = false
    @FocusState private var isNameFieldFocused: Bool

    var body: some View {
        ZStack {
            CTRLColors.base.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                header
                    .padding(.top, CTRLSpacing.md)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: CTRLSpacing.xl) {
                        // Name Section
                        nameSection

                        // Apps Section
                        appsSection

                        // Selected Apps List
                        if appCount > 0 {
                            selectedAppsList
                        } else if !viewOnly {
                            // Empty state — instructional text first, then action
                            VStack(spacing: CTRLSpacing.md) {
                                Image(systemName: "app.dashed")
                                    .font(.system(size: 36, weight: .light))
                                    .foregroundColor(CTRLColors.textTertiary)

                                Text("choose apps to block during focus sessions")
                                    .font(CTRLFonts.bodySmall)
                                    .foregroundColor(CTRLColors.textTertiary)
                                    .multilineTextAlignment(.center)

                                Button(action: { showAppPicker = true }) {
                                    HStack(spacing: CTRLSpacing.xs) {
                                        Image(systemName: "plus")
                                            .font(.system(size: 14, weight: .semibold))
                                        Text("select apps")
                                            .font(CTRLFonts.bodyFont)
                                            .fontWeight(.medium)
                                    }
                                    .foregroundColor(CTRLColors.base)
                                    .padding(.horizontal, CTRLSpacing.lg)
                                    .padding(.vertical, CTRLSpacing.sm)
                                    .background(
                                        Capsule()
                                            .fill(CTRLColors.accent)
                                    )
                                }
                                .padding(.top, CTRLSpacing.xs)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, CTRLSpacing.xl)
                        }

                        // Delete button (only for existing modes, not in view-only, and only if more than 1)
                        if !isNewMode && !viewOnly && appState.modes.count > 1 {
                            deleteSection
                        }

                        Spacer(minLength: 60)
                    }
                    .padding(.horizontal, CTRLSpacing.screenPadding)
                    .padding(.top, CTRLSpacing.lg)
                }
            }
        }
        .onAppear {
            if let existingMode = mode {
                modeName = existingMode.name
                // Ensure includeEntireCategory is preserved when loading existing mode
                appSelection = existingMode.appSelection.withIncludeEntireCategory()
            } else {
                modeName = ""
                appSelection = FamilyActivitySelection(includeEntireCategory: true)
            }
        }
        .familyActivityPicker(isPresented: $showAppPicker, selection: $appSelection)
        .onChange(of: showAppPicker) { _, isShowing in
            if !isShowing {
                // Dismiss keyboard when app picker closes to prevent cursor jump
                isNameFieldFocused = false
            }
        }
        .onChange(of: appSelection) { _, newSelection in
            #if DEBUG
            print("=== CTRL APP SELECTION DEBUG ===")
            print("includeEntireCategory: \(newSelection.includeEntireCategory)")
            print("applicationTokens count: \(newSelection.applicationTokens.count)")
            print("categoryTokens count: \(newSelection.categoryTokens.count)")
            print("applicationTokens: \(newSelection.applicationTokens)")
            print("categoryTokens: \(newSelection.categoryTokens)")
            print("================================")
            #endif
        }
        .alert("duplicate name", isPresented: $showDuplicateNameAlert) {
            Button("ok", role: .cancel) {}
        } message: {
            Text("a mode with this name already exists. please choose a different name.")
        }
        .alert("delete mode?", isPresented: $showDeleteConfirm) {
            Button("cancel", role: .cancel) {}
            Button("delete", role: .destructive) {
                deleteMode()
            }
        } message: {
            Text("delete \"\(mode?.name ?? "")\"? this can't be undone.")
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            if viewOnly {
                Spacer()

                Text("view mode")
                    .font(CTRLFonts.h2)
                    .foregroundColor(CTRLColors.textPrimary)

                Spacer()

                Button(action: { dismiss() }) {
                    Text("done")
                        .font(CTRLFonts.bodyFont)
                        .fontWeight(.medium)
                        .foregroundColor(CTRLColors.accent)
                }
            } else {
                Button(action: {
                    onCancel()
                    dismiss()
                }) {
                    Text("cancel")
                        .font(CTRLFonts.bodyFont)
                        .foregroundColor(CTRLColors.textSecondary)
                }

                Spacer()

                Text(isNewMode ? "new mode" : "edit mode")
                    .font(CTRLFonts.h2)
                    .foregroundColor(CTRLColors.textPrimary)

                Spacer()

                Button(action: saveMode) {
                    Text("save")
                        .font(CTRLFonts.bodyFont)
                        .fontWeight(.medium)
                        .foregroundColor(canSave ? CTRLColors.accent : CTRLColors.textTertiary.opacity(0.5))
                }
                .disabled(!canSave)
            }
        }
        .padding(.horizontal, CTRLSpacing.screenPadding)
    }

    // MARK: - Name Section

    private var nameSection: some View {
        VStack(alignment: .leading, spacing: CTRLSpacing.sm) {
            CTRLSectionHeader(title: "Name")

            SurfaceCard(padding: CTRLSpacing.md, cornerRadius: CTRLSpacing.buttonRadius) {
                TextField("", text: $modeName)
                    .font(CTRLFonts.bodyFont)
                    .foregroundColor(CTRLColors.textPrimary)
                    .disabled(viewOnly)
                    .focused($isNameFieldFocused)
                    .ctrlPlaceholder(when: modeName.isEmpty) {
                        Text("e.g. work, sleep, social detox")
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

            if !viewOnly {
                Button(action: { showAppPicker = true }) {
                    SurfaceCard(padding: CTRLSpacing.md, cornerRadius: CTRLSpacing.buttonRadius) {
                        HStack {
                            Text(appCount > 0 ? "\(appSelection.displayCount) selected" : "select apps")
                                .font(CTRLFonts.bodyFont)
                                .foregroundColor(appCount > 0 ? CTRLColors.textPrimary : CTRLColors.textTertiary)
                                .contentTransition(.numericText())
                                .animation(.easeInOut(duration: 0.2), value: appCount)

                            Spacer()

                            Image(systemName: "plus.circle")
                                .font(.system(size: 18, weight: .regular))
                                .foregroundColor(CTRLColors.accent)
                        }
                    }
                }
                .buttonStyle(PlainButtonStyle())
            } else if appCount > 0 {
                SurfaceCard(padding: CTRLSpacing.md, cornerRadius: CTRLSpacing.buttonRadius) {
                    Text("\(appSelection.displayCount) blocked")
                        .font(CTRLFonts.bodyFont)
                        .foregroundColor(CTRLColors.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    // MARK: - Selected Apps List

    private var selectedAppsList: some View {
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

                        if !viewOnly {
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.25)) {
                                    _ = appSelection.applicationTokens.remove(token)
                                }
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 18))
                                    .foregroundColor(CTRLColors.textTertiary)
                            }
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

                        if !viewOnly {
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.25)) {
                                    _ = appSelection.categoryTokens.remove(token)
                                }
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 18))
                                    .foregroundColor(CTRLColors.textTertiary)
                            }
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

    // MARK: - Delete Section

    private var deleteSection: some View {
        Button(action: { showDeleteConfirm = true }) {
            Text("delete mode")
                .font(CTRLFonts.bodyFont)
                .foregroundColor(CTRLColors.destructive)
        }
        .padding(.top, CTRLSpacing.lg)
    }

    // MARK: - Computed Properties

    private var appCount: Int {
        let apps = appSelection.applicationTokens.count
        let cats = appSelection.categoryTokens.count
        // When includeEntireCategory works, categories expand into applicationTokens
        // so apps already has the full count. Fallback to cats when expansion didn't happen.
        return cats > 0 && apps == 0 ? cats : apps
    }

    private var canSave: Bool {
        let hasName = !modeName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        if isNewMode {
            return hasName && appCount > 0
        }
        return hasName
    }

    // MARK: - Actions

    private func saveMode() {
        let trimmedName = modeName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        // Check for duplicate names (exclude the current mode if editing)
        let isDuplicate = appState.modes.contains {
            $0.name.lowercased() == trimmedName.lowercased() && $0.id != mode?.id
        }

        if isDuplicate {
            showDuplicateNameAlert = true
            return
        }

        var savedMode: BlockingMode

        if let existingMode = mode {
            // Editing — update the existing mode
            savedMode = existingMode
            savedMode.name = trimmedName
            savedMode.appSelection = appSelection
        } else {
            // Adding — create new mode
            savedMode = BlockingMode(name: trimmedName)
            savedMode.appSelection = appSelection
        }

        onSave(savedMode)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        dismiss()
    }

    private func deleteMode() {
        guard let existingMode = mode else { return }
        if let onDelete = onDelete {
            // Let call site handle cascade (unregister schedules from DeviceActivityCenter)
            onDelete(existingMode)
        } else {
            // Fallback: direct delete without cascade unregistration
            appState.deleteMode(existingMode)
        }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
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
