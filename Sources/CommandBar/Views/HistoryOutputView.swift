import SwiftUI

struct HistoryOutputView: View {
    let item: HistoryItem
    let onClose: () -> Void

    var executions: [Date] {
        Database.shared.getHistoryExecutions(historyId: item.id)
    }

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

                // 실행 이력
                if executions.count > 1 {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(L.historyExecutions)(\(executions.count))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        ScrollView {
                            VStack(alignment: .leading, spacing: 2) {
                                ForEach(executions, id: \.self) { date in
                                    Text(date, format: .dateTime)
                                        .font(.caption.monospaced())
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(maxHeight: 100)
                        .padding(8)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(6)
                    }
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
