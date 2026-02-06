import SwiftUI
import FamilyControls
import ManagedSettings
import DeviceActivity

class BlockingManager: ObservableObject {

    // MARK: - Properties

    private let store = ManagedSettingsStore()

    @Published var isBlocking: Bool = false
    @Published var blockedAppsCount: Int = 0

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
        print("Blocking activated")
    }

    func deactivateBlocking() {
        store.shield.applications = nil
        store.shield.applicationCategories = nil
        store.clearAllSettings()
        blockedAppsCount = 0
        isBlocking = false
        print("Blocking deactivated")
    }

    func toggleBlocking(for selection: FamilyActivitySelection) {
        if isBlocking {
            deactivateBlocking()
        } else {
            activateBlocking(for: selection)
        }
    }
}
