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
    }

    // MARK: - Persistence

    private let defaults = UserDefaults(suiteName: "group.in.getctrl.app")
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Published Properties

    @Published var isAuthorized: Bool = false
    @Published var isPaired: Bool = false
    @Published var isBlocking: Bool = false
    @Published var pairedTokenID: String?
    @Published var selectedApps: FamilyActivitySelection = FamilyActivitySelection()

    // MARK: - Computed Properties

    var hasCompletedOnboarding: Bool {
        let hasApps = !selectedApps.applicationTokens.isEmpty || !selectedApps.categoryTokens.isEmpty
        return isPaired && hasApps
    }

    // MARK: - Init

    private init() {
        loadState()
        observeChanges()
        print("[AppState] Init complete — isPaired: \(isPaired), hasCompletedOnboarding: \(hasCompletedOnboarding)")
    }

    // MARK: - Auto-Save Observers

    private func observeChanges() {
        $isBlocking
            .dropFirst()
            .removeDuplicates()
            .sink { [weak self] _ in self?.saveState() }
            .store(in: &cancellables)

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
    }

    // MARK: - State Persistence

    func loadState() {
        isPaired = defaults?.bool(forKey: Keys.isPaired) ?? false
        pairedTokenID = defaults?.string(forKey: Keys.pairedTokenID)
        isBlocking = defaults?.bool(forKey: Keys.isBlocking) ?? false

        if let data = defaults?.data(forKey: Keys.selectedApps),
           let selection = try? PropertyListDecoder().decode(FamilyActivitySelection.self, from: data) {
            selectedApps = selection
            print("[AppState] Loaded \(selection.applicationTokens.count) apps, \(selection.categoryTokens.count) categories")
        }
        print("[AppState] loadState — isPaired: \(isPaired), tokenID: \(pairedTokenID ?? "nil"), isBlocking: \(isBlocking)")
    }

    func saveState() {
        defaults?.set(isPaired, forKey: Keys.isPaired)
        defaults?.set(pairedTokenID, forKey: Keys.pairedTokenID)
        defaults?.set(isBlocking, forKey: Keys.isBlocking)

        if let data = try? PropertyListEncoder().encode(selectedApps) {
            defaults?.set(data, forKey: Keys.selectedApps)
        }

        defaults?.synchronize()
        print("[AppState] saveState — isPaired: \(isPaired), tokenID: \(pairedTokenID ?? "nil"), apps: \(selectedApps.applicationTokens.count), categories: \(selectedApps.categoryTokens.count)")
    }

    // MARK: - Selected Apps

    func saveSelectedApps(_ selection: FamilyActivitySelection) {
        self.selectedApps = selection
        if let data = try? PropertyListEncoder().encode(selection) {
            defaults?.set(data, forKey: Keys.selectedApps)
            defaults?.synchronize()
            print("Saved \(selection.applicationTokens.count) apps, \(selection.categoryTokens.count) categories")
        }
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
