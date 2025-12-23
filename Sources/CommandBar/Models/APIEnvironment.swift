import Foundation

/// API 환경 모델 - Postman/Paw처럼 환경별 변수를 관리
struct APIEnvironment: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String                      // "개발", "운영", "스테이징"
    var color: String                     // "green", "yellow", "red", "blue", "purple", "gray"
    var variables: [String: String]       // key-value 쌍
    var order: Int                        // 정렬 순서
    var createdAt: Date = Date()

    /// 기본 환경 색상 목록
    static let availableColors = ["green", "yellow", "red", "blue", "purple", "gray", "orange"]

    /// 환경 색상에 따른 표시 이름
    var colorDisplayName: String {
        switch color {
        case "green": return "초록"
        case "yellow": return "노랑"
        case "red": return "빨강"
        case "blue": return "파랑"
        case "purple": return "보라"
        case "gray": return "회색"
        case "orange": return "주황"
        default: return color
        }
    }
}

/// 환경 변수 그룹 (var, header 등)
struct EnvironmentVariableGroup: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String                      // "var", "header"
    var order: Int                        // 정렬 순서
}

/// 환경 내보내기/가져오기용 구조체
struct EnvironmentExportData: Codable {
    var environments: [APIEnvironment]
    var variableGroups: [String]
    var exportedAt: Date = Date()
    var version: String = "1.0"
}
