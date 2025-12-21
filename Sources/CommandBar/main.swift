import SwiftUI
import AppKit
import UniformTypeIdentifiers
import ServiceManagement

// MARK: - 다국어 지원 시스템

enum Language: String, Codable, CaseIterable {
    case korean = "ko"
    case english = "en"
    case japanese = "ja"

    var displayName: String {
        switch self {
        case .korean: return "한국어"
        case .english: return "English"
        case .japanese: return "日本語"
        }
    }
}

struct LocalizedStrings: Codable {
    // 탭 이름
    var tabCommands: String
    var tabHistory: String
    var tabClipboard: String
    var tabTrash: String
    var tabSettings: String

    // 실행 타입
    var executionTerminal: String
    var executionBackground: String
    var executionScript: String
    var executionSchedule: String

    // 알림 상태
    var alertDayBefore: String
    var alertHourBefore: String
    var alertThirtyMinBefore: String
    var alertFiveMinBefore: String
    var alertNow: String
    var alertPassed: String

    // 반복 타입
    var repeatNone: String
    var repeatDaily: String
    var repeatWeekly: String
    var repeatMonthly: String

    // 히스토리 타입
    var historyExecuted: String
    var historyBackground: String
    var historyScript: String
    var historyScheduleAlert: String
    var historyReminder: String
    var historyAdded: String
    var historyDeleted: String
    var historyRestored: String
    var historyPermanentlyDeleted: String

    // 공통 버튼
    var buttonClose: String
    var buttonCancel: String
    var buttonConfirm: String
    var buttonSave: String
    var buttonDelete: String
    var buttonRestore: String
    var buttonAdd: String
    var buttonEdit: String
    var buttonRun: String
    var buttonStop: String
    var buttonCopy: String
    var buttonClear: String
    var buttonExport: String
    var buttonImport: String

    // 설정
    var settingsTitle: String
    var settingsGeneral: String
    var settingsHistoryTab: String
    var settingsClipboardTab: String
    var settingsBackup: String
    var settingsLanguage: String
    var settingsAlwaysOnTop: String
    var settingsLaunchAtLogin: String
    var settingsBackgroundOpacity: String
    var settingsMaxCount: String
    var settingsNotesFolderName: String
    var settingsExportFile: String
    var settingsImportFile: String
    var settingsBackupNote: String
    var settingsLanguagePack: String
    var settingsExportLanguagePack: String
    var settingsImportLanguagePack: String

    // 휴지통
    var trashTitle: String
    var trashEmpty: String
    var trashEmptyMessage: String
    var trashEmptyButton: String

    // 명령
    var commandTitle: String
    var commandCommand: String
    var commandType: String
    var commandTerminalApp: String
    var commandInterval: String
    var commandScheduleDate: String
    var commandRepeat: String
    var commandReminders: String
    var commandAddNew: String
    var commandEditTitle: String
    var commandNoCommands: String
    var commandAddFirst: String

    // 파라미터
    var parameterInputTitle: String
    var parameterHelpTitle: String
    var parameterExample: String
    var parameterEnterValue: String

    // 히스토리
    var historyTitle: String
    var historyNoHistory: String
    var historyOutput: String
    var historyTimes: String

    // 클립보드
    var clipboardTitle: String
    var clipboardNoItems: String
    var clipboardSendToNotes: String
    var clipboardMakeCommand: String

    // 알림 메시지
    var alertExportSuccess: String
    var alertExportFailed: String
    var alertImportSuccess: String
    var alertImportFailed: String
    var alertInvalidFormat: String
    var alertClipboardEmpty: String
    var alertCopiedToClipboard: String
    var alertMergeComplete: String
    var alertOverwriteComplete: String
    var alertSaveFailed: String
    var alertReadFailed: String

    // 임포트 다이얼로그
    var importDialogTitle: String
    var importMerge: String
    var importOverwrite: String

    // 언어팩 관련
    var languagePackExportSuccess: String
    var languagePackImportSuccess: String
    var languagePackInvalidFormat: String

    // 스크립트
    var scriptRunning: String
    var scriptCompleted: String
    var scriptFailed: String
    var scriptOutput: String

    // 기타
    var secondsUnit: String
    var minutesUnit: String
    var hoursUnit: String
    var daysUnit: String
    var manual: String
    var running: String
    var stopped: String
    var noOutput: String
    var lastRun: String
    var nextRun: String
    var interval: String

    // 추가 UI 문자열
    var commandListTitle: String
    var addNewItem: String
    var dateTime: String
    var executionMethod: String
    var commandInput: String
    var commandHelpText: String
    var terminalAppLabel: String
    var intervalLabel: String
    var clipboardDetail: String
    var addToTop: String
    var addToBottom: String
    var notification: String
    var contextMenuRun: String
    var contextMenuEdit: String
    var contextMenuCopy: String
    var helpSyntax: String
    var parameter: String
    var timeAfter: String
    var timePassed: String
    var clipboardContent: String
}

// 기본 언어팩들
extension LocalizedStrings {
    static let korean = LocalizedStrings(
        tabCommands: "명령",
        tabHistory: "히스토리",
        tabClipboard: "클립보드",
        tabTrash: "휴지통",
        tabSettings: "설정",

        executionTerminal: "터미널",
        executionBackground: "백그라운드",
        executionScript: "실행",
        executionSchedule: "일정",

        alertDayBefore: "D-1",
        alertHourBefore: "1시간 전",
        alertThirtyMinBefore: "30분 전",
        alertFiveMinBefore: "5분 전",
        alertNow: "지금!",
        alertPassed: "지남",

        repeatNone: "없음",
        repeatDaily: "매일",
        repeatWeekly: "매주",
        repeatMonthly: "매월",

        historyExecuted: "실행",
        historyBackground: "백그라운드",
        historyScript: "스크립트",
        historyScheduleAlert: "일정 알림",
        historyReminder: "미리 알림",
        historyAdded: "등록",
        historyDeleted: "삭제",
        historyRestored: "복원",
        historyPermanentlyDeleted: "제거",

        buttonClose: "닫기",
        buttonCancel: "취소",
        buttonConfirm: "확인",
        buttonSave: "저장",
        buttonDelete: "삭제",
        buttonRestore: "복원",
        buttonAdd: "추가",
        buttonEdit: "편집",
        buttonRun: "실행",
        buttonStop: "정지",
        buttonCopy: "복사",
        buttonClear: "지우기",
        buttonExport: "내보내기",
        buttonImport: "가져오기",

        settingsTitle: "설정",
        settingsGeneral: "기본",
        settingsHistoryTab: "히스토리",
        settingsClipboardTab: "클립보드",
        settingsBackup: "백업",
        settingsLanguage: "언어",
        settingsAlwaysOnTop: "항상 위에 표시",
        settingsLaunchAtLogin: "로그인 시 시작",
        settingsBackgroundOpacity: "배경 투명도",
        settingsMaxCount: "최대 개수",
        settingsNotesFolderName: "메모 폴더명",
        settingsExportFile: "파일 내보내기",
        settingsImportFile: "파일 가져오기",
        settingsBackupNote: "명령 목록만 백업됩니다",
        settingsLanguagePack: "언어팩",
        settingsExportLanguagePack: "언어팩 견본 내보내기",
        settingsImportLanguagePack: "언어팩 가져오기",

        trashTitle: "휴지통",
        trashEmpty: "비우기",
        trashEmptyMessage: "휴지통이 비어있습니다",
        trashEmptyButton: "비우기",

        commandTitle: "제목",
        commandCommand: "명령",
        commandType: "타입",
        commandTerminalApp: "터미널 앱",
        commandInterval: "실행 간격",
        commandScheduleDate: "일정",
        commandRepeat: "반복",
        commandReminders: "미리 알림",
        commandAddNew: "명령 추가",
        commandEditTitle: "명령 편집",
        commandNoCommands: "명령이 없습니다",
        commandAddFirst: "첫 명령을 추가하세요",

        parameterInputTitle: "파라미터 입력",
        parameterHelpTitle: "파라미터 도움말",
        parameterExample: "예시",
        parameterEnterValue: "값 입력",

        historyTitle: "히스토리",
        historyNoHistory: "기록이 없습니다",
        historyOutput: "출력",
        historyTimes: "회",

        clipboardTitle: "클립보드",
        clipboardNoItems: "클립보드가 비어있습니다",
        clipboardSendToNotes: "메모로 보내기",
        clipboardMakeCommand: "명령으로 만들기",

        alertExportSuccess: "내보내기 완료",
        alertExportFailed: "내보내기 실패",
        alertImportSuccess: "가져오기 완료",
        alertImportFailed: "가져오기 실패",
        alertInvalidFormat: "잘못된 형식",
        alertClipboardEmpty: "클립보드가 비어있음",
        alertCopiedToClipboard: "클립보드에 복사됨",
        alertMergeComplete: "병합 완료",
        alertOverwriteComplete: "덮어쓰기 완료",
        alertSaveFailed: "저장 실패",
        alertReadFailed: "파일 읽기 실패",

        importDialogTitle: "가져오기 방식",
        importMerge: "병합 (기존 데이터 유지)",
        importOverwrite: "덮어쓰기 (기존 데이터 삭제)",

        languagePackExportSuccess: "언어팩 견본이 저장되었습니다",
        languagePackImportSuccess: "언어팩을 적용했습니다",
        languagePackInvalidFormat: "잘못된 언어팩 형식입니다",

        scriptRunning: "실행 중...",
        scriptCompleted: "완료",
        scriptFailed: "실패",
        scriptOutput: "출력",

        secondsUnit: "초",
        minutesUnit: "분",
        hoursUnit: "시간",
        daysUnit: "일",
        manual: "수동",
        running: "실행 중",
        stopped: "정지",
        noOutput: "출력 없음",
        lastRun: "마지막 실행",
        nextRun: "다음 실행",
        interval: "간격",

        commandListTitle: "명령 목록",
        addNewItem: "새 항목 추가",
        dateTime: "날짜/시간",
        executionMethod: "실행 방식",
        commandInput: "명령어",
        commandHelpText: "예: echo {name} → 실행 시 name 입력",
        terminalAppLabel: "터미널 앱",
        intervalLabel: "주기 (초, 0이면 수동)",
        clipboardDetail: "클립보드 상세",
        addToTop: "맨 위에 등록",
        addToBottom: "맨 아래에 등록",
        notification: "알림",
        contextMenuRun: "실행",
        contextMenuEdit: "수정",
        contextMenuCopy: "복사",
        helpSyntax: "기본 문법",
        parameter: "파라미터",
        timeAfter: "후",
        timePassed: "지남",
        clipboardContent: "클립보드 내용"
    )

    static let english = LocalizedStrings(
        tabCommands: "Commands",
        tabHistory: "History",
        tabClipboard: "Clipboard",
        tabTrash: "Trash",
        tabSettings: "Settings",

        executionTerminal: "Terminal",
        executionBackground: "Background",
        executionScript: "Script",
        executionSchedule: "Schedule",

        alertDayBefore: "D-1",
        alertHourBefore: "1 hour",
        alertThirtyMinBefore: "30 min",
        alertFiveMinBefore: "5 min",
        alertNow: "Now!",
        alertPassed: "Passed",

        repeatNone: "None",
        repeatDaily: "Daily",
        repeatWeekly: "Weekly",
        repeatMonthly: "Monthly",

        historyExecuted: "Executed",
        historyBackground: "Background",
        historyScript: "Script",
        historyScheduleAlert: "Schedule Alert",
        historyReminder: "Reminder",
        historyAdded: "Added",
        historyDeleted: "Deleted",
        historyRestored: "Restored",
        historyPermanentlyDeleted: "Removed",

        buttonClose: "Close",
        buttonCancel: "Cancel",
        buttonConfirm: "OK",
        buttonSave: "Save",
        buttonDelete: "Delete",
        buttonRestore: "Restore",
        buttonAdd: "Add",
        buttonEdit: "Edit",
        buttonRun: "Run",
        buttonStop: "Stop",
        buttonCopy: "Copy",
        buttonClear: "Clear",
        buttonExport: "Export",
        buttonImport: "Import",

        settingsTitle: "Settings",
        settingsGeneral: "General",
        settingsHistoryTab: "History",
        settingsClipboardTab: "Clipboard",
        settingsBackup: "Backup",
        settingsLanguage: "Language",
        settingsAlwaysOnTop: "Always on Top",
        settingsLaunchAtLogin: "Launch at Login",
        settingsBackgroundOpacity: "Background Opacity",
        settingsMaxCount: "Max Count",
        settingsNotesFolderName: "Notes Folder",
        settingsExportFile: "Export File",
        settingsImportFile: "Import File",
        settingsBackupNote: "Only commands are backed up",
        settingsLanguagePack: "Language Pack",
        settingsExportLanguagePack: "Export Template",
        settingsImportLanguagePack: "Import Pack",

        trashTitle: "Trash",
        trashEmpty: "Empty",
        trashEmptyMessage: "Trash is empty",
        trashEmptyButton: "Empty",

        commandTitle: "Title",
        commandCommand: "Command",
        commandType: "Type",
        commandTerminalApp: "Terminal App",
        commandInterval: "Interval",
        commandScheduleDate: "Schedule",
        commandRepeat: "Repeat",
        commandReminders: "Reminders",
        commandAddNew: "Add Command",
        commandEditTitle: "Edit Command",
        commandNoCommands: "No commands",
        commandAddFirst: "Add your first command",

        parameterInputTitle: "Enter Parameters",
        parameterHelpTitle: "Parameter Help",
        parameterExample: "Example",
        parameterEnterValue: "Enter value",

        historyTitle: "History",
        historyNoHistory: "No history",
        historyOutput: "Output",
        historyTimes: "times",

        clipboardTitle: "Clipboard",
        clipboardNoItems: "Clipboard is empty",
        clipboardSendToNotes: "Send to Notes",
        clipboardMakeCommand: "Make Command",

        alertExportSuccess: "Export complete",
        alertExportFailed: "Export failed",
        alertImportSuccess: "Import complete",
        alertImportFailed: "Import failed",
        alertInvalidFormat: "Invalid format",
        alertClipboardEmpty: "Clipboard is empty",
        alertCopiedToClipboard: "Copied to clipboard",
        alertMergeComplete: "Merge complete",
        alertOverwriteComplete: "Overwrite complete",
        alertSaveFailed: "Save failed",
        alertReadFailed: "Failed to read file",

        importDialogTitle: "Import Method",
        importMerge: "Merge (keep existing)",
        importOverwrite: "Overwrite (delete existing)",

        languagePackExportSuccess: "Language pack template saved",
        languagePackImportSuccess: "Language pack applied",
        languagePackInvalidFormat: "Invalid language pack format",

        scriptRunning: "Running...",
        scriptCompleted: "Completed",
        scriptFailed: "Failed",
        scriptOutput: "Output",

        secondsUnit: "sec",
        minutesUnit: "min",
        hoursUnit: "hour",
        daysUnit: "day",
        manual: "Manual",
        running: "Running",
        stopped: "Stopped",
        noOutput: "No output",
        lastRun: "Last run",
        nextRun: "Next run",
        interval: "Interval",

        commandListTitle: "Command List",
        addNewItem: "Add New Item",
        dateTime: "Date/Time",
        executionMethod: "Execution Method",
        commandInput: "Command",
        commandHelpText: "Ex: echo {name} → enter name at runtime",
        terminalAppLabel: "Terminal App",
        intervalLabel: "Interval (sec, 0 for manual)",
        clipboardDetail: "Clipboard Detail",
        addToTop: "Add to Top",
        addToBottom: "Add to Bottom",
        notification: "Notification",
        contextMenuRun: "Run",
        contextMenuEdit: "Edit",
        contextMenuCopy: "Copy",
        helpSyntax: "Basic Syntax",
        parameter: "Parameter",
        timeAfter: "later",
        timePassed: "ago",
        clipboardContent: "Clipboard Content"
    )

    static let japanese = LocalizedStrings(
        tabCommands: "コマンド",
        tabHistory: "履歴",
        tabClipboard: "クリップボード",
        tabTrash: "ゴミ箱",
        tabSettings: "設定",

        executionTerminal: "ターミナル",
        executionBackground: "バックグラウンド",
        executionScript: "実行",
        executionSchedule: "スケジュール",

        alertDayBefore: "1日前",
        alertHourBefore: "1時間前",
        alertThirtyMinBefore: "30分前",
        alertFiveMinBefore: "5分前",
        alertNow: "今!",
        alertPassed: "経過",

        repeatNone: "なし",
        repeatDaily: "毎日",
        repeatWeekly: "毎週",
        repeatMonthly: "毎月",

        historyExecuted: "実行",
        historyBackground: "バックグラウンド",
        historyScript: "スクリプト",
        historyScheduleAlert: "スケジュール通知",
        historyReminder: "リマインダー",
        historyAdded: "追加",
        historyDeleted: "削除",
        historyRestored: "復元",
        historyPermanentlyDeleted: "完全削除",

        buttonClose: "閉じる",
        buttonCancel: "キャンセル",
        buttonConfirm: "確認",
        buttonSave: "保存",
        buttonDelete: "削除",
        buttonRestore: "復元",
        buttonAdd: "追加",
        buttonEdit: "編集",
        buttonRun: "実行",
        buttonStop: "停止",
        buttonCopy: "コピー",
        buttonClear: "クリア",
        buttonExport: "エクスポート",
        buttonImport: "インポート",

        settingsTitle: "設定",
        settingsGeneral: "一般",
        settingsHistoryTab: "履歴",
        settingsClipboardTab: "クリップボード",
        settingsBackup: "バックアップ",
        settingsLanguage: "言語",
        settingsAlwaysOnTop: "常に最前面",
        settingsLaunchAtLogin: "ログイン時に起動",
        settingsBackgroundOpacity: "背景の透明度",
        settingsMaxCount: "最大件数",
        settingsNotesFolderName: "メモフォルダ名",
        settingsExportFile: "ファイル出力",
        settingsImportFile: "ファイル読込",
        settingsBackupNote: "コマンドのみバックアップされます",
        settingsLanguagePack: "言語パック",
        settingsExportLanguagePack: "テンプレート出力",
        settingsImportLanguagePack: "パック読込",

        trashTitle: "ゴミ箱",
        trashEmpty: "空にする",
        trashEmptyMessage: "ゴミ箱は空です",
        trashEmptyButton: "空にする",

        commandTitle: "タイトル",
        commandCommand: "コマンド",
        commandType: "タイプ",
        commandTerminalApp: "ターミナルアプリ",
        commandInterval: "実行間隔",
        commandScheduleDate: "スケジュール",
        commandRepeat: "繰り返し",
        commandReminders: "リマインダー",
        commandAddNew: "コマンド追加",
        commandEditTitle: "コマンド編集",
        commandNoCommands: "コマンドがありません",
        commandAddFirst: "最初のコマンドを追加してください",

        parameterInputTitle: "パラメータ入力",
        parameterHelpTitle: "パラメータヘルプ",
        parameterExample: "例",
        parameterEnterValue: "値を入力",

        historyTitle: "履歴",
        historyNoHistory: "履歴がありません",
        historyOutput: "出力",
        historyTimes: "回",

        clipboardTitle: "クリップボード",
        clipboardNoItems: "クリップボードは空です",
        clipboardSendToNotes: "メモに送信",
        clipboardMakeCommand: "コマンドにする",

        alertExportSuccess: "エクスポート完了",
        alertExportFailed: "エクスポート失敗",
        alertImportSuccess: "インポート完了",
        alertImportFailed: "インポート失敗",
        alertInvalidFormat: "無効な形式",
        alertClipboardEmpty: "クリップボードが空です",
        alertCopiedToClipboard: "クリップボードにコピー",
        alertMergeComplete: "マージ完了",
        alertOverwriteComplete: "上書き完了",
        alertSaveFailed: "保存失敗",
        alertReadFailed: "ファイル読み込み失敗",

        importDialogTitle: "インポート方法",
        importMerge: "マージ（既存を維持）",
        importOverwrite: "上書き（既存を削除）",

        languagePackExportSuccess: "言語パックテンプレートを保存しました",
        languagePackImportSuccess: "言語パックを適用しました",
        languagePackInvalidFormat: "無効な言語パック形式です",

        scriptRunning: "実行中...",
        scriptCompleted: "完了",
        scriptFailed: "失敗",
        scriptOutput: "出力",

        secondsUnit: "秒",
        minutesUnit: "分",
        hoursUnit: "時間",
        daysUnit: "日",
        manual: "手動",
        running: "実行中",
        stopped: "停止",
        noOutput: "出力なし",
        lastRun: "最終実行",
        nextRun: "次回実行",
        interval: "間隔",

        commandListTitle: "コマンド一覧",
        addNewItem: "新規追加",
        dateTime: "日時",
        executionMethod: "実行方法",
        commandInput: "コマンド",
        commandHelpText: "例: echo {name} → 実行時にname入力",
        terminalAppLabel: "ターミナルアプリ",
        intervalLabel: "間隔（秒、0は手動）",
        clipboardDetail: "クリップボード詳細",
        addToTop: "先頭に追加",
        addToBottom: "末尾に追加",
        notification: "通知",
        contextMenuRun: "実行",
        contextMenuEdit: "編集",
        contextMenuCopy: "コピー",
        helpSyntax: "基本文法",
        parameter: "パラメータ",
        timeAfter: "後",
        timePassed: "経過",
        clipboardContent: "クリップボード内容"
    )

    static func forLanguage(_ language: Language) -> LocalizedStrings {
        switch language {
        case .korean: return .korean
        case .english: return .english
        case .japanese: return .japanese
        }
    }
}

// 언어팩 내보내기/가져오기용 구조체
struct LanguagePackExport: Codable {
    let version: Int
    let languageCode: String
    let languageName: String
    let strings: LocalizedStrings

    init(languageCode: String, languageName: String, strings: LocalizedStrings) {
        self.version = 1
        self.languageCode = languageCode
        self.languageName = languageName
        self.strings = strings
    }
}

// 전역 언어 매니저
class LanguageManager: ObservableObject {
    static let shared = LanguageManager()

    @Published var currentLanguage: Language {
        didSet {
            UserDefaults.standard.set(currentLanguage.rawValue, forKey: "appLanguage")
            loadStrings()
        }
    }

    @Published var strings: LocalizedStrings

    private let customStringsKey = "customLanguageStrings"

    private init() {
        let savedLanguage = UserDefaults.standard.string(forKey: "appLanguage") ?? "ko"
        self.currentLanguage = Language(rawValue: savedLanguage) ?? .korean
        self.strings = .korean
        loadStrings()
    }

    private func loadStrings() {
        // 먼저 커스텀 언어팩이 있는지 확인
        if let customData = UserDefaults.standard.data(forKey: customStringsKey),
           let customStrings = try? JSONDecoder().decode(LocalizedStrings.self, from: customData) {
            strings = customStrings
        } else {
            strings = LocalizedStrings.forLanguage(currentLanguage)
        }
    }

    func importLanguagePack(from data: Data) -> Bool {
        guard let pack = try? JSONDecoder().decode(LanguagePackExport.self, from: data) else {
            return false
        }

        // 커스텀 언어팩 저장
        if let encoded = try? JSONEncoder().encode(pack.strings) {
            UserDefaults.standard.set(encoded, forKey: customStringsKey)
            strings = pack.strings
            return true
        }
        return false
    }

    func exportLanguagePackTemplate() -> Data? {
        let pack = LanguagePackExport(
            languageCode: "custom",
            languageName: "Custom Language",
            strings: strings
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try? encoder.encode(pack)
    }

    func resetToBuiltIn() {
        UserDefaults.standard.removeObject(forKey: customStringsKey)
        strings = LocalizedStrings.forLanguage(currentLanguage)
    }

    var hasCustomPack: Bool {
        UserDefaults.standard.data(forKey: customStringsKey) != nil
    }
}

// 편의를 위한 전역 접근자
var L: LocalizedStrings { LanguageManager.shared.strings }

// 클립보드 아이템
struct ClipboardItem: Identifiable, Codable {
    let id: UUID
    let content: String
    let timestamp: Date

    init(content: String) {
        self.id = UUID()
        self.content = content
        self.timestamp = Date()
    }

    var preview: String {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count > 100 {
            return String(trimmed.prefix(100)) + "..."
        }
        return trimmed
    }
}

struct HoverButtonStyle: ButtonStyle {
    @State private var isHovering = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isHovering ? Color.primary.opacity(0.1) : Color.clear)
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .onHover { hovering in
                isHovering = hovering
            }
    }
}

struct SmallHoverButtonStyle: ButtonStyle {
    @State private var isHovering = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(3)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(isHovering ? Color.primary.opacity(0.1) : Color.clear)
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .onHover { hovering in
                isHovering = hovering
            }
    }
}

struct HoverTextButtonStyle: ButtonStyle {
    @State private var isHovering = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isHovering ? Color.primary.opacity(0.15) : Color.primary.opacity(0.06))
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .onHover { hovering in
                isHovering = hovering
            }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        for window in NSApp.windows {
            window.standardWindowButton(.zoomButton)?.isHidden = true
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            for window in NSApp.windows {
                window.makeKeyAndOrderFront(self)
            }
        }
        return true
    }
}

enum ExecutionType: String, Codable, CaseIterable {
    case terminal = "terminal"
    case background = "background"
    case script = "script"
    case schedule = "schedule"

    var displayName: String {
        switch self {
        case .terminal: return L.executionTerminal
        case .background: return L.executionBackground
        case .script: return L.executionScript
        case .schedule: return L.executionSchedule
        }
    }
}

enum TerminalApp: String, Codable, CaseIterable {
    case iterm2 = "iTerm2"
    case terminal = "Terminal"
}

enum AlertState: String, Codable {
    case none = ""
    case dayBefore = "dayBefore"
    case hourBefore = "hourBefore"
    case thirtyMinBefore = "thirtyMinBefore"
    case fiveMinBefore = "fiveMinBefore"
    case now = "now"
    case passed = "passed"

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
    case none = "none"
    case daily = "daily"
    case weekly = "weekly"
    case monthly = "monthly"

    var displayName: String {
        switch self {
        case .none: return L.repeatNone
        case .daily: return L.repeatDaily
        case .weekly: return L.repeatWeekly
        case .monthly: return L.repeatMonthly
        }
    }
}

struct Command: Identifiable, Codable {
    var id = UUID()
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

// 히스토리 아이템
enum HistoryType: String, Codable {
    case executed = "executed"
    case background = "background"
    case script = "script"
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
        case .scheduleAlert: return L.historyScheduleAlert
        case .reminder: return L.historyReminder
        case .added: return L.historyAdded
        case .deleted: return L.historyDeleted
        case .restored: return L.historyRestored
        case .permanentlyDeleted: return L.historyPermanentlyDeleted
        }
    }
}

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
}

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

class Settings: ObservableObject {
    @Published var alwaysOnTop: Bool {
        didSet {
            UserDefaults.standard.set(alwaysOnTop, forKey: "alwaysOnTop")
            applyAlwaysOnTop()
        }
    }
    @Published var maxHistoryCount: Int {
        didSet {
            UserDefaults.standard.set(maxHistoryCount, forKey: "maxHistoryCount")
        }
    }
    @Published var launchAtLogin: Bool {
        didSet {
            UserDefaults.standard.set(launchAtLogin, forKey: "launchAtLogin")
            applyLaunchAtLogin()
        }
    }
    @Published var backgroundOpacity: Double {
        didSet {
            UserDefaults.standard.set(backgroundOpacity, forKey: "backgroundOpacity")
            applyBackgroundOpacity()
        }
    }
    @Published var notesFolderName: String {
        didSet {
            UserDefaults.standard.set(notesFolderName, forKey: "notesFolderName")
        }
    }
    @Published var maxClipboardCount: Int {
        didSet {
            UserDefaults.standard.set(maxClipboardCount, forKey: "maxClipboardCount")
        }
    }

    init() {
        self.alwaysOnTop = UserDefaults.standard.bool(forKey: "alwaysOnTop")
        let saved = UserDefaults.standard.integer(forKey: "maxHistoryCount")
        self.maxHistoryCount = saved > 0 ? saved : 100
        self.launchAtLogin = UserDefaults.standard.bool(forKey: "launchAtLogin")
        let savedOpacity = UserDefaults.standard.double(forKey: "backgroundOpacity")
        self.backgroundOpacity = savedOpacity > 0 ? savedOpacity : 1.0
        self.notesFolderName = UserDefaults.standard.string(forKey: "notesFolderName") ?? "클립보드 메모"
        let savedClipboardCount = UserDefaults.standard.integer(forKey: "maxClipboardCount")
        self.maxClipboardCount = savedClipboardCount > 0 ? savedClipboardCount : 10000
    }

    func applyAlwaysOnTop() {
        DispatchQueue.main.async {
            for window in NSApp.windows {
                window.level = self.alwaysOnTop ? .floating : .normal
            }
        }
    }

    func applyLaunchAtLogin() {
        do {
            if launchAtLogin {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            print("Failed to set launch at login: \(error)")
        }
    }

    func applyBackgroundOpacity() {
        DispatchQueue.main.async {
            for window in NSApp.windows where window.canBecomeMain {
                window.isOpaque = self.backgroundOpacity >= 1.0
                window.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(self.backgroundOpacity)
            }
        }
    }
}

class CommandStore: ObservableObject {
    @Published var commands: [Command] = []
    @Published var alertingCommandId: UUID?  // 현재 알림 중인 명령
    @Published var history: [HistoryItem] = []
    @Published var clipboardItems: [ClipboardItem] = []
    private var timers: [UUID: Timer] = [:]
    private var scheduleCheckTimer: Timer?
    private var clipboardTimer: Timer?
    private var lastClipboardChangeCount: Int = 0

    private let configDir = URL(fileURLWithPath: NSHomeDirectory())
        .appendingPathComponent(".command_bar")
    private var url: URL { configDir.appendingPathComponent("app.json") }
    private var historyUrl: URL { configDir.appendingPathComponent("history.json") }
    private var clipboardUrl: URL { configDir.appendingPathComponent("clipboard.json") }

    init() {
        ensureConfigDir()
        migrateOldFiles()
        load()
        loadHistory()
        loadClipboard()
        startTimers()
        startScheduleChecker()
        startClipboardMonitor()
    }

    private func ensureConfigDir() {
        try? FileManager.default.createDirectory(at: configDir, withIntermediateDirectories: true)
    }

    private func migrateOldFiles() {
        let oldApp = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(".command_bar_app")
        let oldHistory = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(".command_bar_history")

        if FileManager.default.fileExists(atPath: oldApp.path) && !FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.moveItem(at: oldApp, to: url)
        }
        if FileManager.default.fileExists(atPath: oldHistory.path) && !FileManager.default.fileExists(atPath: historyUrl.path) {
            try? FileManager.default.moveItem(at: oldHistory, to: historyUrl)
        }
    }

    func addHistory(_ item: HistoryItem) {
        // 지금! 알림은 같은 명령 ID면 병합
        if item.type == .scheduleAlert, let cmdId = item.commandId {
            if let index = history.firstIndex(where: { $0.type == .scheduleAlert && $0.commandId == cmdId }) {
                var existing = history.remove(at: index)
                existing.count += 1
                existing.endTimestamp = item.timestamp
                history.insert(existing, at: 0)
                saveHistory()
                return
            }
        }

        history.insert(item, at: 0)
        let maxCount = UserDefaults.standard.integer(forKey: "maxHistoryCount")
        let limit = maxCount > 0 ? maxCount : 100
        if history.count > limit {
            history = Array(history.prefix(limit))
        }
        saveHistory()
    }

    func loadHistory() {
        guard let data = try? Data(contentsOf: historyUrl),
              let decoded = try? JSONDecoder().decode([HistoryItem].self, from: data) else { return }
        history = decoded
    }

    func saveHistory() {
        guard let data = try? JSONEncoder().encode(history) else { return }
        try? data.write(to: historyUrl)
    }

    func clearHistory() {
        history.removeAll()
        saveHistory()
    }

    // 클립보드 관련
    func loadClipboard() {
        guard let data = try? Data(contentsOf: clipboardUrl),
              let decoded = try? JSONDecoder().decode([ClipboardItem].self, from: data) else { return }
        clipboardItems = decoded
    }

    func saveClipboard() {
        guard let data = try? JSONEncoder().encode(clipboardItems) else { return }
        try? data.write(to: clipboardUrl)
    }

    func startClipboardMonitor() {
        lastClipboardChangeCount = NSPasteboard.general.changeCount
        clipboardTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.checkClipboard()
        }
    }

    private func checkClipboard() {
        let pasteboard = NSPasteboard.general
        let currentCount = pasteboard.changeCount
        guard currentCount != lastClipboardChangeCount else { return }
        lastClipboardChangeCount = currentCount

        guard let content = pasteboard.string(forType: .string),
              !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        // 중복 체크 (마지막 아이템과 같으면 무시)
        if let last = clipboardItems.first, last.content == content { return }

        clipboardItems.insert(ClipboardItem(content: content), at: 0)

        // 최대 개수 제한
        let maxCount = UserDefaults.standard.integer(forKey: "maxClipboardCount")
        let limit = maxCount > 0 ? maxCount : 10000
        if clipboardItems.count > limit {
            clipboardItems = Array(clipboardItems.prefix(limit))
        }

        saveClipboard()
    }

    func removeClipboardItem(_ item: ClipboardItem) {
        clipboardItems.removeAll { $0.id == item.id }
        saveClipboard()
    }

    func clearClipboard() {
        clipboardItems.removeAll()
        saveClipboard()
    }

    func registerClipboardAsCommand(_ item: ClipboardItem, asLast: Bool = true) {
        let firstLine = item.content.components(separatedBy: .newlines).first ?? item.content
        let title = String(firstLine.prefix(50))
        let cmd = Command(
            title: title,
            command: item.content,
            executionType: .terminal,
            terminalApp: .iterm2
        )
        if asLast {
            commands.append(cmd)
        } else {
            commands.insert(cmd, at: 0)
        }
        removeClipboardItem(item)
        save()
    }

    func sendToNotes(_ item: ClipboardItem, folderName: String) {
        let escaped = item.content
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let script = """
        tell application "Notes"
            activate
            set folderName to "\(folderName)"
            set theAccount to first account
            if not (exists folder folderName of theAccount) then
                make new folder at theAccount with properties {name:folderName}
            end if
            set targetFolder to folder folderName of theAccount
            set newNote to make new note at targetFolder with properties {body:"\(escaped)"}
            show newNote
        end tell
        """
        var error: NSDictionary?
        NSAppleScript(source: script)?.executeAndReturnError(&error)
        removeClipboardItem(item)
    }

    func startScheduleChecker() {
        scheduleCheckTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.checkSchedules()
        }
    }

    func checkSchedules() {
        let now = Date()
        for i in commands.indices where commands[i].executionType == .schedule {
            guard let date = commands[i].scheduleDate else { continue }

            let diff = date.timeIntervalSince(now)

            // 휴지통에 있으면 무시
            if commands[i].isInTrash { continue }

            // "지금!" 상태이고 아직 확인 안했으면 5초마다 알림
            if diff <= 0 && !commands[i].acknowledged {
                commands[i].alertedTimes.insert(0)
                commands[i].alertState = .now
                // 5초마다 알림 (현재 시간의 초가 5로 나눠떨어지면)
                let seconds = Int(now.timeIntervalSince1970) % 5
                if seconds == 0 {
                    triggerAlert(for: commands[i])
                    // 히스토리 기록
                    addHistory(HistoryItem(
                        timestamp: Date(),
                        title: commands[i].title,
                        command: "지금!",
                        type: .scheduleAlert,
                        output: nil,
                        commandId: commands[i].id
                    ))
                }
                continue
            }

            // 미리 알림 시간 체크
            for reminderTime in commands[i].reminderTimes.sorted().reversed() {
                if diff <= Double(reminderTime) + 30 && diff > Double(reminderTime) - 30 {
                    // 이 알림 시간에 해당하고 아직 알림 안 줬으면
                    if !commands[i].alertedTimes.contains(reminderTime) {
                        commands[i].alertedTimes.insert(reminderTime)
                        save()
                        commands[i].alertState = alertStateFor(seconds: reminderTime)
                        triggerAlert(for: commands[i])
                        // 히스토리 기록
                        addHistory(HistoryItem(
                            timestamp: Date(),
                            title: commands[i].title,
                            command: alertStateFor(seconds: reminderTime).rawValue,
                            type: .reminder,
                            output: nil,
                            commandId: commands[i].id
                        ))
                    }
                    break
                }
            }

            // 현재 상태 표시 업데이트
            if diff <= 0 {
                commands[i].alertState = .now
            } else {
                for reminderTime in commands[i].reminderTimes.sorted() {
                    if diff <= Double(reminderTime) {
                        commands[i].alertState = alertStateFor(seconds: reminderTime)
                        break
                    }
                }
            }
        }
    }

    func alertStateFor(seconds: Int) -> AlertState {
        switch seconds {
        case 0: return .now
        case 300: return .fiveMinBefore
        case 1800: return .thirtyMinBefore
        case 3600: return .hourBefore
        case 86400: return .dayBefore
        default: return .none
        }
    }

    func triggerAlert(for cmd: Command) {
        DispatchQueue.main.async {
            // 강조 표시만 (포커스 이동 안 함)
            self.alertingCommandId = cmd.id
            // 3초 후 강조 해제
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                if self.alertingCommandId == cmd.id {
                    self.alertingCommandId = nil
                }
            }
        }
    }

    func startTimers() {
        for cmd in commands where cmd.executionType == .background && cmd.interval > 0 && !cmd.isInTrash {
            startTimer(for: cmd)
        }
    }

    func startTimer(for cmd: Command) {
        stopTimer(for: cmd.id)
        guard cmd.interval > 0 else { return }

        // 마지막 실행 시간 기준으로 남은 시간 계산
        let now = Date()
        var initialDelay: TimeInterval = 0

        if let lastRun = cmd.lastExecutedAt {
            let elapsed = now.timeIntervalSince(lastRun)
            let remaining = TimeInterval(cmd.interval) - elapsed
            if remaining > 0 {
                initialDelay = remaining
            }
        }

        if initialDelay > 0 {
            // 남은 시간 후에 첫 실행
            DispatchQueue.main.asyncAfter(deadline: .now() + initialDelay) { [weak self] in
                guard let self = self else { return }
                self.runInBackground(cmd)
                let timer = Timer.scheduledTimer(withTimeInterval: TimeInterval(cmd.interval), repeats: true) { [weak self] _ in
                    self?.runInBackground(cmd)
                }
                self.timers[cmd.id] = timer
            }
        } else {
            // 즉시 실행 + 타이머 시작
            runInBackground(cmd)
            let timer = Timer.scheduledTimer(withTimeInterval: TimeInterval(cmd.interval), repeats: true) { [weak self] _ in
                self?.runInBackground(cmd)
            }
            timers[cmd.id] = timer
        }
    }

    func stopTimer(for id: UUID) {
        timers[id]?.invalidate()
        timers.removeValue(forKey: id)
    }

    func stopAllTimers() {
        for timer in timers.values {
            timer.invalidate()
        }
        timers.removeAll()
    }

    func load() {
        guard let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([Command].self, from: data) else { return }
        commands = decoded
    }

    func save() {
        guard let data = try? JSONEncoder().encode(commands) else { return }
        try? data.write(to: url)
    }

    // 스마트 따옴표를 일반 따옴표로 변환
    func normalizeQuotes(_ text: String) -> String {
        text.replacingOccurrences(of: "\u{201C}", with: "\"")  // "
            .replacingOccurrences(of: "\u{201D}", with: "\"")  // "
            .replacingOccurrences(of: "\u{2018}", with: "'")   // '
            .replacingOccurrences(of: "\u{2019}", with: "'")   // '
    }

    func add(_ cmd: Command) {
        var newCmd = cmd
        newCmd.command = normalizeQuotes(cmd.command)
        commands.append(newCmd)
        save()
        if cmd.executionType == .background && cmd.interval > 0 {
            startTimer(for: cmd)
        }
        addHistory(HistoryItem(
            timestamp: Date(),
            title: cmd.title,
            command: cmd.command,
            type: .added,
            output: nil
        ))
    }

    func duplicate(_ cmd: Command) {
        var newCmd = cmd
        newCmd.id = UUID()
        newCmd.title = cmd.title + " (복사)"
        newCmd.isRunning = false
        newCmd.lastOutput = nil
        newCmd.alertState = .none
        newCmd.alertedTimes = []
        newCmd.acknowledged = false

        if let index = commands.firstIndex(where: { $0.id == cmd.id }) {
            commands.insert(newCmd, at: index + 1)
        } else {
            commands.append(newCmd)
        }
        save()
    }

    func moveToTrash(at offsets: IndexSet) {
        for i in offsets {
            stopTimer(for: commands[i].id)
            addHistory(HistoryItem(
                timestamp: Date(),
                title: commands[i].title,
                command: commands[i].command,
                type: .deleted,
                output: nil
            ))
            commands[i].isInTrash = true
        }
        save()
    }

    func moveToTrash(_ cmd: Command) {
        if let i = commands.firstIndex(where: { $0.id == cmd.id }) {
            stopTimer(for: cmd.id)
            commands[i].isInTrash = true
            save()
            addHistory(HistoryItem(
                timestamp: Date(),
                title: cmd.title,
                command: cmd.command,
                type: .deleted,
                output: nil
            ))
        }
    }

    func restoreFromTrash(_ cmd: Command) {
        if let i = commands.firstIndex(where: { $0.id == cmd.id }) {
            commands[i].isInTrash = false
            save()
            if commands[i].executionType == .background && commands[i].interval > 0 {
                startTimer(for: commands[i])
            }
            addHistory(HistoryItem(
                timestamp: Date(),
                title: cmd.title,
                command: cmd.command,
                type: .restored,
                output: nil
            ))
        }
    }

    func deletePermanently(_ cmd: Command) {
        stopTimer(for: cmd.id)
        addHistory(HistoryItem(
            timestamp: Date(),
            title: cmd.title,
            command: cmd.command,
            type: .permanentlyDeleted,
            output: nil
        ))
        commands.removeAll { $0.id == cmd.id }
        save()
    }

    func emptyTrash() {
        commands.removeAll { $0.isInTrash }
        save()
    }

    var trashItems: [Command] {
        commands.filter { $0.isInTrash }
    }

    var activeItems: [Command] {
        commands.filter { !$0.isInTrash }
    }

    func move(from source: IndexSet, to destination: Int) {
        commands.move(fromOffsets: source, toOffset: destination)
        save()
    }

    func update(_ cmd: Command) {
        if let i = commands.firstIndex(where: { $0.id == cmd.id }) {
            stopTimer(for: cmd.id)
            var updated = cmd
            updated.command = normalizeQuotes(cmd.command)
            commands[i] = updated
            commands[i].alertedTimes = []  // 알림 상태 초기화
            commands[i].alertState = .none
            commands[i].acknowledged = false
            save()
            if cmd.executionType == .background && cmd.interval > 0 {
                startTimer(for: cmd)
            }
        }
    }

    func acknowledge(_ cmd: Command) {
        if let i = commands.firstIndex(where: { $0.id == cmd.id }) {
            alertingCommandId = nil

            if commands[i].repeatType != .none, let currentDate = commands[i].scheduleDate {
                // 반복 일정: 다음 알림 시간으로 리셋
                let nextDate: Date
                switch commands[i].repeatType {
                case .daily:
                    nextDate = Calendar.current.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
                case .weekly:
                    nextDate = Calendar.current.date(byAdding: .weekOfYear, value: 1, to: currentDate) ?? currentDate
                case .monthly:
                    nextDate = Calendar.current.date(byAdding: .month, value: 1, to: currentDate) ?? currentDate
                case .none:
                    nextDate = currentDate
                }
                commands[i].scheduleDate = nextDate
                commands[i].alertState = .none
                commands[i].acknowledged = false
                commands[i].alertedTimes = []
                commands[i].historyLoggedTimes = []
            } else {
                // 일회성: 확인 상태로
                commands[i].acknowledged = true
            }
            save()
        }
    }

    func run(_ cmd: Command) {
        switch cmd.executionType {
        case .terminal:
            let app = cmd.terminalApp == .iterm2 ? "iTerm" : "Terminal"
            runInTerminal(cmd, app: app)
        case .background:
            runInBackground(cmd)
        case .script:
            break  // 스크립트는 ContentView에서 처리
        case .schedule:
            break  // 일정은 수동 실행 없음
        }
    }

    private func runInTerminal(_ cmd: Command, app: String) {
        let escaped = cmd.command.replacingOccurrences(of: "\"", with: "\\\"")
        let script: String

        if app == "iTerm" {
            script = """
            tell application "iTerm"
                activate
                if (count of windows) = 0 then
                    create window with default profile
                end if
                tell current session of current window
                    write text "\(escaped)"
                end tell
            end tell
            """
        } else {
            script = """
            tell application "Terminal"
                activate
                if (count of windows) = 0 then
                    do script "\(escaped)"
                else
                    do script "\(escaped)" in front window
                end if
            end tell
            """
        }

        var error: NSDictionary?
        let result = NSAppleScript(source: script)?.executeAndReturnError(&error)

        // 히스토리 기록
        let output: String?
        if let error = error {
            output = error[NSAppleScript.errorMessage] as? String ?? "Error"
        } else {
            output = result?.stringValue ?? "OK"
        }
        addHistory(HistoryItem(
            timestamp: Date(),
            title: cmd.title,
            command: cmd.command,
            type: .executed,
            output: output
        ))
    }

    private func runInBackground(_ cmd: Command) {
        guard let index = commands.firstIndex(where: { $0.id == cmd.id }) else { return }

        commands[index].isRunning = true
        commands[index].lastOutput = nil
        commands[index].lastExecutedAt = Date()

        DispatchQueue.global(qos: .userInitiated).async {
            let process = Process()
            let pipe = Pipe()

            process.executableURL = URL(fileURLWithPath: "/bin/zsh")
            process.arguments = ["-c", cmd.command]
            process.standardOutput = pipe
            process.standardError = pipe

            do {
                try process.run()
                process.waitUntilExit()

                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

                DispatchQueue.main.async {
                    if let i = self.commands.firstIndex(where: { $0.id == cmd.id }) {
                        self.commands[i].lastOutput = output
                        self.commands[i].isRunning = false
                        self.save()
                    }
                    // 히스토리 기록
                    self.addHistory(HistoryItem(
                        timestamp: Date(),
                        title: cmd.title,
                        command: cmd.command,
                        type: .background,
                        output: output
                    ))
                }
            } catch {
                DispatchQueue.main.async {
                    let errorMsg = "Error: \(error.localizedDescription)"
                    if let i = self.commands.firstIndex(where: { $0.id == cmd.id }) {
                        self.commands[i].lastOutput = errorMsg
                        self.commands[i].isRunning = false
                    }
                    // 히스토리 기록
                    self.addHistory(HistoryItem(
                        timestamp: Date(),
                        title: cmd.title,
                        command: cmd.command,
                        type: .background,
                        output: errorMsg
                    ))
                }
            }
        }
    }

    // MARK: - 임포트/익스포트

    func exportData(settings: Settings) -> Data? {
        let exportSettings = ExportSettings(alwaysOnTop: settings.alwaysOnTop)
        let exportData = ExportData(
            version: 1,
            exportedAt: Date(),
            settings: exportSettings,
            commands: commands.filter { !$0.isInTrash }
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try? encoder.encode(exportData)
    }

    func importData(_ data: Data, settings: Settings, merge: Bool) -> Bool {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let imported = try? decoder.decode(ExportData.self, from: data) else {
            return false
        }

        // 설정 적용
        settings.alwaysOnTop = imported.settings.alwaysOnTop

        if merge {
            // 병합: 기존 ID와 겹치면 새 ID 부여
            let existingIds = Set(commands.map { $0.id })
            for var cmd in imported.commands {
                if existingIds.contains(cmd.id) {
                    cmd.id = UUID()
                }
                // 런타임 상태 초기화
                cmd.isRunning = false
                cmd.alertedTimes = []
                cmd.acknowledged = false
                commands.append(cmd)
            }
        } else {
            // 덮어쓰기: 기존 데이터 삭제
            for cmd in commands {
                stopTimer(for: cmd.id)
            }
            commands = imported.commands.map { cmd in
                var c = cmd
                c.isRunning = false
                c.alertedTimes = []
                c.acknowledged = false
                return c
            }
        }

        save()
        startTimers()
        return true
    }
}

struct ContentView: View {
    @StateObject private var store = CommandStore()
    @StateObject private var settings = Settings()
    @State private var showAddSheet = false
    @State private var showSettings = false
    @State private var showingTrash = false
    @State private var showingHistory = false
    @State private var showingClipboard = false
    @State private var editingCommand: Command?
    @State private var selectedId: UUID?
    @State private var draggingItem: Command?
    @State private var selectedHistoryItem: HistoryItem?
    @State private var selectedClipboardItem: ClipboardItem?

    var hasActiveIndicator: Bool {
        store.activeItems.contains { cmd in
            cmd.isRunning || store.alertingCommandId == cmd.id
        }
    }

    var body: some View {
        VStack(spacing: 0) {

            if showingHistory {
                // 히스토리 보기
                HStack {
                    Text(L.tabHistory)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    if !store.history.isEmpty {
                        Button(L.buttonClear) {
                            store.clearHistory()
                        }
                        .font(.caption)
                        .buttonStyle(HoverButtonStyle())
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                Divider()
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(store.history) { item in
                            HStack {
                                Image(systemName: historyTypeIcon(item.type))
                                    .foregroundStyle(historyTypeColor(item.type))
                                    .frame(width: 14)
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 4) {
                                        Text(item.title)
                                            .fontWeight(.medium)
                                        if item.count > 1 {
                                            Text("(\(item.count)회)")
                                                .font(.caption)
                                                .foregroundStyle(.orange)
                                        }
                                    }
                                    if let endTime = item.endTimestamp, item.count > 1 {
                                        Text("\(item.timestamp, format: .dateTime.hour().minute()) ~ \(endTime, format: .dateTime.hour().minute().second())")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    } else {
                                        Text(item.timestamp, format: .dateTime.month().day().hour().minute().second())
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                if item.output != nil {
                                    Button(action: {
                                        HistoryDetailWindowController.show(item: item)
                                    }) {
                                        Image(systemName: "doc.text.magnifyingglass")
                                    }
                                    .buttonStyle(SmallHoverButtonStyle())
                                }
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.gray.opacity(0.1))
                            )
                        }
                    }
                    .padding(8)
                }
                .background(Color.clear)
                .overlay {
                    if store.history.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "clock")
                                .font(.title2)
                                .foregroundStyle(.secondary)
                            Text(L.historyNoHistory)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            } else if showingClipboard {
                // 클립보드 보기
                HStack {
                    Text(L.tabClipboard)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    if !store.clipboardItems.isEmpty {
                        Button(L.buttonClear) {
                            store.clearClipboard()
                        }
                        .font(.caption)
                        .buttonStyle(HoverButtonStyle())
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                Divider()
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(store.clipboardItems) { item in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.preview)
                                        .lineLimit(2)
                                    Text(item.timestamp, format: .dateTime.month().day().hour().minute().second())
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Button(action: {
                                    ClipboardDetailWindowController.show(item: item, store: store, notesFolderName: settings.notesFolderName)
                                }) {
                                    Image(systemName: "doc.text.magnifyingglass")
                                }
                                .buttonStyle(SmallHoverButtonStyle())
                                Button(action: {
                                    store.registerClipboardAsCommand(item, asLast: false)
                                }) {
                                    Image(systemName: "arrow.up.doc")
                                }
                                .buttonStyle(SmallHoverButtonStyle())
                                .help(L.addToTop)
                                Button(action: {
                                    store.registerClipboardAsCommand(item, asLast: true)
                                }) {
                                    Image(systemName: "arrow.down.doc")
                                }
                                .buttonStyle(SmallHoverButtonStyle())
                                .help(L.addToBottom)
                                Button(action: {
                                    store.sendToNotes(item, folderName: settings.notesFolderName)
                                }) {
                                    Image(systemName: "note.text")
                                }
                                .buttonStyle(SmallHoverButtonStyle())
                                .help(L.clipboardSendToNotes)
                                Button(action: {
                                    store.removeClipboardItem(item)
                                }) {
                                    Image(systemName: "trash")
                                        .foregroundStyle(.red)
                                }
                                .buttonStyle(SmallHoverButtonStyle())
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.gray.opacity(0.1))
                            )
                        }
                    }
                    .padding(8)
                }
                .background(Color.clear)
                .overlay {
                    if store.clipboardItems.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "doc.on.clipboard")
                                .font(.title2)
                                .foregroundStyle(.secondary)
                            Text(L.clipboardNoItems)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            } else if showingTrash {
                // 휴지통 보기
                HStack {
                    Text(L.tabTrash)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    if !store.trashItems.isEmpty {
                        Button(L.trashEmpty) {
                            store.emptyTrash()
                        }
                        .font(.caption)
                        .buttonStyle(HoverButtonStyle())
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                Divider()
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(store.trashItems) { cmd in
                            HStack {
                                Image(systemName: trashItemIcon(cmd))
                                    .foregroundStyle(trashItemColor(cmd))
                                    .frame(width: 14)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(cmd.title)
                                    if cmd.executionType == .schedule {
                                        if let date = cmd.scheduleDate {
                                            Text(date, format: .dateTime.month().day().hour().minute())
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    } else {
                                        Text(cmd.command)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                    }
                                }
                                Spacer()
                                Button(action: {
                                    editingCommand = cmd
                                }) {
                                    Image(systemName: "pencil")
                                }
                                .buttonStyle(SmallHoverButtonStyle())
                                Button(action: {
                                    store.restoreFromTrash(cmd)
                                }) {
                                    Image(systemName: "arrow.uturn.backward")
                                        .foregroundStyle(.blue)
                                }
                                .buttonStyle(SmallHoverButtonStyle())
                                Button(action: {
                                    store.deletePermanently(cmd)
                                }) {
                                    Image(systemName: "xmark")
                                        .foregroundStyle(.red)
                                }
                                .buttonStyle(SmallHoverButtonStyle())
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.gray.opacity(0.1))
                            )
                        }
                    }
                    .padding(8)
                }
                .background(Color.clear)
                .overlay {
                    if store.trashItems.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "trash")
                                .font(.title2)
                                .foregroundStyle(.secondary)
                            Text(L.trashEmptyMessage)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            } else {
                // 일반 리스트
                HStack {
                    Text(L.commandListTitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(store.activeItems.count)")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                Divider()
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(store.activeItems) { cmd in
                            CommandRowView(
                                cmd: cmd,
                                isSelected: selectedId == cmd.id,
                                isDragging: draggingItem?.id == cmd.id,
                                isAlerting: store.alertingCommandId == cmd.id,
                                onTap: {
                                    selectedId = cmd.id
                                    if cmd.alertState == .now {
                                        store.acknowledge(cmd)
                                    }
                                },
                                onDoubleTap: { handleRun(cmd) },
                                onEdit: { editingCommand = cmd },
                                onCopy: {
                                    store.duplicate(cmd)
                                },
                                onDelete: {
                                    store.moveToTrash(cmd)
                                },
                                onRun: { handleRun(cmd) }
                            )
                            .onDrag {
                                draggingItem = cmd
                                selectedId = cmd.id
                                return NSItemProvider(object: cmd.id.uuidString as NSString)
                            } preview: {
                                Color.clear.frame(width: 1, height: 1)
                            }
                            .onDrop(of: [.text], delegate: ReorderDropDelegate(
                                item: cmd,
                                items: $store.commands,
                                draggingItem: $draggingItem,
                                onSave: { store.save() }
                            ))
                        }
                    }
                    .padding(8)
                }
                .background(Color.clear)
                .contentShape(Rectangle())
                .onTapGesture {
                    selectedId = nil
                }
                .onDrop(of: [.text], isTargeted: nil) { _ in
                    draggingItem = nil
                    store.save()
                    return true
                }
                .onKeyPress(.return) {
                    if let id = selectedId, let cmd = store.commands.first(where: { $0.id == id }) {
                        store.run(cmd)
                        return .handled
                    }
                    return .ignored
                }
                .overlay {
                    if store.activeItems.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "terminal")
                                .font(.title2)
                                .foregroundStyle(.secondary)
                            Text(L.commandNoCommands)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text(L.commandAddFirst)
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
            }

            Divider()

            HStack {
                Button(action: { showingTrash = false; showingHistory = false; showingClipboard = false }) {
                    ZStack {
                        Image(systemName: "doc.text")
                            .foregroundStyle(!showingTrash && !showingHistory && !showingClipboard ? .primary : .secondary)
                        if (showingTrash || showingHistory || showingClipboard) && hasActiveIndicator {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 6, height: 6)
                                .offset(x: 6, y: -6)
                        }
                    }
                }
                .buttonStyle(HoverButtonStyle())

                if !showingTrash && !showingHistory && !showingClipboard {
                    Button(action: { showAddSheet = true }) {
                        Image(systemName: "plus")
                    }
                    .buttonStyle(HoverButtonStyle())
                }

                Spacer()

                Button(action: { showingClipboard = true; showingHistory = false; showingTrash = false }) {
                    Image(systemName: store.clipboardItems.isEmpty ? "doc.on.clipboard" : "doc.on.clipboard.fill")
                        .foregroundStyle(showingClipboard ? .primary : .secondary)
                }
                .buttonStyle(HoverButtonStyle())

                Button(action: { showingHistory = true; showingTrash = false; showingClipboard = false }) {
                    Image(systemName: store.history.isEmpty ? "clock" : "clock.fill")
                        .foregroundStyle(showingHistory ? .primary : .secondary)
                }
                .buttonStyle(HoverButtonStyle())

                Button(action: { showingTrash = true; showingHistory = false; showingClipboard = false }) {
                    Image(systemName: store.trashItems.isEmpty ? "trash" : "trash.fill")
                        .foregroundStyle(showingTrash ? .primary : .secondary)
                }
                .buttonStyle(HoverButtonStyle())

                Button(action: { showSettings = true }) {
                    Image(systemName: "gearshape")
                        .foregroundStyle(.primary)
                }
                .buttonStyle(HoverButtonStyle())

                Button(action: {
                    DispatchQueue.main.async { snapToRight() }
                }) {
                    Image(systemName: "sidebar.right")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(HoverButtonStyle())
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
        .sheet(isPresented: $showAddSheet) {
            AddCommandView(store: store)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(settings: settings, store: store)
        }
        .sheet(item: $editingCommand) { cmd in
            EditCommandView(store: store, command: cmd)
        }
        .onAppear {
            settings.applyAlwaysOnTop()
            settings.applyBackgroundOpacity()
        }
        .onDrop(of: [.text], isTargeted: nil) { _ in
            if draggingItem != nil {
                draggingItem = nil
                store.save()
            }
            return true
        }
    }

    func snapToRight() {
        guard let window = NSApp.keyWindow ?? NSApp.mainWindow, let screen = window.screen else { return }
        let visibleFrame = screen.visibleFrame
        let minWidth: CGFloat = 280
        let newFrame = NSRect(
            x: visibleFrame.maxX - minWidth,
            y: visibleFrame.minY,
            width: minWidth,
            height: visibleFrame.height
        )
        window.setFrame(newFrame, display: true, animate: false)
    }

    func handleRun(_ cmd: Command) {
        if cmd.executionType == .script {
            ScriptExecutionWindowController.show(command: cmd, store: store)
        } else {
            store.run(cmd)
        }
    }

    func historyTypeColor(_ type: HistoryType) -> Color {
        switch type {
        case .executed: return .blue
        case .background: return .orange
        case .script: return .green
        case .scheduleAlert: return .purple
        case .reminder: return .pink
        case .added: return .mint
        case .deleted: return .red
        case .restored: return .teal
        case .permanentlyDeleted: return .gray
        }
    }

    func historyTypeIcon(_ type: HistoryType) -> String {
        switch type {
        case .executed: return "terminal"
        case .background: return "arrow.clockwise"
        case .script: return "play.fill"
        case .scheduleAlert: return "calendar"
        case .reminder: return "bell.fill"
        case .added: return "plus.circle"
        case .deleted: return "trash"
        case .restored: return "arrow.uturn.backward"
        case .permanentlyDeleted: return "xmark.circle"
        }
    }

    func trashItemIcon(_ cmd: Command) -> String {
        switch cmd.executionType {
        case .terminal: return "terminal"
        case .background: return "arrow.clockwise"
        case .script: return "play.fill"
        case .schedule: return "calendar"
        }
    }

    func trashItemColor(_ cmd: Command) -> Color {
        switch cmd.executionType {
        case .terminal: return .blue
        case .background: return .orange
        case .script: return .green
        case .schedule: return .purple
        }
    }
}

// MARK: - History Detail Window Controller
class HistoryDetailWindowController {
    static var activeWindows: [UUID: NSWindow] = [:]

    static func show(item: HistoryItem) {
        if let existingWindow = activeWindows[item.id] {
            existingWindow.makeKeyAndOrderFront(nil)
            return
        }

        let contentView = HistoryOutputView(
            item: item,
            onClose: { closeWindow(for: item.id) }
        )

        let hostingController = NSHostingController(rootView: contentView)
        let panel = NSPanel(contentViewController: hostingController)

        panel.title = item.title
        panel.styleMask = [.titled, .closable, .resizable, .utilityWindow, .nonactivatingPanel]
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false

        let window = panel
        window.setContentSize(NSSize(width: 500, height: 400))
        window.minSize = NSSize(width: 400, height: 300)

        if let mainWindow = NSApp.mainWindow ?? NSApp.windows.first {
            let mainFrame = mainWindow.frame
            let x = mainFrame.midX - 250
            let y = mainFrame.midY - 200
            window.setFrameOrigin(NSPoint(x: x, y: y))
        } else {
            window.center()
        }

        window.level = .modalPanel
        window.isReleasedWhenClosed = false
        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { _ in
            activeWindows.removeValue(forKey: item.id)
        }

        activeWindows[item.id] = window
        window.makeKeyAndOrderFront(nil)
    }

    static func closeWindow(for itemId: UUID) {
        if let window = activeWindows[itemId] {
            window.close()
            activeWindows.removeValue(forKey: itemId)
        }
    }
}

// 히스토리 출력 보기 뷰
struct HistoryOutputView: View {
    let item: HistoryItem
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.headline)
                Text(item.timestamp, format: .dateTime)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()

            Divider()

            VStack(alignment: .leading, spacing: 12) {
                // 실행 명령어
                VStack(alignment: .leading, spacing: 4) {
                    Text(L.commandInput)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(item.command)
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(6)
                }

                // 출력
                if let output = item.output, !output.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(L.historyOutput)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        OutputTextView(text: output)
                            .padding(8)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(6)
                    }
                    .frame(maxHeight: .infinity)
                }
            }
            .padding()

            Divider()

            HStack {
                Spacer()
                Button(L.buttonClose) {
                    onClose()
                }
                .buttonStyle(HoverTextButtonStyle())
            }
            .padding()
        }
        .frame(minWidth: 450, minHeight: 350)
    }
}

struct CommandRowView: View {
    let cmd: Command
    let isSelected: Bool
    let isDragging: Bool
    let isAlerting: Bool
    let onTap: () -> Void
    let onDoubleTap: () -> Void
    let onEdit: () -> Void
    let onCopy: () -> Void
    let onDelete: () -> Void
    let onRun: () -> Void

    @State private var shakeOffset: CGFloat = 0

    var typeColor: Color {
        switch cmd.executionType {
        case .terminal: return .blue
        case .background: return .orange
        case .script: return .green
        case .schedule: return .purple
        }
    }

    var typeIcon: String {
        switch cmd.executionType {
        case .terminal: return "terminal"
        case .background: return "arrow.clockwise"
        case .script: return "play.fill"
        case .schedule: return "calendar"
        }
    }

    var badgeText: String {
        switch cmd.executionType {
        case .terminal:
            return cmd.terminalApp.rawValue
        case .background:
            if cmd.interval == 0 { return L.manual }
            guard let lastRun = cmd.lastExecutedAt else { return formatRemaining(cmd.interval) + " " + L.timeAfter }
            let nextRun = lastRun.addingTimeInterval(Double(cmd.interval))
            let remaining = Int(nextRun.timeIntervalSinceNow)
            if remaining <= 0 { return L.scriptRunning }
            return formatRemaining(remaining) + " " + L.timeAfter
        case .script:
            return cmd.hasParameters ? L.parameter : L.buttonRun
        case .schedule:
            guard let date = cmd.scheduleDate else { return L.executionSchedule }
            let diff = date.timeIntervalSinceNow

            // 확인했으면 체크 표시
            if cmd.acknowledged {
                return "✓"
            }

            // 지난 시간 표시
            if diff < 0 {
                return formatRemaining(Int(-diff)) + " " + L.timePassed
            }
            // 남은 시간 표시
            else {
                return formatRemaining(Int(diff)) + " " + L.timeAfter
            }
        }
    }

    var alertBadgeColor: Color {
        switch cmd.alertState {
        case .now: return .red
        case .fiveMinBefore: return .orange
        case .thirtyMinBefore: return .orange
        case .hourBefore: return .yellow
        case .dayBefore: return .green
        case .passed: return .gray
        case .none: return typeColor
        }
    }

    var badgeColor: Color {
        if cmd.executionType == .schedule {
            if cmd.acknowledged && cmd.alertState == .now {
                return .green  // 체크 표시일 때 초록색
            }
            if cmd.alertState != .none {
                return alertBadgeColor
            }
        }
        return typeColor
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: typeIcon)
                        .foregroundStyle(typeColor)
                        .frame(width: 14)
                    Text(cmd.title)
                        .fontWeight(isAlerting ? .bold : .regular)
                    ProgressView()
                        .scaleEffect(0.5)
                        .frame(width: 12, height: 12)
                        .opacity(cmd.isRunning ? 1 : 0)
                }
                if cmd.executionType == .schedule {
                    HStack(spacing: 4) {
                        if let date = cmd.scheduleDate {
                            Text(date, format: .dateTime.month().day().hour().minute())
                        }
                        if cmd.repeatType != .none {
                            Text("(\(cmd.repeatType.rawValue))")
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                } else {
                    Text(cmd.command)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                if cmd.executionType == .background {
                    Text(cmd.lastOutput ?? " ")
                        .font(.caption2.monospaced())
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            Spacer()
            Text(badgeText)
                .font(.caption2)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(badgeColor.opacity(0.2))
                .foregroundStyle(badgeColor)
                .cornerRadius(4)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isAlerting ? Color.red.opacity(0.3) : (isSelected ? Color.accentColor.opacity(0.2) : Color.clear))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(isAlerting ? Color.red : (isSelected ? Color.accentColor : Color.primary.opacity(0.1)), lineWidth: isAlerting ? 2 : 1)
        )
        .offset(x: shakeOffset)
        .opacity(isDragging ? 0.5 : 1.0)
        .contentShape(Rectangle())
        .gesture(TapGesture(count: 2).onEnded { onDoubleTap() })
        .simultaneousGesture(TapGesture(count: 1).onEnded { onTap() })
        .overlay {
            RightClickMenu(
                onSelect: onTap,
                onRun: onRun,
                onEdit: onEdit,
                onCopy: onCopy,
                onDelete: onDelete
            )
        }
        .onChange(of: isAlerting) { _, newValue in
            if newValue {
                shake()
            }
        }
    }

    func shake() {
        withAnimation(.linear(duration: 0.05).repeatCount(10, autoreverses: true)) {
            shakeOffset = 5
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            shakeOffset = 0
        }
    }

    func formatRemaining(_ seconds: Int) -> String {
        if seconds >= 86400 {
            return "\(seconds / 86400)" + L.daysUnit
        } else if seconds >= 3600 {
            return "\(seconds / 3600)" + L.hoursUnit
        } else if seconds >= 60 {
            return "\(seconds / 60)" + L.minutesUnit
        } else {
            return "\(seconds)" + L.secondsUnit
        }
    }
}

struct RightClickMenu: NSViewRepresentable {
    let onSelect: () -> Void
    let onRun: () -> Void
    let onEdit: () -> Void
    let onCopy: () -> Void
    let onDelete: () -> Void

    func makeNSView(context: Context) -> NSView {
        let view = RightClickMenuView()
        view.onSelect = onSelect
        view.onRun = onRun
        view.onEdit = onEdit
        view.onCopy = onCopy
        view.onDelete = onDelete
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        guard let view = nsView as? RightClickMenuView else { return }
        view.onSelect = onSelect
        view.onRun = onRun
        view.onEdit = onEdit
        view.onCopy = onCopy
        view.onDelete = onDelete
    }

    class RightClickMenuView: NSView {
        var onSelect: (() -> Void)?
        var onRun: (() -> Void)?
        var onEdit: (() -> Void)?
        var onCopy: (() -> Void)?
        var onDelete: (() -> Void)?

        override func rightMouseDown(with event: NSEvent) {
            showMenu(with: event)
        }

        override func mouseDown(with event: NSEvent) {
            if event.modifierFlags.contains(.control) {
                showMenu(with: event)
            }
            // 왼쪽 클릭은 SwiftUI로 전달
        }

        override func hitTest(_ point: NSPoint) -> NSView? {
            // 우클릭만 이 뷰에서 처리
            if NSEvent.pressedMouseButtons & 0x2 != 0 {
                return super.hitTest(point)
            }
            // Control 키가 눌린 상태면 처리
            if NSEvent.modifierFlags.contains(.control) && NSEvent.pressedMouseButtons & 0x1 != 0 {
                return super.hitTest(point)
            }
            return nil
        }

        func showMenu(with event: NSEvent) {
            onSelect?()

            let menu = NSMenu()

            let runItem = NSMenuItem(title: L.contextMenuRun, action: #selector(runAction), keyEquivalent: "")
            runItem.target = self
            menu.addItem(runItem)

            let editItem = NSMenuItem(title: L.contextMenuEdit, action: #selector(editAction), keyEquivalent: "")
            editItem.target = self
            menu.addItem(editItem)

            let copyItem = NSMenuItem(title: L.contextMenuCopy, action: #selector(copyAction), keyEquivalent: "")
            copyItem.target = self
            menu.addItem(copyItem)

            menu.addItem(NSMenuItem.separator())

            let deleteItem = NSMenuItem(title: L.buttonDelete, action: #selector(deleteAction), keyEquivalent: "")
            deleteItem.target = self
            menu.addItem(deleteItem)

            NSMenu.popUpContextMenu(menu, with: event, for: self)
        }

        @objc func runAction() { onRun?() }
        @objc func editAction() { onEdit?() }
        @objc func copyAction() { onCopy?() }
        @objc func deleteAction() { onDelete?() }
    }
}

struct ReorderDropDelegate: DropDelegate {
    let item: Command
    @Binding var items: [Command]
    @Binding var draggingItem: Command?
    var onSave: () -> Void

    func performDrop(info: DropInfo) -> Bool {
        onSave()
        DispatchQueue.main.async {
            draggingItem = nil
        }
        return true
    }

    func dropEntered(info: DropInfo) {
        guard let dragging = draggingItem,
              dragging.id != item.id,
              let from = items.firstIndex(where: { $0.id == dragging.id }),
              let to = items.firstIndex(where: { $0.id == item.id }),
              from != to else { return }

        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            items.move(fromOffsets: IndexSet(integer: from), toOffset: to > from ? to + 1 : to)
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func dropExited(info: DropInfo) {
        // 드래그 취소 시에도 현재 상태 유지
    }

    func validateDrop(info: DropInfo) -> Bool {
        return draggingItem != nil
    }
}

// MARK: - 파라미터 입력 및 결과 표시

struct ParameterInputView: View {
    let command: Command
    let onExecute: ([String: String]) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var values: [String: String] = [:]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(command.title)
                .font(.headline)

            Text(command.command)
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)

            Divider()

            ForEach(command.parameterInfos, id: \.name) { info in
                VStack(alignment: .leading, spacing: 4) {
                    Text(info.name)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if info.options.isEmpty {
                        TextField("", text: Binding(
                            get: { values[info.name] ?? "" },
                            set: { values[info.name] = $0 }
                        ))
                        .textFieldStyle(.roundedBorder)
                    } else {
                        Picker("", selection: Binding(
                            get: { values[info.name] ?? info.options.first ?? "" },
                            set: { values[info.name] = $0 }
                        )) {
                            ForEach(info.options, id: \.self) { option in
                                Text(option).tag(option)
                            }
                        }
                        .labelsHidden()
                    }
                }
            }

            HStack {
                Button(L.buttonCancel) { dismiss() }
                    .buttonStyle(HoverTextButtonStyle())
                Spacer()
                Button(L.buttonRun) {
                    // 옵션이 있는 파라미터는 기본값 설정
                    var finalValues = values
                    for info in command.parameterInfos {
                        if finalValues[info.name] == nil, let first = info.options.first {
                            finalValues[info.name] = first
                        }
                    }
                    onExecute(finalValues)
                    dismiss()
                }
                .buttonStyle(HoverTextButtonStyle())
                .keyboardShortcut(.return)
            }
        }
        .padding()
        .frame(width: 350)
    }
}

class ScriptRunner: ObservableObject {
    @Published var isRunning = false
    @Published var isFinished = false
    @Published var output = ""

    private var process: Process?
    private var fileHandle: FileHandle?
    private var buffer = ""
    private var updateTimer: Timer?
    private let queue = DispatchQueue(label: "ScriptRunner")

    func run(command: String, completion: @escaping (String) -> Void) {
        DispatchQueue.main.async {
            self.isRunning = true
            self.isFinished = false
            self.output = ""
        }
        buffer = ""

        let proc = Process()
        let pipe = Pipe()

        proc.executableURL = URL(fileURLWithPath: "/bin/zsh")
        proc.arguments = ["-c", command]
        proc.standardOutput = pipe
        proc.standardError = pipe

        self.process = proc
        let handle = pipe.fileHandleForReading
        self.fileHandle = handle

        // 100ms마다 UI 업데이트
        DispatchQueue.main.async {
            self.updateTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                guard let self = self else { return }
                self.queue.sync {
                    if !self.buffer.isEmpty {
                        let text = self.buffer
                        self.buffer = ""
                        DispatchQueue.main.async {
                            self.output += text
                        }
                    }
                }
            }
        }

        // 출력 읽기 (버퍼에 저장)
        handle.readabilityHandler = { [weak self] h in
            let data = h.availableData
            if !data.isEmpty, let str = String(data: data, encoding: .utf8) {
                self?.queue.sync {
                    self?.buffer += str
                }
            }
        }

        // 프로세스 종료 감지
        proc.terminationHandler = { [weak self] _ in
            handle.readabilityHandler = nil
            let remaining = try? handle.readToEnd()

            DispatchQueue.main.async {
                self?.updateTimer?.invalidate()
                self?.updateTimer = nil

                // 남은 버퍼 + 마지막 데이터
                self?.queue.sync {
                    if !self!.buffer.isEmpty {
                        self?.output += self!.buffer
                        self?.buffer = ""
                    }
                }
                if let data = remaining, !data.isEmpty,
                   let str = String(data: data, encoding: .utf8) {
                    self?.output += str
                }

                self?.isRunning = false
                self?.isFinished = true
                completion(self?.output ?? "")
            }
        }

        do {
            try proc.run()
        } catch {
            DispatchQueue.main.async {
                self.updateTimer?.invalidate()
                handle.readabilityHandler = nil
                self.output = "Error: \(error.localizedDescription)"
                self.isRunning = false
                self.isFinished = true
            }
        }
    }

    func stop() {
        updateTimer?.invalidate()
        updateTimer = nil
        fileHandle?.readabilityHandler = nil
        process?.terminate()
        DispatchQueue.main.async {
            self.output += "\n(중단됨)"
            self.isRunning = false
            self.isFinished = true
        }
    }
}

// 효율적인 텍스트 뷰 (NSTextView 래퍼)
struct OutputTextView: NSViewRepresentable {
    let text: String

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        scrollView.drawsBackground = false
        scrollView.backgroundColor = .clear
        let textView = scrollView.documentView as! NSTextView
        textView.isEditable = false
        textView.isSelectable = true
        textView.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        textView.backgroundColor = .clear
        textView.drawsBackground = false
        textView.textColor = NSColor.labelColor
        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        let textView = nsView.documentView as! NSTextView
        let shouldScroll = textView.visibleRect.maxY >= textView.bounds.maxY - 20

        textView.string = text

        // 맨 아래로 스크롤
        if shouldScroll {
            textView.scrollToEndOfDocument(nil)
        }
    }
}

struct ScriptExecutionView: View {
    let command: Command
    let store: CommandStore
    var onClose: (() -> Void)?
    var onExecutionStarted: (() -> Void)?

    @State private var values: [String: String] = [:]
    @State private var executedCommand: String?
    @StateObject private var runner = ScriptRunner()

    var isValid: Bool {
        for info in command.parameterInfos {
            if info.options.isEmpty {
                // 텍스트 입력: 값이 있어야 함
                guard let value = values[info.name], !value.isEmpty else { return false }
            }
            // 옵션 선택: 기본값이 있으므로 항상 valid
        }
        return true
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 상단 헤더
            VStack(alignment: .leading, spacing: 8) {
                Text(command.title)
                    .font(.headline)

                Text(executedCommand ?? command.command)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
            .padding([.horizontal, .top])
            .padding(.bottom, 8)

            // 파라미터 입력 영역
            if !command.parameterInfos.isEmpty && !runner.isRunning && !runner.isFinished {
                Divider()
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(command.parameterInfos, id: \.name) { info in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(info.name)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            if info.options.isEmpty {
                                TextField("", text: Binding(
                                    get: { values[info.name] ?? "" },
                                    set: { values[info.name] = $0 }
                                ))
                                .textFieldStyle(.roundedBorder)
                            } else {
                                Picker("", selection: Binding(
                                    get: { values[info.name] ?? info.options.first ?? "" },
                                    set: { values[info.name] = $0 }
                                )) {
                                    ForEach(info.options, id: \.self) { option in
                                        Text(option).tag(option)
                                    }
                                }
                                .pickerStyle(.menu)
                                .labelsHidden()
                            }
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            }

            // 출력 영역 (남은 공간 채움)
            if runner.isRunning || runner.isFinished {
                Divider()
                OutputTextView(text: runner.output.isEmpty ? "(실행 중...)" : runner.output)
                    .padding(8)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(6)
                    .padding()
            } else {
                Spacer()
            }

            // 하단 버튼 (항상 고정)
            Divider()
            HStack {
                if runner.isFinished {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Spacer()
                    Button(L.buttonClose) { onClose?() }
                        .buttonStyle(HoverTextButtonStyle())
                } else if runner.isRunning {
                    ProgressView()
                        .scaleEffect(0.7)
                        .frame(width: 16, height: 16)
                    Spacer()
                    Button(L.buttonStop) {
                        runner.stop()
                    }
                    .buttonStyle(HoverTextButtonStyle())
                    .foregroundStyle(.red)
                } else {
                    Button(L.buttonClose) { onClose?() }
                        .buttonStyle(HoverTextButtonStyle())
                    Spacer()
                    Button(L.buttonRun) {
                        executeScript()
                    }
                    .buttonStyle(HoverTextButtonStyle())
                    .keyboardShortcut(.return)
                    .disabled(!isValid && !command.parameterInfos.isEmpty)
                }
            }
            .padding()
        }
        .frame(minWidth: 400, minHeight: 250)
    }

    func executeScript() {
        var finalValues = values
        for info in command.parameterInfos {
            if finalValues[info.name] == nil, let first = info.options.first {
                finalValues[info.name] = first
            }
        }
        var finalCommand = command.commandWith(values: finalValues)
        // 스마트 따옴표를 일반 따옴표로 변환
        finalCommand = finalCommand
            .replacingOccurrences(of: "\u{201C}", with: "\"")  // "
            .replacingOccurrences(of: "\u{201D}", with: "\"")  // "
            .replacingOccurrences(of: "\u{2018}", with: "'")   // '
            .replacingOccurrences(of: "\u{2019}", with: "'")

        executedCommand = finalCommand
        onExecutionStarted?()

        runner.run(command: finalCommand) { output in
            store.addHistory(HistoryItem(
                timestamp: Date(),
                title: command.title,
                command: finalCommand,
                type: .script,
                output: output,
                commandId: command.id
            ))
        }
    }
}

// MARK: - Script Execution Window Controller
class ScriptExecutionWindowController {
    static var activeWindows: [UUID: NSWindow] = [:]

    static func show(command: Command, store: CommandStore) {
        // 이미 열린 창이 있으면 앞으로 가져오기
        if let existingWindow = activeWindows[command.id] {
            existingWindow.makeKeyAndOrderFront(nil)
            return
        }

        // 파라미터 개수에 따라 초기 높이 계산
        let paramCount = command.parameterInfos.count
        let baseHeight: CGFloat = 120  // 헤더 + 버튼
        let paramHeight: CGFloat = CGFloat(paramCount) * 55  // 파라미터 당 높이
        let initialHeight: CGFloat = baseHeight + paramHeight

        let contentView = ScriptExecutionView(
            command: command,
            store: store,
            onClose: {
                closeWindow(for: command.id)
            },
            onExecutionStarted: {
                expandWindow(for: command.id)
            }
        )

        let hostingController = NSHostingController(rootView: contentView)
        let panel = NSPanel(contentViewController: hostingController)

        panel.title = command.title
        panel.styleMask = [.titled, .closable, .resizable, .utilityWindow, .nonactivatingPanel]
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false

        let window = panel
        window.setContentSize(NSSize(width: 450, height: initialHeight))
        window.minSize = NSSize(width: 400, height: 150)

        // 메인 창 기준으로 위치
        if let mainWindow = NSApp.mainWindow ?? NSApp.windows.first {
            let mainFrame = mainWindow.frame
            let x = mainFrame.midX - 225
            let y = mainFrame.midY - initialHeight / 2
            window.setFrameOrigin(NSPoint(x: x, y: y))
        } else {
            window.center()
        }

        // 모달처럼 항상 앞에 고정
        window.level = .modalPanel

        // 창 닫힐 때 정리
        window.isReleasedWhenClosed = false
        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { _ in
            activeWindows.removeValue(forKey: command.id)
        }

        activeWindows[command.id] = window
        window.makeKeyAndOrderFront(nil)
    }

    static func expandWindow(for commandId: UUID) {
        guard let window = activeWindows[commandId] else { return }
        let currentFrame = window.frame
        let newHeight: CGFloat = 400
        let newY = currentFrame.origin.y - (newHeight - currentFrame.height)
        let newFrame = NSRect(x: currentFrame.origin.x, y: newY, width: currentFrame.width, height: newHeight)
        window.animator().setFrame(newFrame, display: true)
    }

    static func closeWindow(for commandId: UUID) {
        if let window = activeWindows[commandId] {
            window.close()
            activeWindows.removeValue(forKey: commandId)
        }
    }
}

// MARK: - Clipboard Detail Window Controller
class ClipboardDetailWindowController {
    static var activeWindows: [UUID: NSWindow] = [:]

    static func show(item: ClipboardItem, store: CommandStore, notesFolderName: String) {
        if let existingWindow = activeWindows[item.id] {
            existingWindow.makeKeyAndOrderFront(nil)
            return
        }

        let contentView = ClipboardDetailView(
            item: item,
            store: store,
            notesFolderName: notesFolderName,
            onClose: { closeWindow(for: item.id) }
        )

        let hostingController = NSHostingController(rootView: contentView)
        let panel = NSPanel(contentViewController: hostingController)

        panel.title = L.clipboardDetail
        panel.styleMask = [.titled, .closable, .resizable, .utilityWindow, .nonactivatingPanel]
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false

        let window = panel
        window.setContentSize(NSSize(width: 500, height: 400))
        window.minSize = NSSize(width: 300, height: 200)

        if let mainWindow = NSApp.mainWindow ?? NSApp.windows.first {
            let mainFrame = mainWindow.frame
            let x = mainFrame.midX - 250
            let y = mainFrame.midY - 200
            window.setFrameOrigin(NSPoint(x: x, y: y))
        } else {
            window.center()
        }

        window.level = .modalPanel
        window.isReleasedWhenClosed = false
        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { _ in
            activeWindows.removeValue(forKey: item.id)
        }

        activeWindows[item.id] = window
        window.makeKeyAndOrderFront(nil)
    }

    static func closeWindow(for itemId: UUID) {
        if let window = activeWindows[itemId] {
            window.close()
            activeWindows.removeValue(forKey: itemId)
        }
    }
}

struct ClipboardDetailView: View {
    let item: ClipboardItem
    let store: CommandStore
    let notesFolderName: String
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text(L.clipboardContent)
                    .font(.headline)
                Text(item.timestamp, format: .dateTime)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("\(item.content.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()

            Divider()

            OutputTextView(text: item.content)
                .padding(8)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(6)
                .padding()

            Divider()

            HStack {
                Button(L.addToTop) {
                    store.registerClipboardAsCommand(item, asLast: false)
                    onClose()
                }
                .buttonStyle(HoverTextButtonStyle())
                Button(L.addToBottom) {
                    store.registerClipboardAsCommand(item, asLast: true)
                    onClose()
                }
                .buttonStyle(HoverTextButtonStyle())
                Button(L.clipboardSendToNotes) {
                    store.sendToNotes(item, folderName: notesFolderName)
                    onClose()
                }
                .buttonStyle(HoverTextButtonStyle())
                Spacer()
                Button(L.buttonDelete) {
                    store.removeClipboardItem(item)
                    onClose()
                }
                .buttonStyle(HoverTextButtonStyle())
                .foregroundStyle(.red)
                Button(L.buttonClose) { onClose() }
                    .buttonStyle(HoverTextButtonStyle())
            }
            .padding()
        }
        .frame(minWidth: 300, minHeight: 200)
    }
}

struct AddCommandView: View {
    @ObservedObject var store: CommandStore
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var command = ""
    @State private var executionType: ExecutionType = .terminal
    @State private var terminalApp: TerminalApp = .iterm2
    @State private var interval: String = "0"
    // 일정용
    @State private var scheduleDate = Date()
    @State private var repeatType: RepeatType = .none
    // 미리 알림
    @State private var remind5min = false
    @State private var remind30min = false
    @State private var remind1hour = false
    @State private var remind1day = false
    @State private var showParamHelp = false

    var isValid: Bool {
        if title.isEmpty { return false }
        switch executionType {
        case .terminal, .background, .script:
            return !command.isEmpty
        case .schedule:
            return true
        }
    }

    func canRemind(seconds: Int) -> Bool {
        repeatType != .none || scheduleDate.timeIntervalSinceNow > Double(seconds)
    }

    var reminderTimes: Set<Int> {
        var times: Set<Int> = []
        if remind5min { times.insert(300) }
        if remind30min { times.insert(1800) }
        if remind1hour { times.insert(3600) }
        if remind1day { times.insert(86400) }
        return times
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(L.addNewItem)
                .font(.headline)
                .padding()

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(L.commandTitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("", text: $title)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(L.executionMethod)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Picker("", selection: $executionType) {
                    ForEach(ExecutionType.allCases, id: \.self) {
                        Text($0.displayName)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }

            if executionType == .schedule {
                VStack(alignment: .leading, spacing: 4) {
                    Text(L.dateTime)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    DatePicker("", selection: $scheduleDate, displayedComponents: [.date, .hourAndMinute])
                        .labelsHidden()
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(L.commandRepeat)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Picker("", selection: $repeatType) {
                        ForEach(RepeatType.allCases, id: \.self) {
                            Text($0.displayName)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(L.commandReminders)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 12) {
                        Toggle("5" + L.minutesUnit, isOn: $remind5min)
                            .toggleStyle(.checkbox)
                            .disabled(!canRemind(seconds: 300))
                        Toggle("30" + L.minutesUnit, isOn: $remind30min)
                            .toggleStyle(.checkbox)
                            .disabled(!canRemind(seconds: 1800))
                        Toggle("1" + L.hoursUnit, isOn: $remind1hour)
                            .toggleStyle(.checkbox)
                            .disabled(!canRemind(seconds: 3600))
                        Toggle("1" + L.daysUnit, isOn: $remind1day)
                            .toggleStyle(.checkbox)
                            .disabled(!canRemind(seconds: 86400))
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    Text(L.commandInput)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextEditor(text: $command)
                        .font(.body.monospaced())
                        .frame(height: 80)
                        .padding(4)
                        .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.gray.opacity(0.3)))
                    if executionType == .script {
                        Button(action: { showParamHelp = true }) {
                            Text(L.commandHelpText)
                                .font(.caption)
                                .foregroundStyle(.blue)
                        }
                        .buttonStyle(.plain)
                    }
                }

                if executionType == .terminal {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(L.terminalAppLabel)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Picker("", selection: $terminalApp) {
                            ForEach(TerminalApp.allCases, id: \.self) {
                                Text($0.rawValue)
                            }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                    }
                } else if executionType == .background {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(L.intervalLabel)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("", text: $interval)
                            .textFieldStyle(.roundedBorder)
                        HStack(spacing: 4) {
                            ForEach([("10분", 600), ("1시간", 3600), ("6시간", 21600), ("12시간", 43200), ("24시간", 86400), ("7일", 604800)], id: \.0) { label, seconds in
                                Button(label) {
                                    interval = String(seconds)
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                        }
                    }
                }
                    // script는 명령어만 입력
                }
                }
                .padding()
            }

            Divider()

            HStack {
                Button(L.buttonCancel) {
                    dismiss()
                }
                .buttonStyle(HoverTextButtonStyle())
                Spacer()
                Button(L.buttonAdd) {
                    store.add(Command(
                        title: title,
                        command: command,
                        executionType: executionType,
                        terminalApp: terminalApp,
                        interval: Int(interval) ?? 0,
                        scheduleDate: executionType == .schedule ? scheduleDate : nil,
                        repeatType: repeatType,
                        reminderTimes: reminderTimes
                    ))
                    dismiss()
                }
                .buttonStyle(HoverTextButtonStyle())
                .disabled(!isValid)
            }
            .padding()
        }
        .frame(width: 350)
        .sheet(isPresented: $showParamHelp) {
            ParameterHelpView()
        }
    }
}

struct ParameterHelpView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(L.parameterHelpTitle)
                .font(.headline)

            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(L.helpSyntax)
                        .font(.subheadline.bold())
                    Text("{파라미터명}")
                        .font(.body.monospaced())
                        .padding(6)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(4)
                }

                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    Text(L.parameterExample)
                        .font(.subheadline.bold())

                    Group {
                        Text("echo \"Hello {name}\"")
                        Text("→ 실행 시 name 값 입력")
                            .foregroundStyle(.secondary)
                    }
                    .font(.caption.monospaced())

                    Group {
                        Text("curl -X {method} {url}")
                        Text("→ 실행 시 method, url 값 입력")
                            .foregroundStyle(.secondary)
                    }
                    .font(.caption.monospaced())

                    Group {
                        Text("git commit -m \"{message}\"")
                        Text("→ 실행 시 message 값 입력")
                            .foregroundStyle(.secondary)
                    }
                    .font(.caption.monospaced())
                }
            }

            HStack {
                Spacer()
                Button(L.buttonClose) { dismiss() }
                    .buttonStyle(HoverTextButtonStyle())
            }
        }
        .textSelection(.enabled)
        .padding()
        .frame(width: 320)
    }
}

struct SettingsView: View {
    @ObservedObject var settings: Settings
    @ObservedObject var store: CommandStore
    @ObservedObject var languageManager = LanguageManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab = 0
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var showImportChoice = false
    @State private var pendingImportData: Data?

    private var tabTitles: [String] {
        [L.settingsGeneral, L.settingsHistoryTab, L.settingsClipboardTab, L.settingsBackup, L.settingsLanguage]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(L.settingsTitle)
                .font(.headline)
                .padding(.horizontal)
                .padding(.top)
                .padding(.bottom, 12)

            Divider()

            // 탭 UI
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    ForEach(Array(tabTitles.enumerated()), id: \.offset) { index, title in
                        Button(action: { selectedTab = index }) {
                            VStack(spacing: 0) {
                                Text(title)
                                    .foregroundColor(selectedTab == index ? .primary : .secondary)
                                    .padding(.bottom, 6)
                                Rectangle()
                                    .fill(selectedTab == index ? Color.accentColor : Color.clear)
                                    .frame(height: 2)
                            }
                        }
                        .buttonStyle(.plain)
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, 12)
                Divider()
            }
            .padding(.top, 8)

            // 탭 콘텐츠 (고정 높이)
            VStack(alignment: .leading, spacing: 0) {
                if selectedTab == 0 {
                    // 기본 설정
                    Toggle(L.settingsAlwaysOnTop, isOn: $settings.alwaysOnTop)
                        .frame(maxWidth: .infinity, minHeight: 24, alignment: .leading)
                    Toggle(L.settingsLaunchAtLogin, isOn: $settings.launchAtLogin)
                        .frame(maxWidth: .infinity, minHeight: 24, alignment: .leading)
                    HStack {
                        Text(L.settingsBackgroundOpacity)
                        Slider(value: $settings.backgroundOpacity, in: 0.3...1.0, step: 0.1)
                        Text("\(Int(settings.backgroundOpacity * 100))%")
                            .frame(width: 40)
                    }
                    .frame(maxWidth: .infinity, minHeight: 24, alignment: .leading)
                } else if selectedTab == 1 {
                    // 히스토리 설정
                    HStack {
                        Text(L.settingsMaxCount)
                        Spacer()
                        TextField("", value: $settings.maxHistoryCount, format: .number)
                            .frame(width: 80)
                            .textFieldStyle(.roundedBorder)
                    }
                    .frame(maxWidth: .infinity, minHeight: 24, alignment: .leading)
                } else if selectedTab == 2 {
                    // 클립보드 설정
                    HStack {
                        Text(L.settingsMaxCount)
                        Spacer()
                        TextField("", value: $settings.maxClipboardCount, format: .number)
                            .frame(width: 80)
                            .textFieldStyle(.roundedBorder)
                    }
                    .frame(maxWidth: .infinity, minHeight: 24, alignment: .leading)
                    HStack {
                        Text(L.settingsNotesFolderName)
                        Spacer()
                        TextField("", text: $settings.notesFolderName)
                            .frame(width: 120)
                            .textFieldStyle(.roundedBorder)
                    }
                    .frame(maxWidth: .infinity, minHeight: 24, alignment: .leading)
                } else if selectedTab == 3 {
                    // 백업 (가져오기/내보내기)
                    Text(L.settingsBackupNote)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 24, alignment: .leading)
                    HStack(spacing: 8) {
                        Button(L.settingsExportFile) { exportToFile() }
                        Button(L.settingsImportFile) { loadFromFile() }
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, minHeight: 24, alignment: .leading)
                } else {
                    // 언어 설정
                    HStack {
                        Text(L.settingsLanguage)
                        Spacer()
                        Picker("", selection: $languageManager.currentLanguage) {
                            ForEach(Language.allCases, id: \.self) { lang in
                                Text(lang.displayName).tag(lang)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 100)
                    }
                    .frame(maxWidth: .infinity, minHeight: 24, alignment: .leading)
                    HStack(spacing: 8) {
                        Button(L.settingsExportLanguagePack) { exportLanguagePack() }
                        Button(L.settingsImportLanguagePack) { importLanguagePack() }
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, minHeight: 24, alignment: .leading)
                }
                Spacer()
            }
            .frame(height: 90)
            .padding(12)

            Divider()

            HStack {
                Spacer()
                Button(L.buttonClose) {
                    dismiss()
                }
                .buttonStyle(HoverTextButtonStyle())
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
        }
        .frame(width: 320)
        .alert(L.notification, isPresented: $showAlert) {
            Button(L.buttonConfirm) {}
        } message: {
            Text(alertMessage)
        }
        .confirmationDialog(L.importDialogTitle, isPresented: $showImportChoice, titleVisibility: .visible) {
            Button(L.importMerge) {
                performImport(merge: true)
            }
            Button(L.importOverwrite) {
                performImport(merge: false)
            }
            Button(L.buttonCancel, role: .cancel) {
                pendingImportData = nil
            }
        }
    }

    func exportToFile() {
        guard let data = store.exportData(settings: settings),
              let json = String(data: data, encoding: .utf8) else {
            alertMessage = L.alertExportFailed
            showAlert = true
            return
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyMMdd_HHmmss"
        let filename = "commandbar_\(formatter.string(from: Date())).json"

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = filename

        if panel.runModal() == .OK, let url = panel.url {
            do {
                try json.write(to: url, atomically: true, encoding: .utf8)
                alertMessage = L.alertExportSuccess
                showAlert = true
            } catch {
                alertMessage = L.alertSaveFailed + ": \(error.localizedDescription)"
                showAlert = true
            }
        }
    }

    func exportToClipboard() {
        guard let data = store.exportData(settings: settings),
              let json = String(data: data, encoding: .utf8) else {
            alertMessage = L.alertExportFailed
            showAlert = true
            return
        }

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(json, forType: .string)
        alertMessage = L.alertCopiedToClipboard
        showAlert = true
    }

    func loadFromFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false

        if panel.runModal() == .OK, let url = panel.url {
            do {
                let data = try Data(contentsOf: url)
                // 유효성 검사
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                if (try? decoder.decode(ExportData.self, from: data)) != nil {
                    tryImport(data)
                } else {
                    alertMessage = L.alertInvalidFormat
                    showAlert = true
                }
            } catch {
                alertMessage = L.alertReadFailed
                showAlert = true
            }
        }
    }

    func loadFromClipboard() {
        guard let string = NSPasteboard.general.string(forType: .string),
              let data = string.data(using: .utf8) else {
            alertMessage = L.alertClipboardEmpty
            showAlert = true
            return
        }

        // 유효성 검사
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if (try? decoder.decode(ExportData.self, from: data)) != nil {
            tryImport(data)
        } else {
            alertMessage = L.alertInvalidFormat
            showAlert = true
        }
    }

    func tryImport(_ data: Data) {
        pendingImportData = data
        // 기존 데이터가 없으면 바로 가져오기
        if store.activeItems.isEmpty {
            performImport(merge: false)
        } else {
            showImportChoice = true
        }
    }

    func performImport(merge: Bool) {
        guard let data = pendingImportData else { return }
        if store.importData(data, settings: settings, merge: merge) {
            alertMessage = merge ? L.alertMergeComplete : L.alertOverwriteComplete
        } else {
            alertMessage = L.alertImportFailed
        }
        pendingImportData = nil
        showAlert = true
    }

    func exportLanguagePack() {
        guard let data = languageManager.exportLanguagePackTemplate(),
              let json = String(data: data, encoding: .utf8) else {
            alertMessage = L.alertExportFailed
            showAlert = true
            return
        }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "language_pack_template.json"

        if panel.runModal() == .OK, let url = panel.url {
            do {
                try json.write(to: url, atomically: true, encoding: .utf8)
                alertMessage = L.languagePackExportSuccess
                showAlert = true
            } catch {
                alertMessage = L.alertSaveFailed + ": \(error.localizedDescription)"
                showAlert = true
            }
        }
    }

    func importLanguagePack() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false

        if panel.runModal() == .OK, let url = panel.url {
            do {
                let data = try Data(contentsOf: url)
                if languageManager.importLanguagePack(from: data) {
                    alertMessage = L.languagePackImportSuccess
                } else {
                    alertMessage = L.languagePackInvalidFormat
                }
                showAlert = true
            } catch {
                alertMessage = L.alertReadFailed
                showAlert = true
            }
        }
    }
}

struct TrashView: View {
    @ObservedObject var store: CommandStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(L.trashTitle)
                    .font(.headline)
                Spacer()
                if !store.trashItems.isEmpty {
                    Button(L.trashEmpty) {
                        store.emptyTrash()
                    }
                    .foregroundStyle(.red)
                }
            }

            if store.trashItems.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "trash")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    Text(L.trashEmptyMessage)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(store.trashItems) { cmd in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(cmd.title)
                                    if cmd.executionType == .schedule {
                                        if let date = cmd.scheduleDate {
                                            Text(date, format: .dateTime.month().day().hour().minute())
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    } else {
                                        Text(cmd.command)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                    }
                                }
                                Spacer()
                                Button(L.buttonRestore) {
                                    store.restoreFromTrash(cmd)
                                }
                                .buttonStyle(HoverButtonStyle())
                                Button(action: {
                                    store.deletePermanently(cmd)
                                }) {
                                    Image(systemName: "xmark")
                                        .foregroundStyle(.red)
                                }
                                .buttonStyle(HoverButtonStyle())
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.gray.opacity(0.1))
                            )
                        }
                    }
                }
                .frame(height: 200)
            }

            HStack {
                Spacer()
                Button(L.buttonClose) {
                    dismiss()
                }
                .buttonStyle(HoverTextButtonStyle())
            }
        }
        .padding()
        .frame(width: 350)
    }
}

struct EditCommandView: View {
    @ObservedObject var store: CommandStore
    @Environment(\.dismiss) private var dismiss

    let command: Command
    @State private var title: String
    @State private var commandText: String
    @State private var executionType: ExecutionType
    @State private var terminalApp: TerminalApp
    @State private var interval: String
    // 일정용
    @State private var scheduleDate: Date
    @State private var repeatType: RepeatType
    // 미리 알림
    @State private var showParamHelp = false
    @State private var remind5min: Bool
    @State private var remind30min: Bool
    @State private var remind1hour: Bool
    @State private var remind1day: Bool

    init(store: CommandStore, command: Command) {
        self.store = store
        self.command = command
        _title = State(initialValue: command.title)
        _commandText = State(initialValue: command.command)
        _executionType = State(initialValue: command.executionType)
        _terminalApp = State(initialValue: command.terminalApp)
        _interval = State(initialValue: String(command.interval))
        _scheduleDate = State(initialValue: command.scheduleDate ?? Date())
        _repeatType = State(initialValue: command.repeatType)
        _remind5min = State(initialValue: command.reminderTimes.contains(300))
        _remind30min = State(initialValue: command.reminderTimes.contains(1800))
        _remind1hour = State(initialValue: command.reminderTimes.contains(3600))
        _remind1day = State(initialValue: command.reminderTimes.contains(86400))
    }

    var isValid: Bool {
        if title.isEmpty { return false }
        switch executionType {
        case .terminal, .background, .script:
            return !commandText.isEmpty
        case .schedule:
            return true
        }
    }

    func canRemind(seconds: Int) -> Bool {
        repeatType != .none || scheduleDate.timeIntervalSinceNow > Double(seconds)
    }

    var reminderTimes: Set<Int> {
        var times: Set<Int> = []
        if remind5min { times.insert(300) }
        if remind30min { times.insert(1800) }
        if remind1hour { times.insert(3600) }
        if remind1day { times.insert(86400) }
        return times
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(L.commandEditTitle)
                .font(.headline)

            VStack(alignment: .leading, spacing: 4) {
                Text(L.commandTitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("", text: $title)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(L.executionMethod)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Picker("", selection: $executionType) {
                    ForEach(ExecutionType.allCases, id: \.self) {
                        Text($0.displayName)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }

            if executionType == .schedule {
                VStack(alignment: .leading, spacing: 4) {
                    Text(L.dateTime)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    DatePicker("", selection: $scheduleDate, displayedComponents: [.date, .hourAndMinute])
                        .labelsHidden()
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(L.commandRepeat)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Picker("", selection: $repeatType) {
                        ForEach(RepeatType.allCases, id: \.self) {
                            Text($0.displayName)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(L.commandReminders)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 12) {
                        Toggle("5" + L.minutesUnit, isOn: $remind5min)
                            .toggleStyle(.checkbox)
                            .disabled(!canRemind(seconds: 300))
                        Toggle("30" + L.minutesUnit, isOn: $remind30min)
                            .toggleStyle(.checkbox)
                            .disabled(!canRemind(seconds: 1800))
                        Toggle("1" + L.hoursUnit, isOn: $remind1hour)
                            .toggleStyle(.checkbox)
                            .disabled(!canRemind(seconds: 3600))
                        Toggle("1" + L.daysUnit, isOn: $remind1day)
                            .toggleStyle(.checkbox)
                            .disabled(!canRemind(seconds: 86400))
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    Text(L.commandInput)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextEditor(text: $commandText)
                        .font(.body.monospaced())
                        .frame(height: 80)
                        .padding(4)
                        .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.gray.opacity(0.3)))
                    if executionType == .script {
                        Button(action: { showParamHelp = true }) {
                            Text(L.commandHelpText)
                                .font(.caption)
                                .foregroundStyle(.blue)
                        }
                        .buttonStyle(.plain)
                    }
                }

                if executionType == .terminal {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(L.terminalAppLabel)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Picker("", selection: $terminalApp) {
                            ForEach(TerminalApp.allCases, id: \.self) {
                                Text($0.rawValue)
                            }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                    }
                } else if executionType == .background {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(L.intervalLabel)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("", text: $interval)
                            .textFieldStyle(.roundedBorder)
                        HStack(spacing: 4) {
                            ForEach([("10분", 600), ("1시간", 3600), ("6시간", 21600), ("12시간", 43200), ("24시간", 86400), ("7일", 604800)], id: \.0) { label, seconds in
                                Button(label) {
                                    interval = String(seconds)
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                        }
                    }
                }
                // script는 명령어만
            }

            HStack {
                Button(L.buttonCancel) {
                    dismiss()
                }
                .buttonStyle(HoverTextButtonStyle())
                Spacer()
                Button(L.buttonSave) {
                    var updated = command
                    updated.title = title
                    updated.command = commandText
                    updated.executionType = executionType
                    updated.terminalApp = terminalApp
                    updated.interval = Int(interval) ?? 0
                    updated.scheduleDate = executionType == .schedule ? scheduleDate : nil
                    updated.repeatType = repeatType
                    updated.reminderTimes = reminderTimes
                    store.update(updated)
                    dismiss()
                }
                .buttonStyle(HoverTextButtonStyle())
                .disabled(!isValid)
            }
        }
        .padding()
        .frame(width: 350)
        .sheet(isPresented: $showParamHelp) {
            ParameterHelpView()
        }
    }
}

@main
struct CommandBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 280, minHeight: 300)
        }
        .windowStyle(.titleBar)
        .defaultSize(width: 300, height: 400)
    }
}
