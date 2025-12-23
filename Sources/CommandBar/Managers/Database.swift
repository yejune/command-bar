import Foundation
import SQLite3

class Database {
    static let shared = Database()
    private var db: OpaquePointer?

    private var dbPath: URL {
        let configDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".command_bar")
        return configDir.appendingPathComponent("commandbar.db")
    }

    private init() {
        ensureConfigDir()
        openDatabase()
        createTables()
    }

    private func ensureConfigDir() {
        let configDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".command_bar")
        try? FileManager.default.createDirectory(at: configDir, withIntermediateDirectories: true)
    }

    private func openDatabase() {
        if sqlite3_open(dbPath.path, &db) != SQLITE_OK {
            print("Failed to open database")
        }
    }

    private func createTables() {
        let createSQL = """
        -- 그룹
        CREATE TABLE IF NOT EXISTS groups (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            color TEXT NOT NULL,
            sort_order INTEGER DEFAULT 0
        );

        -- 명령어
        CREATE TABLE IF NOT EXISTS commands (
            id TEXT PRIMARY KEY,
            group_id TEXT,
            title TEXT NOT NULL,
            command TEXT NOT NULL,
            execution_type TEXT NOT NULL,
            terminal_app TEXT DEFAULT 'iterm2',
            interval_seconds INTEGER DEFAULT 0,
            is_running INTEGER DEFAULT 0,
            schedule_date TEXT,
            repeat_type TEXT DEFAULT 'none',
            alert_state TEXT DEFAULT 'none',
            reminder_times TEXT,
            alerted_times TEXT,
            history_logged_times TEXT,
            acknowledged INTEGER DEFAULT 0,
            is_in_trash INTEGER DEFAULT 0,
            is_favorite INTEGER DEFAULT 0,
            url TEXT,
            http_method TEXT DEFAULT 'GET',
            headers TEXT,
            query_params TEXT,
            body_type TEXT DEFAULT 'none',
            body_data TEXT,
            file_params TEXT,
            last_response TEXT,
            last_status_code INTEGER,
            last_output TEXT,
            last_executed_at TEXT
        );

        -- 히스토리
        CREATE TABLE IF NOT EXISTS history (
            id TEXT PRIMARY KEY,
            timestamp TEXT NOT NULL,
            title TEXT NOT NULL,
            command TEXT NOT NULL,
            type TEXT NOT NULL,
            output TEXT,
            count INTEGER DEFAULT 1,
            end_timestamp TEXT,
            command_id TEXT
        );

        -- 클립보드
        CREATE TABLE IF NOT EXISTS clipboard (
            id TEXT PRIMARY KEY,
            timestamp TEXT NOT NULL,
            content TEXT NOT NULL,
            is_favorite INTEGER DEFAULT 0
        );

        -- 설정
        CREATE TABLE IF NOT EXISTS settings (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL
        );

        -- 인덱스
        CREATE INDEX IF NOT EXISTS idx_commands_group ON commands(group_id);
        CREATE INDEX IF NOT EXISTS idx_commands_trash ON commands(is_in_trash);
        CREATE INDEX IF NOT EXISTS idx_history_timestamp ON history(timestamp DESC);
        CREATE INDEX IF NOT EXISTS idx_history_title ON history(title);
        CREATE INDEX IF NOT EXISTS idx_clipboard_timestamp ON clipboard(timestamp DESC);
        CREATE INDEX IF NOT EXISTS idx_clipboard_content ON clipboard(content);
        """

        executeStatements(createSQL)

        // 마이그레이션: is_favorite 컬럼이 없으면 추가
        let addFavoriteColumn = "ALTER TABLE clipboard ADD COLUMN is_favorite INTEGER DEFAULT 0"
        sqlite3_exec(db, addFavoriteColumn, nil, nil, nil)
    }

    private func executeStatements(_ sql: String) {
        var errMsg: UnsafeMutablePointer<CChar>?
        if sqlite3_exec(db, sql, nil, nil, &errMsg) != SQLITE_OK {
            if let errMsg = errMsg {
                print("SQL Error: \(String(cString: errMsg))")
                sqlite3_free(errMsg)
            }
        }
    }

    // MARK: - Groups

    func saveGroups(_ groups: [Group]) {
        executeStatements("DELETE FROM groups")
        for (index, group) in groups.enumerated() {
            let sql = """
            INSERT INTO groups (id, name, color, sort_order)
            VALUES (?, ?, ?, ?)
            """
            var stmt: OpaquePointer?
            if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
                sqlite3_bind_text(stmt, 1, group.id.uuidString, -1, SQLITE_TRANSIENT)
                sqlite3_bind_text(stmt, 2, group.name, -1, SQLITE_TRANSIENT)
                sqlite3_bind_text(stmt, 3, group.color, -1, SQLITE_TRANSIENT)
                sqlite3_bind_int(stmt, 4, Int32(index))
                sqlite3_step(stmt)
            }
            sqlite3_finalize(stmt)
        }
    }

    func loadGroups() -> [Group] {
        var groups: [Group] = []
        let sql = "SELECT id, name, color, sort_order FROM groups ORDER BY sort_order"
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            while sqlite3_step(stmt) == SQLITE_ROW {
                if let idStr = sqlite3_column_text(stmt, 0),
                   let namePtr = sqlite3_column_text(stmt, 1),
                   let colorPtr = sqlite3_column_text(stmt, 2),
                   let id = UUID(uuidString: String(cString: idStr)) {
                    let name = String(cString: namePtr)
                    let color = String(cString: colorPtr)
                    let order = Int(sqlite3_column_int(stmt, 3))
                    groups.append(Group(id: id, name: name, color: color, order: order))
                }
            }
        }
        sqlite3_finalize(stmt)
        return groups
    }

    // MARK: - Commands

    func saveCommands(_ commands: [Command]) {
        executeStatements("DELETE FROM commands")
        for command in commands {
            insertCommand(command)
        }
    }

    func insertCommand(_ command: Command) {
        let sql = """
        INSERT OR REPLACE INTO commands (
            id, group_id, title, command, execution_type, terminal_app,
            interval_seconds, is_running, schedule_date, repeat_type, alert_state,
            reminder_times, alerted_times, history_logged_times, acknowledged,
            is_in_trash, is_favorite, url, http_method, headers, query_params,
            body_type, body_data, file_params, last_response, last_status_code,
            last_output, last_executed_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, command.id.uuidString, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 2, command.groupId.uuidString, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 3, command.title, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 4, command.command, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 5, command.executionType.rawValue, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 6, command.terminalApp.rawValue, -1, SQLITE_TRANSIENT)
            sqlite3_bind_int(stmt, 7, Int32(command.interval))
            sqlite3_bind_int(stmt, 8, command.isRunning ? 1 : 0)
            if let date = command.scheduleDate {
                sqlite3_bind_text(stmt, 9, ISO8601DateFormatter().string(from: date), -1, SQLITE_TRANSIENT)
            } else {
                sqlite3_bind_null(stmt, 9)
            }
            sqlite3_bind_text(stmt, 10, command.repeatType.rawValue, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 11, command.alertState.rawValue, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 12, encodeSet(command.reminderTimes), -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 13, encodeSet(command.alertedTimes), -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 14, encodeSet(command.historyLoggedTimes), -1, SQLITE_TRANSIENT)
            sqlite3_bind_int(stmt, 15, command.acknowledged ? 1 : 0)
            sqlite3_bind_int(stmt, 16, command.isInTrash ? 1 : 0)
            sqlite3_bind_int(stmt, 17, command.isFavorite ? 1 : 0)
            sqlite3_bind_text(stmt, 18, command.url, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 19, command.httpMethod.rawValue, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 20, encodeDict(command.headers), -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 21, encodeDict(command.queryParams), -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 22, command.bodyType.rawValue, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 23, command.bodyData, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 24, encodeDict(command.fileParams), -1, SQLITE_TRANSIENT)
            if let resp = command.lastResponse {
                sqlite3_bind_text(stmt, 25, resp, -1, SQLITE_TRANSIENT)
            } else {
                sqlite3_bind_null(stmt, 25)
            }
            if let code = command.lastStatusCode {
                sqlite3_bind_int(stmt, 26, Int32(code))
            } else {
                sqlite3_bind_null(stmt, 26)
            }
            if let output = command.lastOutput {
                sqlite3_bind_text(stmt, 27, output, -1, SQLITE_TRANSIENT)
            } else {
                sqlite3_bind_null(stmt, 27)
            }
            if let date = command.lastExecutedAt {
                sqlite3_bind_text(stmt, 28, ISO8601DateFormatter().string(from: date), -1, SQLITE_TRANSIENT)
            } else {
                sqlite3_bind_null(stmt, 28)
            }
            sqlite3_step(stmt)
        }
        sqlite3_finalize(stmt)
    }

    func loadCommands() -> [Command] {
        var commands: [Command] = []
        let sql = "SELECT * FROM commands"
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            while sqlite3_step(stmt) == SQLITE_ROW {
                if let cmd = parseCommand(stmt) {
                    commands.append(cmd)
                }
            }
        }
        sqlite3_finalize(stmt)
        return commands
    }

    private func parseCommand(_ stmt: OpaquePointer?) -> Command? {
        guard let stmt = stmt,
              let idStr = sqlite3_column_text(stmt, 0),
              let id = UUID(uuidString: String(cString: idStr)) else { return nil }

        let groupIdStr = sqlite3_column_text(stmt, 1).map { String(cString: $0) } ?? ""
        let groupId = UUID(uuidString: groupIdStr) ?? UUID(uuidString: "00000000-0000-0000-0000-000000000000")!
        let title = sqlite3_column_text(stmt, 2).map { String(cString: $0) } ?? ""
        let commandStr = sqlite3_column_text(stmt, 3).map { String(cString: $0) } ?? ""
        let execTypeStr = sqlite3_column_text(stmt, 4).map { String(cString: $0) } ?? "terminal"
        let terminalStr = sqlite3_column_text(stmt, 5).map { String(cString: $0) } ?? "iterm2"
        let interval = Int(sqlite3_column_int(stmt, 6))
        let isRunning = sqlite3_column_int(stmt, 7) != 0
        let scheduleDateStr = sqlite3_column_text(stmt, 8).map { String(cString: $0) }
        let repeatTypeStr = sqlite3_column_text(stmt, 9).map { String(cString: $0) } ?? "none"
        let alertStateStr = sqlite3_column_text(stmt, 10).map { String(cString: $0) } ?? "none"
        let reminderTimesStr = sqlite3_column_text(stmt, 11).map { String(cString: $0) } ?? "[]"
        let alertedTimesStr = sqlite3_column_text(stmt, 12).map { String(cString: $0) } ?? "[]"
        let historyLoggedTimesStr = sqlite3_column_text(stmt, 13).map { String(cString: $0) } ?? "[]"
        let acknowledged = sqlite3_column_int(stmt, 14) != 0
        let isInTrash = sqlite3_column_int(stmt, 15) != 0
        let isFavorite = sqlite3_column_int(stmt, 16) != 0
        let url = sqlite3_column_text(stmt, 17).map { String(cString: $0) } ?? ""
        let httpMethodStr = sqlite3_column_text(stmt, 18).map { String(cString: $0) } ?? "GET"
        let headersStr = sqlite3_column_text(stmt, 19).map { String(cString: $0) } ?? "{}"
        let queryParamsStr = sqlite3_column_text(stmt, 20).map { String(cString: $0) } ?? "{}"
        let bodyTypeStr = sqlite3_column_text(stmt, 21).map { String(cString: $0) } ?? "none"
        let bodyData = sqlite3_column_text(stmt, 22).map { String(cString: $0) } ?? ""
        let fileParamsStr = sqlite3_column_text(stmt, 23).map { String(cString: $0) } ?? "{}"
        let lastResponse = sqlite3_column_text(stmt, 24).map { String(cString: $0) }
        let lastStatusCode = sqlite3_column_type(stmt, 25) != SQLITE_NULL ? Int(sqlite3_column_int(stmt, 25)) : nil
        let lastOutput = sqlite3_column_text(stmt, 26).map { String(cString: $0) }
        let lastExecutedAtStr = sqlite3_column_text(stmt, 27).map { String(cString: $0) }

        let scheduleDate = scheduleDateStr.flatMap { ISO8601DateFormatter().date(from: $0) }
        let lastExecutedAt = lastExecutedAtStr.flatMap { ISO8601DateFormatter().date(from: $0) }

        return Command(
            id: id,
            groupId: groupId,
            title: title,
            command: commandStr,
            executionType: ExecutionType(rawValue: execTypeStr) ?? .terminal,
            terminalApp: TerminalApp(rawValue: terminalStr) ?? .iterm2,
            interval: interval,
            lastOutput: lastOutput,
            lastExecutedAt: lastExecutedAt,
            isRunning: isRunning,
            scheduleDate: scheduleDate,
            repeatType: RepeatType(rawValue: repeatTypeStr) ?? .none,
            alertState: AlertState(rawValue: alertStateStr) ?? .none,
            reminderTimes: decodeSet(reminderTimesStr),
            alertedTimes: decodeSet(alertedTimesStr),
            historyLoggedTimes: decodeSet(historyLoggedTimesStr),
            acknowledged: acknowledged,
            isInTrash: isInTrash,
            isFavorite: isFavorite,
            url: url,
            httpMethod: HTTPMethod(rawValue: httpMethodStr) ?? .get,
            headers: decodeDict(headersStr),
            queryParams: decodeDict(queryParamsStr),
            bodyType: BodyType(rawValue: bodyTypeStr) ?? .none,
            bodyData: bodyData,
            fileParams: decodeDict(fileParamsStr),
            lastResponse: lastResponse,
            lastStatusCode: lastStatusCode
        )
    }

    func deleteCommand(_ id: UUID) {
        let sql = "DELETE FROM commands WHERE id = ?"
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, id.uuidString, -1, SQLITE_TRANSIENT)
            sqlite3_step(stmt)
        }
        sqlite3_finalize(stmt)
    }

    // MARK: - History

    func addHistory(_ item: HistoryItem) {
        let sql = """
        INSERT INTO history (id, timestamp, title, command, type, output, count, end_timestamp, command_id)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        """
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, item.id.uuidString, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 2, ISO8601DateFormatter().string(from: item.timestamp), -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 3, item.title, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 4, item.command, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 5, item.type.rawValue, -1, SQLITE_TRANSIENT)
            if let output = item.output {
                sqlite3_bind_text(stmt, 6, output, -1, SQLITE_TRANSIENT)
            } else {
                sqlite3_bind_null(stmt, 6)
            }
            sqlite3_bind_int(stmt, 7, Int32(item.count))
            if let endTs = item.endTimestamp {
                sqlite3_bind_text(stmt, 8, ISO8601DateFormatter().string(from: endTs), -1, SQLITE_TRANSIENT)
            } else {
                sqlite3_bind_null(stmt, 8)
            }
            if let cmdId = item.commandId {
                sqlite3_bind_text(stmt, 9, cmdId.uuidString, -1, SQLITE_TRANSIENT)
            } else {
                sqlite3_bind_null(stmt, 9)
            }
            sqlite3_step(stmt)
        }
        sqlite3_finalize(stmt)
    }

    func updateHistory(_ item: HistoryItem) {
        let sql = """
        UPDATE history SET count = ?, end_timestamp = ?, timestamp = ?
        WHERE id = ?
        """
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int(stmt, 1, Int32(item.count))
            if let endTs = item.endTimestamp {
                sqlite3_bind_text(stmt, 2, ISO8601DateFormatter().string(from: endTs), -1, SQLITE_TRANSIENT)
            } else {
                sqlite3_bind_null(stmt, 2)
            }
            sqlite3_bind_text(stmt, 3, ISO8601DateFormatter().string(from: item.timestamp), -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 4, item.id.uuidString, -1, SQLITE_TRANSIENT)
            sqlite3_step(stmt)
        }
        sqlite3_finalize(stmt)
    }

    func loadHistory(limit: Int = 100, offset: Int = 0) -> [HistoryItem] {
        var items: [HistoryItem] = []
        let sql = "SELECT * FROM history ORDER BY timestamp DESC LIMIT ? OFFSET ?"
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int(stmt, 1, Int32(limit))
            sqlite3_bind_int(stmt, 2, Int32(offset))
            while sqlite3_step(stmt) == SQLITE_ROW {
                if let item = parseHistoryItem(stmt) {
                    items.append(item)
                }
            }
        }
        sqlite3_finalize(stmt)
        return items
    }

    func getHistoryDateCounts() -> [String: Int] {
        var counts: [String: Int] = [:]
        let sql = "SELECT date(timestamp) as dt, COUNT(*) as cnt FROM history GROUP BY dt ORDER BY dt DESC LIMIT 60"
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            while sqlite3_step(stmt) == SQLITE_ROW {
                if let datePtr = sqlite3_column_text(stmt, 0) {
                    let dateStr = String(cString: datePtr)
                    let count = Int(sqlite3_column_int(stmt, 1))
                    counts[dateStr] = count
                }
            }
        }
        sqlite3_finalize(stmt)
        return counts
    }

    func getClipboardDateCounts() -> [String: Int] {
        var counts: [String: Int] = [:]
        let sql = "SELECT date(timestamp) as dt, COUNT(*) as cnt FROM clipboard GROUP BY dt ORDER BY dt DESC LIMIT 60"
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            while sqlite3_step(stmt) == SQLITE_ROW {
                if let datePtr = sqlite3_column_text(stmt, 0) {
                    let dateStr = String(cString: datePtr)
                    let count = Int(sqlite3_column_int(stmt, 1))
                    counts[dateStr] = count
                }
            }
        }
        sqlite3_finalize(stmt)
        return counts
    }

    func searchHistory(query: String, startDate: Date? = nil, endDate: Date? = nil, limit: Int = 100) -> [HistoryItem] {
        var items: [HistoryItem] = []
        var conditions: [String] = []
        var params: [Any] = []

        if !query.isEmpty {
            conditions.append("(title LIKE ? OR command LIKE ?)")
            let pattern = "%\(query)%"
            params.append(pattern)
            params.append(pattern)
        }
        if let start = startDate {
            conditions.append("timestamp >= ?")
            params.append(ISO8601DateFormatter().string(from: start))
        }
        if let end = endDate {
            conditions.append("timestamp <= ?")
            params.append(ISO8601DateFormatter().string(from: end))
        }

        let whereClause = conditions.isEmpty ? "" : "WHERE " + conditions.joined(separator: " AND ")
        let sql = "SELECT * FROM history \(whereClause) ORDER BY timestamp DESC LIMIT ?"

        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            var idx: Int32 = 1
            for param in params {
                if let str = param as? String {
                    sqlite3_bind_text(stmt, idx, str, -1, SQLITE_TRANSIENT)
                }
                idx += 1
            }
            sqlite3_bind_int(stmt, idx, Int32(limit))

            while sqlite3_step(stmt) == SQLITE_ROW {
                if let item = parseHistoryItem(stmt) {
                    items.append(item)
                }
            }
        }
        sqlite3_finalize(stmt)
        return items
    }

    func findHistoryByCommandId(_ commandId: UUID, type: HistoryType) -> HistoryItem? {
        let sql = "SELECT * FROM history WHERE command_id = ? AND type = ? ORDER BY timestamp DESC LIMIT 1"
        var stmt: OpaquePointer?
        var item: HistoryItem?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, commandId.uuidString, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 2, type.rawValue, -1, SQLITE_TRANSIENT)
            if sqlite3_step(stmt) == SQLITE_ROW {
                item = parseHistoryItem(stmt)
            }
        }
        sqlite3_finalize(stmt)
        return item
    }

    private func parseHistoryItem(_ stmt: OpaquePointer?) -> HistoryItem? {
        guard let stmt = stmt,
              let idStr = sqlite3_column_text(stmt, 0),
              let id = UUID(uuidString: String(cString: idStr)),
              let tsStr = sqlite3_column_text(stmt, 1),
              let timestamp = ISO8601DateFormatter().date(from: String(cString: tsStr)) else { return nil }

        let title = sqlite3_column_text(stmt, 2).map { String(cString: $0) } ?? ""
        let command = sqlite3_column_text(stmt, 3).map { String(cString: $0) } ?? ""
        let typeStr = sqlite3_column_text(stmt, 4).map { String(cString: $0) } ?? "executed"
        let output = sqlite3_column_text(stmt, 5).map { String(cString: $0) }
        let count = Int(sqlite3_column_int(stmt, 6))
        let endTsStr = sqlite3_column_text(stmt, 7).map { String(cString: $0) }
        let cmdIdStr = sqlite3_column_text(stmt, 8).map { String(cString: $0) }

        let endTimestamp = endTsStr.flatMap { ISO8601DateFormatter().date(from: $0) }
        let commandId = cmdIdStr.flatMap { UUID(uuidString: $0) }

        return HistoryItem(
            id: id,
            timestamp: timestamp,
            title: title,
            command: command,
            type: HistoryType(rawValue: typeStr) ?? .executed,
            output: output,
            count: count,
            endTimestamp: endTimestamp,
            commandId: commandId
        )
    }

    func clearHistory() {
        executeStatements("DELETE FROM history")
    }

    // MARK: - Clipboard

    func addClipboard(_ item: ClipboardItem) {
        let sql = "INSERT INTO clipboard (id, timestamp, content, is_favorite) VALUES (?, ?, ?, ?)"
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, item.id.uuidString, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 2, ISO8601DateFormatter().string(from: item.timestamp), -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 3, item.content, -1, SQLITE_TRANSIENT)
            sqlite3_bind_int(stmt, 4, item.isFavorite ? 1 : 0)
            sqlite3_step(stmt)
        }
        sqlite3_finalize(stmt)
    }

    func loadClipboard(limit: Int = 100, offset: Int = 0) -> [ClipboardItem] {
        var items: [ClipboardItem] = []
        let sql = "SELECT * FROM clipboard ORDER BY timestamp DESC LIMIT ? OFFSET ?"
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int(stmt, 1, Int32(limit))
            sqlite3_bind_int(stmt, 2, Int32(offset))
            while sqlite3_step(stmt) == SQLITE_ROW {
                if let item = parseClipboardItem(stmt) {
                    items.append(item)
                }
            }
        }
        sqlite3_finalize(stmt)
        return items
    }

    func searchClipboard(query: String, startDate: Date? = nil, endDate: Date? = nil, limit: Int = 100) -> [ClipboardItem] {
        var items: [ClipboardItem] = []
        var conditions: [String] = []
        var params: [Any] = []

        if !query.isEmpty {
            conditions.append("content LIKE ?")
            params.append("%\(query)%")
        }
        if let start = startDate {
            conditions.append("timestamp >= ?")
            params.append(ISO8601DateFormatter().string(from: start))
        }
        if let end = endDate {
            conditions.append("timestamp <= ?")
            params.append(ISO8601DateFormatter().string(from: end))
        }

        let whereClause = conditions.isEmpty ? "" : "WHERE " + conditions.joined(separator: " AND ")
        let sql = "SELECT * FROM clipboard \(whereClause) ORDER BY timestamp DESC LIMIT ?"

        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            var idx: Int32 = 1
            for param in params {
                if let str = param as? String {
                    sqlite3_bind_text(stmt, idx, str, -1, SQLITE_TRANSIENT)
                }
                idx += 1
            }
            sqlite3_bind_int(stmt, idx, Int32(limit))

            while sqlite3_step(stmt) == SQLITE_ROW {
                if let item = parseClipboardItem(stmt) {
                    items.append(item)
                }
            }
        }
        sqlite3_finalize(stmt)
        return items
    }

    func clipboardExists(_ content: String) -> Bool {
        let sql = "SELECT 1 FROM clipboard WHERE content = ? LIMIT 1"
        var stmt: OpaquePointer?
        var exists = false
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, content, -1, SQLITE_TRANSIENT)
            exists = sqlite3_step(stmt) == SQLITE_ROW
        }
        sqlite3_finalize(stmt)
        return exists
    }

    func deleteClipboard(_ id: UUID) {
        let sql = "DELETE FROM clipboard WHERE id = ?"
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, id.uuidString, -1, SQLITE_TRANSIENT)
            sqlite3_step(stmt)
        }
        sqlite3_finalize(stmt)
    }

    private func parseClipboardItem(_ stmt: OpaquePointer?) -> ClipboardItem? {
        guard let stmt = stmt,
              let idStr = sqlite3_column_text(stmt, 0),
              let id = UUID(uuidString: String(cString: idStr)),
              let tsStr = sqlite3_column_text(stmt, 1),
              let timestamp = ISO8601DateFormatter().date(from: String(cString: tsStr)),
              let contentPtr = sqlite3_column_text(stmt, 2) else { return nil }

        let content = String(cString: contentPtr)
        let isFavorite = sqlite3_column_int(stmt, 3) != 0
        return ClipboardItem(id: id, timestamp: timestamp, content: content, isFavorite: isFavorite)
    }

    func clearClipboard() {
        executeStatements("DELETE FROM clipboard")
    }

    func toggleClipboardFavorite(_ id: UUID) -> Bool {
        // 현재 값 읽기
        var currentValue = false
        let selectSQL = "SELECT is_favorite FROM clipboard WHERE id = ?"
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, selectSQL, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, id.uuidString, -1, SQLITE_TRANSIENT)
            if sqlite3_step(stmt) == SQLITE_ROW {
                currentValue = sqlite3_column_int(stmt, 0) != 0
            }
        }
        sqlite3_finalize(stmt)

        // 토글
        let newValue = !currentValue
        let updateSQL = "UPDATE clipboard SET is_favorite = ? WHERE id = ?"
        var updateStmt: OpaquePointer?
        if sqlite3_prepare_v2(db, updateSQL, -1, &updateStmt, nil) == SQLITE_OK {
            sqlite3_bind_int(updateStmt, 1, newValue ? 1 : 0)
            sqlite3_bind_text(updateStmt, 2, id.uuidString, -1, SQLITE_TRANSIENT)
            sqlite3_step(updateStmt)
        }
        sqlite3_finalize(updateStmt)

        return newValue
    }

    // MARK: - Settings

    func getSetting(_ key: String) -> String? {
        let sql = "SELECT value FROM settings WHERE key = ?"
        var stmt: OpaquePointer?
        var value: String?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, key, -1, SQLITE_TRANSIENT)
            if sqlite3_step(stmt) == SQLITE_ROW {
                if let ptr = sqlite3_column_text(stmt, 0) {
                    value = String(cString: ptr)
                }
            }
        }
        sqlite3_finalize(stmt)
        return value
    }

    func setSetting(_ key: String, value: String) {
        let sql = "INSERT OR REPLACE INTO settings (key, value) VALUES (?, ?)"
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, key, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 2, value, -1, SQLITE_TRANSIENT)
            sqlite3_step(stmt)
        }
        sqlite3_finalize(stmt)
    }

    func getBoolSetting(_ key: String, defaultValue: Bool = false) -> Bool {
        guard let value = getSetting(key) else { return defaultValue }
        return value == "true" || value == "1"
    }

    func setBoolSetting(_ key: String, value: Bool) {
        setSetting(key, value: value ? "true" : "false")
    }

    func getDoubleSetting(_ key: String, defaultValue: Double = 0) -> Double {
        guard let value = getSetting(key), let num = Double(value) else { return defaultValue }
        return num
    }

    func setDoubleSetting(_ key: String, value: Double) {
        setSetting(key, value: String(value))
    }

    func getIntSetting(_ key: String, defaultValue: Int = 0) -> Int {
        guard let value = getSetting(key), let num = Int(value) else { return defaultValue }
        return num
    }

    func setIntSetting(_ key: String, value: Int) {
        setSetting(key, value: String(value))
    }

    // MARK: - Helpers

    private func encodeSet(_ set: Set<Int>) -> String {
        let array = Array(set)
        guard let data = try? JSONEncoder().encode(array),
              let str = String(data: data, encoding: .utf8) else { return "[]" }
        return str
    }

    private func decodeSet(_ str: String) -> Set<Int> {
        guard let data = str.data(using: .utf8),
              let array = try? JSONDecoder().decode([Int].self, from: data) else { return [] }
        return Set(array)
    }

    private func encodeDict(_ dict: [String: String]) -> String {
        guard let data = try? JSONEncoder().encode(dict),
              let str = String(data: data, encoding: .utf8) else { return "{}" }
        return str
    }

    private func decodeDict(_ str: String) -> [String: String] {
        guard let data = str.data(using: .utf8),
              let dict = try? JSONDecoder().decode([String: String].self, from: data) else { return [:] }
        return dict
    }

    // MARK: - Migration

    func needsMigration() -> Bool {
        let configDir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".command_bar")
        let appJsonExists = FileManager.default.fileExists(atPath: configDir.appendingPathComponent("app.json").path)
        let dbEmpty = loadCommands().isEmpty && loadGroups().isEmpty
        return appJsonExists && dbEmpty
    }
}

// SQLite transient constant
private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
