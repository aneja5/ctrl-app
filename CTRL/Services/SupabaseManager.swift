import Foundation
import Supabase

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
            supabaseKey: config.anonKey
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
        print("[SupabaseManager] OTP sent to \(email)")
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
        print("[SupabaseManager] OTP verified, user: \(session.user.id)")
    }

    /// Signs out the current user and clears local session.
    func signOut() async throws {
        isLoading = true
        defer { isLoading = false }

        try await client.auth.signOut()
        self.currentUser = nil
        print("[SupabaseManager] User signed out")
    }

    /// Returns the current user, or nil if not authenticated.
    func getCurrentUser() async -> User? {
        do {
            let user = try await client.auth.user()
            self.currentUser = user
            return user
        } catch {
            print("[SupabaseManager] No current user: \(error.localizedDescription)")
            self.currentUser = nil
            return nil
        }
    }

    // MARK: - Session Restoration

    private func restoreSession() async {
        do {
            let session = try await client.auth.session
            self.currentUser = session.user
            print("[SupabaseManager] Session restored for user: \(session.user.id)")
        } catch {
            self.currentUser = nil
            print("[SupabaseManager] No existing session")
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
