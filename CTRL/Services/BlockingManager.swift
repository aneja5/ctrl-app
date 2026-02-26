import SwiftUI
import FamilyControls
import ManagedSettings
import DeviceActivity

class BlockingManager: ObservableObject {

    // MARK: - Properties

    private let store = ManagedSettingsStore(named: .init("manual"))

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
            #if DEBUG
            print("[BlockingManager] Restored blocking state from ManagedSettingsStore")
            #endif
        }
    }

    // MARK: - Safety Check

    /// Clears denyAppRemoval/denyAppInstallation if no active session is running.
    /// Protects against stale restrictions left by a crashed or force-killed session.
    func ensureConsistentState() {
        if !isBlocking {
            if store.application.denyAppRemoval == true || store.application.denyAppInstallation == true {
                store.application.denyAppRemoval = false
                store.application.denyAppInstallation = false
                #if DEBUG
                print("[BlockingManager] Safety check: cleared stale denyAppRemoval/denyAppInstallation")
                #endif
            }
        }
    }

    // MARK: - Authorization

    func requestAuthorization() async -> Bool {
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
            return true
        } catch {
            #if DEBUG
            print("Screen Time authorization failed: \(error.localizedDescription)")
            #endif
            return false
        }
    }

    // MARK: - Blocking Controls

    func activateBlocking(for selection: FamilyActivitySelection, strictMode: Bool = false) {
        #if DEBUG
        print("[Blocking] ============ ACTIVATE START ============")
        print("[Blocking] applicationTokens: \(selection.applicationTokens.count)")
        print("[Blocking] categoryTokens: \(selection.categoryTokens.count)")
        print("[Blocking] webDomainTokens: \(selection.webDomainTokens.count)")
        #endif

        // Block individual apps (nil when empty to avoid empty-set edge cases)
        store.shield.applications = selection.applicationTokens.isEmpty
            ? nil : selection.applicationTokens

        // Category-level blocking: only as fallback for pre-migration modes
        // that have categories but no expanded applicationTokens yet.
        // When includeEntireCategory is true, categories expand into applicationTokens,
        // so applying categoryTokens separately would over-block the entire category.
        if selection.applicationTokens.isEmpty && !selection.categoryTokens.isEmpty {
            store.shield.applicationCategories = .specific(selection.categoryTokens)
        } else {
            store.shield.applicationCategories = nil
        }

        // Block web domains associated with the selection
        store.shield.webDomains = selection.webDomainTokens.isEmpty
            ? nil : selection.webDomainTokens

        let apps = selection.applicationTokens.count
        let cats = selection.categoryTokens.count
        blockedAppsCount = cats > 0 && apps == 0 ? cats : apps

        // Strict mode restrictions
        if strictMode {
            store.application.denyAppRemoval = true
            store.application.denyAppInstallation = true
        }

        isBlocking = true
        strictModeActive = strictMode

        #if DEBUG
        print("[Blocking] Applied — apps: \(store.shield.applications?.count ?? 0)")
        print("[Blocking] Applied — categories: \(String(describing: store.shield.applicationCategories))")
        print("[Blocking] Applied — webDomains: \(store.shield.webDomains?.count ?? 0)")
        print("[Blocking] Strict mode: \(strictMode)")
        print("[Blocking] ============ ACTIVATE END ============")
        #endif
    }

    func deactivateBlocking() {
        store.shield.applications = nil
        store.shield.applicationCategories = nil
        store.shield.webDomains = nil

        // Clear strict mode restrictions
        store.application.denyAppRemoval = false
        store.application.denyAppInstallation = false

        store.clearAllSettings()
        blockedAppsCount = 0
        isBlocking = false
        strictModeActive = false

        #if DEBUG
        print("[Blocking] ============ DEACTIVATE ============")
        print("[Blocking] All shields cleared")
        #endif
    }

    func toggleBlocking(for selection: FamilyActivitySelection, strictMode: Bool = false) {
        if isBlocking {
            deactivateBlocking()
        } else {
            activateBlocking(for: selection, strictMode: strictMode)
        }
    }
}
