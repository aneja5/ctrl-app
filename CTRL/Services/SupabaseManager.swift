import Foundation
import Supabase

// MARK: - Cloud Data Models

/// Data model matching the `user_data` Supabase table.
/// Only contains cloud-safe fields (no FamilyActivitySelection).
struct CloudUserData: Codable {
    let id: UUID?
    let userId: UUID
    let email: String
    let modeNames: [String]
    let focusHistory: [CloudFocusEntry]
    let emergencyUnlocksRemaining: Int
    let emergencyResetDate: Date?          // Legacy — kept for backward compat
    let lastOverrideUsedDate: String?
    let overrideEarnBackDays: Int?
    let deviceId: String?
    let encryptedModesData: String?
    let strictModeEnabled: Bool?
    let updatedAt: Date?
    let currentStreak: Int?
    let longestStreak: Int?
    let lastStreakDate: String?
    let longestSessionSeconds: Int?
    let longestSessionDate: Date?
    let bestDaySeconds: Int?
    let bestDayDate: Date?
    let bestWeekSeconds: Int?
    let bestWeekStart: Date?
    let cumulativeLifetimeSeconds: Int?
    let cumulativeLifetimeSessions: Int?
    let cumulativeLifetimeDays: Int?

    enum CodingKeys: String, CodingKey {
        case id, email
        case userId = "user_id"
        case modeNames = "mode_names"
        case focusHistory = "focus_history"
        case emergencyUnlocksRemaining = "emergency_unlocks_remaining"
        case emergencyResetDate = "emergency_reset_date"
        case lastOverrideUsedDate = "last_override_used_date"
        case overrideEarnBackDays = "override_earn_back_days"
        case deviceId = "device_id"
        case encryptedModesData = "encrypted_modes_data"
        case strictModeEnabled = "strict_mode_enabled"
        case updatedAt = "updated_at"
        case currentStreak = "current_streak"
        case longestStreak = "longest_streak"
        case lastStreakDate = "last_streak_date"
        case longestSessionSeconds = "longest_session_seconds"
        case longestSessionDate = "longest_session_date"
        case bestDaySeconds = "best_day_seconds"
        case bestDayDate = "best_day_date"
        case bestWeekSeconds = "best_week_seconds"
        case bestWeekStart = "best_week_start"
        case cumulativeLifetimeSeconds = "cumulative_lifetime_seconds"
        case cumulativeLifetimeSessions = "cumulative_lifetime_sessions"
        case cumulativeLifetimeDays = "cumulative_lifetime_days"
    }
}

/// For writing (upsert) — only client-controlled fields.
/// Excludes server-generated fields (id, updated_at, created_at).
struct CloudUserDataWrite: Codable {
    let userId: UUID
    let email: String
    let modeNames: [String]
    let focusHistory: [CloudFocusEntry]
    let emergencyUnlocksRemaining: Int
    let lastOverrideUsedDate: String?
    let overrideEarnBackDays: Int
    let deviceId: String?
    let encryptedModesData: String?
    let strictModeEnabled: Bool
    let currentStreak: Int
    let longestStreak: Int
    let lastStreakDate: String?
    let longestSessionSeconds: Int
    let longestSessionDate: Date?
    let bestDaySeconds: Int
    let bestDayDate: Date?
    let bestWeekSeconds: Int
    let bestWeekStart: Date?
    let cumulativeLifetimeSeconds: Int
    let cumulativeLifetimeSessions: Int
    let cumulativeLifetimeDays: Int

    enum CodingKeys: String, CodingKey {
        case email
        case userId = "user_id"
        case modeNames = "mode_names"
        case focusHistory = "focus_history"
        case emergencyUnlocksRemaining = "emergency_unlocks_remaining"
        case lastOverrideUsedDate = "last_override_used_date"
        case overrideEarnBackDays = "override_earn_back_days"
        case deviceId = "device_id"
        case encryptedModesData = "encrypted_modes_data"
        case strictModeEnabled = "strict_mode_enabled"
        case currentStreak = "current_streak"
        case longestStreak = "longest_streak"
        case lastStreakDate = "last_streak_date"
        case longestSessionSeconds = "longest_session_seconds"
        case longestSessionDate = "longest_session_date"
        case bestDaySeconds = "best_day_seconds"
        case bestDayDate = "best_day_date"
        case bestWeekSeconds = "best_week_seconds"
        case bestWeekStart = "best_week_start"
        case cumulativeLifetimeSeconds = "cumulative_lifetime_seconds"
        case cumulativeLifetimeSessions = "cumulative_lifetime_sessions"
        case cumulativeLifetimeDays = "cumulative_lifetime_days"
    }
}

struct CloudFocusEntry: Codable {
    let date: String
    let totalSeconds: TimeInterval
    let sessionCount: Int

    init(date: String, totalSeconds: TimeInterval, sessionCount: Int = 0) {
        self.date = date
        self.totalSeconds = totalSeconds
        self.sessionCount = sessionCount
    }

    // Backward-compatible decoder — existing cloud data lacks sessionCount
    enum CodingKeys: String, CodingKey {
        case date, totalSeconds, sessionCount
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        date = try container.decode(String.self, forKey: .date)
        totalSeconds = try container.decode(TimeInterval.self, forKey: .totalSeconds)
        sessionCount = try container.decodeIfPresent(Int.self, forKey: .sessionCount) ?? 0
    }
}

/// Manages Supabase authentication via OTP (magic link / 6-digit code).
/// Reads project URL and anon key from Config.plist — never hardcoded.
@MainActor
final class SupabaseManager: ObservableObject {

    // MARK: - Singleton

    static let shared = SupabaseManager()

    // MARK: - Published State

    @Published private(set) var currentUser: User?
    @Published private(set) var isLoading = false

    /// Whether a user session is currently active.
    var isAuthenticated: Bool {
        currentUser != nil
    }

    // MARK: - Supabase Client

    let client: SupabaseClient

    // MARK: - Init

    private init() {
        let config = Self.loadConfig()
        self.client = SupabaseClient(
            supabaseURL: config.url,
            supabaseKey: config.anonKey,
            options: .init(
                auth: .init(
                    emitLocalSessionAsInitialSession: true
                )
            )
        )

        // Restore session on launch
        Task { [weak self] in
            await self?.restoreSession()
        }
    }

    // MARK: - Auth Methods

    /// Sends a one-time password to the given email address.
    func sendOTP(email: String) async throws {
        isLoading = true
        defer { isLoading = false }

        try await client.auth.signInWithOTP(email: email)
        #if DEBUG
        print("[SupabaseManager] OTP sent to \(email)")
        #endif
    }

    /// Verifies the OTP code and creates a session.
    func verifyOTP(email: String, code: String) async throws {
        isLoading = true
        defer { isLoading = false }

        let session = try await client.auth.verifyOTP(
            email: email,
            token: code,
            type: .email
        )
        self.currentUser = session.user
        #if DEBUG
        print("[SupabaseManager] OTP verified, user: \(session.user.id)")
        #endif
    }

    /// Signs out the current user and clears local session.
    func signOut() async throws {
        isLoading = true
        defer { isLoading = false }

        try await client.auth.signOut()
        self.currentUser = nil
        #if DEBUG
        print("[SupabaseManager] User signed out")
        #endif
    }

    /// Returns the current user, or nil if not authenticated.
    func getCurrentUser() async -> User? {
        do {
            let user = try await client.auth.user()
            self.currentUser = user
            return user
        } catch {
            #if DEBUG
            print("[SupabaseManager] No current user: \(error.localizedDescription)")
            #endif
            self.currentUser = nil
            return nil
        }
    }

    // MARK: - Cloud Data Methods

    /// Upserts user data to the `user_data` table.
    /// Accepts `CloudUserDataWrite` which excludes server-generated fields (id, updated_at).
    func saveUserData(_ data: CloudUserDataWrite) async throws {
        try await client
            .from("user_data")
            .upsert(data, onConflict: "user_id")
            .execute()

        #if DEBUG
        print("[SupabaseManager] User data saved for \(data.email)")
        #endif
    }

    /// Fetches user data from `user_data` table by user_id.
    /// Returns nil if no cloud data exists for this user.
    func fetchUserData(userId: UUID) async throws -> CloudUserData? {
        let response: [CloudUserData] = try await client
            .from("user_data")
            .select()
            .eq("user_id", value: userId.uuidString)
            .limit(1)
            .execute()
            .value

        #if DEBUG
        print("[SupabaseManager] Fetched user data: \(response.first != nil ? "found" : "none")")
        #endif

        return response.first
    }

    /// Deletes all user data from the `user_data` table for the current user.
    func deleteUserData(userId: UUID) async throws {
        try await client
            .from("user_data")
            .delete()
            .eq("user_id", value: userId.uuidString)
            .execute()

        #if DEBUG
        print("[SupabaseManager] User data deleted for \(userId)")
        #endif
    }

    // MARK: - Session Restoration

    private func restoreSession() async {
        do {
            let session = try await client.auth.session
            self.currentUser = session.user
            #if DEBUG
            print("[SupabaseManager] Session restored for user: \(session.user.id)")
            #endif
        } catch {
            self.currentUser = nil
            #if DEBUG
            print("[SupabaseManager] No existing session")
            #endif
        }
    }

    // MARK: - Config Loading

    private struct Config {
        let url: URL
        let anonKey: String
    }

    private static func loadConfig() -> Config {
        guard let path = Bundle.main.path(forResource: "Config", ofType: "plist"),
              let dict = NSDictionary(contentsOfFile: path) as? [String: Any],
              let urlString = dict["SUPABASE_URL"] as? String,
              let url = URL(string: urlString),
              let anonKey = dict["SUPABASE_ANON_KEY"] as? String
        else {
            fatalError("[SupabaseManager] Missing or invalid Config.plist. Add SUPABASE_URL and SUPABASE_ANON_KEY.")
        }
        return Config(url: url, anonKey: anonKey)
    }
}
