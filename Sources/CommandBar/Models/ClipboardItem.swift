import Foundation

struct ClipboardItem: Identifiable, Codable {
    let id: UUID
    let content: String
    let timestamp: Date

    init(content: String) {
        self.id = UUID()
        self.content = content
        self.timestamp = Date()
    }

    init(id: UUID, timestamp: Date, content: String) {
        self.id = id
        self.timestamp = timestamp
        self.content = content
    }

    var preview: String {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count > 100 {
            return String(trimmed.prefix(100)) + "..."
        }
        return trimmed
    }
}
