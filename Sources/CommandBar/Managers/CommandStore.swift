import SwiftUI
import AppKit

class CommandStore: ObservableObject {
    static let defaultGroupId = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!

    @Published var commands: [Command] = []
    @Published var groups: [Group] = []
    @Published var alertingCommandId: UUID?  // 현재 알림 중인 명령
    @Published var history: [HistoryItem] = []
    @Published var clipboardItems: [ClipboardItem] = []
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

    init() {
        ensureConfigDir()
        migrateOldFiles()
        load()
        loadHistory()
        loadClipboard()
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
        // URL 생성 (queryParams 적용)
        var urlComponents = URLComponents(string: command.url)
        if !command.queryParams.isEmpty {
            urlComponents?.queryItems = command.queryParams.map { URLQueryItem(name: $0.key, value: $0.value) }
        }

        guard let finalURL = urlComponents?.url else {
            let error = NSError(domain: "CommandStore", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
            return (nil, nil, error)
        }

        // URLRequest 생성
        var urlRequest = URLRequest(url: finalURL)

        // httpMethod 설정
        urlRequest.httpMethod = command.httpMethod.rawValue

        // headers 적용
        for (key, value) in command.headers {
            urlRequest.setValue(value, forHTTPHeaderField: key)
        }

        // body 설정 (bodyType에 따라)
        switch command.bodyType {
        case .none:
            break
        case .json:
            if !command.bodyData.isEmpty {
                urlRequest.httpBody = command.bodyData.data(using: .utf8)
                if command.headers["Content-Type"] == nil {
                    urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
                }
            }
        case .formData:
            if !command.bodyData.isEmpty {
                urlRequest.httpBody = command.bodyData.data(using: .utf8)
                if command.headers["Content-Type"] == nil {
                    urlRequest.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
                }
            }
        case .multipart:
            do {
                let boundary = UUID().uuidString
                urlRequest.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

                var body = Data()

                // 텍스트 파라미터 추가 (bodyData를 JSON으로 파싱)
                if !command.bodyData.isEmpty {
                    if let jsonData = command.bodyData.data(using: .utf8),
                       let textParams = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
                        for (key, value) in textParams {
                            body.append("--\(boundary)\r\n".data(using: .utf8)!)
                            body.append("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n".data(using: .utf8)!)
                            body.append("\(value)\r\n".data(using: .utf8)!)
                        }
                    }
                }

                // 파일 파라미터 추가
                for (key, filePath) in command.fileParams {
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
            } catch {
                return (nil, nil, error)
            }
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
        if let groupsData = try? Data(contentsOf: groupsUrl),
           let decodedGroups = try? JSONDecoder().decode([Group].self, from: groupsData) {
            groups = decodedGroups
        }
        ensureDefaultGroup()

        // Load commands
        guard let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([Command].self, from: data) else {
            return
        }

        // Migration: assign default group ID to commands without groupId or with invalid groupId
        let validGroupIds = Set(groups.map { $0.id })
        commands = decoded.map { cmd in
            var updatedCmd = cmd
            if !validGroupIds.contains(updatedCmd.groupId) {
                updatedCmd.groupId = Self.defaultGroupId
            }
            return updatedCmd
        }
    }

    func save() {
        // Save commands
        guard let data = try? JSONEncoder().encode(commands) else { return }
        try? data.write(to: url)

        // Save groups
        guard let groupsData = try? JSONEncoder().encode(groups) else { return }
        try? groupsData.write(to: groupsUrl)
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
            for cmd in commands {
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
        return true
    }
}
