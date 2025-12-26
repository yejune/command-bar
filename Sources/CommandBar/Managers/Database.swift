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
        -- ID 관리 테이블
        CREATE TABLE IF NOT EXISTS ids (
            id TEXT PRIMARY KEY,
            type TEXT NOT NULL,
            table_seq INTEGER NOT NULL
        );
        CREATE INDEX IF NOT EXISTS idx_ids_type_seq ON ids(type, table_seq);

        -- 그룹
        CREATE TABLE IF NOT EXISTS groups (
            seq INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            color TEXT NOT NULL,
            sort_order INTEGER DEFAULT 0
        );

        -- 명령어
        CREATE TABLE IF NOT EXISTS commands (
            seq INTEGER PRIMARY KEY AUTOINCREMENT,
            id TEXT UNIQUE NOT NULL,
            group_seq INTEGER,
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
            last_executed_at TEXT,
            label TEXT,
            FOREIGN KEY (group_seq) REFERENCES groups(seq)
        );

        -- 히스토리
        CREATE TABLE IF NOT EXISTS history (
            seq INTEGER PRIMARY KEY AUTOINCREMENT,
            id TEXT UNIQUE NOT NULL,
            timestamp TEXT NOT NULL,
            title TEXT NOT NULL,
            command TEXT NOT NULL,
            type TEXT NOT NULL,
            output TEXT,
            count INTEGER DEFAULT 1,
            end_timestamp TEXT,
            command_seq INTEGER,
            first_executed_at TEXT,
            deleted_at TEXT,
            request_url TEXT,
            request_method TEXT,
            request_headers TEXT,
            request_body TEXT,
            request_query_params TEXT,
            status_code INTEGER,
            is_success INTEGER,
            FOREIGN KEY (command_seq) REFERENCES commands(seq)
        );

        -- 클립보드
        CREATE TABLE IF NOT EXISTS clipboard (
            seq INTEGER PRIMARY KEY AUTOINCREMENT,
            id TEXT UNIQUE NOT NULL,
            timestamp TEXT NOT NULL,
            content TEXT NOT NULL,
            is_favorite INTEGER DEFAULT 0,
            copy_count INTEGER DEFAULT 1,
            first_copied_at TEXT,
            deleted_at TEXT
        );

        -- 설정
        CREATE TABLE IF NOT EXISTS settings (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL
        );

        -- API 환경
        CREATE TABLE IF NOT EXISTS environments (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            color TEXT NOT NULL DEFAULT 'blue',
            variables TEXT NOT NULL DEFAULT '{}',
            sort_order INTEGER DEFAULT 0
        );

        -- 인덱스
        CREATE INDEX IF NOT EXISTS idx_commands_group ON commands(group_seq);
        CREATE INDEX IF NOT EXISTS idx_commands_trash ON commands(is_in_trash);
        CREATE INDEX IF NOT EXISTS idx_commands_label ON commands(label);
        CREATE INDEX IF NOT EXISTS idx_history_timestamp ON history(timestamp DESC);
        CREATE INDEX IF NOT EXISTS idx_history_title ON history(title);
        CREATE INDEX IF NOT EXISTS idx_history_deleted ON history(deleted_at);
        CREATE INDEX IF NOT EXISTS idx_clipboard_timestamp ON clipboard(timestamp DESC);
        CREATE INDEX IF NOT EXISTS idx_clipboard_content ON clipboard(content);
        CREATE INDEX IF NOT EXISTS idx_clipboard_deleted ON clipboard(deleted_at);
        """

        executeStatements(createSQL)

        // 클립보드 복사 이력 테이블 생성
        let createClipboardCopiesTable = """
        CREATE TABLE IF NOT EXISTS clipboard_copies (
            id TEXT PRIMARY KEY,
            clipboard_id TEXT NOT NULL,
            copied_at TEXT NOT NULL
        )
        """
        executeStatements(createClipboardCopiesTable)

        let createClipboardCopiesIndex = "CREATE INDEX IF NOT EXISTS idx_clipboard_copies_clipboard_id ON clipboard_copies(clipboard_id)"
        sqlite3_exec(db, createClipboardCopiesIndex, nil, nil, nil)

        // 히스토리 실행 이력 테이블 생성
        let createHistoryExecutionsTable = """
        CREATE TABLE IF NOT EXISTS history_executions (
            id TEXT PRIMARY KEY,
            history_id TEXT NOT NULL,
            executed_at TEXT NOT NULL
        )
        """
        executeStatements(createHistoryExecutionsTable)

        let createHistoryExecutionsIndex = "CREATE INDEX IF NOT EXISTS idx_history_executions_history_id ON history_executions(history_id)"
        sqlite3_exec(db, createHistoryExecutionsIndex, nil, nil, nil)

        // Secure Values 테이블 (암호화된 값 저장)
        let createSecureValuesTable = """
        CREATE TABLE IF NOT EXISTS secure_values (
            id TEXT PRIMARY KEY,
            encrypted_value TEXT NOT NULL,
            key_version INTEGER NOT NULL,
            label TEXT,
            created_at TEXT NOT NULL,
            updated_at TEXT
        )
        """
        executeStatements(createSecureValuesTable)

        let secureValuesIndex = "CREATE INDEX IF NOT EXISTS idx_secure_values_key_version ON secure_values(key_version)"
        sqlite3_exec(db, secureValuesIndex, nil, nil, nil)

        let secureLabelIndex = "CREATE UNIQUE INDEX IF NOT EXISTS idx_secure_values_label ON secure_values(label) WHERE label IS NOT NULL"
        sqlite3_exec(db, secureLabelIndex, nil, nil, nil)

        // Variables 테이블 (var 라벨 저장)
        let createVariablesTable = """
        CREATE TABLE IF NOT EXISTS variables (
            id TEXT PRIMARY KEY,
            value TEXT NOT NULL,
            label TEXT UNIQUE NOT NULL,
            created_at TEXT NOT NULL,
            updated_at TEXT
        )
        """
        executeStatements(createVariablesTable)

        let variablesLabelIndex = "CREATE UNIQUE INDEX IF NOT EXISTS idx_variables_label ON variables(label)"
        sqlite3_exec(db, variablesLabelIndex, nil, nil, nil)

        let commandLabelIndex = "CREATE UNIQUE INDEX IF NOT EXISTS idx_commands_label_unique ON commands(label) WHERE label IS NOT NULL"
        sqlite3_exec(db, commandLabelIndex, nil, nil, nil)

        // Secure Key Versions 테이블 (키 버전 메타데이터)
        let createSecureKeyVersionsTable = """
        CREATE TABLE IF NOT EXISTS secure_key_versions (
            version INTEGER PRIMARY KEY,
            key_hash TEXT NOT NULL,
            created_at TEXT NOT NULL,
            is_active INTEGER DEFAULT 0
        )
        """
        executeStatements(createSecureKeyVersionsTable)

        // 마이그레이션: 기존 history 테이블에 새 컬럼 추가
        migrateHistoryTable()
    }

    private func migrateHistoryTable() {
        // 컬럼 존재 여부 확인 후 추가
        let columns = [
            ("request_url", "TEXT"),
            ("request_method", "TEXT"),
            ("request_headers", "TEXT"),
            ("request_body", "TEXT"),
            ("request_query_params", "TEXT"),
            ("status_code", "INTEGER"),
            ("is_success", "INTEGER")
        ]

        for (columnName, columnType) in columns {
            let checkSQL = "SELECT \(columnName) FROM history LIMIT 1"
            var stmt: OpaquePointer?
            if sqlite3_prepare_v2(db, checkSQL, -1, &stmt, nil) != SQLITE_OK {
                // 컬럼이 없으면 추가
                let alterSQL = "ALTER TABLE history ADD COLUMN \(columnName) \(columnType)"
                sqlite3_exec(db, alterSQL, nil, nil, nil)
            }
            sqlite3_finalize(stmt)
        }
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
        // DELETE 제거 - 개별 삭제는 deleteGroup 사용
        for (index, group) in groups.enumerated() {
            if let seq = group.seq {
                // 기존 그룹 업데이트
                let sql = """
                INSERT OR REPLACE INTO groups (seq, name, color, sort_order)
                VALUES (?, ?, ?, ?)
                """
                var stmt: OpaquePointer?
                if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
                    sqlite3_bind_int(stmt, 1, Int32(seq))
                    sqlite3_bind_text(stmt, 2, group.name, -1, SQLITE_TRANSIENT)
                    sqlite3_bind_text(stmt, 3, group.color, -1, SQLITE_TRANSIENT)
                    sqlite3_bind_int(stmt, 4, Int32(index))
                    sqlite3_step(stmt)
                }
                sqlite3_finalize(stmt)
            } else {
                // 새 그룹 추가
                let sql = """
                INSERT INTO groups (name, color, sort_order)
                VALUES (?, ?, ?)
                """
                var stmt: OpaquePointer?
                if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
                    sqlite3_bind_text(stmt, 1, group.name, -1, SQLITE_TRANSIENT)
                    sqlite3_bind_text(stmt, 2, group.color, -1, SQLITE_TRANSIENT)
                    sqlite3_bind_int(stmt, 3, Int32(index))
                    sqlite3_step(stmt)
                }
                sqlite3_finalize(stmt)
            }
        }
    }

    func deleteGroup(_ seq: Int) {
        let sql = "DELETE FROM groups WHERE seq = ?"
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int(stmt, 1, Int32(seq))
            sqlite3_step(stmt)
        }
        sqlite3_finalize(stmt)
    }

    func loadGroups() -> [Group] {
        var groups: [Group] = []
        let sql = "SELECT seq, name, color, sort_order FROM groups ORDER BY sort_order"
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            while sqlite3_step(stmt) == SQLITE_ROW {
                let seq = Int(sqlite3_column_int(stmt, 0))
                if let namePtr = sqlite3_column_text(stmt, 1),
                   let colorPtr = sqlite3_column_text(stmt, 2) {
                    let name = String(cString: namePtr)
                    let color = String(cString: colorPtr)
                    let order = Int(sqlite3_column_int(stmt, 3))
                    groups.append(Group(seq: seq, name: name, color: color, order: order))
                }
            }
        }
        sqlite3_finalize(stmt)
        return groups
    }

    // MARK: - Commands

    func saveCommands(_ commands: [Command]) {
        // DELETE 제거 - 개별 삭제는 deleteCommand 사용
        // INSERT OR REPLACE로 upsert
        for command in commands {
            insertCommand(command)
        }
    }

    func insertCommand(_ command: Command) {
        let sql = """
        INSERT OR REPLACE INTO commands (
            id, group_seq, title, command, execution_type, terminal_app,
            interval_seconds, is_running, schedule_date, repeat_type, alert_state,
            reminder_times, alerted_times, history_logged_times, acknowledged,
            is_in_trash, is_favorite, url, http_method, headers, query_params,
            body_type, body_data, file_params, last_response, last_status_code,
            last_output, last_executed_at, label
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, command.id, -1, SQLITE_TRANSIENT)
            if let groupSeq = command.groupSeq {
                sqlite3_bind_int(stmt, 2, Int32(groupSeq))
            } else {
                sqlite3_bind_null(stmt, 2)
            }
            sqlite3_bind_text(stmt, 3, command.label, -1, SQLITE_TRANSIENT)
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
            sqlite3_bind_text(stmt, 29, command.label, -1, SQLITE_TRANSIENT)
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

    func getCommandById(_ id: String) -> Command? {
        let sql = "SELECT * FROM commands WHERE id = ?"
        var stmt: OpaquePointer?
        var result: Command?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, id, -1, SQLITE_TRANSIENT)
            if sqlite3_step(stmt) == SQLITE_ROW {
                result = parseCommand(stmt)
            }
        }
        sqlite3_finalize(stmt)
        return result
    }

    private func parseCommand(_ stmt: OpaquePointer?) -> Command? {
        guard let stmt = stmt,
              let idStr = sqlite3_column_text(stmt, 1) else { return nil }

        let seq = Int(sqlite3_column_int(stmt, 0))
        let id = String(cString: idStr)
        let groupSeq = sqlite3_column_type(stmt, 2) != SQLITE_NULL ? Int(sqlite3_column_int(stmt, 2)) : nil
        // 컬럼 29(label)에서 읽기
        let label = sqlite3_column_text(stmt, 29).map { String(cString: $0) } ?? ""
        let commandStr = sqlite3_column_text(stmt, 4).map { String(cString: $0) } ?? ""
        let execTypeStr = sqlite3_column_text(stmt, 5).map { String(cString: $0) } ?? "terminal"
        let terminalStr = sqlite3_column_text(stmt, 6).map { String(cString: $0) } ?? "iterm2"
        let interval = Int(sqlite3_column_int(stmt, 7))
        let isRunning = sqlite3_column_int(stmt, 8) != 0
        let scheduleDateStr = sqlite3_column_text(stmt, 9).map { String(cString: $0) }
        let repeatTypeStr = sqlite3_column_text(stmt, 10).map { String(cString: $0) } ?? "none"
        let alertStateStr = sqlite3_column_text(stmt, 11).map { String(cString: $0) } ?? "none"
        let reminderTimesStr = sqlite3_column_text(stmt, 12).map { String(cString: $0) } ?? "[]"
        let alertedTimesStr = sqlite3_column_text(stmt, 13).map { String(cString: $0) } ?? "[]"
        let historyLoggedTimesStr = sqlite3_column_text(stmt, 14).map { String(cString: $0) } ?? "[]"
        let acknowledged = sqlite3_column_int(stmt, 15) != 0
        let isInTrash = sqlite3_column_int(stmt, 16) != 0
        let isFavorite = sqlite3_column_int(stmt, 17) != 0
        let url = sqlite3_column_text(stmt, 18).map { String(cString: $0) } ?? ""
        let httpMethodStr = sqlite3_column_text(stmt, 19).map { String(cString: $0) } ?? "GET"
        let headersStr = sqlite3_column_text(stmt, 20).map { String(cString: $0) } ?? "{}"
        let queryParamsStr = sqlite3_column_text(stmt, 21).map { String(cString: $0) } ?? "{}"
        let bodyTypeStr = sqlite3_column_text(stmt, 22).map { String(cString: $0) } ?? "none"
        let bodyData = sqlite3_column_text(stmt, 23).map { String(cString: $0) } ?? ""
        let fileParamsStr = sqlite3_column_text(stmt, 24).map { String(cString: $0) } ?? "{}"
        let lastResponse = sqlite3_column_text(stmt, 25).map { String(cString: $0) }
        let lastStatusCode = sqlite3_column_type(stmt, 26) != SQLITE_NULL ? Int(sqlite3_column_int(stmt, 26)) : nil
        let lastOutput = sqlite3_column_text(stmt, 27).map { String(cString: $0) }
        let lastExecutedAtStr = sqlite3_column_text(stmt, 28).map { String(cString: $0) }

        let scheduleDate = scheduleDateStr.flatMap { ISO8601DateFormatter().date(from: $0) }
        let lastExecutedAt = lastExecutedAtStr.flatMap { ISO8601DateFormatter().date(from: $0) }

        return Command(
            seq: seq,
            id: id,
            groupSeq: groupSeq,
            label: label,
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

    func deleteCommand(_ id: String) {
        let sql = "DELETE FROM commands WHERE id = ?"
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, id, -1, SQLITE_TRANSIENT)
            sqlite3_step(stmt)
        }
        sqlite3_finalize(stmt)
    }

    // MARK: - History

    func addHistory(_ item: HistoryItem) {
        let sql = """
        INSERT INTO history (id, timestamp, title, command, type, output, count, end_timestamp, command_seq, first_executed_at,
                            request_url, request_method, request_headers, request_body, request_query_params, status_code, is_success)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, item.id, -1, SQLITE_TRANSIENT)
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
            if let cmdSeq = item.commandSeq {
                sqlite3_bind_int(stmt, 9, Int32(cmdSeq))
            } else {
                sqlite3_bind_null(stmt, 9)
            }
            if let firstExec = item.firstExecutedAt {
                sqlite3_bind_text(stmt, 10, ISO8601DateFormatter().string(from: firstExec), -1, SQLITE_TRANSIENT)
            } else {
                sqlite3_bind_null(stmt, 10)
            }
            // API 요청 정보
            if let url = item.requestUrl {
                sqlite3_bind_text(stmt, 11, url, -1, SQLITE_TRANSIENT)
            } else {
                sqlite3_bind_null(stmt, 11)
            }
            if let method = item.requestMethod {
                sqlite3_bind_text(stmt, 12, method, -1, SQLITE_TRANSIENT)
            } else {
                sqlite3_bind_null(stmt, 12)
            }
            if let headers = item.requestHeaders {
                sqlite3_bind_text(stmt, 13, headers, -1, SQLITE_TRANSIENT)
            } else {
                sqlite3_bind_null(stmt, 13)
            }
            if let body = item.requestBody {
                sqlite3_bind_text(stmt, 14, body, -1, SQLITE_TRANSIENT)
            } else {
                sqlite3_bind_null(stmt, 14)
            }
            if let params = item.requestQueryParams {
                sqlite3_bind_text(stmt, 15, params, -1, SQLITE_TRANSIENT)
            } else {
                sqlite3_bind_null(stmt, 15)
            }
            if let code = item.statusCode {
                sqlite3_bind_int(stmt, 16, Int32(code))
            } else {
                sqlite3_bind_null(stmt, 16)
            }
            if let success = item.isSuccess {
                sqlite3_bind_int(stmt, 17, success ? 1 : 0)
            } else {
                sqlite3_bind_null(stmt, 17)
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
            sqlite3_bind_text(stmt, 4, item.id, -1, SQLITE_TRANSIENT)
            sqlite3_step(stmt)
        }
        sqlite3_finalize(stmt)
    }

    func updateHistoryOutput(id: String, output: String) {
        let sql = "UPDATE history SET output = ? WHERE id = ?"
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, output, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 2, id, -1, SQLITE_TRANSIENT)
            sqlite3_step(stmt)
        }
        sqlite3_finalize(stmt)
    }

    func loadHistory(limit: Int = 100, offset: Int = 0) -> [HistoryItem] {
        var items: [HistoryItem] = []
        let sql = "SELECT * FROM history WHERE deleted_at IS NULL ORDER BY timestamp DESC LIMIT ? OFFSET ?"
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

    func findHistoryByCommandSeq(_ commandSeq: Int, type: HistoryType) -> HistoryItem? {
        let sql = "SELECT * FROM history WHERE command_seq = ? AND type = ? ORDER BY timestamp DESC LIMIT 1"
        var stmt: OpaquePointer?
        var item: HistoryItem?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int(stmt, 1, Int32(commandSeq))
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
              let idStr = sqlite3_column_text(stmt, 1),
              let tsStr = sqlite3_column_text(stmt, 2),
              let timestamp = ISO8601DateFormatter().date(from: String(cString: tsStr)) else { return nil }

        let seq = Int(sqlite3_column_int(stmt, 0))
        let id = String(cString: idStr)
        let title = sqlite3_column_text(stmt, 3).map { String(cString: $0) } ?? ""
        let command = sqlite3_column_text(stmt, 4).map { String(cString: $0) } ?? ""
        let typeStr = sqlite3_column_text(stmt, 5).map { String(cString: $0) } ?? "executed"
        let output = sqlite3_column_text(stmt, 6).map { String(cString: $0) }
        let count = Int(sqlite3_column_int(stmt, 7))
        let endTsStr = sqlite3_column_text(stmt, 8).map { String(cString: $0) }
        let commandSeq = sqlite3_column_type(stmt, 9) != SQLITE_NULL ? Int(sqlite3_column_int(stmt, 9)) : nil
        let firstExecStr = sqlite3_column_text(stmt, 10).map { String(cString: $0) }
        let deletedAtStr = sqlite3_column_text(stmt, 11).map { String(cString: $0) }

        // API 요청 정보 (새 컬럼)
        let requestUrl = sqlite3_column_text(stmt, 12).map { String(cString: $0) }
        let requestMethod = sqlite3_column_text(stmt, 13).map { String(cString: $0) }
        let requestHeaders = sqlite3_column_text(stmt, 14).map { String(cString: $0) }
        let requestBody = sqlite3_column_text(stmt, 15).map { String(cString: $0) }
        let requestQueryParams = sqlite3_column_text(stmt, 16).map { String(cString: $0) }
        let statusCode = sqlite3_column_type(stmt, 17) != SQLITE_NULL ? Int(sqlite3_column_int(stmt, 17)) : nil
        let isSuccess = sqlite3_column_type(stmt, 18) != SQLITE_NULL ? (sqlite3_column_int(stmt, 18) == 1) : nil

        let endTimestamp = endTsStr.flatMap { ISO8601DateFormatter().date(from: $0) }
        let firstExecutedAt = firstExecStr.flatMap { ISO8601DateFormatter().date(from: $0) }
        let deletedAt = deletedAtStr.flatMap { ISO8601DateFormatter().date(from: $0) }

        var item = HistoryItem(
            seq: seq,
            id: id,
            timestamp: timestamp,
            title: title,
            command: command,
            type: HistoryType(rawValue: typeStr) ?? .executed,
            output: output,
            count: count,
            endTimestamp: endTimestamp,
            commandSeq: commandSeq,
            requestUrl: requestUrl,
            requestMethod: requestMethod,
            requestHeaders: requestHeaders,
            requestBody: requestBody,
            requestQueryParams: requestQueryParams,
            statusCode: statusCode,
            isSuccess: isSuccess
        )
        item.firstExecutedAt = firstExecutedAt
        item.deletedAt = deletedAt
        return item
    }

    /// 히스토리 중복 확인 및 업데이트 (title + command + type 기준)
    /// 중복이 있으면 count 증가, timestamp 갱신, 실행이력 추가 후 true 반환
    /// 중복이 없으면 false 반환
    func historyExistsAndUpdate(title: String, command: String, type: HistoryType) -> Bool {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedCommand = command.trimmingCharacters(in: .whitespacesAndNewlines)

        let selectSql = "SELECT id, count, deleted_at FROM history WHERE trim(title) = ? AND trim(command) = ? AND type = ? LIMIT 1"
        var stmt: OpaquePointer?
        var historyId: String?
        var currentCount = 0

        if sqlite3_prepare_v2(db, selectSql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, trimmedTitle, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 2, trimmedCommand, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 3, type.rawValue, -1, SQLITE_TRANSIENT)
            if sqlite3_step(stmt) == SQLITE_ROW {
                if let idStr = sqlite3_column_text(stmt, 0) {
                    historyId = String(cString: idStr)
                }
                currentCount = Int(sqlite3_column_int(stmt, 1))
            }
        }
        sqlite3_finalize(stmt)

        guard let id = historyId else {
            return false
        }

        // 카운트 증가, 타임스탬프 갱신, 삭제 상태 해제 (복원)
        let updateSql = "UPDATE history SET count = ?, timestamp = ?, deleted_at = NULL WHERE id = ?"
        var updateStmt: OpaquePointer?
        if sqlite3_prepare_v2(db, updateSql, -1, &updateStmt, nil) == SQLITE_OK {
            sqlite3_bind_int(updateStmt, 1, Int32(currentCount + 1))
            sqlite3_bind_text(updateStmt, 2, ISO8601DateFormatter().string(from: Date()), -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(updateStmt, 3, id, -1, SQLITE_TRANSIENT)
            sqlite3_step(updateStmt)
        }
        sqlite3_finalize(updateStmt)

        // 실행 이력 추가
        addHistoryExecution(historyId: id, executedAt: Date())

        return true
    }

    func addHistoryExecution(historyId: String, executedAt: Date) {
        let sql = "INSERT INTO history_executions (id, history_id, executed_at) VALUES (?, ?, ?)"
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, generateUniqueShortId(), -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 2, historyId, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 3, ISO8601DateFormatter().string(from: executedAt), -1, SQLITE_TRANSIENT)
            sqlite3_step(stmt)
        }
        sqlite3_finalize(stmt)
    }

    func getHistoryExecutions(historyId: String) -> [Date] {
        var dates: [Date] = []
        let sql = "SELECT executed_at FROM history_executions WHERE history_id = ? ORDER BY executed_at DESC"
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, historyId, -1, SQLITE_TRANSIENT)
            let formatter = ISO8601DateFormatter()
            while sqlite3_step(stmt) == SQLITE_ROW {
                if let dateStr = sqlite3_column_text(stmt, 0) {
                    if let date = formatter.date(from: String(cString: dateStr)) {
                        dates.append(date)
                    }
                }
            }
        }
        sqlite3_finalize(stmt)
        return dates
    }

    func clearHistory() {
        executeStatements("DELETE FROM history")
        executeStatements("DELETE FROM history_executions")
    }

    func deleteHistory(id: String) {
        var stmt: OpaquePointer?
        let sql = "DELETE FROM history WHERE id = ?"
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, id, -1, SQLITE_TRANSIENT)
            sqlite3_step(stmt)
        }
        sqlite3_finalize(stmt)
        // 관련 실행 이력도 삭제
        let execSql = "DELETE FROM history_executions WHERE history_id = ?"
        if sqlite3_prepare_v2(db, execSql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, id, -1, SQLITE_TRANSIENT)
            sqlite3_step(stmt)
        }
        sqlite3_finalize(stmt)
    }

    func getHistoryCount() -> Int {
        var count = 0
        let sql = "SELECT COUNT(*) FROM history WHERE deleted_at IS NULL"
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            if sqlite3_step(stmt) == SQLITE_ROW {
                count = Int(sqlite3_column_int(stmt, 0))
            }
        }
        sqlite3_finalize(stmt)
        return count
    }

    // MARK: - Clipboard

    func addClipboard(_ item: ClipboardItem) {
        let sql = "INSERT INTO clipboard (id, timestamp, content, is_favorite, copy_count, first_copied_at) VALUES (?, ?, ?, ?, ?, ?)"
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, item.id, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 2, ISO8601DateFormatter().string(from: item.timestamp), -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 3, item.content, -1, SQLITE_TRANSIENT)
            sqlite3_bind_int(stmt, 4, item.isFavorite ? 1 : 0)
            sqlite3_bind_int(stmt, 5, Int32(item.copyCount))
            if let firstCopiedAt = item.firstCopiedAt {
                sqlite3_bind_text(stmt, 6, ISO8601DateFormatter().string(from: firstCopiedAt), -1, SQLITE_TRANSIENT)
            } else {
                sqlite3_bind_null(stmt, 6)
            }
            sqlite3_step(stmt)
        }
        sqlite3_finalize(stmt)
    }

    /// 클립보드 내용 수정
    func updateClipboardContent(id: String, content: String) {
        let sql = "UPDATE clipboard SET content = ? WHERE id = ?"
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, content, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 2, id, -1, SQLITE_TRANSIENT)
            sqlite3_step(stmt)
        }
        sqlite3_finalize(stmt)
    }

    func loadClipboard(limit: Int = 100, offset: Int = 0) -> [ClipboardItem] {
        var items: [ClipboardItem] = []
        let sql = "SELECT * FROM clipboard WHERE deleted_at IS NULL ORDER BY timestamp DESC LIMIT ? OFFSET ?"
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
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        let sql = "SELECT 1 FROM clipboard WHERE trim(content) = ? LIMIT 1"
        var stmt: OpaquePointer?
        var exists = false
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, trimmedContent, -1, SQLITE_TRANSIENT)
            exists = sqlite3_step(stmt) == SQLITE_ROW
        }
        sqlite3_finalize(stmt)
        return exists
    }

    func clipboardExistsAndUpdate(_ content: String) -> Bool {
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        let selectSql = "SELECT id, copy_count FROM clipboard WHERE trim(content) = ? LIMIT 1"
        var stmt: OpaquePointer?
        var clipboardId: String?
        var currentCount = 0

        if sqlite3_prepare_v2(db, selectSql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, trimmedContent, -1, SQLITE_TRANSIENT)
            if sqlite3_step(stmt) == SQLITE_ROW {
                if let idStr = sqlite3_column_text(stmt, 0) {
                    clipboardId = String(cString: idStr)
                }
                currentCount = Int(sqlite3_column_int(stmt, 1))
            }
        }
        sqlite3_finalize(stmt)

        guard let id = clipboardId else {
            return false
        }

        // 카운트 증가 및 타임스탬프 갱신 (최상단 이동)
        let updateSql = "UPDATE clipboard SET copy_count = ?, timestamp = ? WHERE id = ?"
        var updateStmt: OpaquePointer?
        if sqlite3_prepare_v2(db, updateSql, -1, &updateStmt, nil) == SQLITE_OK {
            sqlite3_bind_int(updateStmt, 1, Int32(currentCount + 1))
            sqlite3_bind_text(updateStmt, 2, ISO8601DateFormatter().string(from: Date()), -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(updateStmt, 3, id, -1, SQLITE_TRANSIENT)
            sqlite3_step(updateStmt)
        }
        sqlite3_finalize(updateStmt)

        // 복사 이력 추가
        addClipboardCopy(clipboardId: id, copiedAt: Date())

        return true
    }

    func addClipboardCopy(clipboardId: String, copiedAt: Date) {
        let sql = "INSERT INTO clipboard_copies (id, clipboard_id, copied_at) VALUES (?, ?, ?)"
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, generateUniqueShortId(), -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 2, clipboardId, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 3, ISO8601DateFormatter().string(from: copiedAt), -1, SQLITE_TRANSIENT)
            sqlite3_step(stmt)
        }
        sqlite3_finalize(stmt)
    }

    func deleteClipboard(_ id: String) {
        let sql = "DELETE FROM clipboard WHERE id = ?"
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, id, -1, SQLITE_TRANSIENT)
            sqlite3_step(stmt)
        }
        sqlite3_finalize(stmt)
    }

    private func parseClipboardItem(_ stmt: OpaquePointer?) -> ClipboardItem? {
        guard let stmt = stmt,
              let idStr = sqlite3_column_text(stmt, 1),
              let tsStr = sqlite3_column_text(stmt, 2),
              let timestamp = ISO8601DateFormatter().date(from: String(cString: tsStr)),
              let contentPtr = sqlite3_column_text(stmt, 3) else { return nil }

        let seq = Int(sqlite3_column_int(stmt, 0))
        let id = String(cString: idStr)
        let content = String(cString: contentPtr)
        let isFavorite = sqlite3_column_int(stmt, 4) != 0
        let copyCount = Int(sqlite3_column_int(stmt, 5))
        let firstCopiedAtStr = sqlite3_column_text(stmt, 6).map { String(cString: $0) }
        let firstCopiedAt = firstCopiedAtStr.flatMap { ISO8601DateFormatter().date(from: $0) }
        let deletedAtStr = sqlite3_column_text(stmt, 7).map { String(cString: $0) }
        let deletedAt = deletedAtStr.flatMap { ISO8601DateFormatter().date(from: $0) }

        return ClipboardItem(seq: seq, id: id, content: content, timestamp: timestamp, isFavorite: isFavorite, copyCount: copyCount, firstCopiedAt: firstCopiedAt, deletedAt: deletedAt)
    }

    func clearClipboard() {
        executeStatements("DELETE FROM clipboard")
        executeStatements("DELETE FROM clipboard_copies")
    }

    func getClipboardCount() -> Int {
        var count = 0
        let sql = "SELECT COUNT(*) FROM clipboard WHERE deleted_at IS NULL"
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            if sqlite3_step(stmt) == SQLITE_ROW {
                count = Int(sqlite3_column_int(stmt, 0))
            }
        }
        sqlite3_finalize(stmt)
        return count
    }

    func toggleClipboardFavorite(_ id: String) -> Bool {
        // 현재 값 읽기
        var currentValue = false
        let selectSQL = "SELECT is_favorite FROM clipboard WHERE id = ?"
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, selectSQL, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, id, -1, SQLITE_TRANSIENT)
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
            sqlite3_bind_text(updateStmt, 2, id, -1, SQLITE_TRANSIENT)
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

    // MARK: - Environments

    func saveEnvironments(_ environments: [APIEnvironment]) {
        // DELETE 제거 - INSERT OR REPLACE로 upsert
        for (index, env) in environments.enumerated() {
            let sql = """
            INSERT OR REPLACE INTO environments (id, name, color, variables, sort_order)
            VALUES (?, ?, ?, ?, ?)
            """
            var stmt: OpaquePointer?
            if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
                sqlite3_bind_text(stmt, 1, env.id.uuidString, -1, SQLITE_TRANSIENT)
                sqlite3_bind_text(stmt, 2, env.name, -1, SQLITE_TRANSIENT)
                sqlite3_bind_text(stmt, 3, env.color, -1, SQLITE_TRANSIENT)
                sqlite3_bind_text(stmt, 4, encodeDict(env.variables), -1, SQLITE_TRANSIENT)
                sqlite3_bind_int(stmt, 5, Int32(index))
                sqlite3_step(stmt)
            }
            sqlite3_finalize(stmt)
        }
    }

    func loadEnvironments() -> [APIEnvironment] {
        var environments: [APIEnvironment] = []
        let sql = "SELECT id, name, color, variables, sort_order FROM environments ORDER BY sort_order"
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            while sqlite3_step(stmt) == SQLITE_ROW {
                if let idStr = sqlite3_column_text(stmt, 0),
                   let namePtr = sqlite3_column_text(stmt, 1),
                   let colorPtr = sqlite3_column_text(stmt, 2),
                   let variablesPtr = sqlite3_column_text(stmt, 3),
                   let id = UUID(uuidString: String(cString: idStr)) {
                    let name = String(cString: namePtr)
                    let color = String(cString: colorPtr)
                    let variablesStr = String(cString: variablesPtr)
                    let order = Int(sqlite3_column_int(stmt, 4))
                    environments.append(APIEnvironment(
                        id: id,
                        name: name,
                        color: color,
                        variables: decodeDict(variablesStr),
                        order: order
                    ))
                }
            }
        }
        sqlite3_finalize(stmt)
        return environments
    }

    func insertEnvironment(_ env: APIEnvironment) {
        let sql = """
        INSERT OR REPLACE INTO environments (id, name, color, variables, sort_order)
        VALUES (?, ?, ?, ?, ?)
        """
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, env.id.uuidString, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 2, env.name, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 3, env.color, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 4, encodeDict(env.variables), -1, SQLITE_TRANSIENT)
            sqlite3_bind_int(stmt, 5, Int32(env.order))
            sqlite3_step(stmt)
        }
        sqlite3_finalize(stmt)
    }

    // MARK: - JSON Migration Check

    func needsMigration() -> Bool {
        let configDir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".command_bar")
        let appJsonExists = FileManager.default.fileExists(atPath: configDir.appendingPathComponent("app.json").path)
        let dbEmpty = loadCommands().isEmpty && loadGroups().isEmpty
        return appJsonExists && dbEmpty
    }

    // MARK: - Short IDs

    /// 유니크한 6자 short_id 생성
    /// 타입과 seq에 맞는 유니크 ID 생성 및 등록
    func generateUniqueId(type: String, tableSeq: Int) -> String {
        let chars = "abcdefghijklmnopqrstuvwxyz0123456789"
        var shortId: String
        var attempts = 0
        repeat {
            shortId = String((0..<6).map { _ in chars.randomElement()! })
            attempts += 1
            if attempts > 1000 { // 무한루프 방지
                shortId += String(Int.random(in: 0...999))
                break
            }
        } while idExists(shortId)

        // ids 테이블에 등록
        let sql = "INSERT OR REPLACE INTO ids (id, type, table_seq) VALUES (?, ?, ?)"
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, shortId, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 2, type, -1, SQLITE_TRANSIENT)
            sqlite3_bind_int(stmt, 3, Int32(tableSeq))
            sqlite3_step(stmt)
        }
        sqlite3_finalize(stmt)

        return shortId
    }

    func generateUniqueShortId(length: Int = 6) -> String {
        let chars = "abcdefghijklmnopqrstuvwxyz0123456789"
        var shortId: String
        var attempts = 0
        repeat {
            shortId = String((0..<length).map { _ in chars.randomElement()! })
            attempts += 1
            if attempts > 1000 { // 무한루프 방지
                shortId += String(Int.random(in: 0...999))
                break
            }
        } while idExists(shortId)
        return shortId
    }

    /// ID 중복 체크 (ids 테이블에서 확인)
    func idExists(_ id: String) -> Bool {
        let sql = "SELECT 1 FROM ids WHERE id = ? LIMIT 1"
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, id, -1, SQLITE_TRANSIENT)
            if sqlite3_step(stmt) == SQLITE_ROW {
                sqlite3_finalize(stmt)
                return true
            }
        }
        sqlite3_finalize(stmt)
        return false
    }

    // MARK: - 휴지통 (Trash)

    // 히스토리 소프트 삭제
    func softDeleteHistory(id: String) {
        let now = ISO8601DateFormatter().string(from: Date())
        let sql = "UPDATE history SET deleted_at = ? WHERE id = ?"
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, now, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 2, id, -1, SQLITE_TRANSIENT)
            sqlite3_step(stmt)
        }
        sqlite3_finalize(stmt)
    }

    // 클립보드 소프트 삭제
    func softDeleteClipboard(id: String) {
        let now = ISO8601DateFormatter().string(from: Date())
        let sql = "UPDATE clipboard SET deleted_at = ? WHERE id = ?"
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, now, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 2, id, -1, SQLITE_TRANSIENT)
            sqlite3_step(stmt)
        }
        sqlite3_finalize(stmt)
    }

    // 히스토리 복원
    func restoreHistory(id: String) {
        let sql = "UPDATE history SET deleted_at = NULL WHERE id = ?"
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, id, -1, SQLITE_TRANSIENT)
            sqlite3_step(stmt)
        }
        sqlite3_finalize(stmt)
    }

    // 클립보드 복원
    func restoreClipboard(id: String) {
        let sql = "UPDATE clipboard SET deleted_at = NULL WHERE id = ?"
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, id, -1, SQLITE_TRANSIENT)
            sqlite3_step(stmt)
        }
        sqlite3_finalize(stmt)
    }

    // 삭제된 히스토리 로드
    func loadTrashHistory(limit: Int = 100, offset: Int = 0) -> [HistoryItem] {
        var items: [HistoryItem] = []
        let sql = "SELECT * FROM history WHERE deleted_at IS NOT NULL ORDER BY deleted_at DESC LIMIT ? OFFSET ?"
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

    // 삭제된 클립보드 로드
    func loadTrashClipboard(limit: Int = 100, offset: Int = 0) -> [ClipboardItem] {
        var items: [ClipboardItem] = []
        let sql = "SELECT * FROM clipboard WHERE deleted_at IS NOT NULL ORDER BY deleted_at DESC LIMIT ? OFFSET ?"
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

    // 삭제된 히스토리 개수
    func getTrashHistoryCount() -> Int {
        var count = 0
        let sql = "SELECT COUNT(*) FROM history WHERE deleted_at IS NOT NULL"
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            if sqlite3_step(stmt) == SQLITE_ROW {
                count = Int(sqlite3_column_int(stmt, 0))
            }
        }
        sqlite3_finalize(stmt)
        return count
    }

    // 삭제된 클립보드 개수
    func getTrashClipboardCount() -> Int {
        var count = 0
        let sql = "SELECT COUNT(*) FROM clipboard WHERE deleted_at IS NOT NULL"
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            if sqlite3_step(stmt) == SQLITE_ROW {
                count = Int(sqlite3_column_int(stmt, 0))
            }
        }
        sqlite3_finalize(stmt)
        return count
    }

    // 휴지통 비우기 (히스토리)
    func emptyTrashHistory() {
        // 영구 삭제된 히스토리의 실행 이력도 삭제
        executeStatements("DELETE FROM history_executions WHERE history_id IN (SELECT id FROM history WHERE deleted_at IS NOT NULL)")
        executeStatements("DELETE FROM history WHERE deleted_at IS NOT NULL")
    }

    // 휴지통 비우기 (클립보드)
    func emptyTrashClipboard() {
        // 영구 삭제된 클립보드의 복사 이력도 삭제
        executeStatements("DELETE FROM clipboard_copies WHERE clipboard_id IN (SELECT id FROM clipboard WHERE deleted_at IS NOT NULL)")
        executeStatements("DELETE FROM clipboard WHERE deleted_at IS NOT NULL")
    }

    // 전체 휴지통 비우기
    func emptyAllTrash() {
        emptyTrashHistory()
        emptyTrashClipboard()
    }

    // MARK: - Secure Values (암호화된 값 관리)

    /// 암호화된 값 저장 (라벨 포함)
    func insertSecureValue(id: String, encryptedValue: String, keyVersion: Int, label: String? = nil) {
        let now = ISO8601DateFormatter().string(from: Date())
        let sql = "INSERT OR REPLACE INTO secure_values (id, encrypted_value, key_version, label, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?)"
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, id, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 2, encryptedValue, -1, SQLITE_TRANSIENT)
            sqlite3_bind_int(stmt, 3, Int32(keyVersion))
            if let label = label {
                sqlite3_bind_text(stmt, 4, label, -1, SQLITE_TRANSIENT)
            } else {
                sqlite3_bind_null(stmt, 4)
            }
            sqlite3_bind_text(stmt, 5, now, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 6, now, -1, SQLITE_TRANSIENT)
            sqlite3_step(stmt)
        }
        sqlite3_finalize(stmt)
    }

    /// 라벨로 secure value ID 조회
    func getSecureIdByLabel(_ label: String) -> String? {
        let sql = "SELECT id FROM secure_values WHERE label = ?"
        var stmt: OpaquePointer?
        var result: String?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, label, -1, SQLITE_TRANSIENT)
            if sqlite3_step(stmt) == SQLITE_ROW {
                if let idCStr = sqlite3_column_text(stmt, 0) {
                    result = String(cString: idCStr)
                }
            }
        }
        sqlite3_finalize(stmt)
        return result
    }

    /// ID로 라벨 조회
    func getSecureLabelById(_ id: String) -> String? {
        let sql = "SELECT label FROM secure_values WHERE id = ?"
        var stmt: OpaquePointer?
        var result: String?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, id, -1, SQLITE_TRANSIENT)
            if sqlite3_step(stmt) == SQLITE_ROW {
                if let labelCStr = sqlite3_column_text(stmt, 0) {
                    result = String(cString: labelCStr)
                }
            }
        }
        sqlite3_finalize(stmt)
        return result
    }

    /// 라벨 존재 여부 확인
    func secureLabelExists(_ label: String) -> Bool {
        return getSecureIdByLabel(label) != nil
    }

    /// 모든 라벨 목록 조회
    func getAllSecureLabels() -> [String] {
        var result: [String] = []
        let sql = "SELECT label FROM secure_values WHERE label IS NOT NULL ORDER BY label"
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            while sqlite3_step(stmt) == SQLITE_ROW {
                if let labelCStr = sqlite3_column_text(stmt, 0) {
                    result.append(String(cString: labelCStr))
                }
            }
        }
        sqlite3_finalize(stmt)
        return result
    }

    /// 암호화된 값 조회
    func getSecureValue(id: String) -> (encrypted: String, keyVersion: Int)? {
        let sql = "SELECT encrypted_value, key_version FROM secure_values WHERE id = ?"
        var stmt: OpaquePointer?
        var result: (encrypted: String, keyVersion: Int)?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, id, -1, SQLITE_TRANSIENT)
            if sqlite3_step(stmt) == SQLITE_ROW {
                if let encryptedCStr = sqlite3_column_text(stmt, 0) {
                    let encrypted = String(cString: encryptedCStr)
                    let keyVersion = Int(sqlite3_column_int(stmt, 1))
                    result = (encrypted, keyVersion)
                }
            }
        }
        sqlite3_finalize(stmt)
        return result
    }

    /// 암호화된 값 업데이트 (키 마이그레이션 시 사용)
    func updateSecureValue(id: String, encryptedValue: String, keyVersion: Int) {
        let now = ISO8601DateFormatter().string(from: Date())
        let sql = "UPDATE secure_values SET encrypted_value = ?, key_version = ?, updated_at = ? WHERE id = ?"
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, encryptedValue, -1, SQLITE_TRANSIENT)
            sqlite3_bind_int(stmt, 2, Int32(keyVersion))
            sqlite3_bind_text(stmt, 3, now, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 4, id, -1, SQLITE_TRANSIENT)
            sqlite3_step(stmt)
        }
        sqlite3_finalize(stmt)
    }

    /// 암호화된 값 삭제
    func deleteSecureValue(id: String) {
        let sql = "DELETE FROM secure_values WHERE id = ?"
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, id, -1, SQLITE_TRANSIENT)
            sqlite3_step(stmt)
        }
        sqlite3_finalize(stmt)
    }

    /// 암호화된 값의 라벨 수정
    func updateSecureLabel(id: String, label: String?) {
        let now = ISO8601DateFormatter().string(from: Date())
        let sql = "UPDATE secure_values SET label = ?, updated_at = ? WHERE id = ?"
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            if let label = label, !label.isEmpty {
                sqlite3_bind_text(stmt, 1, label, -1, SQLITE_TRANSIENT)
            } else {
                sqlite3_bind_null(stmt, 1)
            }
            sqlite3_bind_text(stmt, 2, now, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 3, id, -1, SQLITE_TRANSIENT)
            sqlite3_step(stmt)
        }
        sqlite3_finalize(stmt)
    }

    /// 전체 암호화된 값 목록 (키 버전 포함)
    func getAllSecureValues() -> [(id: String, keyVersion: Int)] {
        var result: [(id: String, keyVersion: Int)] = []
        let sql = "SELECT id, key_version FROM secure_values"
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            while sqlite3_step(stmt) == SQLITE_ROW {
                if let idCStr = sqlite3_column_text(stmt, 0) {
                    let id = String(cString: idCStr)
                    let keyVersion = Int(sqlite3_column_int(stmt, 1))
                    result.append((id, keyVersion))
                }
            }
        }
        sqlite3_finalize(stmt)
        return result
    }

    /// 전체 암호화된 값 목록 (상세 정보 포함)
    func getAllSecureValuesWithDetails() -> [(id: String, label: String?, createdAt: Date, keyVersion: Int)] {
        var result: [(id: String, label: String?, createdAt: Date, keyVersion: Int)] = []
        let sql = "SELECT id, label, created_at, key_version FROM secure_values ORDER BY created_at DESC"
        var stmt: OpaquePointer?
        let formatter = ISO8601DateFormatter()
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            while sqlite3_step(stmt) == SQLITE_ROW {
                if let idCStr = sqlite3_column_text(stmt, 0) {
                    let id = String(cString: idCStr)
                    let label = sqlite3_column_text(stmt, 1).map { String(cString: $0) }
                    let createdAtStr = sqlite3_column_text(stmt, 2).map { String(cString: $0) } ?? ""
                    let createdAt = formatter.date(from: createdAtStr) ?? Date()
                    let keyVersion = Int(sqlite3_column_int(stmt, 3))
                    result.append((id, label, createdAt, keyVersion))
                }
            }
        }
        sqlite3_finalize(stmt)
        return result
    }

    /// secure value ID 존재 여부 확인
    func secureValueExists(id: String) -> Bool {
        let sql = "SELECT 1 FROM secure_values WHERE id = ? LIMIT 1"
        var stmt: OpaquePointer?
        var exists = false
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, id, -1, SQLITE_TRANSIENT)
            exists = sqlite3_step(stmt) == SQLITE_ROW
        }
        sqlite3_finalize(stmt)
        return exists
    }

    /// 6자리 유니크 secure ID 생성
    func generateSecureId() -> String {
        let chars = "abcdefghijklmnopqrstuvwxyz0123456789"
        var id: String
        repeat {
            id = String((0..<6).map { _ in chars.randomElement()! })
        } while secureValueExists(id: id)
        return id
    }

    // MARK: - Secure Key Versions (키 버전 관리)

    /// 현재 활성 키 버전 조회
    func getCurrentKeyVersion() -> Int {
        let sql = "SELECT version FROM secure_key_versions WHERE is_active = 1 LIMIT 1"
        var stmt: OpaquePointer?
        var version = 0
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            if sqlite3_step(stmt) == SQLITE_ROW {
                version = Int(sqlite3_column_int(stmt, 0))
            }
        }
        sqlite3_finalize(stmt)
        return version
    }

    /// 새 키 버전 등록
    func insertKeyVersion(version: Int, keyHash: String) {
        let now = ISO8601DateFormatter().string(from: Date())
        let sql = "INSERT INTO secure_key_versions (version, key_hash, created_at, is_active) VALUES (?, ?, ?, 0)"
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int(stmt, 1, Int32(version))
            sqlite3_bind_text(stmt, 2, keyHash, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 3, now, -1, SQLITE_TRANSIENT)
            sqlite3_step(stmt)
        }
        sqlite3_finalize(stmt)
    }

    /// 키 버전 활성화 (기존 활성 해제 후)
    func setActiveKeyVersion(version: Int) {
        // 모든 키 비활성화
        executeStatements("UPDATE secure_key_versions SET is_active = 0")
        // 지정된 키 활성화
        let sql = "UPDATE secure_key_versions SET is_active = 1 WHERE version = ?"
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int(stmt, 1, Int32(version))
            sqlite3_step(stmt)
        }
        sqlite3_finalize(stmt)
    }

    /// 키 해시 조회 (검증용)
    func getKeyHash(version: Int) -> String? {
        let sql = "SELECT key_hash FROM secure_key_versions WHERE version = ?"
        var stmt: OpaquePointer?
        var keyHash: String?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int(stmt, 1, Int32(version))
            if sqlite3_step(stmt) == SQLITE_ROW {
                if let hashCStr = sqlite3_column_text(stmt, 0) {
                    keyHash = String(cString: hashCStr)
                }
            }
        }
        sqlite3_finalize(stmt)
        return keyHash
    }

    /// 다음 키 버전 번호 조회
    func getNextKeyVersion() -> Int {
        let sql = "SELECT COALESCE(MAX(version), 0) + 1 FROM secure_key_versions"
        var stmt: OpaquePointer?
        var nextVersion = 1
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            if sqlite3_step(stmt) == SQLITE_ROW {
                nextVersion = Int(sqlite3_column_int(stmt, 0))
            }
        }
        sqlite3_finalize(stmt)
        return nextVersion
    }

    /// 특정 키 버전으로 암호화된 값 목록
    func getSecureValuesByKeyVersion(version: Int) -> [String] {
        var ids: [String] = []
        let sql = "SELECT id FROM secure_values WHERE key_version = ?"
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int(stmt, 1, Int32(version))
            while sqlite3_step(stmt) == SQLITE_ROW {
                if let idCStr = sqlite3_column_text(stmt, 0) {
                    ids.append(String(cString: idCStr))
                }
            }
        }
        sqlite3_finalize(stmt)
        return ids
    }

    // MARK: - Variables (var 라벨 관리)

    /// 변수 저장 (라벨 포함)
    func insertVariable(id: String, value: String, label: String) {
        let now = ISO8601DateFormatter().string(from: Date())
        let sql = "INSERT OR REPLACE INTO variables (id, value, label, created_at, updated_at) VALUES (?, ?, ?, ?, ?)"
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, id, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 2, value, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 3, label, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 4, now, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 5, now, -1, SQLITE_TRANSIENT)
            sqlite3_step(stmt)
        }
        sqlite3_finalize(stmt)
    }

    /// 라벨로 변수 ID 조회
    func getVariableIdByLabel(_ label: String) -> String? {
        let sql = "SELECT id FROM variables WHERE label = ?"
        var stmt: OpaquePointer?
        var result: String?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, label, -1, SQLITE_TRANSIENT)
            if sqlite3_step(stmt) == SQLITE_ROW {
                if let idCStr = sqlite3_column_text(stmt, 0) {
                    result = String(cString: idCStr)
                }
            }
        }
        sqlite3_finalize(stmt)
        return result
    }

    /// ID로 변수 라벨 조회
    func getVariableLabelById(_ id: String) -> String? {
        let sql = "SELECT label FROM variables WHERE id = ?"
        var stmt: OpaquePointer?
        var result: String?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, id, -1, SQLITE_TRANSIENT)
            if sqlite3_step(stmt) == SQLITE_ROW {
                if let labelCStr = sqlite3_column_text(stmt, 0) {
                    result = String(cString: labelCStr)
                }
            }
        }
        sqlite3_finalize(stmt)
        return result
    }

    /// 라벨로 변수 값 조회
    func getVariableValueByLabel(_ label: String) -> String? {
        let sql = "SELECT value FROM variables WHERE label = ?"
        var stmt: OpaquePointer?
        var result: String?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, label, -1, SQLITE_TRANSIENT)
            if sqlite3_step(stmt) == SQLITE_ROW {
                if let valueCStr = sqlite3_column_text(stmt, 0) {
                    result = String(cString: valueCStr)
                }
            }
        }
        sqlite3_finalize(stmt)
        return result
    }

    /// ID로 변수 값 조회
    func getVariableValueById(_ id: String) -> String? {
        let sql = "SELECT value FROM variables WHERE id = ?"
        var stmt: OpaquePointer?
        var result: String?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, id, -1, SQLITE_TRANSIENT)
            if sqlite3_step(stmt) == SQLITE_ROW {
                if let valueCStr = sqlite3_column_text(stmt, 0) {
                    result = String(cString: valueCStr)
                }
            }
        }
        sqlite3_finalize(stmt)
        return result
    }

    /// 변수 라벨 존재 여부 확인
    func variableLabelExists(_ label: String) -> Bool {
        return getVariableIdByLabel(label) != nil
    }

    /// 변수 라벨 업데이트
    func updateVariableLabel(id: String, label: String?) {
        let sql = "UPDATE variables SET label = ? WHERE id = ?"
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            if let label = label {
                sqlite3_bind_text(stmt, 1, label, -1, SQLITE_TRANSIENT)
            } else {
                sqlite3_bind_null(stmt, 1)
            }
            sqlite3_bind_text(stmt, 2, id, -1, SQLITE_TRANSIENT)
            sqlite3_step(stmt)
        }
        sqlite3_finalize(stmt)
    }

    /// 변수 값 업데이트
    func updateVariableValue(id: String, value: String) {
        let sql = "UPDATE variables SET value = ? WHERE id = ?"
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, value, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 2, id, -1, SQLITE_TRANSIENT)
            sqlite3_step(stmt)
        }
        sqlite3_finalize(stmt)
    }

    /// 모든 변수 라벨 목록 조회
    func getAllVariableLabels() -> [String] {
        var result: [String] = []
        let sql = "SELECT label FROM variables WHERE label IS NOT NULL ORDER BY label"
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            while sqlite3_step(stmt) == SQLITE_ROW {
                if let labelCStr = sqlite3_column_text(stmt, 0) {
                    result.append(String(cString: labelCStr))
                }
            }
        }
        sqlite3_finalize(stmt)
        return result
    }

    /// 모든 변수 ID 목록 조회
    func getAllVariableIds() -> [String] {
        var result: [String] = []
        let sql = "SELECT id FROM variables ORDER BY id"
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            while sqlite3_step(stmt) == SQLITE_ROW {
                if let idCStr = sqlite3_column_text(stmt, 0) {
                    result.append(String(cString: idCStr))
                }
            }
        }
        sqlite3_finalize(stmt)
        return result
    }

    /// 모든 암호화 값 ID 목록 조회
    func getAllSecureIds() -> [String] {
        var result: [String] = []
        let sql = "SELECT id FROM secure_values ORDER BY id"
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            while sqlite3_step(stmt) == SQLITE_ROW {
                if let idCStr = sqlite3_column_text(stmt, 0) {
                    result.append(String(cString: idCStr))
                }
            }
        }
        sqlite3_finalize(stmt)
        return result
    }

    /// 변수 삭제
    func deleteVariable(id: String) {
        let sql = "DELETE FROM variables WHERE id = ?"
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, id, -1, SQLITE_TRANSIENT)
            sqlite3_step(stmt)
        }
        sqlite3_finalize(stmt)
    }

    /// 6자리 유니크 변수 ID 생성
    func generateVariableId() -> String {
        let chars = "abcdefghijklmnopqrstuvwxyz0123456789"
        var id: String
        repeat {
            id = String((0..<6).map { _ in chars.randomElement()! })
        } while variableIdExists(id: id)
        return id
    }

    /// 변수 ID 존재 여부 확인
    func variableIdExists(id: String) -> Bool {
        let sql = "SELECT 1 FROM variables WHERE id = ? LIMIT 1"
        var stmt: OpaquePointer?
        var exists = false
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, id, -1, SQLITE_TRANSIENT)
            exists = sqlite3_step(stmt) == SQLITE_ROW
        }
        sqlite3_finalize(stmt)
        return exists
    }

    // MARK: - Command Labels (id 라벨 관리)

    /// 명령어에 라벨 설정
    func setCommandLabel(commandId: String, label: String?) {
        let sql = "UPDATE commands SET label = ? WHERE id = ?"
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            if let label = label {
                sqlite3_bind_text(stmt, 1, label, -1, SQLITE_TRANSIENT)
            } else {
                sqlite3_bind_null(stmt, 1)
            }
            sqlite3_bind_text(stmt, 2, commandId, -1, SQLITE_TRANSIENT)
            sqlite3_step(stmt)
        }
        sqlite3_finalize(stmt)
    }

    /// 명령어 라벨 업데이트 (alias)
    func updateCommandLabel(id: String, label: String?) {
        setCommandLabel(commandId: id, label: label)
    }

    /// 라벨 또는 제목으로 명령어 ID 조회
    func getCommandIdByLabel(_ label: String) -> String? {
        // 먼저 label에서 찾고, 없으면 title에서 찾기
        let sql = "SELECT id FROM commands WHERE label = ? OR title = ? LIMIT 1"
        var stmt: OpaquePointer?
        var result: String?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, label, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 2, label, -1, SQLITE_TRANSIENT)
            if sqlite3_step(stmt) == SQLITE_ROW {
                if let idCStr = sqlite3_column_text(stmt, 0) {
                    result = String(cString: idCStr)
                }
            }
        }
        sqlite3_finalize(stmt)
        return result
    }

    /// ID로 명령어 라벨 조회 (label이 없으면 title을 fallback으로 사용)
    func getCommandLabelById(_ commandId: String) -> String? {
        let sql = "SELECT label, title FROM commands WHERE id = ?"
        var stmt: OpaquePointer?
        var result: String?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, commandId, -1, SQLITE_TRANSIENT)
            if sqlite3_step(stmt) == SQLITE_ROW {
                // label이 있으면 label 사용, 없으면 title을 fallback으로 사용
                if let labelCStr = sqlite3_column_text(stmt, 0) {
                    result = String(cString: labelCStr)
                } else if let titleCStr = sqlite3_column_text(stmt, 1) {
                    result = String(cString: titleCStr)
                }
            }
        }
        sqlite3_finalize(stmt)
        return result
    }

    /// ID로 명령어 lastResponse 조회
    func getCommandLastResponse(_ commandId: String) -> String? {
        let sql = "SELECT last_response FROM commands WHERE id = ?"
        var stmt: OpaquePointer?
        var result: String?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, commandId, -1, SQLITE_TRANSIENT)
            if sqlite3_step(stmt) == SQLITE_ROW {
                if let responseCStr = sqlite3_column_text(stmt, 0) {
                    result = String(cString: responseCStr)
                }
            }
        }
        sqlite3_finalize(stmt)
        return result
    }

    /// 명령어 라벨 존재 여부 확인
    func commandLabelExists(_ label: String) -> Bool {
        return getCommandIdByLabel(label) != nil
    }

    /// 모든 명령어 라벨 목록 조회
    func getAllCommandLabels() -> [String] {
        var result: [String] = []
        let sql = "SELECT label FROM commands WHERE label IS NOT NULL ORDER BY label"
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            while sqlite3_step(stmt) == SQLITE_ROW {
                if let labelCStr = sqlite3_column_text(stmt, 0) {
                    result.append(String(cString: labelCStr))
                }
            }
        }
        sqlite3_finalize(stmt)
        return result
    }

    // MARK: - ID/Seq Helper Functions

    /// ID로 테이블 정보 조회 (체이닝용)
    func getTableInfo(id: String) -> (type: String, seq: Int)? {
        let sql = "SELECT type, table_seq FROM ids WHERE id = ?"
        var stmt: OpaquePointer?
        var result: (type: String, seq: Int)?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, id, -1, SQLITE_TRANSIENT)
            if sqlite3_step(stmt) == SQLITE_ROW {
                if let typeStr = sqlite3_column_text(stmt, 0) {
                    let type = String(cString: typeStr)
                    let seq = Int(sqlite3_column_int(stmt, 1))
                    result = (type: type, seq: seq)
                }
            }
        }
        sqlite3_finalize(stmt)
        return result
    }

    /// group id로 seq 조회

    /// command id로 seq 조회
    func getCommandSeq(commandId: String) -> Int? {
        let sql = "SELECT seq FROM commands WHERE id = ?"
        var stmt: OpaquePointer?
        var seq: Int?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, commandId, -1, SQLITE_TRANSIENT)
            if sqlite3_step(stmt) == SQLITE_ROW {
                seq = Int(sqlite3_column_int(stmt, 0))
            }
        }
        sqlite3_finalize(stmt)
        return seq
    }

    /// 유니크한 6자리 command id 생성
    func generateCommandId() -> String {
        let chars = "abcdefghijklmnopqrstuvwxyz0123456789"
        var id: String
        repeat {
            id = String((0..<6).map { _ in chars.randomElement()! })
        } while commandIdExists(id)
        return id
    }

    /// command id 존재 여부 확인
    func commandIdExists(_ id: String) -> Bool {
        let sql = "SELECT COUNT(*) FROM commands WHERE id = ?"
        var stmt: OpaquePointer?
        var exists = false
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, id, -1, SQLITE_TRANSIENT)
            if sqlite3_step(stmt) == SQLITE_ROW {
                exists = sqlite3_column_int(stmt, 0) > 0
            }
        }
        sqlite3_finalize(stmt)
        return exists
    }

    /// command id 업데이트
    func updateCommandId(oldId: String, newId: String) -> Bool {
        // 새 ID가 이미 존재하는지 확인
        if commandIdExists(newId) {
            return false
        }

        let sql = "UPDATE commands SET id = ? WHERE id = ?"
        var stmt: OpaquePointer?
        var success = false
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, newId, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 2, oldId, -1, SQLITE_TRANSIENT)
            success = sqlite3_step(stmt) == SQLITE_DONE
        }
        sqlite3_finalize(stmt)
        return success
    }
}

// SQLite transient constant
private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
