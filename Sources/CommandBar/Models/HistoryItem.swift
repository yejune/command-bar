import Foundation

struct HistoryItem: Identifiable, Codable {
    var id = UUID()
    var timestamp: Date
    let title: String
    let command: String
    let type: HistoryType
    var output: String?
    var count: Int = 1  // 반복 횟수
    var endTimestamp: Date?  // 반복 종료 시간
    var commandId: UUID?  // 원본 명령 ID (일정 알림 병합용)
    var firstExecutedAt: Date?  // 최초 실행 시간 (카운트 기능용)
}
