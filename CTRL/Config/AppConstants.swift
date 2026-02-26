import Foundation

enum AppConstants {

    // MARK: - Session Thresholds

    /// Below this, session is ignored entirely (not logged)
    static let minimumSessionToLog: Int = 5

    /// Minimum seconds to count as a "session" in history
    static let minimumSessionForHistory: Int = 60

    /// Minimum seconds (10 min) for a day to count toward streak
    static let minimumSessionForStreak: Int = 600

    /// Minimum seconds (10 min) for a session to count toward override earn-back
    static let minimumSessionForEarnBack: TimeInterval = 600

    // MARK: - Modes

    static let maxModes: Int = 6
    static let defaultModeNames: [String] = ["Focus", "Sleep", "Detox"]

    // MARK: - Overrides

    static let startingOverrides: Int = 3
    static let maxOverrides: Int = 5
    static let earnBackStreakDays: Int = 7

    // MARK: - Schedules

    static let maxSchedules: Int = 6

    // MARK: - NFC

    /// Minimum seconds between NFC scans to avoid iOS resource errors
    static let nfcScanCooldown: TimeInterval = 2.0

    // MARK: - History

    /// Number of days of focus history to retain
    static let historyRetentionDays: Int = 90
}
