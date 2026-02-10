import SwiftUI
import FamilyControls
import ManagedSettings
import DeviceActivity

class BlockingManager: ObservableObject {

    // MARK: - Properties

    private let store = ManagedSettingsStore()

    @Published var isBlocking: Bool = false
    @Published var blockedAppsCount: Int = 0

    // MARK: - Init

    init() {
        // Check if ManagedSettingsStore has active shields from a previous session
        let hasShieldedApps = store.shield.applications != nil
        let hasShieldedCategories = store.shield.applicationCategories != nil
        if hasShieldedApps || hasShieldedCategories {
            isBlocking = true
            print("[BlockingManager] Restored blocking state from ManagedSettingsStore")
        }
    }

    // MARK: - Authorization

    func requestAuthorization() async -> Bool {
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
            return true
        } catch {
            print("Screen Time authorization failed: \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - Blocking Controls

    func activateBlocking(for selection: FamilyActivitySelection) {
        store.shield.applications = selection.applicationTokens
        store.shield.applicationCategories = .specific(selection.categoryTokens)
        blockedAppsCount = selection.applicationTokens.count + selection.categoryTokens.count
        isBlocking = true
        print("[BlockingManager] Blocking activated — \(blockedAppsCount) apps/categories")
    }

    func deactivateBlocking() {
        store.shield.applications = nil
        store.shield.applicationCategories = nil
        store.clearAllSettings()
        blockedAppsCount = 0
        isBlocking = false
        print("[BlockingManager] Blocking deactivated")
    }

    func toggleBlocking(for selection: FamilyActivitySelection) {
        if isBlocking {
            deactivateBlocking()
        } else {
            activateBlocking(for: selection)
        }
    }
}
