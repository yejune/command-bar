import SwiftUI

struct HistoryOutputView: View {
    let item: HistoryItem
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.headline)
                Text(item.timestamp, format: .dateTime)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()

            Divider()

            VStack(alignment: .leading, spacing: 12) {
                // 실행 명령어
                VStack(alignment: .leading, spacing: 4) {
                    Text(L.commandInput)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(item.command)
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(6)
                }

                // 출력
                if let output = item.output, !output.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(L.historyOutput)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        OutputTextView(text: output)
                            .padding(8)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(6)
                    }
                    .frame(maxHeight: .infinity)
                }
            }
            .padding()

            Divider()

            HStack {
                Spacer()
                Button(L.buttonClose) {
                    onClose()
                }
                .buttonStyle(HoverTextButtonStyle())
            }
            .padding()
        }
        .frame(minWidth: 450, minHeight: 350)
    }
}
