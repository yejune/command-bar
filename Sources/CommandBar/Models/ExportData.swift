import Foundation

// 임포트/익스포트용 구조체
struct ExportSettings: Codable {
    let alwaysOnTop: Bool
}

struct ExportData: Codable {
    let version: Int
    let exportedAt: Date
    let settings: ExportSettings
    let commands: [Command]
}
