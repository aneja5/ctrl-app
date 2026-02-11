import SwiftUI
import FamilyControls
import ManagedSettings
import DeviceActivity

class BlockingManager: ObservableObject {

    // MARK: - Properties

    private let store = ManagedSettingsStore()

    @Published var isBlocking: Bool = false
    @Published var blockedAppsCount: Int = 0
    @Published var strictModeActive: Bool = false

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

    func activateBlocking(for selection: FamilyActivitySelection, strictMode: Bool = false) {
        store.shield.applications = selection.applicationTokens
        store.shield.applicationCategories = .specific(selection.categoryTokens)
        blockedAppsCount = selection.applicationTokens.count + selection.categoryTokens.count

        // Strict mode restrictions
        if strictMode {
            store.application.denyAppRemoval = true
            store.application.denyAppInstallation = true
        }

        isBlocking = true
        strictModeActive = strictMode
        print("[BlockingManager] Blocking activated — \(blockedAppsCount) apps/categories, strictMode: \(strictMode)")
    }

    func deactivateBlocking() {
        store.shield.applications = nil
        store.shield.applicationCategories = nil

        // Clear strict mode restrictions
        store.application.denyAppRemoval = false
        store.application.denyAppInstallation = false

        store.clearAllSettings()
        blockedAppsCount = 0
        isBlocking = false
        strictModeActive = false
        print("[BlockingManager] Blocking deactivated")
    }

    func toggleBlocking(for selection: FamilyActivitySelection, strictMode: Bool = false) {
        if isBlocking {
            deactivateBlocking()
        } else {
            activateBlocking(for: selection, strictMode: strictMode)
        }
    }
}
