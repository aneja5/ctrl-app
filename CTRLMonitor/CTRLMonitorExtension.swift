import DeviceActivity
import ManagedSettings
import FamilyControls
import Foundation
import os

/// Lightweight DeviceActivityMonitor extension — backup shield applicator.
/// The main app's syncScheduleShields() is the primary mechanism.
/// This extension fires as a bonus when iOS decides to run it.
/// Uses the same named "schedule" store as the main app (idempotent writes).
class CTRLMonitorExtension: DeviceActivityMonitor {

    private let store = ManagedSettingsStore(named: .init("schedule"))
    private let logger = Logger(subsystem: "in.getctrl.app.monitor", category: "Schedule")

    private var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: "group.in.getctrl.app")
    }

    // MARK: - Interval Start

    override func intervalDidStart(for activity: DeviceActivityName) {
        guard let defaults = sharedDefaults else { return }
        let activityName = activity.rawValue

        // Debug timestamps
        defaults.set(Date().description, forKey: "debug_lastIntervalDidStart")
        defaults.set(activityName, forKey: "debug_lastActivityName")
        defaults.synchronize()

        guard activityName.hasPrefix("ctrl_schedule_") else { return }
        let scheduleId = String(activityName.dropFirst("ctrl_schedule_".count))

        // Skip if manually ended today
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        if defaults.string(forKey: "schedule_skipped_\(scheduleId)") == formatter.string(from: Date()) {
            logger.info("Schedule \(scheduleId) skipped today")
            return
        }

        // Read modeId from schedule metadata, then load mode tokens
        if let modeId = defaults.string(forKey: "schedule_modeId_\(scheduleId)"),
           let data = defaults.data(forKey: "mode_tokens_\(modeId)"),
           let selection = try? PropertyListDecoder().decode(FamilyActivitySelection.self, from: data) {
            // Apply shields via mode token indirection
            store.shield.applications = selection.applicationTokens.isEmpty ? nil : selection.applicationTokens
            store.shield.applicationCategories = selection.categoryTokens.isEmpty ? nil : .specific(selection.categoryTokens)
            store.shield.webDomains = selection.webDomainTokens.isEmpty ? nil : selection.webDomainTokens

            defaults.set(scheduleId, forKey: "active_schedule_id")
            defaults.synchronize()
            logger.info("Applied shields for \(scheduleId) via mode \(modeId)")
            return
        }

        // Fallback: try legacy key (schedule_selection_<id>)
        if let legacyData = defaults.data(forKey: "schedule_selection_\(scheduleId)"),
           let selection = try? PropertyListDecoder().decode(FamilyActivitySelection.self, from: legacyData) {
            store.shield.applications = selection.applicationTokens.isEmpty ? nil : selection.applicationTokens
            store.shield.applicationCategories = selection.categoryTokens.isEmpty ? nil : .specific(selection.categoryTokens)
            store.shield.webDomains = selection.webDomainTokens.isEmpty ? nil : selection.webDomainTokens

            defaults.set(scheduleId, forKey: "active_schedule_id")
            defaults.synchronize()
            logger.info("Applied shields for \(scheduleId) via legacy key")
            return
        }

        logger.error("No mode tokens for schedule \(scheduleId)")
    }

    // MARK: - Interval End

    override func intervalDidEnd(for activity: DeviceActivityName) {
        guard let defaults = sharedDefaults else { return }
        let activityName = activity.rawValue
        guard activityName.hasPrefix("ctrl_schedule_") else { return }
        let scheduleId = String(activityName.dropFirst("ctrl_schedule_".count))

        defaults.set(Date().description, forKey: "debug_lastIntervalDidEnd")
        defaults.synchronize()

        // Check requireNFCToEnd — simple bool key
        if defaults.bool(forKey: "schedule_requireNFC_\(scheduleId)") {
            logger.info("NFC required to end \(scheduleId) — shields remain")
            return
        }

        // Clear shields
        store.shield.applications = nil
        store.shield.applicationCategories = nil
        store.shield.webDomains = nil
        store.clearAllSettings()

        defaults.removeObject(forKey: "active_schedule_id")
        defaults.synchronize()
        logger.info("Cleared shields for \(scheduleId)")
    }
}
