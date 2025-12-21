import Foundation

struct Command: Identifiable, Codable {
    var id = UUID()
    var groupId: UUID = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!
    var title: String
    var command: String
    var executionType: ExecutionType
    var terminalApp: TerminalApp = .iterm2
    var interval: Int = 0  // 초 단위, 0이면 수동
    var lastOutput: String?
    var lastExecutedAt: Date?  // 마지막 실행 시간
    var isRunning: Bool = false
    // 일정용
    var scheduleDate: Date?
    var repeatType: RepeatType = .none
    var alertState: AlertState = .none
    // 미리 알림 설정 (초 단위): 5분=300, 30분=1800, 1시간=3600, 1일=86400
    var reminderTimes: Set<Int> = []  // 선택된 미리 알림 시간들
    var alertedTimes: Set<Int> = []  // 이미 알림 준 시간들
    var historyLoggedTimes: Set<Int> = []  // 히스토리 기록된 시간들
    var acknowledged: Bool = false  // 클릭해서 확인함
    var isInTrash: Bool = false  // 휴지통에 있음
    var isFavorite: Bool = false  // 즐겨찾기

    enum CodingKeys: String, CodingKey {
        case id, groupId, title, command, executionType, terminalApp, interval
        case lastOutput, lastExecutedAt, isRunning, scheduleDate, repeatType
        case alertState, reminderTimes, alertedTimes, historyLoggedTimes
        case acknowledged, isInTrash, isFavorite
    }

    init(id: UUID = UUID(), groupId: UUID = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!, title: String, command: String, executionType: ExecutionType, terminalApp: TerminalApp = .iterm2, interval: Int = 0, lastOutput: String? = nil, lastExecutedAt: Date? = nil, isRunning: Bool = false, scheduleDate: Date? = nil, repeatType: RepeatType = .none, alertState: AlertState = .none, reminderTimes: Set<Int> = [], alertedTimes: Set<Int> = [], historyLoggedTimes: Set<Int> = [], acknowledged: Bool = false, isInTrash: Bool = false, isFavorite: Bool = false) {
        self.id = id
        self.groupId = groupId
        self.title = title
        self.command = command
        self.executionType = executionType
        self.terminalApp = terminalApp
        self.interval = interval
        self.lastOutput = lastOutput
        self.lastExecutedAt = lastExecutedAt
        self.isRunning = isRunning
        self.scheduleDate = scheduleDate
        self.repeatType = repeatType
        self.alertState = alertState
        self.reminderTimes = reminderTimes
        self.alertedTimes = alertedTimes
        self.historyLoggedTimes = historyLoggedTimes
        self.acknowledged = acknowledged
        self.isInTrash = isInTrash
        self.isFavorite = isFavorite
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        groupId = try container.decodeIfPresent(UUID.self, forKey: .groupId) ?? UUID(uuidString: "00000000-0000-0000-0000-000000000000")!
        title = try container.decode(String.self, forKey: .title)
        command = try container.decode(String.self, forKey: .command)
        executionType = try container.decode(ExecutionType.self, forKey: .executionType)
        terminalApp = try container.decodeIfPresent(TerminalApp.self, forKey: .terminalApp) ?? .iterm2
        interval = try container.decodeIfPresent(Int.self, forKey: .interval) ?? 0
        lastOutput = try container.decodeIfPresent(String.self, forKey: .lastOutput)
        lastExecutedAt = try container.decodeIfPresent(Date.self, forKey: .lastExecutedAt)
        isRunning = try container.decodeIfPresent(Bool.self, forKey: .isRunning) ?? false
        scheduleDate = try container.decodeIfPresent(Date.self, forKey: .scheduleDate)
        repeatType = try container.decodeIfPresent(RepeatType.self, forKey: .repeatType) ?? .none
        alertState = try container.decodeIfPresent(AlertState.self, forKey: .alertState) ?? .none
        reminderTimes = try container.decodeIfPresent(Set<Int>.self, forKey: .reminderTimes) ?? []
        alertedTimes = try container.decodeIfPresent(Set<Int>.self, forKey: .alertedTimes) ?? []
        historyLoggedTimes = try container.decodeIfPresent(Set<Int>.self, forKey: .historyLoggedTimes) ?? []
        acknowledged = try container.decodeIfPresent(Bool.self, forKey: .acknowledged) ?? false
        isInTrash = try container.decodeIfPresent(Bool.self, forKey: .isInTrash) ?? false
        isFavorite = try container.decodeIfPresent(Bool.self, forKey: .isFavorite) ?? false
    }
}

// 파라미터 정보
struct ParameterInfo {
    let name: String      // 파라미터 이름
    let options: [String] // 옵션 (비어있으면 텍스트 입력)
    let fullMatch: String // 전체 매칭 문자열 (예: "앱이름:hae|bflow")
}

// 파라미터 파싱 extension
extension Command {
    var parameterInfos: [ParameterInfo] {
        guard let regex = try? NSRegularExpression(pattern: "\\{([^}]+)\\}") else { return [] }
        let range = NSRange(command.startIndex..., in: command)
        let matches = regex.matches(in: command, range: range)
        var result: [ParameterInfo] = []
        var seenNames: Set<String> = []
        for match in matches {
            if let r = Range(match.range(at: 1), in: command) {
                let fullMatch = String(command[r])
                // "이름:옵션1|옵션2" 형태 파싱
                let parts = fullMatch.split(separator: ":", maxSplits: 1)
                let name = String(parts[0])
                let options: [String]
                if parts.count > 1 {
                    options = String(parts[1]).split(separator: "|").map { String($0) }
                } else {
                    options = []
                }
                if !seenNames.contains(name) {
                    seenNames.insert(name)
                    result.append(ParameterInfo(name: name, options: options, fullMatch: fullMatch))
                }
            }
        }
        return result
    }

    var parameters: [String] { parameterInfos.map { $0.name } }

    var hasParameters: Bool { !parameters.isEmpty }

    func commandWith(values: [String: String]) -> String {
        var result = command
        for info in parameterInfos {
            if let value = values[info.name] {
                // 쉘 특수문자 이스케이프
                let escaped = value
                    .replacingOccurrences(of: "\\", with: "\\\\")
                    .replacingOccurrences(of: "\"", with: "\\\"")
                    .replacingOccurrences(of: "$", with: "\\$")
                    .replacingOccurrences(of: "`", with: "\\`")
                result = result.replacingOccurrences(of: "{\(info.fullMatch)}", with: escaped)
            }
        }
        return result
    }
}
