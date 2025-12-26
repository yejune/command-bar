import Foundation

enum ExecutionType: String, Codable, CaseIterable {
    case terminal = "터미널"
    case background = "백그라운드"
    case script = "실행"
    case schedule = "일정"
    case api = "API"

    var displayName: String {
        switch self {
        case .terminal: return L.executionTerminal
        case .background: return L.executionBackground
        case .script: return L.executionScript
        case .schedule: return L.executionSchedule
        case .api: return "API"
        }
    }
}

enum TerminalApp: String, Codable, CaseIterable {
    case iterm2 = "iTerm2"
    case terminal = "Terminal"
}

enum AlertState: String, Codable {
    case none = ""
    case dayBefore = "D-1"
    case hourBefore = "1시간 전"
    case thirtyMinBefore = "30분 전"
    case fiveMinBefore = "5분 전"
    case now = "지금!"
    case passed = "지남"

    var displayName: String {
        switch self {
        case .none: return ""
        case .dayBefore: return L.alertDayBefore
        case .hourBefore: return L.alertHourBefore
        case .thirtyMinBefore: return L.alertThirtyMinBefore
        case .fiveMinBefore: return L.alertFiveMinBefore
        case .now: return L.alertNow
        case .passed: return L.alertPassed
        }
    }
}

enum RepeatType: String, Codable, CaseIterable {
    case none = "없음"
    case daily = "매일"
    case weekly = "매주"
    case monthly = "매월"

    var displayName: String {
        switch self {
        case .none: return L.repeatNone
        case .daily: return L.repeatDaily
        case .weekly: return L.repeatWeekly
        case .monthly: return L.repeatMonthly
        }
    }
}

enum HistoryType: String, Codable {
    case executed = "executed"
    case background = "background"
    case script = "script"
    case api = "api"
    case scheduleAlert = "scheduleAlert"
    case reminder = "reminder"
    case added = "added"
    case deleted = "deleted"
    case restored = "restored"
    case permanentlyDeleted = "permanentlyDeleted"

    var displayName: String {
        switch self {
        case .executed: return L.historyExecuted
        case .background: return L.historyBackground
        case .script: return L.historyScript
        case .api: return "API"
        case .scheduleAlert: return L.historyScheduleAlert
        case .reminder: return L.historyReminder
        case .added: return L.historyAdded
        case .deleted: return L.historyDeleted
        case .restored: return L.historyRestored
        case .permanentlyDeleted: return L.historyPermanentlyDeleted
        }
    }
}

enum HTTPMethod: String, Codable, CaseIterable {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case delete = "DELETE"
    case patch = "PATCH"
}

enum BodyType: String, Codable, CaseIterable {
    case none = "none"
    case json = "json"
    case formData = "formData"
    case multipart = "multipart"

    var displayName: String {
        switch self {
        case .none: return "None"
        case .json: return "JSON"
        case .formData: return "Form Data"
        case .multipart: return "Multipart (파일)"
        }
    }
}

struct KeyValuePair: Identifiable {
    let id = UUID()
    var key: String
    var value: String
}
