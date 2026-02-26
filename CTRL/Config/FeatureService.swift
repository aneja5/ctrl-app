import Foundation

// MARK: - Feature Definitions

enum Feature: String, CaseIterable {

    // === SESSION FEATURES ===
    case manualSessions          // start without NFC tag
    case breaks                  // earned breaks during sessions
    case schedules               // auto-start/stop sessions on schedule

    // === BLOCKING FEATURES ===
    case strictMode              // prevent app deletion during session
    case webDomainBlocking       // block Safari domains

    // === SAFETY FEATURES ===
    case emergencyOverrides      // emergency session exit
    case overrideEarnBack        // earn overrides through consistency

    // === TRACKING FEATURES ===
    case streakTracking          // daily streak calculation
    case personalRecords         // longest session, best day, best week
    case weeklyStats             // week tab in activity
    case monthlyStats            // month tab in activity
    case lifetimeStats           // lifetime tab in activity

    // === CLOUD FEATURES ===
    case cloudSync               // sync to Supabase
    case encryptedSync           // encrypt app selections before sync

    // === ONBOARDING ===
    case defaultModes            // create focus/sleep/detox on first launch

    // === FUTURE (gated off) ===
    case celebrations            // post-session celebration screen
    case tapRitual               // NFC tap ritual animations
    case shareCard               // share focus stats card
}

// MARK: - Feature Service

final class FeatureService {

    static let shared = FeatureService()
    private init() {}

    // The master configuration.
    // Change values here to enable/disable features app-wide.
    // When remote config is added later, this dictionary gets
    // populated from the server instead of hardcoded.

    private let configuration: [Feature: Bool] = [

        // === v1.0 — ENABLED ===
        .manualSessions:        true,
        .strictMode:            true,
        .webDomainBlocking:     true,
        .emergencyOverrides:    true,
        .overrideEarnBack:      true,
        .streakTracking:        true,
        .personalRecords:       true,
        .weeklyStats:           true,
        .monthlyStats:          true,
        .lifetimeStats:         true,
        .cloudSync:             true,
        .encryptedSync:         true,
        .defaultModes:          true,

        // === v1.0 — DISABLED ===
        .breaks:                false,
        .schedules:             false,
        .celebrations:          false,
        .tapRitual:             false,
        .shareCard:             false,
    ]

    // MARK: - Public API

    func isEnabled(_ feature: Feature) -> Bool {
        return configuration[feature] ?? false
    }

    func allEnabled(_ features: Feature...) -> Bool {
        return features.allSatisfy { isEnabled($0) }
    }

    func anyEnabled(_ features: Feature...) -> Bool {
        return features.contains { isEnabled($0) }
    }

    // MARK: - Debug

    #if DEBUG
    func printStatus() {
        print("[FeatureService] Feature flags:")
        for feature in Feature.allCases {
            let status = isEnabled(feature) ? "ON" : "OFF"
            print("  [\(status)] \(feature.rawValue)")
        }
    }
    #endif
}

// MARK: - Global convenience (keeps call sites clean)

func featureEnabled(_ feature: Feature) -> Bool {
    FeatureService.shared.isEnabled(feature)
}
