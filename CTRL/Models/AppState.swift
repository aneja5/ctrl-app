import SwiftUI
import Combine
import FamilyControls

enum SessionStartMethod: String, Codable {
    case nfc
    case manual
}

struct BreakOption: Identifiable {
    let id = UUID()
    let durationMinutes: Int     // 5 or 10
    var durationSeconds: Int { durationMinutes * 60 }
}

struct BreakMilestone {
    let focusMinutesRequired: Int   // 25, 45, 90
    let breakMinutes: Int           // 5, 5, 10
}

class AppState: ObservableObject {

    // MARK: - Singleton

    static let shared = AppState()

    // MARK: - UserDefaults Keys

    private enum Keys {
        static let isBlocking = "ctrl_is_blocking"
        static let selectedApps = "ctrl_selected_apps_data"
        static let emergencyUnlocks = "ctrl_emergency_unlocks_remaining"
        static let emergencyResetDate = "ctrl_emergency_reset_date"
        static let modesData = "ctrl_modes_data"
        static let activeModeId = "ctrl_active_mode_id"
        static let totalBlockedSeconds = "ctrl_total_blocked_seconds"
        static let focusDate = "ctrl_focus_date"
        static let focusHistory = "ctrl_focus_history"
        static let blockingStartDate = "ctrl_blocking_start_date"
        static let strictMode = "ctrl_strict_mode"
        static let hasCompletedOnboarding = "ctrl_has_completed_onboarding"
        static let userEmail = "ctrl_user_email"
        static let sessionStartTime = "ctrl_session_start_time"
        static let isInSession = "ctrl_is_in_session"
        static let schedulesData = "ctrl_schedules_data"
        static let sessionStartMethod = "ctrl_session_start_method"
        static let registrationDate = "ctrl_registration_date"
        static let currentStreak = "ctrl_current_streak"
        static let longestStreak = "ctrl_longest_streak"
        static let lastStreakDate = "ctrl_last_streak_date"
        static let longestSessionSeconds = "ctrl_longest_session_seconds"
        static let longestSessionDate = "ctrl_longest_session_date"
        static let bestDaySeconds = "ctrl_best_day_seconds"
        static let bestDayDate = "ctrl_best_day_date"
        static let bestWeekSeconds = "ctrl_best_week_seconds"
        static let bestWeekStart = "ctrl_best_week_start"
        static let cumulativeLifetimeSeconds = "ctrl_cumulative_lifetime_seconds"
        static let cumulativeLifetimeSessions = "ctrl_cumulative_lifetime_sessions"
        static let cumulativeLifetimeDays = "ctrl_cumulative_lifetime_days"
        static let lastOverrideUsedDate = "ctrl_last_override_used_date"
        static let overrideEarnBackDays = "ctrl_override_earn_back_days"
        static let overrideV2Migrated = "ctrl_override_v2_migrated"
    }

    // MARK: - Persistence

    private let defaults: UserDefaults
    private var cancellables = Set<AnyCancellable>()
    private var isLoadingState = false  // Prevents didSet triggers during loadState

    // MARK: - Published Properties

    @Published var isAuthorized: Bool = false
    @Published var isBlocking: Bool = false
    @Published var selectedApps: FamilyActivitySelection = FamilyActivitySelection(includeEntireCategory: true)
    @Published var modes: [BlockingMode] = [] {
        didSet {
            #if DEBUG
            print("[AppState] Modes changed: \(modes.count) modes")
            if modes.isEmpty {
                print("[AppState] ⚠️ MODES CLEARED - stack trace needed")
                Thread.callStackSymbols.forEach { print($0) }
            }
            #endif
            // Don't saveState() here — Combine observer handles it (debounced)
        }
    }
    @Published var activeModeId: UUID? = nil
    @Published var emergencyUnlocksRemaining: Int = AppConstants.startingOverrides
    @Published var totalBlockedSeconds: TimeInterval = 0
    @Published var focusHistory: [DailyFocusEntry] = []
    @Published var strictModeEnabled: Bool = false
    @Published var hasCompletedOnboarding: Bool = false
    @Published var userEmail: String? = nil
    @Published var isReturningFromNewDevice: Bool = false  // Transient — not persisted
    @Published var showReselectionAlert: Bool = false  // Transient — fires on launch if stale modes exist
    @Published var isInSession: Bool = false
    @Published var sessionStartMethod: SessionStartMethod = .nfc
    @Published var elapsedSeconds: Int = 0
    @Published var schedules: [FocusSchedule] = []
    @Published var currentStreak: Int = 0
    @Published var longestStreak: Int = 0
    var lastStreakDate: String? = nil  // "yyyy-MM-dd"

    // Personal records
    var longestSessionSeconds: Int = 0
    var longestSessionDate: Date? = nil
    var bestDaySeconds: Int = 0
    var bestDayDate: Date? = nil
    var bestWeekSeconds: Int = 0
    var bestWeekStart: Date? = nil

    // Cumulative lifetime counters (survive 90-day history trim)
    var cumulativeLifetimeSeconds: TimeInterval = 0
    var cumulativeLifetimeSessions: Int = 0
    var cumulativeLifetimeDays: Int = 0

    // MARK: - Break State (in-memory only, not persisted)

    static let breakMilestones: [BreakMilestone] = [
        BreakMilestone(focusMinutesRequired: 25, breakMinutes: 5),
        BreakMilestone(focusMinutesRequired: 45, breakMinutes: 5),
        BreakMilestone(focusMinutesRequired: 90, breakMinutes: 10),
    ]

    /// Breaks the user has earned but not yet taken
    @Published var earnedBreaks: [BreakOption] = []

    /// Whether the user is currently on a break
    @Published var isOnBreak: Bool = false

    /// Seconds remaining in the current break (counts down)
    @Published var breakSecondsRemaining: Int = 0

    /// Total break seconds consumed so far this session (for stats)
    var totalBreakSecondsTaken: Int = 0

    /// When the current break started
    var breakStartDate: Date? = nil

    /// Total duration of the current break in seconds (for foreground catch-up)
    var breakTotalDuration: Int = 0

    /// Which milestone indices have been reached this session (to avoid re-earning)
    private var earnedMilestoneIndices: Set<Int> = []

    /// Focus-only elapsed seconds (total elapsed minus break time)
    var focusSecondsExcludingBreaks: Int {
        let breakSecondsInProgress = isOnBreak
            ? Int(Date().timeIntervalSince(breakStartDate ?? Date()))
            : 0
        return max(0, elapsedSeconds - totalBreakSecondsTaken - breakSecondsInProgress)
    }

    @Published var sessionStartTime: Date? {
        didSet {
            if !isLoadingState {
                debouncedSave()
            }
        }
    }
    var lastOverrideUsedDate: String? = nil   // "yyyy-MM-dd" format
    var overrideEarnBackDays: Int = 0
    @Published var pendingOverrideEarnedNotification: Bool = false
    var registrationDate: Date?
    var blockingStartDate: Date? = nil
    var focusDate: Date? = nil
    private var timer: Timer?

    /// Modes that were saved before the includeEntireCategory fix and need re-selection.
    var modesNeedingReselection: [BlockingMode] {
        modes.filter { $0.needsReselection }
    }

    // MARK: - Computed Properties

    var activeMode: BlockingMode? {
        guard let id = activeModeId else { return nil }
        return modes.first { $0.id == id }
    }

    /// User has modes = they've used the app before
    var hasPreviousData: Bool {
        return !modes.isEmpty
    }

    /// Screen Time permission has been granted
    var hasScreenTimePermission: Bool {
        return AuthorizationCenter.shared.authorizationStatus == .approved
    }

    // MARK: - Init

    private init() {
        #if DEBUG
        print("[AppState] init - START")
        #endif
        if let suiteDefaults = UserDefaults(suiteName: "group.in.getctrl.app") {
            self.defaults = suiteDefaults
        } else {
            self.defaults = UserDefaults.standard
            #if DEBUG
            print("[AppState] WARNING: App Group unavailable, falling back to standard UserDefaults")
            #endif
        }

        // Detect fresh install BEFORE loading state
        // Keychain (Supabase auth) survives app deletion, UserDefaults does not
        // Only sign out if truly fresh — no onboarding AND no email (mid-onboarding users have email)
        let hasOnboarded = defaults.bool(forKey: Keys.hasCompletedOnboarding)
        let hasEmail = defaults.string(forKey: Keys.userEmail) != nil
        if !hasOnboarded && !hasEmail {
            #if DEBUG
            print("[AppState] Fresh install detected - clearing stale Keychain auth")
            #endif
            Task {
                try? await SupabaseManager.shared.signOut()
            }
        }

        loadState()
        observeChanges()
        restoreSessionIfNeeded()

        #if DEBUG
        print("[AppState] Init complete — hasCompletedOnboarding: \(hasCompletedOnboarding), modes: \(modes.count)")
        #endif
    }

    // MARK: - Auto-Save Observers

    private func observeChanges() {
        $selectedApps
            .dropFirst()
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] _ in self?.debouncedSave() }
            .store(in: &cancellables)

        $modes
            .dropFirst()
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] _ in self?.debouncedSave() }
            .store(in: &cancellables)

        $activeModeId
            .dropFirst()
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] _ in self?.debouncedSave() }
            .store(in: &cancellables)

        $schedules
            .dropFirst()
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] _ in self?.debouncedSave() }
            .store(in: &cancellables)
    }

    // MARK: - State Persistence

    func loadState() {
        isLoadingState = true
        defer { isLoadingState = false }

        hasCompletedOnboarding = defaults.bool(forKey: Keys.hasCompletedOnboarding)
        userEmail = defaults.string(forKey: Keys.userEmail)
        // isBlocking is NOT persisted — always starts as false on launch
        // Clean up any stale value from previous versions
        defaults.removeObject(forKey: Keys.isBlocking)

        if let data = defaults.data(forKey: Keys.selectedApps),
           let selection = try? PropertyListDecoder().decode(FamilyActivitySelection.self, from: data) {
            // Re-apply includeEntireCategory which is lost during deserialization
            selectedApps = selection.withIncludeEntireCategory()
        }

        // Load modes
        if let data = defaults.data(forKey: Keys.modesData),
           let loadedModes = try? JSONDecoder().decode([BlockingMode].self, from: data) {
            // Deduplicate by name (keep first occurrence)
            var seenNames = Set<String>()
            let uniqueModes = loadedModes.filter { mode in
                let key = mode.name.lowercased()
                if seenNames.contains(key) {
                    return false
                }
                seenNames.insert(key)
                return true
            }
            modes = uniqueModes

            // Migration: write mode tokens to shared storage for extension access
            for mode in uniqueModes {
                writeModeTokenToShared(mode)
            }

            // Migration: detect modes saved before includeEntireCategory fix
            // Only applies to pre-v1.0 TestFlight users — fresh installs are unaffected
            if !defaults.bool(forKey: "didRunCategoryMigration") {
                if uniqueModes.contains(where: { $0.needsReselection }) {
                    showReselectionAlert = true
                    #if DEBUG
                    let staleNames = uniqueModes.filter { $0.needsReselection }.map { $0.name }
                    print("[AppState] Migration: modes need re-selection: \(staleNames)")
                    #endif
                } else {
                    defaults.set(true, forKey: "didRunCategoryMigration")
                }
            }
        }

        // Load active mode ID
        if let idString = defaults.string(forKey: Keys.activeModeId),
           let id = UUID(uuidString: idString) {
            activeModeId = id
        }

        // Ensure activeModeId points to an existing mode
        if !modes.isEmpty && (activeModeId == nil || !modes.contains(where: { $0.id == activeModeId })) {
            activeModeId = modes.first?.id
        }

        // Load override data (v2 earn-back system)
        if defaults.object(forKey: Keys.emergencyUnlocks) != nil {
            emergencyUnlocksRemaining = defaults.integer(forKey: Keys.emergencyUnlocks)
        } else {
            emergencyUnlocksRemaining = AppConstants.startingOverrides
        }
        lastOverrideUsedDate = defaults.string(forKey: Keys.lastOverrideUsedDate)
        overrideEarnBackDays = defaults.integer(forKey: Keys.overrideEarnBackDays)
        registrationDate = defaults.object(forKey: Keys.registrationDate) as? Date
        // Backfill for existing users who onboarded before registrationDate was tracked
        if registrationDate == nil && hasCompletedOnboarding {
            registrationDate = Date()
            defaults.set(registrationDate, forKey: Keys.registrationDate)
        }
        totalBlockedSeconds = defaults.double(forKey: Keys.totalBlockedSeconds)
        focusDate = defaults.object(forKey: Keys.focusDate) as? Date
        if let data = defaults.data(forKey: Keys.focusHistory),
           let history = try? JSONDecoder().decode([DailyFocusEntry].self, from: data) {
            focusHistory = history
        }
        blockingStartDate = defaults.object(forKey: Keys.blockingStartDate) as? Date
        strictModeEnabled = defaults.bool(forKey: Keys.strictMode)

        // If app was blocking but no start date recorded, set it now
        if isBlocking && blockingStartDate == nil {
            blockingStartDate = Date()
            #if DEBUG
            print("[AppState] Restored missing blockingStartDate")
            #endif
        }

        // Load session state
        isInSession = defaults.bool(forKey: Keys.isInSession)
        if let methodString = defaults.string(forKey: Keys.sessionStartMethod),
           let method = SessionStartMethod(rawValue: methodString) {
            sessionStartMethod = method
        } else {
            sessionStartMethod = .nfc
        }

        let startTimeInterval = defaults.double(forKey: Keys.sessionStartTime)
        if startTimeInterval > 0 {
            sessionStartTime = Date(timeIntervalSince1970: startTimeInterval)
        } else {
            sessionStartTime = nil
        }

        // Load schedules
        if let data = defaults.data(forKey: Keys.schedulesData),
           let loadedSchedules = try? JSONDecoder().decode([FocusSchedule].self, from: data) {
            schedules = loadedSchedules
        }

        // Load streak data
        currentStreak = defaults.integer(forKey: Keys.currentStreak)
        longestStreak = defaults.integer(forKey: Keys.longestStreak)
        lastStreakDate = defaults.string(forKey: Keys.lastStreakDate)

        // Load personal records
        longestSessionSeconds = defaults.integer(forKey: Keys.longestSessionSeconds)
        longestSessionDate = defaults.object(forKey: Keys.longestSessionDate) as? Date
        bestDaySeconds = defaults.integer(forKey: Keys.bestDaySeconds)
        bestDayDate = defaults.object(forKey: Keys.bestDayDate) as? Date
        bestWeekSeconds = defaults.integer(forKey: Keys.bestWeekSeconds)
        bestWeekStart = defaults.object(forKey: Keys.bestWeekStart) as? Date

        // Load cumulative lifetime counters
        cumulativeLifetimeSeconds = defaults.double(forKey: Keys.cumulativeLifetimeSeconds)
        cumulativeLifetimeSessions = defaults.integer(forKey: Keys.cumulativeLifetimeSessions)
        cumulativeLifetimeDays = defaults.integer(forKey: Keys.cumulativeLifetimeDays)

        // Backfill cumulative counters from existing focusHistory (one-time migration)
        if cumulativeLifetimeSeconds == 0 && cumulativeLifetimeSessions == 0 && !focusHistory.isEmpty {
            let historySeconds = focusHistory.reduce(0.0) { $0 + $1.totalSeconds }
            let historySessions = focusHistory.reduce(0) { $0 + $1.sessionCount }
            let historyDays = focusHistory.filter { $0.totalSeconds > 0 }.count
            if historySeconds > 0 {
                cumulativeLifetimeSeconds = historySeconds
                cumulativeLifetimeSessions = historySessions
                cumulativeLifetimeDays = historyDays
                defaults.set(cumulativeLifetimeSeconds, forKey: Keys.cumulativeLifetimeSeconds)
                defaults.set(cumulativeLifetimeSessions, forKey: Keys.cumulativeLifetimeSessions)
                defaults.set(cumulativeLifetimeDays, forKey: Keys.cumulativeLifetimeDays)
                #if DEBUG
                print("[AppState] Backfilled cumulative counters: \(Int(cumulativeLifetimeSeconds))s, \(cumulativeLifetimeSessions) sessions, \(cumulativeLifetimeDays) days")
                #endif
            }
        }

        // Recalculate streak from history (handles app not opened for days)
        recalculateStreakFromHistory()

        checkAndResetDailyFocusTime()
        migrateToOverrideV2IfNeeded()

        #if DEBUG
        print("[AppState] loadState — email: \(userEmail ?? "nil"), onboarded: \(hasCompletedOnboarding), modes: \(modes.count)")
        for mode in modes {
            let appCount = mode.appSelection.applicationTokens.count
            let catCount = mode.appSelection.categoryTokens.count
            print("[AppState]   Loaded mode '\(mode.name)' with \(appCount) apps, \(catCount) categories")
        }
        #endif
    }

    // MARK: - Debounced Save

    private var saveWorkItem: DispatchWorkItem?

    /// Debounced save — coalesces rapid changes into a single write
    private func debouncedSave() {
        saveWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.saveState()
        }
        saveWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: workItem)
    }

    func saveState() {
        guard !isLoadingState else {
            #if DEBUG
            print("[AppState] saveState - SKIPPED (loading in progress)")
            #endif
            return
        }

        // isBlocking intentionally NOT saved

        if let data = try? PropertyListEncoder().encode(selectedApps) {
            defaults.set(data, forKey: Keys.selectedApps)
        }

        if let data = try? JSONEncoder().encode(modes) {
            defaults.set(data, forKey: Keys.modesData)
        }
        defaults.set(activeModeId?.uuidString, forKey: Keys.activeModeId)

        defaults.set(emergencyUnlocksRemaining, forKey: Keys.emergencyUnlocks)
        defaults.set(lastOverrideUsedDate, forKey: Keys.lastOverrideUsedDate)
        defaults.set(overrideEarnBackDays, forKey: Keys.overrideEarnBackDays)
        if let regDate = registrationDate {
            defaults.set(regDate, forKey: Keys.registrationDate)
        }
        defaults.set(totalBlockedSeconds, forKey: Keys.totalBlockedSeconds)
        if let date = focusDate {
            defaults.set(date, forKey: Keys.focusDate)
        }
        if let data = try? JSONEncoder().encode(focusHistory) {
            defaults.set(data, forKey: Keys.focusHistory)
        }

        if let startDate = blockingStartDate {
            defaults.set(startDate, forKey: Keys.blockingStartDate)
        } else {
            defaults.removeObject(forKey: Keys.blockingStartDate)
        }
        defaults.set(strictModeEnabled, forKey: Keys.strictMode)
        defaults.set(hasCompletedOnboarding, forKey: Keys.hasCompletedOnboarding)
        defaults.set(userEmail, forKey: Keys.userEmail)

        // Save schedules
        if let data = try? JSONEncoder().encode(schedules) {
            defaults.set(data, forKey: Keys.schedulesData)
        }

        // Save session state
        defaults.set(isInSession, forKey: Keys.isInSession)
        defaults.set(sessionStartMethod.rawValue, forKey: Keys.sessionStartMethod)
        if let startTime = sessionStartTime {
            defaults.set(startTime.timeIntervalSince1970, forKey: Keys.sessionStartTime)
        } else {
            defaults.removeObject(forKey: Keys.sessionStartTime)
        }

        // Save streak data
        defaults.set(currentStreak, forKey: Keys.currentStreak)
        defaults.set(longestStreak, forKey: Keys.longestStreak)
        defaults.set(lastStreakDate, forKey: Keys.lastStreakDate)

        // Save personal records
        defaults.set(longestSessionSeconds, forKey: Keys.longestSessionSeconds)
        if let d = longestSessionDate { defaults.set(d, forKey: Keys.longestSessionDate) }
        defaults.set(bestDaySeconds, forKey: Keys.bestDaySeconds)
        if let d = bestDayDate { defaults.set(d, forKey: Keys.bestDayDate) }
        defaults.set(bestWeekSeconds, forKey: Keys.bestWeekSeconds)
        if let d = bestWeekStart { defaults.set(d, forKey: Keys.bestWeekStart) }

        // Save cumulative lifetime counters
        defaults.set(cumulativeLifetimeSeconds, forKey: Keys.cumulativeLifetimeSeconds)
        defaults.set(cumulativeLifetimeSessions, forKey: Keys.cumulativeLifetimeSessions)
        defaults.set(cumulativeLifetimeDays, forKey: Keys.cumulativeLifetimeDays)

        defaults.synchronize()

        #if DEBUG
        print("[AppState] saveState — modes: \(modes.count), activeMode: \(activeMode?.name ?? "nil")")
        for mode in modes {
            let appCount = mode.appSelection.applicationTokens.count
            let catCount = mode.appSelection.categoryTokens.count
            print("[AppState]   Saving mode '\(mode.name)' with \(appCount) apps, \(catCount) categories")
        }
        #endif
    }

    // MARK: - Selected Apps

    func saveSelectedApps(_ selection: FamilyActivitySelection) {
        // Don't overwrite existing apps with empty selection
        if selection.applicationTokens.isEmpty && selection.categoryTokens.isEmpty {
            if !self.selectedApps.applicationTokens.isEmpty || !self.selectedApps.categoryTokens.isEmpty {
                return
            }
        }

        self.selectedApps = selection
        if let data = try? PropertyListEncoder().encode(selection) {
            defaults.set(data, forKey: Keys.selectedApps)
            defaults.synchronize()
        }

        // Sync to the active mode
        if let id = activeModeId, let index = modes.firstIndex(where: { $0.id == id }) {
            modes[index].appSelection = selection
        }
    }

    // MARK: - Emergency Unlock (Earn-Back System)

    func useEmergencyUnlock() -> Bool {
        if emergencyUnlocksRemaining > 0 {
            emergencyUnlocksRemaining -= 1
            lastOverrideUsedDate = DailyFocusEntry.todayKey()
            overrideEarnBackDays = 0
            saveState()
            if featureEnabled(.cloudSync) {
                Task { @MainActor in CloudSyncManager.shared.syncToCloud(appState: self) }
            }
            #if DEBUG
            print("[AppState] Emergency unlock used, remaining: \(emergencyUnlocksRemaining), earn-back reset")
            #endif
            return true
        }
        return false
    }

    /// Recalculates earn-back progress after a session ends.
    /// Walks focusHistory from the day after lastOverrideUsedDate,
    /// counting consecutive days with 10+ minutes of focus.
    /// Awards +1 override when 7 consecutive qualifying days are reached.
    func updateOverrideEarnBack() {
        guard featureEnabled(.overrideEarnBack) else { return }
        guard emergencyUnlocksRemaining < AppConstants.maxOverrides else {
            overrideEarnBackDays = 0
            return
        }

        guard let lastUsedString = lastOverrideUsedDate,
              let lastUsedDate = DailyFocusEntry.dateFormatter.date(from: lastUsedString) else {
            return
        }

        let calendar = Calendar.current
        let formatter = DailyFocusEntry.dateFormatter
        let today = calendar.startOfDay(for: Date())

        guard let startDate = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: lastUsedDate)) else { return }

        let qualifyingDates: Set<String> = Set(
            focusHistory
                .filter { $0.totalSeconds >= AppConstants.minimumSessionForEarnBack }
                .map { $0.date }
        )

        var consecutiveDays = 0
        var checkDate = startDate

        while checkDate <= today {
            let key = formatter.string(from: checkDate)
            if qualifyingDates.contains(key) {
                consecutiveDays += 1
            } else if checkDate < today {
                // Past day with no qualifying session — streak broken
                consecutiveDays = 0
            } else {
                break  // Today not over yet
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: checkDate) else { break }
            checkDate = next
        }

        overrideEarnBackDays = consecutiveDays

        if consecutiveDays >= AppConstants.earnBackStreakDays {
            emergencyUnlocksRemaining = min(emergencyUnlocksRemaining + 1, AppConstants.maxOverrides)
            overrideEarnBackDays = 0
            // Move anchor forward so next earn-back starts fresh
            lastOverrideUsedDate = formatter.string(from: Date())
            pendingOverrideEarnedNotification = true
            #if DEBUG
            print("[AppState] Override earned! Now at \(emergencyUnlocksRemaining)/\(AppConstants.maxOverrides)")
            #endif
        }

        saveState()
    }

    /// One-time migration from monthly-reset overrides to earn-back system.
    private func migrateToOverrideV2IfNeeded() {
        guard !defaults.bool(forKey: Keys.overrideV2Migrated) else { return }
        emergencyUnlocksRemaining = min(emergencyUnlocksRemaining, AppConstants.maxOverrides)
        defaults.removeObject(forKey: Keys.emergencyResetDate)
        defaults.set(true, forKey: Keys.overrideV2Migrated)
        saveState()
        #if DEBUG
        print("[AppState] Migrated to override v2: \(emergencyUnlocksRemaining) overrides")
        #endif
    }

    // MARK: - Focus Time Tracking

    func checkAndResetDailyFocusTime() {
        let calendar = Calendar.current
        let today = Date()

        if let lastDate = focusDate {
            if !calendar.isDateInToday(lastDate) {
                // Archive previous day's total to history.
                // Skip if a session is active — logSessionAcrossDays will handle it when the session ends.
                if totalBlockedSeconds > 0 && !isInSession {
                    let dateKey = DailyFocusEntry.dateFormatter.string(from: lastDate)
                    archiveFocusEntry(date: dateKey, seconds: totalBlockedSeconds)
                }
                totalBlockedSeconds = 0
                focusDate = today
                trimOldHistory()
                saveState()
                #if DEBUG
                print("[AppState] Daily focus time reset\(isInSession ? " (active session — skipped archive, will split on end)" : "")")
                #endif
            }
        } else {
            focusDate = today
            saveState()
        }
    }

    func startBlockingTimer(method: SessionStartMethod = .nfc) {
        guard !isInSession else { return }
        checkAndResetDailyFocusTime()
        isInSession = true
        sessionStartMethod = method
        let now = Date()
        sessionStartTime = now
        blockingStartDate = now
        elapsedSeconds = 0
        startTimer()
        saveState()
    }

    func stopBlockingTimer() {
        guard isInSession else { return }
        // If on break, finalize break time first
        if featureEnabled(.breaks) && isOnBreak {
            endBreak()
        }

        isInSession = false
        sessionStartMethod = .nfc
        sessionStartTime = nil
        timer?.invalidate()
        timer = nil

        // Log focus time — split across calendar days if session crosses midnight
        // Uses focus-only time (excludes break duration) for all stats
        if let startDate = blockingStartDate {
            let now = Date()
            let totalElapsed = Int(now.timeIntervalSince(startDate))
            let focusElapsed = max(0, totalElapsed - totalBreakSecondsTaken)

            if focusElapsed >= AppConstants.minimumSessionToLog {
                totalBlockedSeconds += TimeInterval(focusElapsed)

                // Count new days BEFORE logging (days that had no prior data)
                let newDays = countNewDaysInSession(start: startDate, end: now)

                // Sessions under threshold log time but don't count toward session count
                let countsAsSession = focusElapsed >= AppConstants.minimumSessionForHistory
                logSessionAcrossDays(start: startDate, end: now, totalFocusSeconds: focusElapsed, countSession: countsAsSession)
                updateStreakAndRecords(sessionSeconds: focusElapsed)

                // Increment cumulative lifetime counters
                cumulativeLifetimeSeconds += TimeInterval(focusElapsed)
                if countsAsSession {
                    cumulativeLifetimeSessions += 1
                }
                cumulativeLifetimeDays += newDays

                // Update override earn-back progress
                updateOverrideEarnBack()

                #if DEBUG
                print("[AppState] Session ended — \(focusElapsed)s focus (of \(totalElapsed)s total, \(totalBreakSecondsTaken)s break)")
                #endif
            }
        }

        blockingStartDate = nil
        elapsedSeconds = 0
        if featureEnabled(.breaks) {
            resetBreakState()
        }
        saveState()
        if featureEnabled(.cloudSync) {
            Task { @MainActor in CloudSyncManager.shared.syncToCloud(appState: self) }
        }
    }

    var currentSessionSeconds: TimeInterval {
        guard let start = blockingStartDate else { return 0 }
        return max(0, Date().timeIntervalSince(start))
    }

    // MARK: - Session Restore

    func restoreSessionIfNeeded() {
        guard isInSession else { return }

        guard let startTime = sessionStartTime else {
            #if DEBUG
            print("[AppState] restoreSession - sessionStartTime is nil, cannot restore")
            #endif
            return
        }

        // Restore blockingStartDate if needed
        if blockingStartDate == nil {
            blockingStartDate = startTime
        }

        // Calculate elapsed time
        let elapsed = Int(Date().timeIntervalSince(startTime))
        elapsedSeconds = max(0, elapsed)

        // Re-earn any breaks for this session duration
        // (break state is in-memory only, so it's lost on app kill)
        if featureEnabled(.breaks) {
            checkBreakEarning()
        }

        // Restart the timer
        startTimer()

        #if DEBUG
        print("[AppState] Restored session — elapsed: \(elapsedSeconds)s, earned breaks: \(earnedBreaks.count)")
        #endif
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                guard let self = self else { return }
                if featureEnabled(.breaks) && self.isOnBreak {
                    // Count down break timer
                    self.breakSecondsRemaining -= 1
                } else {
                    // Normal focus timer
                    self.elapsedSeconds += 1
                    if featureEnabled(.breaks) {
                        self.checkBreakEarning()
                    }
                }
            }
        }
    }

    // MARK: - Break Earning

    private func checkBreakEarning() {
        let focusMinutes = focusSecondsExcludingBreaks / 60

        for (index, milestone) in Self.breakMilestones.enumerated() {
            if focusMinutes >= milestone.focusMinutesRequired
                && !earnedMilestoneIndices.contains(index) {
                earnedMilestoneIndices.insert(index)
                earnedBreaks.append(BreakOption(durationMinutes: milestone.breakMinutes))

                #if DEBUG
                print("[AppState] Break earned: \(milestone.breakMinutes)min at \(focusMinutes)min focus")
                #endif
            }
        }
    }

    // MARK: - Break Lifecycle

    func startBreak(_ breakOption: BreakOption) {
        guard !isOnBreak else { return }
        // Remove this break from earned list
        earnedBreaks.removeAll { $0.id == breakOption.id }
        isOnBreak = true
        breakSecondsRemaining = breakOption.durationSeconds
        breakTotalDuration = breakOption.durationSeconds
        breakStartDate = Date()

        #if DEBUG
        print("[AppState] Break started: \(breakOption.durationMinutes)min")
        #endif
    }

    func endBreak() {
        guard isOnBreak else { return }
        if let start = breakStartDate {
            totalBreakSecondsTaken += Int(Date().timeIntervalSince(start))
        }
        isOnBreak = false
        breakSecondsRemaining = 0
        breakTotalDuration = 0
        breakStartDate = nil

        #if DEBUG
        print("[AppState] Break ended. Total break time: \(totalBreakSecondsTaken)s")
        #endif
    }

    func resetBreakState() {
        earnedBreaks = []
        isOnBreak = false
        breakSecondsRemaining = 0
        totalBreakSecondsTaken = 0
        breakStartDate = nil
        breakTotalDuration = 0
        earnedMilestoneIndices = []
    }

    // MARK: - Focus History Helpers

    private func logToTodayHistory(_ seconds: TimeInterval) {
        let todayKey = DailyFocusEntry.todayKey()
        if let index = focusHistory.firstIndex(where: { $0.date == todayKey }) {
            focusHistory[index].totalSeconds += seconds
            focusHistory[index].sessionCount += 1
        } else {
            focusHistory.append(DailyFocusEntry(date: todayKey, totalSeconds: seconds, sessionCount: 1))
        }
    }

    /// Splits a session across calendar-day boundaries and logs each segment to focusHistory.
    /// Example: 11pm–3am logs 1h to day 1, 3h to day 2. Session count goes to start day only.
    /// - Parameter totalFocusSeconds: If provided, scales wall-clock segments to focus-only time (excluding breaks).
    /// - Parameter countSession: If false, only logs seconds without incrementing sessionCount (for sessions < 60s).
    private func logSessionAcrossDays(start: Date, end: Date, totalFocusSeconds: Int? = nil, countSession: Bool = true) {
        let calendar = Calendar.current
        let formatter = DailyFocusEntry.dateFormatter
        var current = start
        var isFirstSegment = true

        let wallClockTotal = end.timeIntervalSince(start)
        let focusTotal = totalFocusSeconds.map { Double($0) } ?? wallClockTotal
        // Ratio to scale each segment's wall-clock seconds to focus-only seconds
        let ratio = wallClockTotal > 0 ? focusTotal / wallClockTotal : 1.0

        while current < end {
            guard let nextDayStart = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: current)) else { break }
            let segmentEnd = min(nextDayStart, end)
            let wallClockSegment = segmentEnd.timeIntervalSince(current)
            let focusSegment = wallClockSegment * ratio

            if focusSegment > 0 {
                let dateKey = formatter.string(from: current)
                let shouldCountSession = countSession && isFirstSegment
                if let index = focusHistory.firstIndex(where: { $0.date == dateKey }) {
                    focusHistory[index].totalSeconds += focusSegment
                    if shouldCountSession {
                        focusHistory[index].sessionCount += 1
                    }
                } else {
                    focusHistory.append(DailyFocusEntry(
                        date: dateKey,
                        totalSeconds: focusSegment,
                        sessionCount: shouldCountSession ? 1 : 0
                    ))
                }
                #if DEBUG
                print("[AppState] Logged \(Int(focusSegment))s to \(dateKey)\(shouldCountSession ? " (+1 session)" : "")")
                #endif
            }

            current = segmentEnd
            isFirstSegment = false
        }
    }

    private func archiveFocusEntry(date: String, seconds: TimeInterval) {
        if let index = focusHistory.firstIndex(where: { $0.date == date }) {
            focusHistory[index].totalSeconds = seconds
        } else {
            focusHistory.append(DailyFocusEntry(date: date, totalSeconds: seconds))
        }
    }

    /// Counts how many calendar days in the session range don't yet have focus data.
    /// Called BEFORE logSessionAcrossDays so we can detect truly new days.
    private func countNewDaysInSession(start: Date, end: Date) -> Int {
        let calendar = Calendar.current
        let formatter = DailyFocusEntry.dateFormatter
        var newDays = 0
        var current = start

        while current < end {
            let dateKey = formatter.string(from: current)
            let existing = focusHistory.first(where: { $0.date == dateKey })
            if existing == nil || existing!.totalSeconds <= 0 {
                newDays += 1
            }
            guard let nextDayStart = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: current)) else { break }
            current = nextDayStart
        }

        return newDays
    }

    private func trimOldHistory() {
        let cutoff = Calendar.current.date(byAdding: .day, value: -AppConstants.historyRetentionDays, to: Date()) ?? Date()
        let cutoffKey = DailyFocusEntry.dateFormatter.string(from: cutoff)
        focusHistory.removeAll { $0.date < cutoffKey }
    }

    // MARK: - Streak Tracking

    /// Recalculates streak from focusHistory. Called on launch to handle
    /// days when the app wasn't opened (streak may have broken).
    func recalculateStreakFromHistory() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let formatter = DailyFocusEntry.dateFormatter

        // Build set of dates with 10+ minute sessions (streak-qualifying)
        let activeDates: Set<String> = Set(
            focusHistory
                .filter { $0.totalSeconds >= Double(AppConstants.minimumSessionForStreak) }
                .map { $0.date }
        )

        // Include today if currently in session or has data
        let todayKey = formatter.string(from: today)
        var checkDates = activeDates
        if isInSession { checkDates.insert(todayKey) }

        // Count consecutive days backwards from today (or yesterday)
        var streak = 0
        var checkDate = today

        // If today has no qualifying data, start from yesterday
        // (give users the full day to maintain streak)
        if !checkDates.contains(todayKey) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: today) else {
                currentStreak = 0
                return
            }
            checkDate = yesterday
        }

        while true {
            let key = formatter.string(from: checkDate)
            if checkDates.contains(key) {
                streak += 1
                guard let prev = calendar.date(byAdding: .day, value: -1, to: checkDate) else { break }
                checkDate = prev
            } else {
                break
            }
        }

        currentStreak = streak

        // Full historical scan for longest streak
        // (walks all qualifying dates chronologically, not just backwards from today)
        let sortedDates = activeDates.sorted()
        var historicalLongest = 0
        var runLength = 0
        var previousDate: Date? = nil

        for dateString in sortedDates {
            guard let date = formatter.date(from: dateString) else { continue }
            if let prev = previousDate,
               let expected = calendar.date(byAdding: .day, value: 1, to: prev),
               calendar.isDate(date, inSameDayAs: expected) {
                runLength += 1
            } else {
                runLength = 1
            }
            historicalLongest = max(historicalLongest, runLength)
            previousDate = date
        }

        longestStreak = max(historicalLongest, streak)
    }

    /// Called after each session ends. Updates streak and personal records.
    func updateStreakAndRecords(sessionSeconds: Int) {
        guard featureEnabled(.streakTracking) else { return }
        let todayKey = DailyFocusEntry.todayKey()

        // --- Streak update ---
        if lastStreakDate == todayKey {
            // Already counted today — just recalc to be safe
            recalculateStreakFromHistory()
        } else {
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: Date())
            let yesterdayKey: String? = {
                guard let y = calendar.date(byAdding: .day, value: -1, to: today) else { return nil }
                return DailyFocusEntry.dateFormatter.string(from: y)
            }()

            // Only count if today's total meets streak-qualifying threshold
            let todayTotal = focusHistory.first(where: { $0.date == todayKey })?.totalSeconds ?? 0
            if Int(todayTotal) >= AppConstants.minimumSessionForStreak {
                if lastStreakDate == yesterdayKey {
                    currentStreak += 1
                } else if lastStreakDate != todayKey {
                    // Gap > 1 day or first streak
                    currentStreak = 1
                }
                lastStreakDate = todayKey
                if currentStreak > longestStreak {
                    longestStreak = currentStreak
                }
            }
        }

        // --- Personal records ---
        // Longest session
        if sessionSeconds > longestSessionSeconds {
            longestSessionSeconds = sessionSeconds
            longestSessionDate = Date()
        }

        // Best day (check today's total)
        let todayTotal = Int(todayFocusSeconds)
        if todayTotal > bestDaySeconds {
            bestDaySeconds = todayTotal
            bestDayDate = Date()
        }

        // Best week (check current week's total)
        let weekTotal = Int(weekFocusSeconds)
        if weekTotal > bestWeekSeconds {
            bestWeekSeconds = weekTotal
            let calendar = CalendarHelper.mondayFirst
            let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())
            bestWeekStart = calendar.date(from: components)
        }
    }

    // MARK: - Focus Stats

    var todayFocusSeconds: TimeInterval {
        let todayKey = DailyFocusEntry.todayKey()
        let logged = focusHistory.first(where: { $0.date == todayKey })?.totalSeconds ?? 0
        // For active sessions spanning midnight, only count today's portion
        if let start = blockingStartDate {
            let startOfToday = Calendar.current.startOfDay(for: Date())
            let effectiveStart = max(start, startOfToday)
            return logged + max(0, Date().timeIntervalSince(effectiveStart))
        }
        return logged
    }

    var weekFocusSeconds: TimeInterval {
        let calendar = CalendarHelper.mondayFirst
        guard let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())) else { return 0 }
        let weekStartKey = DailyFocusEntry.dateFormatter.string(from: weekStart)
        let logged = focusHistory
            .filter { $0.date >= weekStartKey }
            .reduce(0) { $0 + $1.totalSeconds }
        // For active sessions, only count the portion within this week
        if let start = blockingStartDate {
            let effectiveStart = max(start, weekStart)
            return logged + max(0, Date().timeIntervalSince(effectiveStart))
        }
        return logged
    }

    var monthFocusSeconds: TimeInterval {
        let calendar = Calendar.current
        guard let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: Date())) else { return 0 }
        let monthStartKey = DailyFocusEntry.dateFormatter.string(from: monthStart)
        let logged = focusHistory
            .filter { $0.date >= monthStartKey }
            .reduce(0) { $0 + $1.totalSeconds }
        // For active sessions, only count the portion within this month
        if let start = blockingStartDate {
            let effectiveStart = max(start, monthStart)
            return logged + max(0, Date().timeIntervalSince(effectiveStart))
        }
        return logged
    }

    var todaySessionCount: Int {
        let todayKey = DailyFocusEntry.todayKey()
        let logged = focusHistory.first(where: { $0.date == todayKey })?.sessionCount ?? 0
        return logged + (isInSession ? 1 : 0)
    }

    var totalLifetimeSeconds: TimeInterval {
        cumulativeLifetimeSeconds + max(0, currentSessionSeconds)
    }

    var totalLifetimeSessions: Int {
        cumulativeLifetimeSessions + (isInSession ? 1 : 0)
    }

    var totalDaysFocused: Int {
        cumulativeLifetimeDays
    }

    static func formatTime(_ seconds: TimeInterval) -> String {
        let h = Int(seconds) / 3600
        let m = (Int(seconds) % 3600) / 60
        let s = Int(seconds) % 60
        if h > 0 {
            return String(format: "%dh %dm", h, m)
        } else if m > 0 {
            return String(format: "%dm %ds", m, s)
        } else {
            return String(format: "%ds", s)
        }
    }

    // MARK: - Blocking Modes

    func addMode(_ mode: BlockingMode) {
        // Reject empty names
        guard !mode.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        // Prevent duplicates by name
        guard !modes.contains(where: { $0.name.lowercased() == mode.name.lowercased() }) else {
            // Still set as active if needed
            if let existing = modes.first(where: { $0.name.lowercased() == mode.name.lowercased() }) {
                activeModeId = existing.id
            }
            return
        }

        guard modes.count < AppConstants.maxModes else { return }
        modes.append(mode)
        writeModeTokenToShared(mode)

        // Set as active if it's the first mode
        if modes.count == 1 {
            activeModeId = mode.id
        }
        saveState()
        if featureEnabled(.cloudSync) {
            Task { @MainActor in CloudSyncManager.shared.syncToCloud(appState: self) }
        }
    }

    /// Delete a mode and auto-disable any schedules that reference it.
    /// Returns the list of affected schedules so callers can unregister them from DeviceActivityCenter.
    @discardableResult
    func deleteMode(_ mode: BlockingMode) -> [FocusSchedule] {
        guard modes.count > 1 else { return [] }
        // Prevent deleting the active mode during a session
        guard !isInSession || mode.id != activeModeId else { return [] }
        removeModeTokenFromShared(mode)
        modes.removeAll { $0.id == mode.id }

        // Auto-disable schedules that reference this mode (don't delete — user can reassign)
        var affected: [FocusSchedule] = []
        for i in schedules.indices where schedules[i].modeId == mode.id {
            affected.append(schedules[i])
            schedules[i].isEnabled = false
        }

        if activeModeId == mode.id {
            activeModeId = modes.first?.id
        }
        saveState()
        if featureEnabled(.cloudSync) {
            Task { @MainActor in CloudSyncManager.shared.syncToCloud(appState: self) }
        }

        #if DEBUG
        if !affected.isEmpty {
            print("[AppState] Auto-disabled \(affected.count) schedules referencing deleted mode '\(mode.name)'")
        }
        #endif
        return affected
    }

    func updateMode(_ mode: BlockingMode) {
        // Reject empty names
        guard !mode.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        if let index = modes.firstIndex(where: { $0.id == mode.id }) {
            modes[index] = mode
            writeModeTokenToShared(mode)
            saveState()
            if featureEnabled(.cloudSync) {
                Task { @MainActor in CloudSyncManager.shared.syncToCloud(appState: self) }
            }
        }
    }

    // MARK: - Mode Tokens (Shared Storage)

    /// Write a mode's FamilyActivitySelection to shared storage so the extension can read it
    func writeModeTokenToShared(_ mode: BlockingMode) {
        guard let data = try? PropertyListEncoder().encode(mode.appSelection) else { return }
        defaults.set(data, forKey: "mode_tokens_\(mode.id.uuidString)")
        defaults.synchronize()
        #if DEBUG
        print("[AppState] Wrote mode tokens for '\(mode.name)' (\(mode.id.uuidString))")
        #endif
    }

    /// Remove a mode's tokens from shared storage
    func removeModeTokenFromShared(_ mode: BlockingMode) {
        defaults.removeObject(forKey: "mode_tokens_\(mode.id.uuidString)")
        defaults.synchronize()
        #if DEBUG
        print("[AppState] Removed mode tokens for '\(mode.name)' (\(mode.id.uuidString))")
        #endif
    }

    func setActiveMode(id: UUID) {
        activeModeId = id
        if let mode = activeMode {
            selectedApps = mode.appSelection
        }
        saveState()
    }

    // MARK: - Schedules

    func addSchedule(_ schedule: FocusSchedule) {
        guard schedules.count < AppConstants.maxSchedules else { return }
        schedules.append(schedule)
        saveState()
    }

    func updateSchedule(_ schedule: FocusSchedule) {
        if let index = schedules.firstIndex(where: { $0.id == schedule.id }) {
            schedules[index] = schedule
            saveState()
        }
    }

    func deleteSchedule(_ schedule: FocusSchedule) {
        schedules.removeAll { $0.id == schedule.id }
        saveState()
    }

    // MARK: - Onboarding

    func markOnboardingComplete() {
        guard !hasCompletedOnboarding else { return }
        hasCompletedOnboarding = true
        if registrationDate == nil {
            registrationDate = Date()
        }
        saveState()
    }

    // MARK: - Reset Local Data (Sign-Out / Delete)

    /// Wipes all local data (UserDefaults + in-memory state).
    /// Called on sign-out and delete-data. Does NOT touch Keychain.
    func resetLocalData() {
        // 1. Stop any active timer
        timer?.invalidate()
        timer = nil

        // 2. Clear mode tokens from shared storage (before wiping modes)
        for mode in modes {
            removeModeTokenFromShared(mode)
        }

        // 3. Wipe ALL keys from app group UserDefaults
        for key in defaults.dictionaryRepresentation().keys {
            defaults.removeObject(forKey: key)
        }
        defaults.synchronize()

        // 4. Cancel pending debounced saves
        saveWorkItem?.cancel()
        saveWorkItem = nil

        // 5. Reset all @Published properties to defaults
        //    Use isLoadingState to suppress Combine observers
        isLoadingState = true
        defer { isLoadingState = false }

        isAuthorized = false
        isBlocking = false
        selectedApps = FamilyActivitySelection(includeEntireCategory: true)
        modes = []
        activeModeId = nil
        emergencyUnlocksRemaining = AppConstants.startingOverrides
        totalBlockedSeconds = 0
        focusHistory = []
        strictModeEnabled = false
        hasCompletedOnboarding = false
        userEmail = nil
        isInSession = false
        sessionStartMethod = .nfc
        elapsedSeconds = 0
        schedules = []
        sessionStartTime = nil
        currentStreak = 0
        longestStreak = 0

        // 6. Reset non-published properties
        lastOverrideUsedDate = nil
        overrideEarnBackDays = 0
        pendingOverrideEarnedNotification = false
        registrationDate = nil
        blockingStartDate = nil
        focusDate = nil
        lastStreakDate = nil
        longestSessionSeconds = 0
        longestSessionDate = nil
        bestDaySeconds = 0
        bestDayDate = nil
        bestWeekSeconds = 0
        bestWeekStart = nil
        cumulativeLifetimeSeconds = 0
        cumulativeLifetimeSessions = 0
        cumulativeLifetimeDays = 0

        // 7. Reset transient flags
        isReturningFromNewDevice = false
        showReselectionAlert = false

        #if DEBUG
        print("[AppState] All local data wiped")
        #endif
    }

    // MARK: - Demo Data (App Store screenshots)

    #if DEBUG
    func injectDemoData() {
        let formatter = DailyFocusEntry.dateFormatter
        let calendar = Calendar.current
        let today = Date()

        var demoHistory: [DailyFocusEntry] = []

        // 21 days of varied focus data (seconds)
        let dailySeconds: [Int] = [
            7200, 5400, 10800, 3600, 9000, 2700, 3600,   // week 1
            4500, 7800, 6000, 1800, 8400, 5400, 0,        // week 2
            10200, 3600, 7200, 9600, 4800, 1200, 6000      // week 3
        ]

        for i in 0..<21 {
            let date = calendar.date(byAdding: .day, value: -(20 - i), to: today)!
            let seconds = dailySeconds[i]
            if seconds > 0 {
                let sessions = max(1, seconds / 3600)
                demoHistory.append(DailyFocusEntry(
                    date: formatter.string(from: date),
                    totalSeconds: TimeInterval(seconds),
                    sessionCount: sessions
                ))
            }
        }

        focusHistory = demoHistory

        // Streaks
        currentStreak = 7
        longestStreak = 12
        lastStreakDate = DailyFocusEntry.todayKey()

        // Cumulative lifetime
        cumulativeLifetimeSeconds = 38 * 3600  // 38 hours
        cumulativeLifetimeSessions = 47
        cumulativeLifetimeDays = 18

        // Personal records
        longestSessionSeconds = 10800  // 3 hours
        longestSessionDate = calendar.date(byAdding: .day, value: -5, to: today)
        bestDaySeconds = 10800
        bestDayDate = calendar.date(byAdding: .day, value: -5, to: today)
        bestWeekSeconds = 42300
        bestWeekStart = calendar.date(byAdding: .day, value: -13, to: today)

        // Registration date (for avg/week calculations)
        registrationDate = calendar.date(byAdding: .day, value: -21, to: today)

        // Overrides (show partial earn-back)
        emergencyUnlocksRemaining = 4
        overrideEarnBackDays = 4

        saveState()

        if featureEnabled(.cloudSync) {
            Task { @MainActor in
                CloudSyncManager.shared.syncToCloud(appState: self)
            }
        }
    }
    #endif

}
