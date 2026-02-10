import Foundation
import FamilyControls

struct BlockingMode: Identifiable, Codable {
    var id: UUID = UUID()
    var name: String
    var appSelection: FamilyActivitySelection
    var isActive: Bool = false

    // For Codable - FamilyActivitySelection needs PropertyListEncoder
    enum CodingKeys: String, CodingKey {
        case id, name, appSelectionData, isActive
    }

    init(name: String, appSelection: FamilyActivitySelection = FamilyActivitySelection()) {
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
            appSelection = selection
        } else {
            appSelection = FamilyActivitySelection()
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
        appSelection.applicationTokens.count + appSelection.categoryTokens.count
    }
}
