import SwiftUI

struct RegisterClipboardSheet: View {
    @ObservedObject var store: CommandStore
    @Environment(\.dismiss) private var dismiss
    let item: ClipboardItem
    var onComplete: (() -> Void)? = nil

    @State private var selectedGroupSeq: Int?
    @State private var selectedTerminalApp: TerminalApp = .iterm2
    @State private var selectedPosition: Position = .top

    enum Position: String, CaseIterable {
        case top
        case bottom

        var localizedName: String {
            switch self {
            case .top: return L.registerClipboardPositionTop
            case .bottom: return L.registerClipboardPositionBottom
            }
        }
    }

    init(store: CommandStore, item: ClipboardItem, onComplete: (() -> Void)? = nil) {
        self.store = store
        self.item = item
        self.onComplete = onComplete
        let defaultSeq = CommandStore.defaultGroupSeq
        _selectedGroupSeq = State(initialValue: defaultSeq)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(L.registerClipboardTitle)
                .font(.headline)

            Text(item.preview)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            Divider()

            // 위치 선택
            VStack(alignment: .leading, spacing: 4) {
                Text(L.registerClipboardPosition)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Picker("", selection: $selectedPosition) {
                    ForEach(Position.allCases, id: \.self) { position in
                        Text(position.localizedName).tag(position)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
            }

            // 그룹 선택
            VStack(alignment: .leading, spacing: 4) {
                Text(L.groupTitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Picker("", selection: $selectedGroupSeq) {
                    ForEach(store.groups) { group in
                        Label {
                            Text(" \(group.name)")
                        } icon: {
                            colorCircleImage(group.color, size: 8)
                        }.tag(group.seq as Int?)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
            }

            // 터미널 앱 선택
            VStack(alignment: .leading, spacing: 4) {
                Text(L.commandTerminalApp)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Picker("", selection: $selectedTerminalApp) {
                    ForEach(TerminalApp.allCases, id: \.self) { app in
                        Text(app.rawValue).tag(app)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
            }

            Divider()

            // 버튼들
            HStack {
                Spacer()
                Button(L.buttonCancel) {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button(L.registerClipboardRegister) {
                    let asLast = selectedPosition == .bottom
                    let groupSeq = selectedGroupSeq ?? CommandStore.defaultGroupSeq
                    store.registerClipboardAsCommand(
                        item,
                        asLast: asLast,
                        groupSeq: groupSeq,
                        terminalApp: selectedTerminalApp
                    )
                    dismiss()
                    onComplete?()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(width: 280)
    }
}
