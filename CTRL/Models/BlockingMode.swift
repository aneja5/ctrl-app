import Foundation
import FamilyControls

// MARK: - Daily Focus Entry

struct DailyFocusEntry: Codable, Identifiable {
    var id: String { date }
    let date: String           // "yyyy-MM-dd"
    var totalSeconds: TimeInterval
    var sessionCount: Int

    init(date: String, totalSeconds: TimeInterval, sessionCount: Int = 0) {
        self.date = date
        self.totalSeconds = totalSeconds
        self.sessionCount = sessionCount
    }

    // Backward-compatible decoder — existing data lacks sessionCount
    enum CodingKeys: String, CodingKey {
        case date, totalSeconds, sessionCount
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        date = try container.decode(String.self, forKey: .date)
        totalSeconds = try container.decode(TimeInterval.self, forKey: .totalSeconds)
        sessionCount = try container.decodeIfPresent(Int.self, forKey: .sessionCount) ?? 0
    }

    static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    static func todayKey() -> String {
        dateFormatter.string(from: Date())
    }

    func dateValue() -> Date? {
        DailyFocusEntry.dateFormatter.date(from: date)
    }
}

// MARK: - Blocking Mode

struct BlockingMode: Identifiable, Codable {
    var id: UUID = UUID()
    var name: String
    var appSelection: FamilyActivitySelection
    var isActive: Bool = false

    // For Codable - FamilyActivitySelection needs PropertyListEncoder
    enum CodingKeys: String, CodingKey {
        case id, name, appSelectionData, isActive
    }

    init(name: String, appSelection: FamilyActivitySelection = FamilyActivitySelection(includeEntireCategory: true)) {
        self.name = name
        self.appSelection = appSelection
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        isActive = try container.decode(Bool.self, forKey: .isActive)

        if let data = try container.decodeIfPresent(Data.self, forKey: .appSelectionData),
           let selection = try? PropertyListDecoder().decode(FamilyActivitySelection.self, from: data) {
            // Re-apply includeEntireCategory which is lost during deserialization
            appSelection = selection.withIncludeEntireCategory()
        } else {
            appSelection = FamilyActivitySelection(includeEntireCategory: true)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(isActive, forKey: .isActive)

        if let data = try? PropertyListEncoder().encode(appSelection) {
            try container.encode(data, forKey: .appSelectionData)
        }
    }

    var appCount: Int {
        let apps = appSelection.applicationTokens.count
        let cats = appSelection.categoryTokens.count
        // When includeEntireCategory works, categories expand into applicationTokens
        // so apps already has the full count. Fallback to cats when expansion didn't happen.
        return cats > 0 && apps == 0 ? cats : apps
    }

    /// True when this mode has categories but no individual app tokens,
    /// meaning it was saved before the includeEntireCategory fix.
    /// The user needs to re-open the picker and tap Done to trigger expansion.
    var needsReselection: Bool {
        !appSelection.categoryTokens.isEmpty && appSelection.applicationTokens.isEmpty
    }
}

// MARK: - FamilyActivitySelection Helpers

extension FamilyActivitySelection {

    /// Re-creates this selection with `includeEntireCategory: true`.
    /// PropertyListDecoder does NOT preserve the includeEntireCategory flag,
    /// so after any deserialization we must rebuild the selection to restore it.
    /// This ensures the FamilyActivityPicker expands categories into individual app tokens.
    func withIncludeEntireCategory() -> FamilyActivitySelection {
        var fresh = FamilyActivitySelection(includeEntireCategory: true)
        fresh.applicationTokens = self.applicationTokens
        fresh.categoryTokens = self.categoryTokens
        fresh.webDomainTokens = self.webDomainTokens
        return fresh
    }

    /// Unified display string.
    /// When includeEntireCategory expands categories into applicationTokens, apps count
    /// is the true total. When expansion doesn't happen, fall back to categoryTokens count.
    /// Always displays as "X apps" — unified label.
    var displayCount: String {
        let apps = applicationTokens.count
        let cats = categoryTokens.count
        // When includeEntireCategory works, apps includes expanded category members.
        // When it doesn't, fall back to cats count so UI isn't empty.
        let total = cats > 0 && apps == 0 ? cats : apps
        if total == 0 { return "no apps selected" }
        return total == 1 ? "1 app" : "\(total) apps"
    }
}
