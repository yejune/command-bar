import SwiftUI

struct APIParameterInputView: View {
    let command: Command
    let store: CommandStore
    let onExecute: ([String: String]) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var values: [String: String] = [:]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(command.title)
                .font(.headline)

            Text(command.url)
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)

            Divider()

            ForEach(command.apiParameterInfos, id: \.name) { info in
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
                    for info in command.apiParameterInfos {
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
        .frame(width: 450)
    }
}
