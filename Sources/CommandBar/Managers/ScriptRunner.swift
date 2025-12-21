import SwiftUI
import AppKit

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
