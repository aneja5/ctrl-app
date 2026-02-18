import Foundation

struct TokenHistoryEntry: Codable, Identifiable {
    var id: String { uuid }
    let uuid: String
    let fullPayload: String
    let createdAt: Date
}
