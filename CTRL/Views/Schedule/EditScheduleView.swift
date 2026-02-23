import SwiftUI

struct EditScheduleView: View {
    // Input
    let schedule: FocusSchedule?  // nil if adding new
    let isNewSchedule: Bool
    var viewOnly: Bool = false
    var isInSession: Bool = false
    var onSave: (FocusSchedule) -> Void
    var onDelete: ((FocusSchedule) -> Void)?
    var onCancel: () -> Void

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var scheduleManager: ScheduleManager

    // Local state
    @State private var scheduleName: String = ""
    @State private var selectedModeId: UUID? = nil
    @State private var startTime: Date = EditScheduleView.defaultStartTime()
    @State private var endTime: Date = EditScheduleView.defaultEndTime()
    @State private var repeatDays: Set<Int> = [2, 3, 4, 5, 6] // Mon-Fri default
    @State private var requireNFCToEnd: Bool = true
    @State private var showModePicker: Bool = false
    @State private var showDeleteConfirm: Bool = false
    @State private var editingModeFromSheet: EditModeItem? = nil
    @State private var showStartPicker: Bool = false
    @State private var showEndPicker: Bool = false
    @State private var showEndTypeSheet: Bool = false

    // Sheet item for edit/create mode
    private struct EditModeItem: Identifiable {
        let id = UUID()
        let mode: BlockingMode?
        let isNew: Bool
    }

    var body: some View {
        ZStack {
            CTRLColors.base.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                header
                    .padding(.top, CTRLSpacing.md)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: CTRLSpacing.xl) {
                        // Name
                        nameSection

                        // Mode
                        modeSection

                        // Time
                        timeSection

                        // Repeat
                        repeatSection

                        // Delete (edit only, not in view-only)
                        if !isNewSchedule && !viewOnly {
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
            if let existing = schedule {
                scheduleName = existing.name
                selectedModeId = existing.modeId
                startTime = dateFromComponents(existing.startTime)
                endTime = dateFromComponents(existing.endTime)
                repeatDays = existing.repeatDays
                requireNFCToEnd = existing.requireNFCToEnd
            } else {
                // Default to active mode if available
                selectedModeId = appState.activeModeId
            }
        }
        .sheet(isPresented: $showModePicker) {
            if isInSession {
                // In session — mode selection only, no edit/create
                ScheduleModePickerView(
                    selectedModeId: $selectedModeId
                )
                .environmentObject(appState)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
                .presentationBackground(CTRLColors.surface1)
            } else {
                ScheduleModePickerView(
                    selectedModeId: $selectedModeId,
                    onEditMode: { mode in
                        editingModeFromSheet = EditModeItem(mode: mode, isNew: false)
                    },
                    onCreateMode: {
                        editingModeFromSheet = EditModeItem(mode: nil, isNew: true)
                    }
                )
                .environmentObject(appState)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
                .presentationBackground(CTRLColors.surface1)
            }
        }
        .sheet(item: $editingModeFromSheet) { item in
            EditModeView(
                mode: item.mode,
                isNewMode: item.isNew,
                viewOnly: false,
                onSave: { savedMode in
                    if item.isNew {
                        appState.addMode(savedMode)
                        selectedModeId = savedMode.id
                    } else {
                        appState.updateMode(savedMode)
                    }
                },
                onDelete: { modeToDelete in
                    let affected = appState.deleteMode(modeToDelete)
                    for schedule in affected {
                        scheduleManager.unregisterSchedule(schedule)
                    }
                },
                onCancel: { }
            )
            .environmentObject(appState)
            .environmentObject(scheduleManager)
            .presentationBackground(CTRLColors.base)
        }
        .confirmationDialog("end session", isPresented: $showEndTypeSheet) {
            Button("on nfc tap") {
                withAnimation(.easeInOut(duration: 0.2)) {
                    requireNFCToEnd = true
                    showEndPicker = false
                }
            }
            Button("at a set time") {
                withAnimation(.easeInOut(duration: 0.2)) {
                    requireNFCToEnd = false
                    showEndPicker = true
                    showStartPicker = false
                }
            }
        }
        .alert("delete schedule?", isPresented: $showDeleteConfirm) {
            Button("cancel", role: .cancel) {}
            Button("delete", role: .destructive) {
                if let existing = schedule {
                    onDelete?(existing)
                }
                dismiss()
            }
        } message: {
            Text("delete \"\(schedule?.name ?? "")\"? this can't be undone.")
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            if viewOnly {
                // View-only: just a spacer on the left to balance
                Color.clear
                    .frame(width: 60, height: 1)
            } else {
                Button(action: {
                    onCancel()
                    dismiss()
                }) {
                    Text("cancel")
                        .font(CTRLFonts.bodyFont)
                        .foregroundColor(CTRLColors.textSecondary)
                }
            }

            Spacer()

            Text(viewOnly ? "schedule" : (isNewSchedule ? "new schedule" : "edit schedule"))
                .font(CTRLFonts.h2)
                .foregroundColor(CTRLColors.textPrimary)

            Spacer()

            if viewOnly {
                Button(action: { dismiss() }) {
                    Text("done")
                        .font(CTRLFonts.bodyFont)
                        .fontWeight(.medium)
                        .foregroundColor(CTRLColors.accent)
                }
            } else {
                Button(action: saveSchedule) {
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
                TextField("", text: $scheduleName)
                    .font(CTRLFonts.bodyFont)
                    .foregroundColor(CTRLColors.textPrimary)
                    .disabled(viewOnly)
                    .ctrlPlaceholder(when: scheduleName.isEmpty) {
                        Text("e.g. morning focus, sleep mode")
                            .font(CTRLFonts.bodyFont)
                            .foregroundColor(CTRLColors.textTertiary)
                    }
            }
        }
    }

    // MARK: - Mode Section

    private var modeSection: some View {
        VStack(alignment: .leading, spacing: CTRLSpacing.sm) {
            CTRLSectionHeader(title: "Mode")

            Button(action: {
                if !viewOnly {
                    showModePicker = true
                }
            }) {
                SurfaceCard(padding: CTRLSpacing.md, cornerRadius: CTRLSpacing.buttonRadius) {
                    HStack {
                        Text(selectedModeName)
                            .font(CTRLFonts.bodyFont)
                            .foregroundColor(selectedModeId != nil ? CTRLColors.textPrimary : CTRLColors.textTertiary)

                        Spacer()

                        if !viewOnly {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .regular))
                                .foregroundColor(CTRLColors.textTertiary)
                        }
                    }
                }
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(viewOnly)
        }
    }

    // MARK: - Time Section

    private var timeSection: some View {
        VStack(alignment: .leading, spacing: CTRLSpacing.sm) {
            CTRLSectionHeader(title: "Time")

            SurfaceCard(padding: 0, cornerRadius: CTRLSpacing.buttonRadius) {
                VStack(spacing: 0) {
                    // Start time row
                    Button(action: {
                        if !viewOnly {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showStartPicker.toggle()
                                if showStartPicker { showEndPicker = false }
                            }
                        }
                    }) {
                        HStack {
                            Text("start")
                                .font(CTRLFonts.bodyFont)
                                .foregroundColor(CTRLColors.textPrimary)

                            Spacer()

                            Text(formatTimeString(startTime))
                                .font(CTRLFonts.bodyFont)
                                .foregroundColor(Color.white.opacity(0.5))
                        }
                        .padding(.horizontal, CTRLSpacing.md)
                        .padding(.vertical, CTRLSpacing.sm)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(viewOnly)

                    // Start time picker (inline expanding)
                    if showStartPicker && !viewOnly {
                        CTRLDivider()
                            .padding(.leading, CTRLSpacing.md)

                        DatePicker("", selection: $startTime, displayedComponents: .hourAndMinute)
                            .datePickerStyle(.wheel)
                            .labelsHidden()
                            .colorScheme(.dark)
                            .frame(maxHeight: 150)
                            .padding(.horizontal, CTRLSpacing.sm)
                    }

                    CTRLDivider()
                        .padding(.leading, CTRLSpacing.md)

                    // End time row
                    Button(action: {
                        if !viewOnly {
                            if requireNFCToEnd {
                                showEndTypeSheet = true
                            } else {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    showEndPicker.toggle()
                                    if showEndPicker { showStartPicker = false }
                                }
                            }
                        }
                    }) {
                        HStack {
                            Text("end")
                                .font(CTRLFonts.bodyFont)
                                .foregroundColor(CTRLColors.textPrimary)

                            Spacer()

                            HStack(spacing: CTRLSpacing.xs) {
                                Text(requireNFCToEnd ? "on nfc tap" : formatTimeString(endTime))
                                    .font(CTRLFonts.bodyFont)
                                    .foregroundColor(Color.white.opacity(0.5))

                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(CTRLColors.textTertiary.opacity(0.5))
                            }
                        }
                        .padding(.horizontal, CTRLSpacing.md)
                        .padding(.vertical, CTRLSpacing.sm)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(viewOnly)

                    // End time picker (inline expanding, only when set time mode)
                    if showEndPicker && !requireNFCToEnd && !viewOnly {
                        CTRLDivider()
                            .padding(.leading, CTRLSpacing.md)

                        DatePicker("", selection: $endTime, displayedComponents: .hourAndMinute)
                            .datePickerStyle(.wheel)
                            .labelsHidden()
                            .colorScheme(.dark)
                            .frame(maxHeight: 150)
                            .padding(.horizontal, CTRLSpacing.sm)

                        // Switch back to NFC option
                        CTRLDivider()
                            .padding(.leading, CTRLSpacing.md)

                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                requireNFCToEnd = true
                                showEndPicker = false
                            }
                        }) {
                            HStack {
                                Text("switch to on nfc tap")
                                    .font(CTRLFonts.micro)
                                    .foregroundColor(CTRLColors.accent)
                                Spacer()
                            }
                            .padding(.horizontal, CTRLSpacing.md)
                            .padding(.vertical, CTRLSpacing.sm)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }

            // Helper text below card
            if requireNFCToEnd {
                Text("tap your ctrl to end the session")
                    .font(CTRLFonts.micro)
                    .foregroundColor(CTRLColors.textTertiary)
                    .padding(.top, CTRLSpacing.micro)
            } else if !viewOnly && scheduleDurationMinutes < FocusSchedule.minimumDurationMinutes {
                Text("schedules must be at least 15 minutes long")
                    .font(CTRLFonts.micro)
                    .foregroundColor(CTRLColors.destructive)
                    .padding(.top, CTRLSpacing.micro)
            }
        }
    }

    // MARK: - Repeat Section

    private var repeatSection: some View {
        VStack(alignment: .leading, spacing: CTRLSpacing.sm) {
            CTRLSectionHeader(title: "Repeat")

            SurfaceCard(padding: CTRLSpacing.md, cornerRadius: CTRLSpacing.buttonRadius) {
                HStack(spacing: CTRLSpacing.sm) {
                    ForEach(FocusSchedule.dayLetters, id: \.weekday) { day in
                        let isActive = repeatDays.contains(day.weekday)
                        Button(action: {
                            if !viewOnly {
                                withAnimation(.easeInOut(duration: 0.15)) {
                                    if isActive {
                                        repeatDays.remove(day.weekday)
                                    } else {
                                        repeatDays.insert(day.weekday)
                                    }
                                }
                            }
                        }) {
                            Text(day.letter)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(isActive ? CTRLColors.base : CTRLColors.textTertiary)
                                .frame(width: 36, height: 36)
                                .background(
                                    Circle()
                                        .fill(isActive ? CTRLColors.accent : CTRLColors.surface2)
                                )
                        }
                        .buttonStyle(PlainButtonStyle())
                        .disabled(viewOnly)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Delete Section

    private var deleteSection: some View {
        Button(action: { showDeleteConfirm = true }) {
            Text("delete schedule")
                .font(CTRLFonts.bodyFont)
                .foregroundColor(CTRLColors.destructive)
        }
        .padding(.top, CTRLSpacing.lg)
    }

    // MARK: - Computed Properties

    private var selectedModeName: String {
        guard let modeId = selectedModeId,
              let mode = appState.modes.first(where: { $0.id == modeId }) else {
            return "select mode"
        }
        return mode.name.lowercased()
    }

    private var canSave: Bool {
        let hasName = !scheduleName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasMode = selectedModeId != nil
        let hasDays = !repeatDays.isEmpty
        let longEnough = requireNFCToEnd || scheduleDurationMinutes >= FocusSchedule.minimumDurationMinutes
        return hasName && hasMode && hasDays && longEnough
    }

    private var scheduleDurationMinutes: Int {
        let startComponents = componentsFromDate(startTime)
        let endComponents = componentsFromDate(endTime)
        let startMins = (startComponents.hour ?? 0) * 60 + (startComponents.minute ?? 0)
        let endMins = (endComponents.hour ?? 0) * 60 + (endComponents.minute ?? 0)
        if endMins > startMins {
            return endMins - startMins
        } else {
            return (24 * 60 - startMins) + endMins
        }
    }

    // MARK: - Actions

    private func saveSchedule() {
        let trimmedName = scheduleName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty, let modeId = selectedModeId else { return }

        let startComponents = componentsFromDate(startTime)
        let endComponents = componentsFromDate(endTime)

        var savedSchedule: FocusSchedule

        if let existing = schedule {
            savedSchedule = existing
            savedSchedule.name = trimmedName
            savedSchedule.modeId = modeId
            savedSchedule.startTime = startComponents
            savedSchedule.endTime = endComponents
            savedSchedule.repeatDays = repeatDays
            savedSchedule.requireNFCToEnd = requireNFCToEnd
        } else {
            savedSchedule = FocusSchedule(
                name: trimmedName,
                modeId: modeId,
                startTime: startComponents,
                endTime: endComponents,
                repeatDays: repeatDays
            )
            savedSchedule.requireNFCToEnd = requireNFCToEnd
        }

        onSave(savedSchedule)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        dismiss()
    }

    // MARK: - Time Helpers

    private func formatTimeString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date).lowercased()
    }

    private static func defaultStartTime() -> Date {
        var components = DateComponents()
        components.hour = 9
        components.minute = 0
        return Calendar.current.date(from: components) ?? Date()
    }

    private static func defaultEndTime() -> Date {
        var components = DateComponents()
        components.hour = 17
        components.minute = 0
        return Calendar.current.date(from: components) ?? Date()
    }

    private func dateFromComponents(_ components: DateComponents) -> Date {
        var dc = DateComponents()
        dc.hour = components.hour ?? 0
        dc.minute = components.minute ?? 0
        return Calendar.current.date(from: dc) ?? Date()
    }

    private func componentsFromDate(_ date: Date) -> DateComponents {
        Calendar.current.dateComponents([.hour, .minute], from: date)
    }
}
