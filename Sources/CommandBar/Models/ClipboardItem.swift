import Foundation

struct ClipboardItem: Identifiable, Codable {
    let id: UUID
    let content: String
    let timestamp: Date
    var isFavorite: Bool

    init(content: String, isFavorite: Bool = false) {
        self.id = UUID()
        self.content = content
        self.timestamp = Date()
        self.isFavorite = isFavorite
    }

    init(id: UUID, timestamp: Date, content: String, isFavorite: Bool = false) {
        self.id = id
        self.timestamp = timestamp
        self.content = content
        self.isFavorite = isFavorite
    }

    enum CodingKeys: String, CodingKey {
        case id, content, timestamp, isFavorite
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        content = try container.decode(String.self, forKey: .content)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        isFavorite = try container.decodeIfPresent(Bool.self, forKey: .isFavorite) ?? false
    }

    var preview: String {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count > 100 {
            return String(trimmed.prefix(100)) + "..."
        }
        return trimmed
    }
}
