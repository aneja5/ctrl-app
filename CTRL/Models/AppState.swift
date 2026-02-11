import SwiftUI
import Combine
import FamilyControls

class AppState: ObservableObject {

    // MARK: - Singleton

    static let shared = AppState()

    // MARK: - UserDefaults Keys

    private enum Keys {
        static let isPaired = "ctrl_is_paired"
        static let pairedTokenID = "ctrl_paired_token_id"
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
    }

    // MARK: - Persistence

    private let defaults: UserDefaults
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Published Properties

    @Published var isAuthorized: Bool = false
    @Published var isPaired: Bool = false
    @Published var isBlocking: Bool = false
    @Published var pairedTokenID: String?
    @Published var selectedApps: FamilyActivitySelection = FamilyActivitySelection()
    @Published var modes: [BlockingMode] = []
    @Published var activeModeId: UUID? = nil
    @Published var emergencyUnlocksRemaining: Int = 5
    @Published var totalBlockedSeconds: TimeInterval = 0
    @Published var focusHistory: [DailyFocusEntry] = []
    var lastEmergencyResetDate: Date?
    var blockingStartDate: Date? = nil
    var focusDate: Date? = nil

    static let maxModes = 6

    // MARK: - Computed Properties

    var hasCompletedOnboarding: Bool {
        return isPaired
    }

    var activeMode: BlockingMode? {
        guard let id = activeModeId else { return nil }
        return modes.first { $0.id == id }
    }

    // MARK: - Init

    private init() {
        if let suiteDefaults = UserDefaults(suiteName: "group.in.getctrl.app") {
            self.defaults = suiteDefaults
            print("[AppState] Using App Group UserDefaults")
        } else {
            self.defaults = UserDefaults.standard
            print("[AppState] WARNING: App Group unavailable, falling back to standard UserDefaults")
        }
        loadState()
        observeChanges()
        print("[AppState] Init complete — isPaired: \(isPaired), hasCompletedOnboarding: \(hasCompletedOnboarding)")
    }

    // MARK: - Auto-Save Observers

    private func observeChanges() {
        $selectedApps
            .dropFirst()
            .sink { [weak self] _ in self?.saveState() }
            .store(in: &cancellables)

        $isPaired
            .dropFirst()
            .removeDuplicates()
            .sink { [weak self] _ in self?.saveState() }
            .store(in: &cancellables)

        $pairedTokenID
            .dropFirst()
            .removeDuplicates()
            .sink { [weak self] _ in self?.saveState() }
            .store(in: &cancellables)

        $modes
            .dropFirst()
            .sink { [weak self] _ in self?.saveState() }
            .store(in: &cancellables)

        $activeModeId
            .dropFirst()
            .sink { [weak self] _ in self?.saveState() }
            .store(in: &cancellables)
    }

    // MARK: - State Persistence

    func loadState() {
        isPaired = defaults.bool(forKey: Keys.isPaired)
        pairedTokenID = defaults.string(forKey: Keys.pairedTokenID)
        // isBlocking is NOT persisted — always starts as false on launch
        // Clean up any stale value from previous versions
        defaults.removeObject(forKey: Keys.isBlocking)

        if let data = defaults.data(forKey: Keys.selectedApps),
           let selection = try? PropertyListDecoder().decode(FamilyActivitySelection.self, from: data) {
            selectedApps = selection
            print("[AppState] Loaded \(selection.applicationTokens.count) apps, \(selection.categoryTokens.count) categories")
        }

        // Load modes
        if let data = defaults.data(forKey: Keys.modesData),
           let loadedModes = try? JSONDecoder().decode([BlockingMode].self, from: data) {
            modes = loadedModes
            print("[AppState] Loaded \(loadedModes.count) blocking modes")
        }

        // Load active mode ID
        if let idString = defaults.string(forKey: Keys.activeModeId),
           let id = UUID(uuidString: idString) {
            activeModeId = id
        }

        // Create default mode if none exist
        if modes.isEmpty {
            let defaultMode = BlockingMode(name: "Focus", appSelection: selectedApps)
            modes = [defaultMode]
            activeModeId = defaultMode.id
            print("[AppState] Created default 'Focus' mode")
        }

        // Ensure activeModeId points to an existing mode
        if activeModeId == nil || !modes.contains(where: { $0.id == activeModeId }) {
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

        // If app was blocking but no start date recorded, set it now
        if isBlocking && blockingStartDate == nil {
            blockingStartDate = Date()
            print("[AppState] Restored missing blockingStartDate")
        }

        checkAndResetDailyFocusTime()
        checkAndResetMonthlyAllowance()

        print("[AppState] loadState — isPaired: \(isPaired), tokenID: \(pairedTokenID ?? "nil"), modes: \(modes.count), activeModeId: \(activeModeId?.uuidString ?? "nil"), emergencyUnlocks: \(emergencyUnlocksRemaining)")
    }

    func saveState() {
        defaults.set(isPaired, forKey: Keys.isPaired)
        defaults.set(pairedTokenID, forKey: Keys.pairedTokenID)
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

        defaults.synchronize()
        print("[AppState] saveState — isPaired: \(isPaired), tokenID: \(pairedTokenID ?? "nil"), modes: \(modes.count), activeMode: \(activeMode?.name ?? "nil")")
    }

    // MARK: - Selected Apps

    func saveSelectedApps(_ selection: FamilyActivitySelection) {
        // Don't overwrite existing apps with empty selection
        if selection.applicationTokens.isEmpty && selection.categoryTokens.isEmpty {
            if !self.selectedApps.applicationTokens.isEmpty || !self.selectedApps.categoryTokens.isEmpty {
                print("[AppState] Ignoring empty selection, keeping existing apps")
                return
            }
        }

        self.selectedApps = selection
        if let data = try? PropertyListEncoder().encode(selection) {
            defaults.set(data, forKey: Keys.selectedApps)
            defaults.synchronize()
            print("[AppState] Saved \(selection.applicationTokens.count) apps, \(selection.categoryTokens.count) categories")
        }

        // Sync to the active mode
        if let id = activeModeId, let index = modes.firstIndex(where: { $0.id == id }) {
            modes[index].appSelection = selection
            print("[AppState] Synced selection to active mode: \(modes[index].name)")
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
                print("[AppState] Monthly emergency unlocks reset to 5")
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
            print("[AppState] Emergency unlock used, remaining: \(emergencyUnlocksRemaining)")
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
                print("[AppState] Daily focus time reset to 0")
            }
        } else {
            focusDate = today
            saveState()
        }
    }

    func startBlockingTimer() {
        checkAndResetDailyFocusTime()
        blockingStartDate = Date()
        saveState()
        print("[AppState] Started blocking timer at \(blockingStartDate!)")
    }

    func stopBlockingTimer() {
        if let start = blockingStartDate {
            let elapsed = Date().timeIntervalSince(start)
            totalBlockedSeconds += elapsed
            blockingStartDate = nil
            logToTodayHistory(elapsed)
            saveState()
            print("[AppState] Blocking timer stopped, added \(Int(elapsed))s, total: \(Int(totalBlockedSeconds))s")
        }
    }

    var currentSessionSeconds: TimeInterval {
        guard let start = blockingStartDate else { return 0 }
        return Date().timeIntervalSince(start)
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

    func addMode(name: String) -> BlockingMode? {
        guard modes.count < 6 else { return nil }
        let newMode = BlockingMode(name: name)
        modes.append(newMode)
        saveState()
        print("[AppState] Added mode: \(name), total: \(modes.count)")
        return newMode
    }

    func deleteMode(id: UUID) {
        guard modes.count > 1 else { return } // Keep at least one mode
        modes.removeAll { $0.id == id }
        if activeModeId == id {
            activeModeId = modes.first?.id
        }
        saveState()
        print("[AppState] Deleted mode, remaining: \(modes.count)")
    }

    func updateMode(_ mode: BlockingMode) {
        if let index = modes.firstIndex(where: { $0.id == mode.id }) {
            modes[index] = mode
            saveState()
            print("[AppState] Updated mode: \(mode.name), apps: \(mode.appCount)")
        }
    }

    func setActiveMode(id: UUID) {
        activeModeId = id
        if let mode = activeMode {
            selectedApps = mode.appSelection
        }
        saveState()
        print("[AppState] Active mode set to: \(activeMode?.name ?? "nil")")
    }

    // MARK: - Token Pairing

    func pairToken(id: String) {
        pairedTokenID = id
        isPaired = true
    }

    func unpairToken() {
        pairedTokenID = nil
        isPaired = false
    }
}
