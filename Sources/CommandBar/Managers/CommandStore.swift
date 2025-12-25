import SwiftUI
import AppKit

class CommandStore: ObservableObject {
    static let defaultGroupId = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!

    @Published var commands: [Command] = []
    @Published var groups: [Group] = []
    @Published var alertingCommandId: UUID?  // 현재 알림 중인 명령
    @Published var history: [HistoryItem] = []
    @Published var clipboardItems: [ClipboardItem] = []

    // API 환경 관리
    @Published var environments: [APIEnvironment] = []
    @Published var activeEnvironmentId: UUID? = nil

    // 페이징 상태
    @Published var historyPage: Int = 0
    @Published var clipboardPage: Int = 0
    @Published var historyTotalCount: Int = 0
    @Published var clipboardTotalCount: Int = 0

    var historyTotalPages: Int {
        let pageSize = Settings.shared.pageSize
        return max(1, (historyTotalCount + pageSize - 1) / pageSize)
    }
    var clipboardTotalPages: Int {
        let pageSize = Settings.shared.pageSize
        return max(1, (clipboardTotalCount + pageSize - 1) / pageSize)
    }
    var hasMoreHistory: Bool { historyPage < historyTotalPages - 1 }
    var hasMoreClipboard: Bool { clipboardPage < clipboardTotalPages - 1 }

    private var scheduleCheckTimer: Timer?
    private var backgroundCheckTimer: Timer?
    private var clipboardTimer: Timer?
    private var lastClipboardChangeCount: Int = 0

    private let configDir = URL(fileURLWithPath: NSHomeDirectory())
        .appendingPathComponent(".command_bar")
    private var url: URL { configDir.appendingPathComponent("app.json") }
    private var groupsUrl: URL { configDir.appendingPathComponent("groups.json") }
    private var historyUrl: URL { configDir.appendingPathComponent("history.json") }
    private var clipboardUrl: URL { configDir.appendingPathComponent("clipboard.json") }

    private let db = Database.shared

    init() {
        ensureConfigDir()
        migrateOldFiles()
        migrateJsonToDb()
        load()
        loadHistory()
        loadClipboard()
        loadEnvironments()
        startBackgroundChecker()
        startScheduleChecker()
        startClipboardMonitor()

        // 잠자기에서 깨어났을 때
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleSystemResume()
        }

        // 화면이 켜졌을 때
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.screensDidWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleSystemResume()
        }

        // 앱이 활성화될 때
        NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleSystemResume()
        }
    }

    func handleSystemResume() {
        // 백그라운드 체커가 중지되었으면 재시작
        if backgroundCheckTimer == nil || !backgroundCheckTimer!.isValid {
            startBackgroundChecker()
        }
        // 스케줄 체커가 중지되었으면 재시작
        if scheduleCheckTimer == nil || !scheduleCheckTimer!.isValid {
            startScheduleChecker()
        }
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

    private func migrateJsonToDb() {
        guard db.needsMigration() else { return }

        // Migrate groups
        if let groupsData = try? Data(contentsOf: groupsUrl),
           let decodedGroups = try? JSONDecoder().decode([Group].self, from: groupsData) {
            db.saveGroups(decodedGroups)
        }

        // Migrate commands
        if let data = try? Data(contentsOf: url),
           let decoded = try? JSONDecoder().decode([Command].self, from: data) {
            db.saveCommands(decoded)
        }

        // Migrate history
        if let historyData = try? Data(contentsOf: historyUrl),
           let decodedHistory = try? JSONDecoder().decode([HistoryItem].self, from: historyData) {
            for item in decodedHistory {
                db.addHistory(item)
            }
        }

        // Migrate clipboard
        if let clipboardData = try? Data(contentsOf: clipboardUrl),
           let decodedClipboard = try? JSONDecoder().decode([ClipboardItem].self, from: clipboardData) {
            for item in decodedClipboard {
                db.addClipboard(item)
            }
        }

        // Rename old JSON files to .bak
        try? FileManager.default.moveItem(at: url, to: url.appendingPathExtension("bak"))
        try? FileManager.default.moveItem(at: groupsUrl, to: groupsUrl.appendingPathExtension("bak"))
        try? FileManager.default.moveItem(at: historyUrl, to: historyUrl.appendingPathExtension("bak"))
        try? FileManager.default.moveItem(at: clipboardUrl, to: clipboardUrl.appendingPathExtension("bak"))
    }

    func addHistory(_ item: HistoryItem) {
        // 지금! 알림은 같은 명령 ID면 병합
        if item.type == .scheduleAlert, let cmdId = item.commandId {
            if var existing = db.findHistoryByCommandId(cmdId, type: .scheduleAlert) {
                existing.count += 1
                existing.endTimestamp = item.timestamp
                existing.timestamp = item.timestamp
                db.updateHistory(existing)
                loadHistory()
                return
            }
        }

        // 같은 title + command + type이 있으면 카운트 증가 및 최상단 이동
        if db.historyExistsAndUpdate(title: item.title, command: item.command, type: item.type) {
            loadHistory()
            return
        }

        // 새로운 히스토리 추가
        var newItem = item
        newItem.firstExecutedAt = item.firstExecutedAt ?? Date()
        db.addHistory(newItem)

        // 첫 실행 이력도 추가
        db.addHistoryExecution(historyId: newItem.id.uuidString, executedAt: Date())

        loadHistory()
    }

    func loadHistory() {
        let pageSize = Settings.shared.pageSize
        historyPage = 0
        historyTotalCount = db.getHistoryCount()
        history = db.loadHistory(limit: pageSize, offset: 0)
    }

    func loadMoreHistory() {
        guard hasMoreHistory else { return }
        let pageSize = Settings.shared.pageSize
        historyPage += 1
        let newItems = db.loadHistory(limit: pageSize, offset: historyPage * pageSize)
        history.append(contentsOf: newItems)
    }

    func goToHistoryPage(_ page: Int) {
        guard page >= 0 && page < historyTotalPages else { return }
        let pageSize = Settings.shared.pageSize
        historyPage = page
        history = db.loadHistory(limit: pageSize, offset: page * pageSize)
    }

    func searchHistory(query: String, startDate: Date? = nil, endDate: Date? = nil) {
        historyPage = 0
        historyTotalCount = 0
        history = db.searchHistory(query: query, startDate: startDate, endDate: endDate)
    }

    func clearHistory() {
        db.clearHistory()
        history.removeAll()
        historyPage = 0
        historyTotalCount = 0
    }

    func deleteHistory(_ item: HistoryItem) {
        db.softDeleteHistory(id: item.id.uuidString)
        history.removeAll { $0.id == item.id }
        historyTotalCount = max(0, historyTotalCount - 1)
    }

    // 클립보드 관련
    func loadClipboard() {
        let pageSize = Settings.shared.pageSize
        clipboardPage = 0
        clipboardTotalCount = db.getClipboardCount()
        clipboardItems = db.loadClipboard(limit: pageSize, offset: 0)
    }

    func loadMoreClipboard() {
        guard hasMoreClipboard else { return }
        let pageSize = Settings.shared.pageSize
        clipboardPage += 1
        let newItems = db.loadClipboard(limit: pageSize, offset: clipboardPage * pageSize)
        clipboardItems.append(contentsOf: newItems)
    }

    func goToClipboardPage(_ page: Int) {
        guard page >= 0 && page < clipboardTotalPages else { return }
        let pageSize = Settings.shared.pageSize
        clipboardPage = page
        clipboardItems = db.loadClipboard(limit: pageSize, offset: page * pageSize)
    }

    func searchClipboard(query: String, startDate: Date? = nil, endDate: Date? = nil) {
        clipboardPage = 0
        clipboardTotalCount = 0
        clipboardItems = db.searchClipboard(query: query, startDate: startDate, endDate: endDate)
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

        // 중복 체크 및 업데이트 (trim 기준)
        if db.clipboardExistsAndUpdate(content) {
            // 중복이면 카운트 증가 + 최상단 이동 완료
            loadClipboard()
            return
        }

        // 신규 항목 추가
        let item = ClipboardItem(content: content)
        db.addClipboard(item)
        loadClipboard()
    }

    func removeClipboardItem(_ item: ClipboardItem) {
        db.softDeleteClipboard(id: item.id.uuidString)
        clipboardItems.removeAll { $0.id == item.id }
        clipboardTotalCount = max(0, clipboardTotalCount - 1)
    }

    func updateClipboardContent(_ item: ClipboardItem, newContent: String) {
        // {encrypt:xxx} → {secure:refId} 변환
        let processResult = SecureValueManager.shared.processForSave(newContent)
        db.updateClipboardContent(id: item.id, content: processResult.text)
        // 로컬 상태 업데이트
        if let index = clipboardItems.firstIndex(where: { $0.id == item.id }) {
            clipboardItems[index] = ClipboardItem(
                id: item.id,
                timestamp: item.timestamp,
                content: processResult.text,
                isFavorite: item.isFavorite,
                copyCount: item.copyCount,
                firstCopiedAt: item.firstCopiedAt
            )
        }
    }

    func clearClipboard() {
        db.clearClipboard()
        clipboardItems.removeAll()
        clipboardPage = 0
        clipboardTotalCount = 0
    }

    func registerClipboardAsCommand(_ item: ClipboardItem, asLast: Bool = true, groupId: UUID = CommandStore.defaultGroupId, terminalApp: TerminalApp = .iterm2) {
        let firstLine = item.content.components(separatedBy: .newlines).first ?? item.content
        let title = String(firstLine.prefix(50))
        let cmd = Command(
            groupId: groupId,
            title: title,
            command: item.content,
            executionType: .terminal,
            terminalApp: terminalApp
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

    func executeAPICommand(_ command: Command) async -> (data: Data?, response: URLResponse?, error: Error?) {
        // {secure:refId} → 복호화된 값으로 치환
        var processedCommand = command.withSecureValuesResolved()

        // 환경 변수 치환
        if let env = activeEnvironment {
            processedCommand = processedCommand.withEnvironmentVariables(env.variables)
        }

        // API 체이닝 참조 치환
        processedCommand = processedCommand.withAPIChainValues { [weak self] commandId, jsonPath in
            self?.getValueFromAPIResponse(commandId: commandId, jsonPath: jsonPath)
        }

        // URL 생성 (queryParams 적용)
        var urlComponents = URLComponents(string: processedCommand.url)
        if !processedCommand.queryParams.isEmpty {
            urlComponents?.queryItems = processedCommand.queryParams.map { URLQueryItem(name: $0.key, value: $0.value) }
        }

        guard let finalURL = urlComponents?.url else {
            let error = NSError(domain: "CommandStore", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
            return (nil, nil, error)
        }

        // URLRequest 생성
        var urlRequest = URLRequest(url: finalURL)

        // httpMethod 설정
        urlRequest.httpMethod = processedCommand.httpMethod.rawValue

        // headers 적용
        for (key, value) in processedCommand.headers {
            urlRequest.setValue(value, forHTTPHeaderField: key)
        }

        // body 설정 (bodyType에 따라)
        switch processedCommand.bodyType {
        case .none:
            break
        case .json:
            if !processedCommand.bodyData.isEmpty {
                urlRequest.httpBody = processedCommand.bodyData.data(using: .utf8)
                if processedCommand.headers["Content-Type"] == nil {
                    urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
                }
            }
        case .formData:
            if !processedCommand.bodyData.isEmpty {
                urlRequest.httpBody = processedCommand.bodyData.data(using: .utf8)
                if processedCommand.headers["Content-Type"] == nil {
                    urlRequest.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
                }
            }
        case .multipart:
            let boundary = UUID().uuidString
            urlRequest.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

            var body = Data()

            // 텍스트 파라미터 추가 (bodyData를 JSON으로 파싱)
            if !processedCommand.bodyData.isEmpty {
                if let jsonData = processedCommand.bodyData.data(using: .utf8),
                   let textParams = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
                    for (key, value) in textParams {
                        body.append("--\(boundary)\r\n".data(using: .utf8)!)
                        body.append("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n".data(using: .utf8)!)
                        body.append("\(value)\r\n".data(using: .utf8)!)
                    }
                }
            }

            // 파일 파라미터 추가
            for (key, filePath) in processedCommand.fileParams {
                let fileURL = URL(fileURLWithPath: filePath)
                let fileName = fileURL.lastPathComponent
                let mimeType = getMimeType(for: fileURL)

                guard let fileData = try? Data(contentsOf: fileURL) else {
                    let error = NSError(domain: "CommandStore", code: -2, userInfo: [NSLocalizedDescriptionKey: "Failed to read file: \(filePath)"])
                    return (nil, nil, error)
                }

                body.append("--\(boundary)\r\n".data(using: .utf8)!)
                body.append("Content-Disposition: form-data; name=\"\(key)\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
                body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
                body.append(fileData)
                body.append("\r\n".data(using: .utf8)!)
            }

            body.append("--\(boundary)--\r\n".data(using: .utf8)!)
            urlRequest.httpBody = body
        }

        // URLSession으로 실행
        do {
            let (data, response) = try await URLSession.shared.data(for: urlRequest)

            // 결과 반환 및 command 업데이트 (lastResponse, lastStatusCode, lastExecutedAt)
            await MainActor.run {
                if let i = commands.firstIndex(where: { $0.id == command.id }) {
                    commands[i].lastExecutedAt = Date()

                    if let httpResponse = response as? HTTPURLResponse {
                        commands[i].lastStatusCode = httpResponse.statusCode
                    }

                    if let responseString = String(data: data, encoding: .utf8) {
                        commands[i].lastResponse = responseString
                    }

                    save()
                }
            }

            return (data, response, nil)
        } catch {
            // 에러 업데이트
            await MainActor.run {
                if let i = commands.firstIndex(where: { $0.id == command.id }) {
                    commands[i].lastExecutedAt = Date()
                    commands[i].lastResponse = "Error: \(error.localizedDescription)"
                    commands[i].lastStatusCode = nil
                    save()
                }
            }

            return (nil, nil, error)
        }
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

    func startBackgroundChecker() {
        backgroundCheckTimer?.invalidate()
        backgroundCheckTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.checkBackgroundCommands()
        }
    }

    func checkBackgroundCommands() {
        let now = Date()
        for cmd in commands where cmd.executionType == .background && cmd.interval > 0 && !cmd.isInTrash && !cmd.isRunning {
            let shouldRun: Bool
            if let lastRun = cmd.lastExecutedAt {
                let elapsed = now.timeIntervalSince(lastRun)
                shouldRun = elapsed >= TimeInterval(cmd.interval)
            } else {
                // 처음 실행
                shouldRun = true
            }

            if shouldRun {
                runInBackground(cmd)
            }
        }
    }

    func load() {
        // Load groups first
        groups = db.loadGroups()
        ensureDefaultGroup()

        // Load commands
        commands = db.loadCommands()

        // Migration: assign default group ID to commands without groupId or with invalid groupId
        let validGroupIds = Set(groups.map { $0.id })
        var needsSave = false
        commands = commands.map { cmd in
            var updatedCmd = cmd
            if !validGroupIds.contains(updatedCmd.groupId) {
                updatedCmd.groupId = Self.defaultGroupId
                needsSave = true
            }
            return updatedCmd
        }
        if needsSave {
            save()
        }
    }

    func save() {
        db.saveCommands(commands)
        db.saveGroups(groups)
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
        // {secure:xxx} → {🔒:refId} 변환
        newCmd.command = SecureValueManager.shared.processForSave(newCmd.command).text
        newCmd.url = SecureValueManager.shared.processForSave(newCmd.url).text
        newCmd.bodyData = SecureValueManager.shared.processForSave(newCmd.bodyData).text
        // 헤더 값도 처리
        newCmd.headers = newCmd.headers.mapValues { SecureValueManager.shared.processForSave($0).text }
        commands.append(newCmd)
        save()
        if cmd.executionType == .background && cmd.interval > 0 {
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

    func restoreFromTrash(_ cmd: Command, toGroupId: UUID? = nil) {
        if let i = commands.firstIndex(where: { $0.id == cmd.id }) {
            commands[i].isInTrash = false
            // 그룹 ID 지정 시 변경, 아니면 기존 그룹이 유효한지 확인
            if let groupId = toGroupId {
                commands[i].groupId = groupId
            } else if !groups.contains(where: { $0.id == commands[i].groupId }) {
                // 기존 그룹이 삭제된 경우 기본 그룹으로
                commands[i].groupId = CommandStore.defaultGroupId
            }
            save()
            if commands[i].executionType == .background && commands[i].interval > 0 {
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
            var updated = cmd
            updated.command = normalizeQuotes(cmd.command)
            // {secure:xxx} → {🔒:refId} 변환
            updated.command = SecureValueManager.shared.processForSave(updated.command).text
            updated.url = SecureValueManager.shared.processForSave(updated.url).text
            updated.bodyData = SecureValueManager.shared.processForSave(updated.bodyData).text
            updated.headers = updated.headers.mapValues { SecureValueManager.shared.processForSave($0).text }
            commands[i] = updated
            commands[i].alertedTimes = []  // 알림 상태 초기화
            commands[i].alertState = .none
            commands[i].acknowledged = false
            save()
            if cmd.executionType == .background && cmd.interval > 0 {
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

    func toggleFavorite(_ command: Command) {
        if let index = commands.firstIndex(where: { $0.id == command.id }) {
            commands[index].isFavorite.toggle()
            DispatchQueue.global(qos: .background).async { [weak self] in
                self?.save()
            }
        }
    }

    func toggleClipboardFavorite(_ item: ClipboardItem) {
        if let index = clipboardItems.firstIndex(where: { $0.id == item.id }) {
            clipboardItems[index].isFavorite = db.toggleClipboardFavorite(item.id)
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
        case .api:
            Task {
                await executeAPICommand(cmd)
            }
        }
    }

    private func runInTerminal(_ cmd: Command, app: String) {
        // {secure:refId} → 복호화된 값으로 치환
        let resolvedCommand = SecureValueManager.shared.processForExecution(cmd.command)
        let escaped = resolvedCommand.replacingOccurrences(of: "\"", with: "\\\"")
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

        // {secure:refId} → 복호화된 값으로 치환
        let resolvedCommand = SecureValueManager.shared.processForExecution(cmd.command)

        DispatchQueue.global(qos: .userInitiated).async {
            let process = Process()
            let pipe = Pipe()

            process.executableURL = URL(fileURLWithPath: "/bin/zsh")
            process.arguments = ["-c", resolvedCommand]
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

    // MARK: - 그룹 관리

    func addGroup(_ group: Group) {
        groups.append(group)
        save()
    }

    func updateGroup(_ group: Group) {
        if let i = groups.firstIndex(where: { $0.id == group.id }) {
            groups[i] = group
            save()
        }
    }

    func deleteGroup(_ group: Group) {
        // 마지막 그룹은 삭제 불가
        guard groups.count > 1 else { return }
        // 기본 그룹은 삭제 불가
        guard group.id != Self.defaultGroupId else { return }
        // 해당 그룹 명령어들을 기본 그룹으로 이동
        for i in commands.indices where commands[i].groupId == group.id {
            commands[i].groupId = Self.defaultGroupId
        }
        groups.removeAll { $0.id == group.id }
        save()
    }

    func deleteGroupWithCommands(_ group: Group) {
        // 마지막 그룹은 삭제 불가
        guard groups.count > 1 else { return }
        // 기본 그룹은 삭제 불가
        guard group.id != Self.defaultGroupId else { return }
        // 해당 그룹의 명령어들을 휴지통으로 이동
        for i in commands.indices where commands[i].groupId == group.id {
            commands[i].isInTrash = true
        }
        groups.removeAll { $0.id == group.id }
        save()
    }

    func deleteGroupAndMerge(_ group: Group, to targetGroupId: UUID) {
        // 마지막 그룹은 삭제 불가
        guard groups.count > 1 else { return }
        // 기본 그룹은 삭제 불가
        guard group.id != Self.defaultGroupId else { return }
        // 해당 그룹의 명령어들을 다른 그룹으로 이동
        for i in commands.indices where commands[i].groupId == group.id {
            commands[i].groupId = targetGroupId
        }
        groups.removeAll { $0.id == group.id }
        save()
    }

    func moveToGroup(_ command: Command, groupId: UUID) {
        if let i = commands.firstIndex(where: { $0.id == command.id }) {
            commands[i].groupId = groupId
            save()
        }
    }

    func itemsForGroup(_ groupId: UUID?) -> [Command] {
        let active = commands.filter { !$0.isInTrash }
        guard let gid = groupId else { return active }
        return active.filter { $0.groupId == gid }
    }

    func ensureDefaultGroup() {
        if groups.isEmpty || !groups.contains(where: { $0.id == Self.defaultGroupId }) {
            let defaultGroup = Group(
                id: Self.defaultGroupId,
                name: L.groupDefault,
                color: "gray",
                order: 0
            )
            groups.insert(defaultGroup, at: 0)
            save()
        }
    }

    // MARK: - 환경 관리

    var activeEnvironment: APIEnvironment? {
        guard let id = activeEnvironmentId else { return nil }
        return environments.first { $0.id == id }
    }

    /// 모든 환경 변수 이름 목록 (자동완성용)
    var allEnvironmentVariableNames: [String] {
        var names = Set<String>()
        for env in environments {
            for key in env.variables.keys {
                names.insert(key)
            }
        }
        return names.sorted()
    }

    func loadEnvironments() {
        environments = db.loadEnvironments()
        // 활성 환경 ID 로드
        if let idStr = db.getSetting("activeEnvironmentId"),
           let id = UUID(uuidString: idStr) {
            activeEnvironmentId = id
        }
    }

    func saveEnvironments() {
        db.saveEnvironments(environments)
        // 활성 환경 ID 저장
        if let id = activeEnvironmentId {
            db.setSetting("activeEnvironmentId", value: id.uuidString)
        } else {
            db.setSetting("activeEnvironmentId", value: "")
        }
    }

    func addEnvironment(_ env: APIEnvironment) {
        environments.append(env)
        saveEnvironments()
    }

    func updateEnvironment(_ env: APIEnvironment) {
        if let i = environments.firstIndex(where: { $0.id == env.id }) {
            environments[i] = env
            saveEnvironments()
        }
    }

    func deleteEnvironment(_ env: APIEnvironment) {
        environments.removeAll { $0.id == env.id }
        if activeEnvironmentId == env.id {
            activeEnvironmentId = nil
        }
        saveEnvironments()
    }

    func setActiveEnvironment(_ env: APIEnvironment?) {
        activeEnvironmentId = env?.id
        saveEnvironments()
    }

    /// 환경 데이터 내보내기
    func exportEnvironments() -> Data? {
        let exportData = EnvironmentExportData(
            environments: environments,
            variableGroups: []
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try? encoder.encode(exportData)
    }

    /// 환경 데이터 가져오기
    func importEnvironments(_ data: Data, merge: Bool) -> Bool {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let imported = try? decoder.decode(EnvironmentExportData.self, from: data) else {
            return false
        }

        if merge {
            // 병합: 기존 ID와 겹치면 새 ID 부여
            let existingIds = Set(environments.map { $0.id })
            for var env in imported.environments {
                if existingIds.contains(env.id) {
                    env.id = UUID()
                }
                environments.append(env)
            }
        } else {
            // 덮어쓰기
            environments = imported.environments
            activeEnvironmentId = nil
        }

        saveEnvironments()
        return true
    }

    /// 다른 API 응답에서 값 추출 (API 체이닝)
    func getValueFromAPIResponse(commandId: UUID, jsonPath: String?) -> String? {
        guard let cmd = commands.first(where: { $0.id == commandId }),
              let response = cmd.lastResponse else {
            return nil
        }

        // jsonPath가 없으면 전체 응답 반환
        guard let path = jsonPath, !path.isEmpty else {
            return response
        }

        // JSON 파싱 후 경로 추출
        guard let data = response.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) else {
            return nil
        }

        return extractValueFromJSON(json, path: path)
    }

    private func extractValueFromJSON(_ json: Any, path: String) -> String? {
        let components = path.split(separator: ".").map { String($0) }
        var current: Any = json

        for component in components {
            // 배열 인덱스 처리 (예: items[0])
            if let match = component.range(of: #"\[(\d+)\]$"#, options: .regularExpression) {
                let key = String(component[..<match.lowerBound])
                let indexStr = String(component[match]).dropFirst().dropLast()
                guard let index = Int(indexStr) else { return nil }

                if !key.isEmpty {
                    guard let dict = current as? [String: Any],
                          let next = dict[key] else { return nil }
                    current = next
                }

                guard let array = current as? [Any],
                      index < array.count else { return nil }
                current = array[index]
            } else {
                guard let dict = current as? [String: Any],
                      let next = dict[component] else { return nil }
                current = next
            }
        }

        // 최종 값을 문자열로 변환
        if let str = current as? String {
            return str
        } else if let num = current as? NSNumber {
            return num.stringValue
        } else if let data = try? JSONSerialization.data(withJSONObject: current),
                  let str = String(data: data, encoding: .utf8) {
            return str
        }
        return nil
    }

    // MARK: - Multipart Helper

    private func getMimeType(for url: URL) -> String {
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "jpg", "jpeg": return "image/jpeg"
        case "png": return "image/png"
        case "gif": return "image/gif"
        case "pdf": return "application/pdf"
        case "json": return "application/json"
        case "txt": return "text/plain"
        default: return "application/octet-stream"
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
            commands = imported.commands.map { cmd in
                var c = cmd
                c.isRunning = false
                c.alertedTimes = []
                c.acknowledged = false
                return c
            }
        }

        save()
        return true
    }

    // MARK: - ID Suggestions for Autocomplete

    /// 모든 항목의 shortId와 제목 목록 (자동완성용)
    var allIdSuggestions: [(id: String, title: String)] {
        let shortIds = db.getAllShortIds()
        var result: [(id: String, title: String)] = []

        for item in shortIds {
            switch item.type {
            case "command":
                if let uuid = UUID(uuidString: item.fullId),
                   let cmd = commands.first(where: { $0.id == uuid && !$0.isInTrash }) {
                    result.append((id: item.shortId, title: cmd.title))
                }
            case "clipboard":
                if let uuid = UUID(uuidString: item.fullId),
                   let clip = clipboardItems.first(where: { $0.id == uuid }) {
                    let preview = String(clip.content.prefix(30)).replacingOccurrences(of: "\n", with: " ")
                    result.append((id: item.shortId, title: preview))
                }
            default:
                break
            }
        }
        return result
    }

    /// shortId로 full UUID 조회
    func getFullId(shortId: String) -> UUID? {
        if let fullIdStr = db.getFullId(shortId: shortId) {
            return UUID(uuidString: fullIdStr)
        }
        return nil
    }

    /// full UUID로 shortId 조회
    func getShortId(fullId: UUID) -> String? {
        return db.getShortId(fullId: fullId.uuidString)
    }

    /// 새 항목에 대한 shortId 생성 및 등록
    func registerShortId(for fullId: UUID, type: String) -> String {
        // 이미 등록되어 있으면 기존 shortId 반환
        if let existing = db.getShortId(fullId: fullId.uuidString) {
            return existing
        }
        let shortId = db.generateUniqueShortId()
        db.insertShortId(shortId: shortId, fullId: fullId.uuidString, type: type)
        return shortId
    }

    // MARK: - ID Chaining

    /// 문자열에서 {id:xxx} 또는 {id:xxx|path} 참조를 처리하여 값으로 치환
    func resolveIdReferences(in text: String) -> String {
        // {id:xxx} 또는 {id:xxx|path} 패턴
        guard let regex = try? NSRegularExpression(pattern: "\\{id:([^}|]+)(?:\\|([^}]+))?\\}") else {
            return text
        }

        var result = text
        let range = NSRange(text.startIndex..., in: text)
        let matches = regex.matches(in: text, range: range).reversed()  // 뒤에서부터 치환

        for match in matches {
            guard let fullRange = Range(match.range, in: result),
                  let shortIdRange = Range(match.range(at: 1), in: result) else { continue }

            let shortId = String(result[shortIdRange])
            let jsonPath: String?
            if match.numberOfRanges > 2, let pathRange = Range(match.range(at: 2), in: result) {
                jsonPath = String(result[pathRange])
            } else {
                jsonPath = nil
            }

            if let value = getValueFromId(shortId: shortId, jsonPath: jsonPath) {
                result.replaceSubrange(fullRange, with: value)
            }
        }

        return result
    }

    /// shortId로 값 조회 (Command의 lastOutput/lastResponse 또는 ClipboardItem의 content)
    func getValueFromId(shortId: String, jsonPath: String?) -> String? {
        guard let fullIdStr = db.getFullId(shortId: shortId),
              let fullId = UUID(uuidString: fullIdStr) else { return nil }

        // Command에서 찾기
        if let cmd = commands.first(where: { $0.id == fullId }) {
            let response: String?
            if cmd.executionType == .api {
                response = cmd.lastResponse
            } else {
                response = cmd.lastOutput
            }

            guard let resp = response else { return nil }

            // jsonPath가 있으면 JSON에서 값 추출
            if let path = jsonPath, !path.isEmpty {
                return extractValueFromJSON(resp, path: path)
            }
            return resp
        }

        // ClipboardItem에서 찾기
        if let clip = clipboardItems.first(where: { $0.id == fullId }) {
            // jsonPath가 있으면 JSON에서 값 추출 시도
            if let path = jsonPath, !path.isEmpty {
                return extractValueFromJSON(clip.content, path: path)
            }
            return clip.content
        }

        return nil
    }

    /// JSON 문자열에서 경로로 값 추출
    private func extractValueFromJSON(_ jsonString: String, path: String) -> String? {
        guard let data = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) else { return nil }

        let components = path.split(separator: ".").map { String($0) }
        var current: Any = json

        for component in components {
            if let dict = current as? [String: Any], let next = dict[component] {
                current = next
            } else if let arr = current as? [Any], let index = Int(component), index < arr.count {
                current = arr[index]
            } else {
                return nil
            }
        }

        if let str = current as? String {
            return str
        } else if let num = current as? NSNumber {
            return num.stringValue
        } else if let bool = current as? Bool {
            return bool ? "true" : "false"
        }
        return nil
    }

    /// 문자열에서 {var:xxx} 참조를 환경 변수 값으로 치환
    func resolveVarReferences(in text: String) -> String {
        guard let env = activeEnvironment else { return text }

        // {var:xxx} 패턴
        guard let regex = try? NSRegularExpression(pattern: "\\{var:([^}]+)\\}") else {
            return text
        }

        var result = text
        let range = NSRange(text.startIndex..., in: text)
        let matches = regex.matches(in: text, range: range).reversed()

        for match in matches {
            guard let fullRange = Range(match.range, in: result),
                  let varNameRange = Range(match.range(at: 1), in: result) else { continue }

            let varName = String(result[varNameRange])
            if let value = env.variables[varName] {
                result.replaceSubrange(fullRange, with: value)
            }
        }

        return result
    }

    // MARK: - 휴지통 (Trash)

    @Published var trashHistory: [HistoryItem] = []
    @Published var trashClipboard: [ClipboardItem] = []
    @Published var trashHistoryCount: Int = 0
    @Published var trashClipboardCount: Int = 0

    func loadTrash() {
        trashHistory = db.loadTrashHistory(limit: 100, offset: 0)
        trashClipboard = db.loadTrashClipboard(limit: 100, offset: 0)
        trashHistoryCount = db.getTrashHistoryCount()
        trashClipboardCount = db.getTrashClipboardCount()
    }

    func restoreHistoryItem(_ item: HistoryItem) {
        db.restoreHistory(id: item.id.uuidString)
        trashHistory.removeAll { $0.id == item.id }
        trashHistoryCount = max(0, trashHistoryCount - 1)
        loadHistory()
    }

    func restoreClipboardItem(_ item: ClipboardItem) {
        db.restoreClipboard(id: item.id.uuidString)
        trashClipboard.removeAll { $0.id == item.id }
        trashClipboardCount = max(0, trashClipboardCount - 1)
        loadClipboard()
    }

    func emptyTrashHistory() {
        db.emptyTrashHistory()
        trashHistory.removeAll()
        trashHistoryCount = 0
    }

    func emptyTrashClipboard() {
        db.emptyTrashClipboard()
        trashClipboard.removeAll()
        trashClipboardCount = 0
    }

    func emptyAllTrash() {
        db.emptyAllTrash()
        trashHistory.removeAll()
        trashClipboard.removeAll()
        trashHistoryCount = 0
        trashClipboardCount = 0
    }
}
