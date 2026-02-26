import Foundation
import UIKit

/// Manages bidirectional sync between local AppState and Supabase cloud storage.
/// Sync is fire-and-forget: failures are logged but never block the user.
@MainActor
final class CloudSyncManager {

    // MARK: - Singleton

    static let shared = CloudSyncManager()

    // MARK: - Device ID

    /// Stable per-device identifier. Uses identifierForVendor which
    /// persists across app reinstalls on the same device.
    private var deviceId: String {
        UIDevice.current.identifierForVendor?.uuidString ?? "unknown"
    }

    private init() {}

    // MARK: - Sync To Cloud

    /// Pushes current local state to Supabase. Fire-and-forget.
    /// Call after: mode CRUD, session end, emergency unlock use.
    func syncToCloud(appState: AppState) {
        guard featureEnabled(.cloudSync) else { return }
        guard let email = appState.userEmail else { return }

        Task {
            do {
                guard let user = await SupabaseManager.shared.getCurrentUser() else {
                    #if DEBUG
                    print("[CloudSync] No authenticated user, skipping sync")
                    #endif
                    return
                }

                let focusEntries = appState.focusHistory.map {
                    CloudFocusEntry(date: $0.date, totalSeconds: $0.totalSeconds, sessionCount: $0.sessionCount)
                }

                // Encrypt app selections (nil if encryption fails — sync continues without)
                let encryptedBlob = EncryptionManager.encryptModes(
                    appState.modes,
                    email: email,
                    userId: user.id
                )

                let data = CloudUserDataWrite(
                    userId: user.id,
                    email: email,
                    modeNames: appState.modes.map { $0.name },
                    focusHistory: focusEntries,
                    emergencyUnlocksRemaining: appState.emergencyUnlocksRemaining,
                    lastOverrideUsedDate: appState.lastOverrideUsedDate,
                    overrideEarnBackDays: appState.overrideEarnBackDays,
                    deviceId: deviceId,
                    encryptedModesData: encryptedBlob,
                    strictModeEnabled: appState.strictModeEnabled,
                    currentStreak: appState.currentStreak,
                    longestStreak: appState.longestStreak,
                    lastStreakDate: appState.lastStreakDate,
                    longestSessionSeconds: appState.longestSessionSeconds,
                    longestSessionDate: appState.longestSessionDate,
                    bestDaySeconds: appState.bestDaySeconds,
                    bestDayDate: appState.bestDayDate,
                    bestWeekSeconds: appState.bestWeekSeconds,
                    bestWeekStart: appState.bestWeekStart,
                    cumulativeLifetimeSeconds: Int(appState.cumulativeLifetimeSeconds),
                    cumulativeLifetimeSessions: appState.cumulativeLifetimeSessions,
                    cumulativeLifetimeDays: appState.cumulativeLifetimeDays
                )

                try await SupabaseManager.shared.saveUserData(data)

                #if DEBUG
                print("[CloudSync] Synced to cloud: \(appState.modes.count) modes, \(appState.focusHistory.count) history entries")
                #endif
            } catch {
                #if DEBUG
                print("[CloudSync] Sync failed (silent): \(error.localizedDescription)")
                #endif
                // Silent failure — never block the user
            }
        }
    }

    // MARK: - Fetch From Cloud

    /// Fetches cloud data after sign-in. Returns nil if no cloud data exists.
    func fetchFromCloud() async -> CloudUserData? {
        do {
            guard let user = await SupabaseManager.shared.getCurrentUser() else {
                #if DEBUG
                print("[CloudSync] No authenticated user, cannot fetch")
                #endif
                return nil
            }

            let data = try await SupabaseManager.shared.fetchUserData(userId: user.id)

            #if DEBUG
            if let data = data {
                print("[CloudSync] Fetched cloud data: \(data.modeNames.count) modes, \(data.focusHistory.count) history entries, device: \(data.deviceId ?? "nil")")
            } else {
                print("[CloudSync] No cloud data found for user")
            }
            #endif

            return data
        } catch {
            #if DEBUG
            print("[CloudSync] Fetch failed (silent): \(error.localizedDescription)")
            #endif
            return nil
        }
    }

    // MARK: - New Device Detection

    /// Determines if the cloud data came from a different device.
    func isNewDevice(cloudData: CloudUserData) -> Bool {
        guard let cloudDeviceId = cloudData.deviceId else { return true }
        return cloudDeviceId != deviceId
    }

    // MARK: - Restore From Cloud

    /// Merges cloud data into local AppState.
    /// Tries to decrypt encrypted app selections first; falls back to name-only restore.
    func restoreFromCloud(_ cloudData: CloudUserData, into appState: AppState) {
        guard featureEnabled(.cloudSync) else { return }
        // Try decrypting encrypted modes (includes app selections)
        if let encrypted = cloudData.encryptedModesData,
           let decryptedModes = EncryptionManager.decryptModes(
               encrypted,
               email: cloudData.email,
               userId: cloudData.userId
           ) {
            // Full restore — modes WITH app selections
            appState.modes = decryptedModes
            // Preserve user's mode selection if it still exists in restored modes
            if !decryptedModes.contains(where: { $0.id == appState.activeModeId }) {
                appState.activeModeId = decryptedModes.first?.id
            }

            #if DEBUG
            print("[CloudSync] Restored \(decryptedModes.count) modes with encrypted app selections")
            for mode in decryptedModes {
                print("[CloudSync]   '\(mode.name)' — \(mode.appCount) apps")
            }
            #endif
        } else {
            // Fallback — name-only restore (no encrypted data or decryption failed)
            let restoredModes = cloudData.modeNames.map { name in
                BlockingMode(name: name)
            }

            if !restoredModes.isEmpty {
                // Capture current mode name before overwriting (name-only restore creates new UUIDs)
                let previousModeName = appState.activeMode?.name
                appState.modes = restoredModes
                // Try to preserve mode selection by name, else fall back to first
                if let name = previousModeName,
                   let match = restoredModes.first(where: { $0.name.lowercased() == name.lowercased() }) {
                    appState.activeModeId = match.id
                } else {
                    appState.activeModeId = restoredModes.first?.id
                }
            }

            #if DEBUG
            print("[CloudSync] Restored \(restoredModes.count) modes (name-only, no encrypted data)")
            #endif
        }

        // Restore focus history
        let restoredHistory = cloudData.focusHistory.map {
            DailyFocusEntry(date: $0.date, totalSeconds: $0.totalSeconds, sessionCount: $0.sessionCount)
        }
        appState.focusHistory = restoredHistory

        // Restore emergency unlocks (v2 earn-back system)
        appState.emergencyUnlocksRemaining = min(cloudData.emergencyUnlocksRemaining, AppConstants.maxOverrides)
        appState.lastOverrideUsedDate = cloudData.lastOverrideUsedDate
        appState.overrideEarnBackDays = cloudData.overrideEarnBackDays ?? 0

        // Restore strict mode preference (only if feature flag is on)
        if featureEnabled(.strictMode) {
            appState.strictModeEnabled = cloudData.strictModeEnabled ?? false
        } else {
            appState.strictModeEnabled = false
        }

        // Restore streak data
        appState.currentStreak = cloudData.currentStreak ?? 0
        appState.longestStreak = cloudData.longestStreak ?? 0
        appState.lastStreakDate = cloudData.lastStreakDate

        // Restore personal records
        appState.longestSessionSeconds = cloudData.longestSessionSeconds ?? 0
        appState.longestSessionDate = cloudData.longestSessionDate
        appState.bestDaySeconds = cloudData.bestDaySeconds ?? 0
        appState.bestDayDate = cloudData.bestDayDate
        appState.bestWeekSeconds = cloudData.bestWeekSeconds ?? 0
        appState.bestWeekStart = cloudData.bestWeekStart

        // Restore cumulative lifetime counters
        appState.cumulativeLifetimeSeconds = TimeInterval(cloudData.cumulativeLifetimeSeconds ?? 0)
        appState.cumulativeLifetimeSessions = cloudData.cumulativeLifetimeSessions ?? 0
        appState.cumulativeLifetimeDays = cloudData.cumulativeLifetimeDays ?? 0

        // Backfill from restored history if cloud had no cumulative data
        if appState.cumulativeLifetimeSeconds == 0
            && appState.cumulativeLifetimeSessions == 0
            && !appState.focusHistory.isEmpty {
            let historySeconds = appState.focusHistory.reduce(0.0) { $0 + $1.totalSeconds }
            let historySessions = appState.focusHistory.reduce(0) { $0 + $1.sessionCount }
            let historyDays = appState.focusHistory.filter { $0.totalSeconds > 0 }.count
            if historySeconds > 0 {
                appState.cumulativeLifetimeSeconds = historySeconds
                appState.cumulativeLifetimeSessions = historySessions
                appState.cumulativeLifetimeDays = historyDays
            }
        }

        // Recalculate streak from restored history
        appState.recalculateStreakFromHistory()

        // Note: caller is responsible for calling saveState() (e.g. via markOnboardingComplete)
    }

    // MARK: - Delete Cloud Data

    /// Deletes all cloud data for the current user.
    func deleteCloudData() async throws {
        guard let user = await SupabaseManager.shared.getCurrentUser() else { return }
        try await SupabaseManager.shared.deleteUserData(userId: user.id)
    }
}
