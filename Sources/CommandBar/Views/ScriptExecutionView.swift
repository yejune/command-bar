import SwiftUI
import AppKit

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

    var shortId: String {
        command.id
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 상단 헤더
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(command.label)
                        .font(.headline)
                    Spacer()
                    Button(action: copyId) {
                        Text(shortId)
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("ID 복사: {command@\(command.id)}")
                }

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
                                AutocompleteTextEditor(
                                    text: Binding(
                                        get: { values[info.name] ?? "" },
                                        set: { values[info.name] = $0 }
                                    ),
                                    suggestions: store.allEnvironmentVariableNames,
                                    idSuggestions: store.allIdSuggestions,
                                    singleLine: true
                                )
                                .frame(height: 24)
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
                        Task {
                            await executeScript()
                        }
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

    func executeScript() async {
        var finalValues = values
        for info in command.parameterInfos {
            if finalValues[info.name] == nil, let first = info.options.first {
                finalValues[info.name] = first
            }
        }
        var finalCommand = command.commandWith(values: finalValues)

        // {command#label} 또는 `command@id` 체이닝 처리 (명령어 실행)
        finalCommand = await store.resolveCommandReferences(in: finalCommand)

        // {var:xxx} 환경 변수 처리
        finalCommand = store.resolveVarReferences(in: finalCommand)

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
                title: command.label,
                command: finalCommand,
                type: .script,
                output: output,
                commandSeq: command.seq
            ))
        }
    }

    func copyId() {
        let idString = "{command@\(shortId)}"
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(idString, forType: .string)
    }
}
