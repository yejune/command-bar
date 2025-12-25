import Foundation

struct Group: Identifiable, Codable {
    var seq: Int?              // DB 내부 seq (auto-increment)
    var id: String             // 6자리 외부 참조용 ID
    var name: String
    var color: String          // "blue", "red", "green", "orange", "purple", "gray"
    var order: Int
    var createdAt: Date = Date()

    // Identifiable 프로토콜용 - id가 String이므로 그대로 사용

    init(seq: Int? = nil, id: String = "", name: String, color: String, order: Int, createdAt: Date = Date()) {
        self.seq = seq
        self.id = id.isEmpty ? Group.generateId() : id
        self.name = name
        self.color = color
        self.order = order
        self.createdAt = createdAt
    }

    /// 6자리 랜덤 ID 생성
    static func generateId() -> String {
        let chars = "abcdefghijklmnopqrstuvwxyz0123456789"
        return String((0..<6).map { _ in chars.randomElement()! })
    }
}
