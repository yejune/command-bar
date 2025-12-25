import Foundation

struct HistoryItem: Identifiable, Codable {
    var seq: Int?              // DB 내부 seq (auto-increment)
    var id: String             // 6자리 외부 참조용 ID
    var timestamp: Date
    let title: String
    let command: String
    let type: HistoryType
    var output: String?
    var count: Int = 1         // 반복 횟수
    var endTimestamp: Date?    // 반복 종료 시간
    var commandSeq: Int?       // commands.seq 참조
    var firstExecutedAt: Date? // 최초 실행 시간 (카운트 기능용)
    var deletedAt: Date?       // 삭제 시간 (휴지통)

    init(seq: Int? = nil, id: String = "", timestamp: Date = Date(), title: String, command: String, type: HistoryType, output: String? = nil, count: Int = 1, endTimestamp: Date? = nil, commandSeq: Int? = nil, firstExecutedAt: Date? = nil, deletedAt: Date? = nil) {
        self.seq = seq
        self.id = id.isEmpty ? HistoryItem.generateId() : id
        self.timestamp = timestamp
        self.title = title
        self.command = command
        self.type = type
        self.output = output
        self.count = count
        self.endTimestamp = endTimestamp
        self.commandSeq = commandSeq
        self.firstExecutedAt = firstExecutedAt
        self.deletedAt = deletedAt
    }

    /// 6자리 랜덤 ID 생성
    static func generateId() -> String {
        let chars = "abcdefghijklmnopqrstuvwxyz0123456789"
        return String((0..<6).map { _ in chars.randomElement()! })
    }
}
