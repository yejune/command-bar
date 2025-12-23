import Foundation

struct ClipboardItem: Identifiable, Codable {
    let id: UUID
    let content: String
    let timestamp: Date
    var isFavorite: Bool
    var copyCount: Int
    var firstCopiedAt: Date?

    init(content: String, isFavorite: Bool = false, copyCount: Int = 1, firstCopiedAt: Date? = nil) {
        self.id = UUID()
        self.content = content
        self.timestamp = Date()
        self.isFavorite = isFavorite
        self.copyCount = copyCount
        self.firstCopiedAt = firstCopiedAt ?? Date()
    }

    init(id: UUID, timestamp: Date, content: String, isFavorite: Bool = false, copyCount: Int = 1, firstCopiedAt: Date? = nil) {
        self.id = id
        self.timestamp = timestamp
        self.content = content
        self.isFavorite = isFavorite
        self.copyCount = copyCount
        self.firstCopiedAt = firstCopiedAt
    }

    enum CodingKeys: String, CodingKey {
        case id, content, timestamp, isFavorite, copyCount, firstCopiedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        content = try container.decode(String.self, forKey: .content)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        isFavorite = try container.decodeIfPresent(Bool.self, forKey: .isFavorite) ?? false
        copyCount = try container.decodeIfPresent(Int.self, forKey: .copyCount) ?? 1
        firstCopiedAt = try container.decodeIfPresent(Date.self, forKey: .firstCopiedAt)
    }

    var preview: String {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count > 100 {
            return String(trimmed.prefix(100)) + "..."
        }
        return trimmed
    }
}
