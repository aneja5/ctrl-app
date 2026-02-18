import SwiftUI
import Combine
import FamilyControls

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
    }

    // MARK: - Persistence

    private let defaults: UserDefaults
    private var cancellables = Set<AnyCancellable>()
    private var isLoadingState = false  // Prevents didSet triggers during loadState

    // MARK: - Published Properties

    @Published var isAuthorized: Bool = false
    @Published var isBlocking: Bool = false
    @Published var selectedApps: FamilyActivitySelection = FamilyActivitySelection()
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
    @Published var isInSession: Bool = false
    @Published var elapsedSeconds: Int = 0
    @Published var sessionStartTime: Date? {
        didSet {
            if !isLoadingState {
                debouncedSave()
            }
        }
    }
    var lastEmergencyResetDate: Date?
    var blockingStartDate: Date? = nil
    var focusDate: Date? = nil
    private var timer: Timer?

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
            print("[AppState] WARNING: App Group unavailable, falling back to standard UserDefaults")
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
            selectedApps = selection
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

        let startTimeInterval = defaults.double(forKey: Keys.sessionStartTime)
        if startTimeInterval > 0 {
            sessionStartTime = Date(timeIntervalSince1970: startTimeInterval)
        } else {
            sessionStartTime = nil
        }

        checkAndResetDailyFocusTime()
        checkAndResetMonthlyAllowance()

        #if DEBUG
        print("[AppState] loadState — email: \(userEmail ?? "nil"), onboarded: \(hasCompletedOnboarding), modes: \(modes.count)")
        #endif
    }

    // MARK: - Debounced Save

    private var saveWorkItem: DispatchWorkItem?

    /// Debounced save — coalesces rapid changes into a single write
    private func debouncedSave() {
        saveWorkItem?.cancel()
        saveWorkItem = DispatchWorkItem { [weak self] in
            self?.saveState()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: saveWorkItem!)
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

        // Save session state
        defaults.set(isInSession, forKey: Keys.isInSession)
        if let startTime = sessionStartTime {
            defaults.set(startTime.timeIntervalSince1970, forKey: Keys.sessionStartTime)
        } else {
            defaults.removeObject(forKey: Keys.sessionStartTime)
        }

        defaults.synchronize()

        #if DEBUG
        print("[AppState] saveState — modes: \(modes.count), activeMode: \(activeMode?.name ?? "nil")")
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

    func checkAndResetMonthlyAllowance() {
        let calendar = Calendar.current
        let now = Date()

        if let lastReset = lastEmergencyResetDate {
            if !calendar.isDate(lastReset, equalTo: now, toGranularity: .month) {
                emergencyUnlocksRemaining = 5
                lastEmergencyResetDate = now
                saveState()
                #if DEBUG
                print("[AppState] Monthly emergency unlocks reset to 5")
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
                // Archive previous day's total to history
                if totalBlockedSeconds > 0 {
                    let dateKey = DailyFocusEntry.dateFormatter.string(from: lastDate)
                    archiveFocusEntry(date: dateKey, seconds: totalBlockedSeconds)
                }
                totalBlockedSeconds = 0
                focusDate = today
                trimOldHistory()
                saveState()
                #if DEBUG
                print("[AppState] Daily focus time reset")
                #endif
            }
        } else {
            focusDate = today
            saveState()
        }
    }

    func startBlockingTimer() {
        checkAndResetDailyFocusTime()
        isInSession = true
        let now = Date()
        sessionStartTime = now
        blockingStartDate = now
        elapsedSeconds = 0
        startTimer()
        saveState()
    }

    func stopBlockingTimer() {
        isInSession = false
        sessionStartTime = nil
        timer?.invalidate()
        timer = nil

        // Log focus time (only once!)
        if let startDate = blockingStartDate {
            let elapsed = Int(Date().timeIntervalSince(startDate))
            if elapsed > 0 {
                totalBlockedSeconds += TimeInterval(elapsed)
                logToTodayHistory(TimeInterval(elapsed))
                #if DEBUG
                print("[AppState] Session ended — \(elapsed)s logged")
                #endif
            }
        }

        blockingStartDate = nil
        elapsedSeconds = 0
        saveState()
    }

    var currentSessionSeconds: TimeInterval {
        guard let start = blockingStartDate else { return 0 }
        return Date().timeIntervalSince(start)
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
        } else {
            focusHistory.append(DailyFocusEntry(date: todayKey, totalSeconds: seconds))
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
        return logged + currentSessionSeconds
    }

    var weekFocusSeconds: TimeInterval {
        let calendar = Calendar.current
        guard let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())) else { return 0 }
        let weekStartKey = DailyFocusEntry.dateFormatter.string(from: weekStart)
        return focusHistory
            .filter { $0.date >= weekStartKey }
            .reduce(0) { $0 + $1.totalSeconds } + currentSessionSeconds
    }

    var monthFocusSeconds: TimeInterval {
        let calendar = Calendar.current
        guard let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: Date())) else { return 0 }
        let monthStartKey = DailyFocusEntry.dateFormatter.string(from: monthStart)
        return focusHistory
            .filter { $0.date >= monthStartKey }
            .reduce(0) { $0 + $1.totalSeconds } + currentSessionSeconds
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

        // Set as active if it's the first mode
        if modes.count == 1 {
            activeModeId = mode.id
        }
        saveState()
    }

    func deleteMode(_ mode: BlockingMode) {
        guard modes.count > 1 else { return }
        modes.removeAll { $0.id == mode.id }

        if activeModeId == mode.id {
            activeModeId = modes.first?.id
        }
        saveState()
    }

    func updateMode(_ mode: BlockingMode) {
        if let index = modes.firstIndex(where: { $0.id == mode.id }) {
            modes[index] = mode
            saveState()
        }
    }

    func setActiveMode(id: UUID) {
        activeModeId = id
        if let mode = activeMode {
            selectedApps = mode.appSelection
        }
        saveState()
    }

    // MARK: - Onboarding

    func markOnboardingComplete() {
        guard !hasCompletedOnboarding else { return }
        hasCompletedOnboarding = true
        saveState()
    }

}
