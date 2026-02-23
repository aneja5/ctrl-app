import SwiftUI
import BackgroundTasks

// MARK: - App Delegate (BGTask Registration)

class AppDelegate: NSObject, UIApplicationDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        if FeatureFlags.schedulesEnabled {
            BGTaskScheduler.shared.register(
                forTaskWithIdentifier: "in.getctrl.app.schedule-check",
                using: nil
            ) { task in
                guard let bgTask = task as? BGAppRefreshTask else {
                    task.setTaskCompleted(success: false)
                    return
                }
                self.handleScheduleCheck(bgTask)
            }
        }
        return true
    }

    /// Background task handler — single syncScheduleShields() call evaluates all schedules.
    private func handleScheduleCheck(_ task: BGAppRefreshTask) {
        // syncScheduleShields() accesses AppState.shared (@MainActor) and ManagedSettingsStore —
        // must run on the main thread to avoid data races.
        DispatchQueue.main.async {
            let scheduleManager = ScheduleManager()

            // Single sync pass — applies or clears the "schedule" store
            scheduleManager.syncScheduleShields()

            // Re-schedule for the next transition (start or end)
            scheduleManager.scheduleNextBGTask(schedules: AppState.shared.schedules)

            task.setTaskCompleted(success: true)

            #if DEBUG
            let defaults = UserDefaults(suiteName: "group.in.getctrl.app")
            defaults?.set(Date().description, forKey: "debug_lastBGTaskFired")
            defaults?.synchronize()
            #endif
        }
    }
}

// MARK: - App Entry Point

@main
struct CTRLApp: App {

    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    @StateObject private var appState = AppState.shared
    @StateObject private var nfcManager = NFCManager()
    @StateObject private var blockingManager = BlockingManager()
    @StateObject private var scheduleManager = ScheduleManager()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .environmentObject(nfcManager)
                .environmentObject(blockingManager)
                .environmentObject(scheduleManager)
                .preferredColorScheme(.dark)
        }
    }
}
