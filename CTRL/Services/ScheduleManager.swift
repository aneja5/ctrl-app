import Foundation
import DeviceActivity
import FamilyControls
import ManagedSettings
import BackgroundTasks
import UserNotifications

class ScheduleManager: ObservableObject {

    // MARK: - Properties

    private let center = DeviceActivityCenter()
    private let sharedDefaults: UserDefaults
    private let store = ManagedSettingsStore(named: .init("schedule"))

    /// Published so SwiftUI reacts to scheduled session state changes
    @Published var activeScheduleId: String? = nil

    /// In-memory dispatch timer for imminent schedule starts
    private var imminentSyncWorkItem: DispatchWorkItem?

    // MARK: - Init

    init() {
        if let defaults = UserDefaults(suiteName: "group.in.getctrl.app") {
            self.sharedDefaults = defaults
        } else {
            self.sharedDefaults = UserDefaults.standard
            #if DEBUG
            print("[ScheduleManager] WARNING: App Group unavailable, falling back to standard UserDefaults")
            #endif
        }
        // Sync from shared storage on launch
        refreshActiveScheduleId()
    }

    // MARK: - Registration

    /// Register a schedule with the system via DeviceActivityCenter
    func registerSchedule(_ schedule: FocusSchedule, mode: BlockingMode) {
        guard schedule.isEnabled else {
            #if DEBUG
            print("[ScheduleManager] Schedule '\(schedule.name)' is disabled, skipping registration")
            #endif
            return
        }

        let activityName = DeviceActivityName("ctrl_schedule_\(schedule.id.uuidString)")

        let deviceSchedule = DeviceActivitySchedule(
            intervalStart: schedule.startTime,
            intervalEnd: schedule.endTime,
            repeats: true
        )

        do {
            try center.startMonitoring(activityName, during: deviceSchedule)
            writeSelectionToShared(schedule: schedule, mode: mode)
            #if DEBUG
            print("[ScheduleManager] Registered schedule '\(schedule.name)' — \(schedule.timeRangeString)")
            #endif

            // Sync shields — will apply immediately if we're in the window
            syncScheduleShields()

            // Schedule BGTask fallback
            scheduleNextBGTask(schedules: AppState.shared.schedules)

            // Schedule local notification + imminent dispatch
            requestNotificationPermission()
            scheduleNotifications(for: schedule)
            scheduleImminentSync(for: AppState.shared.schedules)
        } catch {
            #if DEBUG
            print("[ScheduleManager] Failed to register schedule '\(schedule.name)': \(error.localizedDescription)")
            #endif
        }
    }

    /// Unregister a schedule from the system
    func unregisterSchedule(_ schedule: FocusSchedule) {
        let activityName = DeviceActivityName("ctrl_schedule_\(schedule.id.uuidString)")
        center.stopMonitoring([activityName])
        removeSelectionFromShared(schedule: schedule)
        removeNotifications(for: schedule.id)

        #if DEBUG
        print("[ScheduleManager] Unregistered schedule '\(schedule.name)'")
        #endif

        // Sync shields — will clear if this was the active schedule
        syncScheduleShields()
    }

    /// Differential re-registration: only stop stale monitoring, only register new ones.
    /// Preserves existing DeviceActivityCenter monitoring so pending intervalDidStart fires.
    func reregisterAllSchedules(schedules: [FocusSchedule], modes: [BlockingMode]) {
        let currentlyMonitored = Set(center.activities.map { $0.rawValue })
        var expectedActivities = Set<String>()

        for schedule in schedules where schedule.isEnabled {
            guard let mode = modes.first(where: { $0.id == schedule.modeId }) else {
                #if DEBUG
                print("[ScheduleManager] Mode not found for schedule '\(schedule.name)', skipping")
                #endif
                continue
            }

            let activityName = "ctrl_schedule_\(schedule.id.uuidString)"
            expectedActivities.insert(activityName)

            if !currentlyMonitored.contains(activityName) {
                // New or re-enabled — register it (registerSchedule calls syncScheduleShields internally)
                let name = DeviceActivityName(activityName)
                let deviceSchedule = DeviceActivitySchedule(
                    intervalStart: schedule.startTime,
                    intervalEnd: schedule.endTime,
                    repeats: true
                )
                do {
                    try center.startMonitoring(name, during: deviceSchedule)
                    writeSelectionToShared(schedule: schedule, mode: mode)
                    #if DEBUG
                    print("[ScheduleManager] Registered schedule '\(schedule.name)' — \(schedule.timeRangeString)")
                    #endif
                } catch {
                    #if DEBUG
                    print("[ScheduleManager] Failed to register schedule '\(schedule.name)': \(error.localizedDescription)")
                    #endif
                }
            } else {
                // Already monitored — just update shared storage (mode may have changed)
                writeSelectionToShared(schedule: schedule, mode: mode)
            }
        }

        // Stop only stale activities (deleted or disabled schedules)
        let staleActivities = currentlyMonitored
            .filter { $0.hasPrefix("ctrl_schedule_") }
            .subtracting(expectedActivities)

        if !staleActivities.isEmpty {
            let staleNames = staleActivities.map { DeviceActivityName($0) }
            center.stopMonitoring(staleNames)
            #if DEBUG
            print("[ScheduleManager] Stopped \(staleActivities.count) stale monitoring activities")
            #endif
        }

        // Single sync pass after all registrations
        syncScheduleShields()

        // Schedule BGTask fallback for next transition
        scheduleNextBGTask(schedules: schedules)

        // Schedule notifications for all enabled schedules
        for schedule in schedules where schedule.isEnabled {
            scheduleNotifications(for: schedule)
        }

        // Schedule imminent dispatch timer
        scheduleImminentSync(for: schedules)

        #if DEBUG
        let enabledCount = schedules.filter { $0.isEnabled }.count
        print("[ScheduleManager] Differential re-registration — \(enabledCount) enabled, \(currentlyMonitored.count) already monitored, \(staleActivities.count) stale removed")
        #endif
    }

    // MARK: - Schedule Shield Sync (Primary Activation Mechanism)

    /// Evaluate ALL schedules and apply or clear the "schedule" store atomically.
    /// This is the primary activation mechanism — called from every foreground event,
    /// BGTask handler, schedule save/toggle, and app launch.
    ///
    /// Overlap rules:
    /// 1. Active schedule persists until its window ends (no mid-session switching)
    /// 2. Candidates sorted by start time (earliest first) for deterministic priority
    /// 3. Manual NFC sessions block schedule activation
    func syncScheduleShields() {
        cleanupStaleSkipFlags()

        let calendar = Calendar.current
        let now = Date()
        let todayWeekday = calendar.component(.weekday, from: now)
        let yesterdayWeekday = todayWeekday == 1 ? 7 : todayWeekday - 1
        let currentMinutes = calendar.component(.hour, from: now) * 60 + calendar.component(.minute, from: now)

        // Manual-session guard: don't activate schedules during manual NFC sessions
        let manualStore = ManagedSettingsStore(named: .init("manual"))
        if manualStore.shield.applications != nil || manualStore.shield.applicationCategories != nil {
            #if DEBUG
            print("[ScheduleManager] syncScheduleShields — manual session active, skipping schedule activation")
            #endif
            return
        }

        let appState = AppState.shared

        #if DEBUG
        print("[ScheduleManager] syncScheduleShields — now: \(currentMinutes)min, weekday: \(todayWeekday), schedules: \(appState.schedules.count)")
        #endif

        // If an active schedule is still in-window, keep it (don't switch mid-session)
        if let activeId = activeScheduleId,
           let uuid = UUID(uuidString: activeId),
           let activeSchedule = appState.schedules.first(where: { $0.id == uuid }),
           activeSchedule.isEnabled,
           let activeMode = appState.modes.first(where: { $0.id == activeSchedule.modeId }),
           !isScheduleSkippedToday(activeId) {

            if isScheduleInWindow(activeSchedule, currentMinutes: currentMinutes,
                                  todayWeekday: todayWeekday, yesterdayWeekday: yesterdayWeekday) {
                // Re-apply shields (idempotent — ensures consistency after reboot/crash)
                let selection = activeMode.appSelection
                store.shield.applications = selection.applicationTokens.isEmpty ? nil : selection.applicationTokens
                // Category fallback only for pre-migration modes with no expanded applicationTokens
                store.shield.applicationCategories = (selection.applicationTokens.isEmpty && !selection.categoryTokens.isEmpty)
                    ? .specific(selection.categoryTokens) : nil
                store.shield.webDomains = selection.webDomainTokens.isEmpty ? nil : selection.webDomainTokens
                #if DEBUG
                print("[ScheduleManager]   '\(activeSchedule.name)' — still active, maintaining shields")
                #endif
                return
            }
            // Active schedule's window ended — fall through to find next candidate
        }

        // Collect all in-window candidates with their start times
        var candidates: [(schedule: FocusSchedule, mode: BlockingMode, startMin: Int)] = []

        for schedule in appState.schedules where schedule.isEnabled {
            guard let mode = appState.modes.first(where: { $0.id == schedule.modeId }) else {
                #if DEBUG
                print("[ScheduleManager]   '\(schedule.name)' — SKIP: mode not found")
                #endif
                continue
            }
            guard !isScheduleSkippedToday(schedule.id.uuidString) else {
                #if DEBUG
                print("[ScheduleManager]   '\(schedule.name)' — SKIP: skipped today")
                #endif
                continue
            }

            if isScheduleInWindow(schedule, currentMinutes: currentMinutes,
                                  todayWeekday: todayWeekday, yesterdayWeekday: yesterdayWeekday) {
                let startMin = (schedule.startTime.hour ?? 0) * 60 + (schedule.startTime.minute ?? 0)
                candidates.append((schedule, mode, startMin))
            }
        }

        // Sort by start time (earliest first) — deterministic overlap priority
        // Tiebreaker by UUID ensures stable ordering when start times match
        candidates.sort {
            if $0.startMin != $1.startMin { return $0.startMin < $1.startMin }
            return $0.schedule.id.uuidString < $1.schedule.id.uuidString
        }

        if let winner = candidates.first {
            let schedule = winner.schedule
            let mode = winner.mode
            let selection = mode.appSelection
            store.shield.applications = selection.applicationTokens.isEmpty ? nil : selection.applicationTokens
            // Category fallback only for pre-migration modes with no expanded applicationTokens
            store.shield.applicationCategories = (selection.applicationTokens.isEmpty && !selection.categoryTokens.isEmpty)
                ? .specific(selection.categoryTokens) : nil
            store.shield.webDomains = selection.webDomainTokens.isEmpty ? nil : selection.webDomainTokens

            let scheduleIdString = schedule.id.uuidString
            sharedDefaults.set(scheduleIdString, forKey: "active_schedule_id")
            sharedDefaults.synchronize()

            if activeScheduleId != scheduleIdString {
                activeScheduleId = scheduleIdString
                #if DEBUG
                print("[ScheduleManager] syncScheduleShields — activated '\(schedule.name)'")
                print("[ScheduleManager]   apps: \(store.shield.applications?.count ?? 0)")
                print("[ScheduleManager]   categories: \(store.shield.applicationCategories != nil)")
                print("[ScheduleManager]   webDomains: \(store.shield.webDomains?.count ?? 0)")
                #endif
            }
        } else {
            // No schedule in window — but don't clear if requireNFCToEnd is set
            if let activeId = activeScheduleId,
               let uuid = UUID(uuidString: activeId),
               let activeSchedule = AppState.shared.schedules.first(where: { $0.id == uuid }),
               activeSchedule.requireNFCToEnd {
                #if DEBUG
                print("[ScheduleManager] syncScheduleShields — window ended but requireNFCToEnd, shields remain")
                #endif
                return // Shields stay until NFC tap
            }

            // Clear the schedule store
            if activeScheduleId != nil {
                store.shield.applications = nil
                store.shield.applicationCategories = nil
                store.shield.webDomains = nil
                store.clearAllSettings()
                clearActiveSchedule()
                #if DEBUG
                print("[ScheduleManager] syncScheduleShields — cleared shields, no active schedule")
                #endif
            }
        }
    }

    /// Check if a schedule is currently in its active time window
    private func isScheduleInWindow(_ schedule: FocusSchedule, currentMinutes: Int,
                                     todayWeekday: Int, yesterdayWeekday: Int) -> Bool {
        let startMin = (schedule.startTime.hour ?? 0) * 60 + (schedule.startTime.minute ?? 0)
        let endMin = (schedule.endTime.hour ?? 0) * 60 + (schedule.endTime.minute ?? 0)

        let isInWindow: Bool
        let relevantWeekday: Int

        if endMin > startMin {
            // Same-day schedule (e.g. 9:00 AM – 5:00 PM)
            isInWindow = currentMinutes >= startMin && currentMinutes < endMin
            relevantWeekday = todayWeekday
        } else {
            // Crosses midnight (e.g. 10:00 PM – 6:00 AM)
            if currentMinutes >= startMin {
                isInWindow = true; relevantWeekday = todayWeekday
            } else if currentMinutes < endMin {
                isInWindow = true; relevantWeekday = yesterdayWeekday
            } else {
                isInWindow = false; relevantWeekday = todayWeekday
            }
        }

        #if DEBUG
        let dayMatch = schedule.repeatDays.contains(relevantWeekday)
        print("[ScheduleManager]   '\(schedule.name)' — window: \(startMin)-\(endMin), inWindow: \(isInWindow), weekday \(relevantWeekday) match: \(dayMatch), days: \(schedule.repeatDays.sorted())")
        #endif

        return isInWindow && schedule.repeatDays.contains(relevantWeekday)
    }

    // MARK: - Shared Storage

    /// Write schedule metadata as simple key-value pairs for the extension.
    /// Mode tokens are written separately by AppState on mode save.
    private func writeSelectionToShared(schedule: FocusSchedule, mode: BlockingMode) {
        let id = schedule.id.uuidString

        // Schedule → Mode mapping (extension reads this to find mode tokens)
        sharedDefaults.set(schedule.modeId.uuidString, forKey: "schedule_modeId_\(id)")

        // Individual config values (no JSON blob)
        sharedDefaults.set(schedule.requireNFCToEnd, forKey: "schedule_requireNFC_\(id)")
        sharedDefaults.set(Array(schedule.repeatDays), forKey: "schedule_repeatDays_\(id)")

        sharedDefaults.synchronize()

        #if DEBUG
        print("[ScheduleManager] Wrote shared storage for schedule '\(schedule.name)' → mode \(schedule.modeId.uuidString)")
        #endif
    }

    /// Remove shared storage for a schedule
    private func removeSelectionFromShared(schedule: FocusSchedule) {
        let id = schedule.id.uuidString
        // New keys
        sharedDefaults.removeObject(forKey: "schedule_modeId_\(id)")
        sharedDefaults.removeObject(forKey: "schedule_requireNFC_\(id)")
        sharedDefaults.removeObject(forKey: "schedule_repeatDays_\(id)")
        // Skip flag cleanup
        sharedDefaults.removeObject(forKey: "schedule_skipped_\(id)")
        // Legacy cleanup
        sharedDefaults.removeObject(forKey: "schedule_selection_\(id)")
        sharedDefaults.removeObject(forKey: "schedule_config_\(id)")
        sharedDefaults.synchronize()
    }

    /// Clear the active schedule ID from shared storage (called when NFC ends a scheduled session)
    func clearActiveSchedule() {
        sharedDefaults.removeObject(forKey: "active_schedule_id")
        sharedDefaults.synchronize()
        activeScheduleId = nil
        #if DEBUG
        print("[ScheduleManager] Cleared active schedule ID from shared storage")
        #endif
    }

    /// End the active scheduled session — clears shields and active ID.
    /// Called when user taps NFC or override to end a scheduled session early.
    /// After clearing, checks if another overlapping schedule should take over (handoff).
    func endActiveSession() {
        // Mark as skipped today so it doesn't reactivate in this window
        if let scheduleId = activeScheduleId {
            markScheduleSkippedToday(scheduleId)
        }
        store.shield.applications = nil
        store.shield.applicationCategories = nil
        store.shield.webDomains = nil
        store.clearAllSettings()
        clearActiveSchedule()

        // Handoff: check if another overlapping schedule should take over
        syncScheduleShields()

        #if DEBUG
        print("[ScheduleManager] Ended active scheduled session — marked skipped, checked for handoff")
        #endif
    }

    /// Refresh published state from shared storage.
    /// Call on app foreground to detect sessions started by the monitor extension.
    func refreshActiveScheduleId() {
        activeScheduleId = sharedDefaults.string(forKey: "active_schedule_id")
    }

    // MARK: - Skip Today (Prevent Reactivation)

    /// Check if the currently active schedule was manually ended today
    func isActiveScheduleSkippedToday() -> Bool {
        guard let id = activeScheduleId else { return false }
        return isScheduleSkippedToday(id)
    }

    /// Clear the skip flag for a schedule. Called when user re-enables or edits a schedule.
    func clearSkipFlag(for scheduleId: String) {
        sharedDefaults.removeObject(forKey: "schedule_skipped_\(scheduleId)")
        sharedDefaults.synchronize()
        #if DEBUG
        print("[ScheduleManager] Cleared skip flag for \(scheduleId)")
        #endif
    }

    /// Remove skip flags from previous days (auto-cleanup on each sync)
    private func cleanupStaleSkipFlags() {
        let today = todayDateString()
        let allKeys = sharedDefaults.dictionaryRepresentation().keys
        for key in allKeys where key.hasPrefix("schedule_skipped_") {
            if let storedDate = sharedDefaults.string(forKey: key), storedDate != today {
                sharedDefaults.removeObject(forKey: key)
            }
        }
    }

    private func markScheduleSkippedToday(_ scheduleId: String) {
        let today = todayDateString()
        sharedDefaults.set(today, forKey: "schedule_skipped_\(scheduleId)")
        sharedDefaults.synchronize()
        #if DEBUG
        print("[ScheduleManager] Marked schedule \(scheduleId) as skipped for \(today)")
        #endif
    }

    private func isScheduleSkippedToday(_ scheduleId: String) -> Bool {
        guard let skippedDate = sharedDefaults.string(forKey: "schedule_skipped_\(scheduleId)") else { return false }
        return skippedDate == todayDateString()
    }

    private func todayDateString() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }

    // MARK: - Extension Debug Info

    /// Read and log debug keys written by CTRLMonitorExtension.
    func logExtensionDebugInfo() {
        #if DEBUG
        let activeId = sharedDefaults.string(forKey: "active_schedule_id") ?? "none"
        let lastStart = sharedDefaults.string(forKey: "debug_lastIntervalDidStart") ?? "never"
        let lastActivity = sharedDefaults.string(forKey: "debug_lastActivityName") ?? "none"
        let lastEnd = sharedDefaults.string(forKey: "debug_lastIntervalDidEnd") ?? "never"
        let lastBGTask = sharedDefaults.string(forKey: "debug_lastBGTaskFired") ?? "never"

        print("[ScheduleManager] === Debug Info ===")
        print("[ScheduleManager] active_schedule_id: \(activeId)")
        print("[ScheduleManager] Extension lastStart: \(lastStart)")
        print("[ScheduleManager] Extension lastActivity: \(lastActivity)")
        print("[ScheduleManager] Extension lastEnd: \(lastEnd)")
        print("[ScheduleManager] BGTask lastFired: \(lastBGTask)")

        // Shield status
        print("[ScheduleManager] Shield apps: \(store.shield.applications?.count ?? 0)")
        print("[ScheduleManager] Shield categories: \(store.shield.applicationCategories != nil)")
        print("[ScheduleManager] Shield webDomains: \(store.shield.webDomains?.count ?? 0)")

        // Shared storage inventory
        let allKeys = sharedDefaults.dictionaryRepresentation().keys
        let modeTokenKeys = allKeys.filter { $0.hasPrefix("mode_tokens_") }
        let scheduleKeys = allKeys.filter { $0.hasPrefix("schedule_modeId_") }
        print("[ScheduleManager] Mode tokens in shared: \(modeTokenKeys.count)")
        print("[ScheduleManager] Schedule mappings in shared: \(scheduleKeys.count)")
        print("[ScheduleManager] ==================")
        #endif
    }

    // MARK: - Background App Refresh Task

    /// Schedule a BGAppRefreshTask to fire near the next schedule transition (start or end).
    func scheduleNextBGTask(schedules: [FocusSchedule]) {
        let request = BGAppRefreshTaskRequest(identifier: "in.getctrl.app.schedule-check")
        request.earliestBeginDate = nextTransitionDate(from: schedules)
            .map { Date(timeInterval: -60, since: $0) }
            ?? Date(timeIntervalSinceNow: 15 * 60)

        do {
            try BGTaskScheduler.shared.submit(request)
            #if DEBUG
            print("[ScheduleManager] Scheduled BGAppRefreshTask — earliest: \(request.earliestBeginDate?.description ?? "nil")")
            #endif
        } catch {
            #if DEBUG
            print("[ScheduleManager] Failed to schedule BGAppRefreshTask: \(error.localizedDescription)")
            #endif
        }
    }

    /// Finds the next upcoming schedule start OR end Date across all enabled schedules.
    private func nextTransitionDate(from schedules: [FocusSchedule]) -> Date? {
        let calendar = Calendar.current
        let now = Date()
        var earliest: Date?

        for schedule in schedules where schedule.isEnabled {
            guard !schedule.repeatDays.isEmpty else { continue }

            let times = [
                (schedule.startTime.hour ?? 0, schedule.startTime.minute ?? 0),
                (schedule.endTime.hour ?? 0, schedule.endTime.minute ?? 0)
            ]

            for dayOffset in 0..<7 {
                guard let candidateDay = calendar.date(byAdding: .day, value: dayOffset, to: now) else { continue }
                let weekday = calendar.component(.weekday, from: candidateDay)
                guard schedule.repeatDays.contains(weekday) else { continue }

                for (hour, minute) in times {
                    var components = calendar.dateComponents([.year, .month, .day], from: candidateDay)
                    components.hour = hour
                    components.minute = minute
                    components.second = 0

                    guard let candidateDate = calendar.date(from: components),
                          candidateDate > now else { continue }

                    if earliest.map({ candidateDate < $0 }) ?? true {
                        earliest = candidateDate
                    }
                }
            }
        }

        return earliest
    }

    // MARK: - Schedule Notifications

    /// Request notification authorization (idempotent — system prompt only shows once)
    func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            #if DEBUG
            print("[ScheduleManager] Notification permission: \(granted), error: \(error?.localizedDescription ?? "none")")
            #endif
        }
    }

    /// Schedule local notifications for a schedule's start times.
    /// Creates one repeating notification per repeat day so the user is reminded to open the app.
    func scheduleNotifications(for schedule: FocusSchedule) {
        let notifCenter = UNUserNotificationCenter.current()

        // Remove existing notifications for this schedule
        let prefix = "ctrl_schedule_\(schedule.id.uuidString)_"
        notifCenter.removePendingNotificationRequests(withIdentifiers:
            schedule.repeatDays.map { "\(prefix)day_\($0)" }
        )

        guard schedule.isEnabled else { return }

        let content = UNMutableNotificationContent()
        content.title = "ctrl"
        content.body = "\(schedule.name) is starting \u{2014} open ctrl to activate blocking"
        content.sound = .default

        for weekday in schedule.repeatDays {
            var dateComponents = DateComponents()
            dateComponents.weekday = weekday
            dateComponents.hour = schedule.startTime.hour
            dateComponents.minute = schedule.startTime.minute

            let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
            let identifier = "\(prefix)day_\(weekday)"
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

            notifCenter.add(request) { error in
                #if DEBUG
                if let error = error {
                    print("[ScheduleManager] Failed to schedule notification \(identifier): \(error.localizedDescription)")
                }
                #endif
            }
        }

        #if DEBUG
        print("[ScheduleManager] Scheduled \(schedule.repeatDays.count) notifications for '\(schedule.name)'")
        #endif
    }

    /// Remove all notifications for a schedule
    func removeNotifications(for scheduleId: UUID) {
        let notifCenter = UNUserNotificationCenter.current()
        let identifiers = (1...7).map { "ctrl_schedule_\(scheduleId.uuidString)_day_\($0)" }
        notifCenter.removePendingNotificationRequests(withIdentifiers: identifiers)

        #if DEBUG
        print("[ScheduleManager] Removed notifications for schedule \(scheduleId.uuidString)")
        #endif
    }

    // MARK: - Imminent Schedule Sync

    /// If a schedule starts within the next 30 minutes and today is a scheduled day,
    /// dispatch a precise in-memory call to syncScheduleShields() at the exact start time.
    /// Only works while the app process is alive (foreground or suspended).
    func scheduleImminentSync(for schedules: [FocusSchedule]) {
        imminentSyncWorkItem?.cancel()

        let calendar = Calendar.current
        let now = Date()
        let todayWeekday = calendar.component(.weekday, from: now)

        var earliestDelay: TimeInterval?

        for schedule in schedules where schedule.isEnabled {
            guard schedule.repeatDays.contains(todayWeekday) else { continue }

            var startComponents = calendar.dateComponents([.year, .month, .day], from: now)
            startComponents.hour = schedule.startTime.hour
            startComponents.minute = schedule.startTime.minute
            startComponents.second = 0

            guard let startDate = calendar.date(from: startComponents) else { continue }
            let delay = startDate.timeIntervalSince(now)

            // Only schedule if start is 0–30 minutes from now
            guard delay > 0 && delay <= 30 * 60 else { continue }

            if earliestDelay.map({ delay < $0 }) ?? true {
                earliestDelay = delay
            }
        }

        guard let delay = earliestDelay else { return }

        let workItem = DispatchWorkItem { [weak self] in
            self?.syncScheduleShields()
        }
        imminentSyncWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)

        #if DEBUG
        print("[ScheduleManager] Scheduled imminent sync in \(Int(delay))s")
        #endif
    }

    // MARK: - Feature Flag Cleanup

    static func cleanupSchedulesIfDisabled() {
        guard !featureEnabled(.schedules) else { return }
        DeviceActivityCenter().stopMonitoring()
        ManagedSettingsStore(named: .init("schedule")).clearAllSettings()
        let shared = UserDefaults(suiteName: "group.in.getctrl.app")
        shared?.set(false, forKey: "schedule_active")
        shared?.removeObject(forKey: "active_schedule_id")
        #if DEBUG
        print("[ScheduleManager] Schedules disabled — cleaned up monitoring and shields")
        #endif
    }
}
