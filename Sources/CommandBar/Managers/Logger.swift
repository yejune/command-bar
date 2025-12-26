import Foundation
import AppKit

/// 앱 로그 관리자
class Logger {
    static let shared = Logger()

    private let logFileURL: URL
    private let dateFormatter: DateFormatter
    private let queue = DispatchQueue(label: "com.commandbar.logger", qos: .utility)

    private init() {
        // 로그 파일 경로: ~/Library/Logs/CommandBar/commandbar.log
        let logsDir = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Logs")
            .appendingPathComponent("CommandBar")

        try? FileManager.default.createDirectory(at: logsDir, withIntermediateDirectories: true)

        logFileURL = logsDir.appendingPathComponent("commandbar.log")

        dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"

        // 시작 로그
        log("=== CommandBar Started ===")
    }

    /// 디버그 로깅 활성화 여부 (Settings에서 가져옴)
    var isEnabled: Bool {
        Settings.shared.debugLogging
    }

    /// 로그 기록
    func log(_ message: String, level: LogLevel = .info, file: String = #file, function: String = #function, line: Int = #line) {
        // chain 레벨은 debugLogging 설정에 따라 필터링
        if level == .chain && !isEnabled {
            return
        }

        queue.async { [weak self] in
            guard let self = self else { return }

            let timestamp = self.dateFormatter.string(from: Date())
            let fileName = (file as NSString).lastPathComponent
            let logLine = "[\(timestamp)] [\(level.rawValue)] [\(fileName):\(line)] \(message)\n"

            if let data = logLine.data(using: .utf8) {
                if FileManager.default.fileExists(atPath: self.logFileURL.path) {
                    if let handle = try? FileHandle(forWritingTo: self.logFileURL) {
                        handle.seekToEndOfFile()
                        handle.write(data)
                        handle.closeFile()
                    }
                } else {
                    try? data.write(to: self.logFileURL)
                }
            }

            #if DEBUG
            print(logLine, terminator: "")
            #endif
        }
    }

    /// 체이닝 로그 (배지 치환 추적)
    func logChain(_ message: String) {
        log("🔗 \(message)", level: .chain)
    }

    /// 로그 파일 경로
    var logFilePath: String {
        logFileURL.path
    }

    /// 로그 파일 열기
    func openLogFile() {
        NSWorkspace.shared.open(logFileURL)
    }

    /// 로그 파일 내용 읽기 (최근 N줄)
    func readLastLines(_ count: Int = 100) -> String {
        guard let content = try? String(contentsOf: logFileURL, encoding: .utf8) else {
            return ""
        }
        let lines = content.components(separatedBy: .newlines)
        let lastLines = lines.suffix(count)
        return lastLines.joined(separator: "\n")
    }

    /// 로그 파일 삭제
    func clearLog() {
        try? FileManager.default.removeItem(at: logFileURL)
        log("=== Log Cleared ===")
    }

    enum LogLevel: String {
        case info = "INFO"
        case debug = "DEBUG"
        case chain = "CHAIN"
        case error = "ERROR"
        case warning = "WARN"
    }
}

// 편의 함수
func logInfo(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
    Logger.shared.log(message, level: .info, file: file, function: function, line: line)
}

func logDebug(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
    Logger.shared.log(message, level: .debug, file: file, function: function, line: line)
}

func logChain(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
    Logger.shared.log("🔗 \(message)", level: .chain, file: file, function: function, line: line)
}

func logError(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
    Logger.shared.log(message, level: .error, file: file, function: function, line: line)
}
