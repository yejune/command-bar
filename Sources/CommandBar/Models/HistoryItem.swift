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

    // API 요청 정보
    var requestUrl: String?
    var requestMethod: String?
    var requestHeaders: String?     // JSON 문자열
    var requestBody: String?
    var requestQueryParams: String? // JSON 문자열
    var statusCode: Int?
    var isSuccess: Bool?            // 성공 여부

    init(seq: Int? = nil, id: String = "", timestamp: Date = Date(), title: String, command: String, type: HistoryType, output: String? = nil, count: Int = 1, endTimestamp: Date? = nil, commandSeq: Int? = nil, firstExecutedAt: Date? = nil, deletedAt: Date? = nil,
         requestUrl: String? = nil, requestMethod: String? = nil, requestHeaders: String? = nil, requestBody: String? = nil, requestQueryParams: String? = nil, statusCode: Int? = nil, isSuccess: Bool? = nil) {
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
        self.requestUrl = requestUrl
        self.requestMethod = requestMethod
        self.requestHeaders = requestHeaders
        self.requestBody = requestBody
        self.requestQueryParams = requestQueryParams
        self.statusCode = statusCode
        self.isSuccess = isSuccess
    }

    /// 6자리 랜덤 ID 생성
    static func generateId() -> String {
        let chars = "abcdefghijklmnopqrstuvwxyz0123456789"
        return String((0..<6).map { _ in chars.randomElement()! })
    }
}
