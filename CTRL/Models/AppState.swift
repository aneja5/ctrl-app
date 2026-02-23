import SwiftUI
import Combine
import FamilyControls

enum SessionStartMethod: String, Codable {
    case nfc
    case manual
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
    @Published var emergencyUnlocksRemaining: Int = 5
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
    @Published var sessionStartTime: Date? {
        didSet {
            if !isLoadingState {
                debouncedSave()
            }
        }
    }
    var lastEmergencyResetDate: Date?
    var registrationDate: Date?
    var blockingStartDate: Date? = nil
    var focusDate: Date? = nil
    private var timer: Timer?

    /// Modes that were saved before the includeEntireCategory fix and need re-selection.
    var modesNeedingReselection: [BlockingMode] {
        modes.filter { $0.needsReselection }
    }

    static let maxModes = 6

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
            if uniqueModes.contains(where: { $0.needsReselection }) {
                showReselectionAlert = true
                #if DEBUG
                let staleNames = uniqueModes.filter { $0.needsReselection }.map { $0.name }
                print("[AppState] Migration: modes need re-selection: \(staleNames)")
                #endif
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

        // Load emergency unlock data
        if defaults.object(forKey: Keys.emergencyUnlocks) != nil {
            emergencyUnlocksRemaining = defaults.integer(forKey: Keys.emergencyUnlocks)
        } else {
            emergencyUnlocksRemaining = 5
        }
        lastEmergencyResetDate = defaults.object(forKey: Keys.emergencyResetDate) as? Date
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

        checkAndResetDailyFocusTime()
        checkAndResetMonthlyAllowance()

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
        if let resetDate = lastEmergencyResetDate {
            defaults.set(resetDate, forKey: Keys.emergencyResetDate)
        }
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

    // MARK: - Emergency Unlock

    /// Returns the next reset date based on the user's registration day-of-month.
    /// For example, if the user registered on the 15th, overrides reset on the 15th of each month.
    func nextOverrideResetDate() -> Date? {
        let calendar = Calendar.current
        let now = Date()
        let regDay = registrationDate.map { calendar.component(.day, from: $0) } ?? 1

        // Try the registration day in the current month
        var components = calendar.dateComponents([.year, .month], from: now)
        components.day = min(regDay, calendar.range(of: .day, in: .month, for: now)?.count ?? 28)

        if let candidate = calendar.date(from: components), candidate > now {
            return candidate
        }

        // Already passed this month — use next month
        guard let nextMonth = calendar.date(byAdding: .month, value: 1, to: now) else { return nil }
        components = calendar.dateComponents([.year, .month], from: nextMonth)
        components.day = min(regDay, calendar.range(of: .day, in: .month, for: nextMonth)?.count ?? 28)
        return calendar.date(from: components)
    }

    func checkAndResetMonthlyAllowance() {
        let calendar = Calendar.current
        let now = Date()

        if let lastReset = lastEmergencyResetDate {
            let regDay = registrationDate.map { calendar.component(.day, from: $0) } ?? 1

            // Build the reset date for the current month
            var components = calendar.dateComponents([.year, .month], from: now)
            components.day = min(regDay, calendar.range(of: .day, in: .month, for: now)?.count ?? 28)

            if let resetThisMonth = calendar.date(from: components),
               now >= resetThisMonth && lastReset < resetThisMonth {
                emergencyUnlocksRemaining = 5
                lastEmergencyResetDate = now
                saveState()
                #if DEBUG
                print("[AppState] Monthly emergency unlocks reset to 5 (registration-based)")
                #endif
            }
        } else {
            lastEmergencyResetDate = now
            saveState()
        }
    }

    func useEmergencyUnlock() -> Bool {
        if emergencyUnlocksRemaining > 0 {
            emergencyUnlocksRemaining -= 1
            saveState()
            Task { @MainActor in CloudSyncManager.shared.syncToCloud(appState: self) }
            #if DEBUG
            print("[AppState] Emergency unlock used, remaining: \(emergencyUnlocksRemaining)")
            #endif
            return true
        }
        return false
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
        isInSession = false
        sessionStartMethod = .nfc
        sessionStartTime = nil
        timer?.invalidate()
        timer = nil

        // Log focus time — split across calendar days if session crosses midnight
        if let startDate = blockingStartDate {
            let now = Date()
            let elapsed = Int(now.timeIntervalSince(startDate))
            if elapsed > 0 {
                totalBlockedSeconds += TimeInterval(elapsed)
                logSessionAcrossDays(start: startDate, end: now)
                #if DEBUG
                print("[AppState] Session ended — \(elapsed)s logged (split across days if needed)")
                #endif
            }
        }

        blockingStartDate = nil
        elapsedSeconds = 0
        saveState()
        Task { @MainActor in CloudSyncManager.shared.syncToCloud(appState: self) }
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

        // Restart the timer
        startTimer()

        #if DEBUG
        print("[AppState] Restored session — elapsed: \(elapsedSeconds)s")
        #endif
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                self?.elapsedSeconds += 1
            }
        }
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
    private func logSessionAcrossDays(start: Date, end: Date) {
        let calendar = Calendar.current
        let formatter = DailyFocusEntry.dateFormatter
        var current = start
        var isFirstSegment = true

        while current < end {
            guard let nextDayStart = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: current)) else { break }
            let segmentEnd = min(nextDayStart, end)
            let segmentSeconds = segmentEnd.timeIntervalSince(current)

            if segmentSeconds > 0 {
                let dateKey = formatter.string(from: current)
                if let index = focusHistory.firstIndex(where: { $0.date == dateKey }) {
                    focusHistory[index].totalSeconds += segmentSeconds
                    if isFirstSegment {
                        focusHistory[index].sessionCount += 1
                    }
                } else {
                    focusHistory.append(DailyFocusEntry(
                        date: dateKey,
                        totalSeconds: segmentSeconds,
                        sessionCount: isFirstSegment ? 1 : 0
                    ))
                }
                #if DEBUG
                print("[AppState] Logged \(Int(segmentSeconds))s to \(dateKey)\(isFirstSegment ? " (+1 session)" : "")")
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

    private func trimOldHistory() {
        // Keep only the last 90 days
        let cutoff = Calendar.current.date(byAdding: .day, value: -90, to: Date()) ?? Date()
        let cutoffKey = DailyFocusEntry.dateFormatter.string(from: cutoff)
        focusHistory.removeAll { $0.date < cutoffKey }
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
        focusHistory.reduce(0) { $0 + $1.totalSeconds } + max(0, currentSessionSeconds)
    }

    var totalLifetimeSessions: Int {
        focusHistory.reduce(0) { $0 + $1.sessionCount } + (isInSession ? 1 : 0)
    }

    var totalDaysFocused: Int {
        focusHistory.filter { $0.totalSeconds > 0 }.count
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
        // Prevent duplicates by name
        guard !modes.contains(where: { $0.name.lowercased() == mode.name.lowercased() }) else {
            // Still set as active if needed
            if let existing = modes.first(where: { $0.name.lowercased() == mode.name.lowercased() }) {
                activeModeId = existing.id
            }
            return
        }

        guard modes.count < 6 else { return }
        modes.append(mode)
        writeModeTokenToShared(mode)

        // Set as active if it's the first mode
        if modes.count == 1 {
            activeModeId = mode.id
        }
        saveState()
        Task { @MainActor in CloudSyncManager.shared.syncToCloud(appState: self) }
    }

    /// Delete a mode and auto-disable any schedules that reference it.
    /// Returns the list of affected schedules so callers can unregister them from DeviceActivityCenter.
    @discardableResult
    func deleteMode(_ mode: BlockingMode) -> [FocusSchedule] {
        guard modes.count > 1 else { return [] }
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
        Task { @MainActor in CloudSyncManager.shared.syncToCloud(appState: self) }

        #if DEBUG
        if !affected.isEmpty {
            print("[AppState] Auto-disabled \(affected.count) schedules referencing deleted mode '\(mode.name)'")
        }
        #endif
        return affected
    }

    func updateMode(_ mode: BlockingMode) {
        if let index = modes.firstIndex(where: { $0.id == mode.id }) {
            modes[index] = mode
            writeModeTokenToShared(mode)
            saveState()
            Task { @MainActor in CloudSyncManager.shared.syncToCloud(appState: self) }
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

    static let maxSchedules = 6

    func addSchedule(_ schedule: FocusSchedule) {
        guard schedules.count < Self.maxSchedules else { return }
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

}
