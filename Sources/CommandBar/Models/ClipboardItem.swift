import Foundation

struct ClipboardItem: Identifiable, Codable {
    var seq: Int?              // DB 내부 seq (auto-increment)
    var id: String             // 6자리 외부 참조용 ID
    let content: String
    let timestamp: Date
    var isFavorite: Bool
    var copyCount: Int
    var firstCopiedAt: Date?
    var deletedAt: Date?       // 삭제 시간 (휴지통)

    init(seq: Int? = nil, id: String = "", content: String, timestamp: Date = Date(), isFavorite: Bool = false, copyCount: Int = 1, firstCopiedAt: Date? = nil, deletedAt: Date? = nil) {
        self.seq = seq
        self.id = id.isEmpty ? ClipboardItem.generateId() : id
        self.content = content
        self.timestamp = timestamp
        self.isFavorite = isFavorite
        self.copyCount = copyCount
        self.firstCopiedAt = firstCopiedAt ?? timestamp
        self.deletedAt = deletedAt
    }

    /// 6자리 랜덤 ID 생성
    static func generateId() -> String {
        let chars = "abcdefghijklmnopqrstuvwxyz0123456789"
        return String((0..<6).map { _ in chars.randomElement()! })
    }

    var preview: String {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count > 100 {
            return String(trimmed.prefix(100)) + "..."
        }
        return trimmed
    }
}
