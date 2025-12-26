import SwiftUI
import AppKit

class CommandStore: ObservableObject {
    static let defaultGroupSeq: Int = 1

    @Published var commands: [Command] = []
    @Published var groups: [Group] = []
    @Published var alertingCommandId: String?  // 현재 알림 중인 명령
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
        // 지금! 알림은 같은 명령 seq면 병합
        if item.type == .scheduleAlert, let cmdSeq = item.commandSeq {
            if var existing = db.findHistoryByCommandSeq(cmdSeq, type: .scheduleAlert) {
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
        db.addHistoryExecution(historyId: newItem.id, executedAt: Date())

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
        db.softDeleteHistory(id: item.id)
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
        db.softDeleteClipboard(id: item.id)
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
                seq: item.seq,
                id: item.id,
                content: processResult.text,
                timestamp: item.timestamp,
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

    func registerClipboardAsCommand(_ item: ClipboardItem, asLast: Bool = true, groupSeq: Int = CommandStore.defaultGroupSeq, terminalApp: TerminalApp = .iterm2) {
        let firstLine = item.content.components(separatedBy: .newlines).first ?? item.content
        let cmdLabel = String(firstLine.prefix(50))
        let cmd = Command(
            groupSeq: groupSeq,
            label: cmdLabel,
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
        // 1. 먼저 command@id 체이닝 처리 (명령어 실행)
        var processedCommand = await resolveCommandChainingInCommand(command)

        // 2. {secure:refId} → 복호화된 값으로 치환
        processedCommand = processedCommand.withSecureValuesResolved()

        // 3. 환경 변수 치환
        if let env = activeEnvironment {
            processedCommand = processedCommand.withEnvironmentVariables(env.variables)
        }

        // 최종 curl 명령 로깅 (실제 값 포함)
        var curlLog = "curl -X \(processedCommand.httpMethod.rawValue) '\(processedCommand.url)'"
        for (key, value) in processedCommand.headers {
            curlLog += " \\\n  -H '\(key): \(value)'"
        }
        if !processedCommand.bodyData.isEmpty {
            curlLog += " \\\n  -d '\(processedCommand.bodyData)'"
        }
        logChain("=== 최종 curl ===\n\(curlLog)\n=================")

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
                        title: commands[i].label,
                        command: "지금!",
                        type: .scheduleAlert,
                        output: nil,
                        commandSeq: db.getCommandSeq(commandId: commands[i].id)
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
                            title: commands[i].label,
                            command: alertStateFor(seconds: reminderTime).rawValue,
                            type: .reminder,
                            output: nil,
                            commandSeq: db.getCommandSeq(commandId: commands[i].id)
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

        // Migration: assign default group seq to commands without groupSeq or with invalid groupSeq
        let validGroupSeqs = Set(groups.compactMap { $0.seq })
        var needsSave = false
        commands = commands.map { cmd in
            var updatedCmd = cmd
            if let seq = updatedCmd.groupSeq, !validGroupSeqs.contains(seq) {
                updatedCmd.groupSeq = Self.defaultGroupSeq
                needsSave = true
            } else if updatedCmd.groupSeq == nil {
                updatedCmd.groupSeq = Self.defaultGroupSeq
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

        // 1. {id#라벨}, {var#라벨:값}, {var#라벨} 처리
        let labelResult = processIdVarLabels(newCmd.command)
        if let error = labelResult.error {
            print("Label processing error: \(error)")
            // 에러가 있어도 계속 진행 (에러 처리는 UI에서 해야 함)
        }
        newCmd.command = labelResult.text

        // 2. {secure:xxx}, {secure#라벨:xxx} → {secure:refId} 변환
        let secureResult = SecureValueManager.shared.processForSave(newCmd.command)
        if let error = secureResult.error {
            print("Secure processing error: \(error)")
        }
        newCmd.command = secureResult.text
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
            title: cmd.label,
            command: cmd.command,
            type: .added,
            output: nil
        ))
    }

    func duplicate(_ cmd: Command) {
        var newCmd = cmd
        newCmd.id = Command.generateId()
        newCmd.label = cmd.label + " (복사)"
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
                title: commands[i].label,
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
                title: cmd.label,
                command: cmd.command,
                type: .deleted,
                output: nil
            ))
        }
    }

    func restoreFromTrash(_ cmd: Command, toGroupSeq: Int? = nil) {
        if let i = commands.firstIndex(where: { $0.id == cmd.id }) {
            commands[i].isInTrash = false
            // 그룹 seq 지정 시 변경, 아니면 기존 그룹이 유효한지 확인
            if let groupSeq = toGroupSeq {
                commands[i].groupSeq = groupSeq
            } else if let seq = commands[i].groupSeq {
                // 기존 그룹 seq가 유효한지 확인
                if !groups.contains(where: { $0.seq == seq }) {
                    // 기존 그룹이 삭제된 경우 기본 그룹으로
                    commands[i].groupSeq = CommandStore.defaultGroupSeq
                }
            } else {
                // groupSeq가 없으면 기본 그룹으로
                commands[i].groupSeq = CommandStore.defaultGroupSeq
            }
            save()
            if commands[i].executionType == .background && commands[i].interval > 0 {
            }
            addHistory(HistoryItem(
                timestamp: Date(),
                title: cmd.label,
                command: cmd.command,
                type: .restored,
                output: nil
            ))
        }
    }

    func deletePermanently(_ cmd: Command) {
        addHistory(HistoryItem(
            timestamp: Date(),
            title: cmd.label,
            command: cmd.command,
            type: .permanentlyDeleted,
            output: nil
        ))
        db.deleteCommand(cmd.id)
        commands.removeAll { $0.id == cmd.id }
    }

    func emptyTrash() {
        let trashIds = commands.filter { $0.isInTrash }.map { $0.id }
        for id in trashIds {
            db.deleteCommand(id)
        }
        commands.removeAll { $0.isInTrash }
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

            // 1. {id#라벨}, {var#라벨:값}, {var#라벨} 처리
            let labelResult = processIdVarLabels(updated.command)
            if let error = labelResult.error {
                print("Label processing error: \(error)")
                // 에러가 있어도 계속 진행 (에러 처리는 UI에서 해야 함)
            }
            updated.command = labelResult.text

            // 2. {secure:xxx} → {secure:refId} 변환
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
        // 1. {var:varId} or {var:envVar} → 실제 값으로 치환
        var resolvedCommand = resolveVarReferences(in: cmd.command)
        // 2. {secure:refId} → 복호화된 값으로 치환
        resolvedCommand = SecureValueManager.shared.processForExecution(resolvedCommand)
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
            title: cmd.label,
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

        // 1. {var:varId} or {var:envVar} → 실제 값으로 치환
        var resolvedCommand = resolveVarReferences(in: cmd.command)
        // 2. {secure:refId} → 복호화된 값으로 치환
        resolvedCommand = SecureValueManager.shared.processForExecution(resolvedCommand)

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
                        title: cmd.label,
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
                        title: cmd.label,
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
        guard group.seq != Self.defaultGroupSeq else { return }
        // 해당 그룹 명령어들을 기본 그룹으로 이동
        let groupSeq = group.seq
        for i in commands.indices where commands[i].groupSeq == groupSeq {
            commands[i].groupSeq = Self.defaultGroupSeq
        }
        if let seq = group.seq {
            db.deleteGroup(seq)
        }
        groups.removeAll { $0.seq == group.seq }
        save()
    }

    func deleteGroupWithCommands(_ group: Group) {
        // 마지막 그룹은 삭제 불가
        guard groups.count > 1 else { return }
        // 기본 그룹은 삭제 불가
        guard group.seq != Self.defaultGroupSeq else { return }
        // 해당 그룹의 명령어들을 휴지통으로 이동
        let groupSeq = group.seq
        for i in commands.indices where commands[i].groupSeq == groupSeq {
            commands[i].isInTrash = true
        }
        if let seq = group.seq {
            db.deleteGroup(seq)
        }
        groups.removeAll { $0.seq == group.seq }
        save()
    }

    func deleteGroupAndMerge(_ group: Group, to targetGroupSeq: Int) {
        // 마지막 그룹은 삭제 불가
        guard groups.count > 1 else { return }
        // 기본 그룹은 삭제 불가
        guard group.seq != Self.defaultGroupSeq else { return }
        // 해당 그룹의 명령어들을 다른 그룹으로 이동
        let groupSeq = group.seq
        for i in commands.indices where commands[i].groupSeq == groupSeq {
            commands[i].groupSeq = targetGroupSeq
        }
        if let seq = group.seq {
            db.deleteGroup(seq)
        }
        groups.removeAll { $0.seq == group.seq }
        save()
    }

    func moveToGroup(_ command: Command, groupSeq: Int) {
        if let i = commands.firstIndex(where: { $0.id == command.id }) {
            commands[i].groupSeq = groupSeq
            save()
        }
    }

    func itemsForGroup(_ groupSeq: Int?) -> [Command] {
        let active = commands.filter { !$0.isInTrash }
        guard let seq = groupSeq else { return active }
        return active.filter { $0.groupSeq == seq }
    }

    func ensureDefaultGroup() {
        if groups.isEmpty || !groups.contains(where: { $0.seq == Self.defaultGroupSeq }) {
            let defaultGroup = Group(
                seq: Self.defaultGroupSeq,
                name: L.groupDefault,
                color: "gray",
                order: 0
            )
            groups.insert(defaultGroup, at: 0)
            db.saveGroups(groups)  // save() 대신 groups만 저장 (commands 삭제 방지)
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
            // 병합: 기존 ID와 겹치면 새 ID 부여 (APIEnvironment는 아직 UUID 사용)
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
    func getValueFromAPIResponse(commandId: String, jsonPath: String?) -> String? {
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
                    cmd.id = Command.generateId()
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

    /// 모든 항목의 id와 제목 목록 (자동완성용)
    var allIdSuggestions: [(id: String, title: String)] {
        var result: [(id: String, title: String)] = []

        // Commands
        for cmd in commands where !cmd.isInTrash {
            result.append((id: cmd.id, title: cmd.label))
        }

        // Clipboard items
        for clip in clipboardItems {
            let preview = String(clip.content.prefix(30)).replacingOccurrences(of: "\n", with: " ")
            result.append((id: clip.id, title: preview))
        }

        return result
    }

    // MARK: - Command Chaining

    /// secure 값을 마스킹 (히스토리 저장용)
    private func maskSecureValues(in text: String) -> String {
        var result = text
        // 복호화된 secure 값을 다시 `secure@id` 형식으로 변환하기는 어려움
        // 대신 secure 패턴을 *** 로 마스킹
        // 여기서는 일단 그대로 반환 (secure는 이미 withSecureValuesResolved로 치환됨)
        // TODO: secure 값 추적해서 마스킹
        return result
    }

    /// 체이닝 로그
    private func logChaining(_ msg: String) {
        logChain(msg)
    }

    /// Command 객체의 모든 필드에서 체이닝 처리
    func resolveCommandChainingInCommand(_ command: Command) async -> Command {
        var cmd = command

        logChaining("Processing command: \(command.label)")
        logChaining("Headers: \(cmd.headers)")

        // URL 체이닝
        cmd.url = await resolveCommandReferences(in: cmd.url)

        // Headers 체이닝
        var resolvedHeaders: [String: String] = [:]
        for (key, value) in cmd.headers {
            logChaining("Header \(key): \(value)")
            let resolved = await resolveCommandReferences(in: value)
            logChaining("Header \(key) resolved: \(resolved)")
            resolvedHeaders[key] = resolved
        }
        cmd.headers = resolvedHeaders

        // Body 체이닝
        logChaining("Body: \(cmd.bodyData)")
        cmd.bodyData = await resolveCommandReferences(in: cmd.bodyData)
        logChaining("Body resolved: \(cmd.bodyData)")

        // QueryParams 체이닝
        var resolvedParams: [String: String] = [:]
        for (key, value) in cmd.queryParams {
            resolvedParams[key] = await resolveCommandReferences(in: value)
        }
        cmd.queryParams = resolvedParams

        logChaining("Headers after: \(cmd.headers)")
        return cmd
    }

    /// 문자열에서 명령어 참조를 처리하여 값으로 치환
    /// - `command@id` 또는 `command@id|path` (배지 저장 형식)
    /// - {command#label} 또는 {command#label|path} (입력 형식)
    func resolveCommandReferences(in text: String) async -> String {
        var result = text

        logChaining("Resolve input: \(text)")

        // 1. 배지 형식: `command@id` 또는 `command@id|path`
        if let badgeRegex = try? NSRegularExpression(pattern: "`command@([^`|]+)(?:\\|([^`]+))?`") {
            let range = NSRange(result.startIndex..., in: result)
            let matches = badgeRegex.matches(in: result, range: range).reversed()
            logChaining("Found \(matches.count) matches in: \(text)")

            for match in matches {
                guard let fullRange = Range(match.range, in: result),
                      let idRange = Range(match.range(at: 1), in: result) else { continue }

                let commandId = String(result[idRange])
                let jsonPath: String?
                if match.numberOfRanges > 2, let pathRange = Range(match.range(at: 2), in: result) {
                    jsonPath = String(result[pathRange])
                } else {
                    jsonPath = nil
                }

                if let value = await executeAndGetValue(commandId: commandId, jsonPath: jsonPath) {
                    result.replaceSubrange(fullRange, with: value)
                }
            }
        }

        return result
    }

    /// 체이닝: 명령어 실행 후 결과 반환
    func executeAndGetValue(commandId: String, jsonPath: String?) async -> String? {
        // Command 찾기
        guard let cmd = commands.first(where: { $0.id == commandId }) else {
            // ClipboardItem에서 찾기
            if let clip = clipboardItems.first(where: { $0.id == commandId }) {
                if let path = jsonPath, !path.isEmpty {
                    return extractValueFromJSON(clip.content, path: path)
                }
                return clip.content
            }
            return nil
        }

        // 명령어 실행
        let response: String?
        let startTime = Date()

        switch cmd.executionType {
        case .api:
            let result = await executeAPICommand(cmd)
            var statusCode = 0
            var isSuccess = false

            if let httpResponse = result.response as? HTTPURLResponse {
                statusCode = httpResponse.statusCode
                isSuccess = (200..<300).contains(statusCode)
            }

            if let data = result.data {
                response = String(data: data, encoding: .utf8)
                logChaining("API response data: \(response ?? "nil")")
            } else if let error = result.error {
                response = "Error: \(error.localizedDescription)"
                logChaining("API error: \(response ?? "nil")")
            } else {
                response = nil
                logChaining("API no data, no error")
            }

            // API 히스토리 저장
            let headersJson = try? JSONSerialization.data(withJSONObject: cmd.headers, options: [])
            let queryParamsJson = try? JSONSerialization.data(withJSONObject: cmd.queryParams, options: [])

            // curl 형식으로 command 생성
            var curlCommand = "curl -X \(cmd.httpMethod.rawValue) '\(cmd.url)'"
            for (key, value) in cmd.headers {
                curlCommand += " -H '\(key): \(value)'"
            }
            if !cmd.bodyData.isEmpty {
                let escapedBody = cmd.bodyData.replacingOccurrences(of: "'", with: "'\\''")
                curlCommand += " -d '\(escapedBody)'"
            }

            addHistory(HistoryItem(
                timestamp: startTime,
                title: cmd.label,
                command: curlCommand,
                type: .api,
                output: response ?? "",
                requestUrl: cmd.url,
                requestMethod: cmd.httpMethod.rawValue,
                requestHeaders: headersJson.flatMap { String(data: $0, encoding: .utf8) },
                requestBody: cmd.bodyData,
                requestQueryParams: queryParamsJson.flatMap { String(data: $0, encoding: .utf8) },
                statusCode: statusCode,
                isSuccess: isSuccess
            ))

        case .terminal, .background, .script, .schedule:
            // 셸 명령어 동기 실행
            response = executeShellCommand(cmd.command)
        }

        guard let resp = response else { return nil }

        // 결과 저장
        if let idx = commands.firstIndex(where: { $0.id == commandId }) {
            if cmd.executionType == .api {
                commands[idx].lastResponse = resp
            } else {
                commands[idx].lastOutput = resp
            }
            save()
        }

        // jsonPath 처리
        if let path = jsonPath, !path.isEmpty {
            return extractValueFromJSON(resp, path: path)
        }
        return resp
    }

    /// 동기 셸 명령어 실행
    private func executeShellCommand(_ command: String) -> String? {
        let process = Process()
        let pipe = Pipe()

        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-c", command]
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)

            // 히스토리 저장
            if let cmd = commands.first(where: { $0.command == command }) {
                addHistory(HistoryItem(
                    timestamp: Date(),
                    title: cmd.label,
                    command: command,
                    type: .background,
                    output: output
                ))
            }

            return output
        } catch {
            return nil
        }
    }

    /// commandId로 명령어 결과값 조회
    func getValueFromCommand(commandId: String, jsonPath: String?) -> String? {
        // Command에서 찾기
        if let cmd = commands.first(where: { $0.id == commandId }) {
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
        if let clip = clipboardItems.first(where: { $0.id == commandId }) {
            if let path = jsonPath, !path.isEmpty {
                return extractValueFromJSON(clip.content, path: path)
            }
            return clip.content
        }

        return nil
    }

    /// id로 값 조회 (Command의 lastOutput/lastResponse 또는 ClipboardItem의 content)
    func getValueFromId(id: String, jsonPath: String?) -> String? {
        // Command에서 찾기
        if let cmd = commands.first(where: { $0.id == id }) {
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
        if let clip = clipboardItems.first(where: { $0.id == id }) {
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

    /// 문자열에서 {var:xxx} 참조를 변수 값 또는 환경 변수 값으로 치환
    /// - {var:6자리ID} → DB의 variables 테이블에서 값 조회
    /// - {var:환경변수명} → 환경 변수에서 값 조회
    func resolveVarReferences(in text: String) -> String {
        // {var:xxx} 패턴
        guard let regex = try? NSRegularExpression(pattern: "\\{var:([^}]+)\\}") else {
            return text
        }

        var result = text
        let range = NSRange(text.startIndex..., in: text)
        let matches = regex.matches(in: text, range: range).reversed()

        if !matches.isEmpty {
            logChain("var 치환 시작: \(matches.count)개 발견")
        }

        for match in matches {
            guard let fullRange = Range(match.range, in: result),
                  let varNameRange = Range(match.range(at: 1), in: result) else { continue }

            let varName = String(result[varNameRange])

            // 1. 먼저 DB 변수에서 찾기 (6자리 ID 형식)
            if let value = db.getVariableValueById(varName) {
                let label = db.getVariableLabelById(varName) ?? varName
                logChain("var:\(varName) (\(label)) → \(value)")
                result.replaceSubrange(fullRange, with: value)
            }
            // 2. 환경 변수에서 찾기
            else if let env = activeEnvironment, let value = env.variables[varName] {
                logChain("var:\(varName) (env) → \(value)")
                result.replaceSubrange(fullRange, with: value)
            } else {
                logChain("var:\(varName) → 값 없음")
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
        db.restoreHistory(id: item.id)
        trashHistory.removeAll { $0.id == item.id }
        trashHistoryCount = max(0, trashHistoryCount - 1)
        loadHistory()
    }

    func restoreClipboardItem(_ item: ClipboardItem) {
        db.restoreClipboard(id: item.id)
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

    // MARK: - ID/Var Label Processing

    /// 저장 전 처리 결과
    struct LabelProcessResult {
        var text: String
        var labels: [(commandId: String, label: String)]  // 설정된 라벨들
        var error: String?
        var errorRange: NSRange?
    }

    /// id/var 라벨 처리:
    /// - {id#라벨}, [id#라벨] → 기존 라벨로 명령어 참조 → `id@commandId`
    /// - {var#라벨:값}, [var#라벨:값] → 새 변수 + 라벨 저장 → `var@varId`
    /// - {var#라벨}, [var#라벨] → 기존 라벨 참조 → `var@varId`
    /// - {id:xxx}, [id:xxx] → `id@xxx`
    /// - {var:xxx}, [var:xxx] → `var@xxx`
    func processIdVarLabels(_ text: String) -> LabelProcessResult {
        var result = text
        let labels: [(commandId: String, label: String)] = []

        // 1. {id#라벨} 또는 [id#라벨] 패턴 처리 (기존 라벨로 명령어 참조)
        let idLabelPatterns = ["\\{id#([^}]+)\\}", "\\[id#([^\\]]+)\\]"]
        for pattern in idLabelPatterns {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            let range = NSRange(result.startIndex..., in: result)
            let matches = regex.matches(in: result, range: range).reversed()

            for match in matches {
                guard let fullRange = Range(match.range, in: result),
                      let labelRange = Range(match.range(at: 1), in: result) else {
                    continue
                }

                let label = String(result[labelRange])

                // 라벨로 명령어 ID 조회
                if let commandId = db.getCommandIdByLabel(label) {
                    result.replaceSubrange(fullRange, with: "`id@\(commandId)`")  // 저장은 항상 @id
                } else {
                    return LabelProcessResult(text: text, labels: [], error: "라벨 '\(label)'을(를) 가진 명령어를 찾을 수 없습니다.", errorRange: match.range)
                }
            }
        }

        // 2. {var#라벨:값} 또는 [var#라벨:값] 패턴 처리 (라벨 + 새 변수)
        let varLabelValuePatterns = ["\\{var#([^:}]+):([^}]+)\\}", "\\[var#([^:\\]]+):([^\\]]+)\\]"]
        for pattern in varLabelValuePatterns {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            let range = NSRange(result.startIndex..., in: result)
            let matches = regex.matches(in: result, range: range).reversed()

            for match in matches {
                guard let fullRange = Range(match.range, in: result),
                      let labelRange = Range(match.range(at: 1), in: result),
                      let valueRange = Range(match.range(at: 2), in: result) else {
                    continue
                }

                let label = String(result[labelRange])
                let value = String(result[valueRange])

                // 라벨 중복 검사
                if db.variableLabelExists(label) {
                    return LabelProcessResult(text: text, labels: [], error: "변수 라벨 '\(label)'이(가) 이미 존재합니다.", errorRange: match.range)
                }

                // 변수 저장 (ID 생성, 라벨은 별도 저장)
                let varId = db.generateVariableId()
                db.insertVariable(id: varId, value: value, label: label)
                result.replaceSubrange(fullRange, with: "`var@\(varId)`")  // 저장은 항상 @id
            }
        }

        // 3. {var#라벨} 또는 [var#라벨] 패턴 처리 (기존 라벨 참조)
        let varLabelOnlyPatterns = ["\\{var#([^:}]+)\\}", "\\[var#([^:\\]]+)\\]"]
        for pattern in varLabelOnlyPatterns {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            let range = NSRange(result.startIndex..., in: result)
            let matches = regex.matches(in: result, range: range).reversed()

            for match in matches {
                guard let fullRange = Range(match.range, in: result),
                      let labelRange = Range(match.range(at: 1), in: result) else {
                    continue
                }

                let label = String(result[labelRange])

                // 라벨로 변수 ID 조회
                if let varId = db.getVariableIdByLabel(label) {
                    result.replaceSubrange(fullRange, with: "`var@\(varId)`")  // 저장은 항상 @id
                } else {
                    return LabelProcessResult(text: text, labels: [], error: "변수 라벨 '\(label)'을(를) 찾을 수 없습니다.", errorRange: match.range)
                }
            }
        }

        // 4. {id:xxx} 또는 [id:xxx] 패턴 처리 → `id@xxx`
        let idPatterns = ["\\{id:([^}]+)\\}", "\\[id:([^\\]]+)\\]"]
        for pattern in idPatterns {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            let range = NSRange(result.startIndex..., in: result)
            let matches = regex.matches(in: result, range: range).reversed()

            for match in matches {
                guard let fullRange = Range(match.range, in: result),
                      let idRange = Range(match.range(at: 1), in: result) else {
                    continue
                }
                let id = String(result[idRange])
                result.replaceSubrange(fullRange, with: "`id@\(id)`")
            }
        }

        // 5. {var:xxx} 또는 [var:xxx] 패턴 처리 → `var@xxx`
        let varPatterns = ["\\{var:([^}]+)\\}", "\\[var:([^\\]]+)\\]"]
        for pattern in varPatterns {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            let range = NSRange(result.startIndex..., in: result)
            let matches = regex.matches(in: result, range: range).reversed()

            for match in matches {
                guard let fullRange = Range(match.range, in: result),
                      let idRange = Range(match.range(at: 1), in: result) else {
                    continue
                }
                let id = String(result[idRange])
                result.replaceSubrange(fullRange, with: "`var@\(id)`")
            }
        }

        return LabelProcessResult(text: result, labels: labels, error: nil, errorRange: nil)
    }

    /// 모든 변수 라벨 목록
    func getAllVariableLabels() -> [String] {
        return db.getAllVariableLabels()
    }

    /// 모든 명령어 라벨 목록
    func getAllCommandLabels() -> [String] {
        return db.getAllCommandLabels()
    }

    /// 명령어에 라벨 설정
    func setCommandLabel(_ command: Command, label: String?) {
        db.setCommandLabel(commandId: command.id, label: label)
    }
}
