import SwiftUI

struct ScheduleListView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var scheduleManager: ScheduleManager
    @EnvironmentObject var blockingManager: BlockingManager
    @Environment(\.dismiss) private var dismiss

    @State private var editingSchedule: EditScheduleItem? = nil

    // Sheet item — unique ID forces fresh EditScheduleView each time
    struct EditScheduleItem: Identifiable {
        let id = UUID()
        let schedule: FocusSchedule?
        let isNew: Bool
        let viewOnly: Bool
    }

    /// True when the user is in any session (manual NFC or scheduled)
    private var isInSession: Bool {
        blockingManager.isBlocking || scheduleManager.activeScheduleId != nil
    }

    var body: some View {
        ZStack {
            CTRLColors.base.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: CTRLSpacing.lg) {
                    // Header
                    header
                        .padding(.top, CTRLSpacing.md)

                    if appState.schedules.isEmpty {
                        // Empty State
                        emptyState
                    } else {
                        // Schedule List
                        scheduleList

                        // Create button (when list exists)
                        if appState.schedules.count < AppConstants.maxSchedules {
                            createButton
                        }
                    }

                    if appState.schedules.contains(where: { $0.isEnabled }) {
                        Text("tip: open ctrl before your schedule starts to ensure blocking activates")
                            .font(.system(size: 10))
                            .foregroundColor(Color.white.opacity(0.25))
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                            .padding(.top, CTRLSpacing.xs)
                    }

                    Spacer(minLength: 40)
                }
                .padding(.horizontal, CTRLSpacing.screenPadding)
            }
        }
        .sheet(item: $editingSchedule) { item in
            if item.viewOnly {
                // View-only — no save/delete callbacks needed
                EditScheduleView(
                    schedule: item.schedule,
                    isNewSchedule: false,
                    viewOnly: true,
                    isInSession: true,
                    onSave: { _ in },
                    onDelete: nil,
                    onCancel: { }
                )
                .environmentObject(appState)
                .environmentObject(scheduleManager)
                .presentationBackground(CTRLColors.base)
            } else {
                EditScheduleView(
                    schedule: item.schedule,
                    isNewSchedule: item.isNew,
                    viewOnly: false,
                    isInSession: isInSession,
                    onSave: { savedSchedule in
                        if item.isNew {
                            appState.addSchedule(savedSchedule)
                        } else {
                            appState.updateSchedule(savedSchedule)
                            // Clear skip flag on edit+save — user re-confirmed the schedule
                            scheduleManager.clearSkipFlag(for: savedSchedule.id.uuidString)
                        }
                        // Register with DeviceActivityCenter
                        if savedSchedule.isEnabled,
                           let mode = appState.modes.first(where: { $0.id == savedSchedule.modeId }) {
                            scheduleManager.registerSchedule(savedSchedule, mode: mode)
                            // If schedule activated immediately (we're in the window), start the timer
                            if scheduleManager.activeScheduleId == savedSchedule.id.uuidString {
                                appState.startBlockingTimer()
                            }
                        } else {
                            scheduleManager.unregisterSchedule(savedSchedule)
                        }
                    },
                    onDelete: { scheduleToDelete in
                        // If this is the active scheduled session, stop the timer first
                        if scheduleManager.activeScheduleId == scheduleToDelete.id.uuidString {
                            appState.stopBlockingTimer()
                            scheduleManager.endActiveSession()
                        } else {
                            scheduleManager.unregisterSchedule(scheduleToDelete)
                        }
                        appState.deleteSchedule(scheduleToDelete)
                    },
                    onCancel: { }
                )
                .environmentObject(appState)
                .environmentObject(scheduleManager)
                .presentationBackground(CTRLColors.base)
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text("schedule")
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

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: CTRLSpacing.md) {
            Spacer()
                .frame(height: CTRLSpacing.xxl)

            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 40, weight: .light))
                .foregroundColor(CTRLColors.textTertiary)

            Text("automate your focus sessions")
                .font(CTRLFonts.bodySmall)
                .foregroundColor(CTRLColors.textTertiary)
                .multilineTextAlignment(.center)

            Text("set times to automatically block apps")
                .font(CTRLFonts.micro)
                .foregroundColor(CTRLColors.textTertiary)
                .multilineTextAlignment(.center)

            Button(action: {
                editingSchedule = EditScheduleItem(schedule: nil, isNew: true, viewOnly: false)
            }) {
                HStack(spacing: CTRLSpacing.xs) {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .semibold))
                    Text("create schedule")
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
    }

    // MARK: - Schedule List

    private var scheduleList: some View {
        let overlapping = overlappingScheduleIds

        return VStack(spacing: CTRLSpacing.sm) {
            ForEach(appState.schedules) { schedule in
                let isActiveSchedule = schedule.id.uuidString == scheduleManager.activeScheduleId
                let modeExists = appState.modes.contains(where: { $0.id == schedule.modeId })

                ScheduleCard(
                    schedule: schedule,
                    modeName: modeName(for: schedule),
                    isActiveSession: isActiveSchedule,
                    hasOverlap: overlapping.contains(schedule.id),
                    modeDeleted: !modeExists,
                    onToggle: { isEnabled in
                        toggleSchedule(schedule, enabled: isEnabled)
                    },
                    onTap: {
                        editingSchedule = EditScheduleItem(
                            schedule: schedule,
                            isNew: false,
                            viewOnly: isActiveSchedule
                        )
                    }
                )
            }
        }
    }

    // MARK: - Overlap Detection

    /// Returns IDs of enabled schedules that overlap with at least one other enabled schedule
    private var overlappingScheduleIds: Set<UUID> {
        let enabled = appState.schedules.filter { $0.isEnabled }
        var overlapping = Set<UUID>()

        for i in 0..<enabled.count {
            for j in (i + 1)..<enabled.count {
                let a = enabled[i]
                let b = enabled[j]
                // Only flag if they share at least one repeat day
                guard !a.repeatDays.intersection(b.repeatDays).isEmpty else { continue }
                if schedulesOverlap(a, b) {
                    overlapping.insert(a.id)
                    overlapping.insert(b.id)
                }
            }
        }
        return overlapping
    }

    private func schedulesOverlap(_ a: FocusSchedule, _ b: FocusSchedule) -> Bool {
        let aStart = (a.startTime.hour ?? 0) * 60 + (a.startTime.minute ?? 0)
        let aEnd = (a.endTime.hour ?? 0) * 60 + (a.endTime.minute ?? 0)
        let bStart = (b.startTime.hour ?? 0) * 60 + (b.startTime.minute ?? 0)
        let bEnd = (b.endTime.hour ?? 0) * 60 + (b.endTime.minute ?? 0)

        let aWraps = aEnd <= aStart  // crosses midnight
        let bWraps = bEnd <= bStart

        if !aWraps && !bWraps {
            // Both same-day: standard interval overlap
            return aStart < bEnd && bStart < aEnd
        } else if aWraps && !bWraps {
            // a wraps midnight: covers [aStart..1440) and [0..aEnd)
            return bStart < aEnd || bEnd > aStart
        } else if !aWraps && bWraps {
            return aStart < bEnd || aEnd > bStart
        } else {
            // Both wrap midnight: always overlap (both cover the midnight hour)
            return true
        }
    }

    // MARK: - Create Button

    private var createButton: some View {
        Button(action: {
            editingSchedule = EditScheduleItem(schedule: nil, isNew: true, viewOnly: false)
        }) {
            HStack(spacing: CTRLSpacing.sm) {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(CTRLColors.textTertiary)

                Text("create schedule")
                    .font(CTRLFonts.bodyFont)
                    .foregroundColor(CTRLColors.textTertiary)

                Spacer()
            }
            .padding(.horizontal, CTRLSpacing.md)
            .frame(height: 56)
            .background(
                RoundedRectangle(cornerRadius: CTRLSpacing.buttonRadius)
                    .fill(CTRLColors.surface1.opacity(0.5))
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Helpers

    private func modeName(for schedule: FocusSchedule) -> String {
        appState.modes.first(where: { $0.id == schedule.modeId })?.name.lowercased() ?? "unknown"
    }

    private func toggleSchedule(_ schedule: FocusSchedule, enabled: Bool) {
        var updated = schedule
        updated.isEnabled = enabled
        appState.updateSchedule(updated)

        // Register or unregister with DeviceActivityCenter
        if enabled, let mode = appState.modes.first(where: { $0.id == schedule.modeId }) {
            // Clear skip flag — user explicitly re-enabled, should reactivate if in window
            scheduleManager.clearSkipFlag(for: schedule.id.uuidString)
            scheduleManager.registerSchedule(updated, mode: mode)
            // If schedule activated immediately (we're in the window), start the timer
            if scheduleManager.activeScheduleId == updated.id.uuidString {
                appState.startBlockingTimer()
            }
        } else {
            scheduleManager.unregisterSchedule(updated)
            // If this was the active session, stop the timer
            if scheduleManager.activeScheduleId == nil {
                appState.stopBlockingTimer()
            }
        }
    }
}

// MARK: - Schedule Card

struct ScheduleCard: View {
    let schedule: FocusSchedule
    let modeName: String
    var isActiveSession: Bool = false
    var hasOverlap: Bool = false
    var modeDeleted: Bool = false
    let onToggle: (Bool) -> Void
    let onTap: () -> Void

    @State private var isEnabled: Bool

    init(schedule: FocusSchedule, modeName: String, isActiveSession: Bool = false,
         hasOverlap: Bool = false, modeDeleted: Bool = false,
         onToggle: @escaping (Bool) -> Void, onTap: @escaping () -> Void) {
        self.schedule = schedule
        self.modeName = modeName
        self.isActiveSession = isActiveSession
        self.hasOverlap = hasOverlap
        self.modeDeleted = modeDeleted
        self.onToggle = onToggle
        self.onTap = onTap
        self._isEnabled = State(initialValue: schedule.isEnabled)
    }

    var body: some View {
        Button(action: onTap) {
            SurfaceCard(padding: CTRLSpacing.md, cornerRadius: CTRLSpacing.buttonRadius) {
                VStack(alignment: .leading, spacing: CTRLSpacing.sm) {
                    // Row 1: Name + Toggle
                    HStack {
                        Text(schedule.name.lowercased())
                            .font(CTRLFonts.bodyFont)
                            .foregroundColor(isEnabled ? CTRLColors.textPrimary : CTRLColors.textTertiary)

                        Spacer()

                        Toggle("", isOn: $isEnabled)
                            .tint(CTRLColors.accent)
                            .labelsHidden()
                            .disabled(isActiveSession)
                            .onChange(of: isEnabled) { _, newValue in
                                onToggle(newValue)
                            }
                    }

                    // Row 2: Mode + Time
                    HStack(spacing: CTRLSpacing.xs) {
                        Text(modeName)
                            .font(CTRLFonts.bodySmall)
                            .foregroundColor(CTRLColors.textSecondary)

                        Text("·")
                            .font(CTRLFonts.bodySmall)
                            .foregroundColor(CTRLColors.textTertiary)

                        Text(schedule.timeRangeString)
                            .font(CTRLFonts.bodySmall)
                            .foregroundColor(CTRLColors.textSecondary)
                    }

                    // Row 3: Repeat Days
                    HStack(spacing: CTRLSpacing.xs) {
                        ForEach(FocusSchedule.dayLetters, id: \.weekday) { day in
                            let isActive = schedule.repeatDays.contains(day.weekday)
                            Text(day.letter)
                                .font(CTRLFonts.micro)
                                .foregroundColor(isActive ? CTRLColors.accent : CTRLColors.textTertiary.opacity(0.5))
                                .frame(width: 20, height: 20)
                        }
                    }

                    // Row 4: Status indicators
                    if modeDeleted {
                        Text("mode deleted")
                            .font(CTRLFonts.micro)
                            .foregroundColor(.red.opacity(0.7))
                    } else if hasOverlap && isEnabled {
                        Text("overlaps another schedule")
                            .font(CTRLFonts.micro)
                            .foregroundColor(CTRLColors.textTertiary.opacity(0.5))
                    }
                }
                .opacity(isEnabled ? 1.0 : 0.5)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}
