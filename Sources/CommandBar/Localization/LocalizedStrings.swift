import Foundation

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
    var hideWindow: String
    var showWindow: String
    var snapToLeft: String
    var snapToRight: String
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
    var settingsAutoHide: String
    var settingsHideOpacity: String
    var settingsDoubleClickToRun: String
    var settingsScrollMode: String
    var settingsInfiniteScroll: String
    var settingsPaging: String
    var settingsPageSize: String
    var buttonLoadMore: String
    var shortcutConflict: String
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
    var trashRestore: String

    // 명령
    var commandTitle: String
    var commandLabel: String
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
    var historyExecutions: String
    var historyShowRaw: String

    // 검색
    var searchPlaceholder: String

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

    // 배지 편집
    var badgeEditTitle: String
    var badgeEditLabel: String
    var badgeEditUseJsonPath: String
    var badgeEditJsonPath: String
    var badgeEditJsonPathHint: String
    var badgeEditActualValue: String
    var badgeEditActualValueHint: String
    var badgeEditEditStorageFormat: String
    var badgeEditStorageFormat: String
    var badgeEditStorageFormatHint: String
    var badgeEditConnectedCommands: String
    var badgeEditSecureValueHint: String
    var badgeEditVariableValueHint: String

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
    var contextMenuCopyId: String
    var helpSyntax: String
    var parameter: String
    var timeAfter: String
    var timePassed: String
    var clipboardContent: String

    // 그룹
    var groupTitle: String
    var groupAll: String
    var groupDefault: String
    var groupAddNew: String
    var groupEdit: String
    var groupNamePlaceholder: String
    var groupDeleteConfirm: String
    var groupCannotDeleteDefault: String
    var moveToGroup: String
    var groupColor: String
    var groupDeleteTitle: String
    var groupDeleteMerge: String
    var groupDeleteWithCommands: String
    var groupSelectTarget: String
    var groupLastGroupCannotDelete: String
    var groupNoGroups: String
    var groupCommandCount: String

    // 즐겨찾기
    var favoriteAdd: String
    var favoriteRemove: String

    // 클립보드 등록 모달
    var registerClipboardTitle: String
    var registerClipboardPosition: String
    var registerClipboardPositionTop: String
    var registerClipboardPositionBottom: String
    var registerClipboardRegister: String

    // API 요청
    var apiRequestTitle: String
    var apiEndpoint: String
    var apiMethod: String
    var apiHeaders: String
    var apiQueryParams: String
    var apiBodyType: String
    var apiBodyData: String
    var apiResponse: String
    var apiStatusCode: String
    var apiAddHeader: String
    var apiAddParam: String
    var apiExecute: String
    var apiLastExecuted: String
    var apiNoResponse: String
    var apiLoading: String
    var apiAddNew: String
    var apiResponseHeaders: String
    var apiResponseBody: String
    var apiExecutionTime: String
    var apiRequestInfo: String
    var apiCopyResponse: String

    // API 환경
    var envManagerTitle: String
    var envAddEnvironment: String
    var envAddVariable: String
    var envExport: String
    var envImport: String
    var envNoEnvironments: String
    var envAddFirst: String
    var envNoVariables: String
    var envAddFirstVariable: String
    var envVariable: String
    var envActiveEnvironment: String
    var envClear: String
    var envEdit: String
    var envDelete: String
    var envName: String
    var envColor: String
    var envVariableName: String
    var envTitle: String
    var envSelectEnvironment: String
    var envManage: String

    // 사이드바 모드
    var sidebarModeActive: String
    var sidebarModeInactive: String
    var accessibilityPermissionTitle: String
    var accessibilityPermissionMessage: String
    var accessibilityOpenSettings: String
}
