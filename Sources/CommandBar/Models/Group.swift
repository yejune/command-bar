import Foundation

struct Group: Identifiable, Codable {
    var seq: Int?              // DB 내부 seq (auto-increment)
    var name: String
    var color: String          // "blue", "red", "green", "orange", "purple", "gray"
    var order: Int
    var createdAt: Date = Date()

    // Identifiable 프로토콜용 - seq를 사용
    var id: Int { seq ?? 0 }

    init(seq: Int? = nil, name: String, color: String, order: Int, createdAt: Date = Date()) {
        self.seq = seq
        self.name = name
        self.color = color
        self.order = order
        self.createdAt = createdAt
    }
}
