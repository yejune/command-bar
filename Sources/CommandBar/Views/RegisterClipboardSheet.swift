import SwiftUI

struct RegisterClipboardSheet: View {
    @ObservedObject var store: CommandStore
    @Environment(\.dismiss) private var dismiss
    let item: ClipboardItem

    @State private var selectedGroupId: UUID
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

    init(store: CommandStore, item: ClipboardItem) {
        self.store = store
        self.item = item
        // 기본 그룹 선택
        _selectedGroupId = State(initialValue: CommandStore.defaultGroupId)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(L.registerClipboardTitle)
                .font(.headline)

            Text(item.preview)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)

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
                Picker("", selection: $selectedGroupId) {
                    ForEach(store.groups) { group in
                        Label {
                            Text(" \(group.name)")
                        } icon: {
                            colorCircleImage(group.color, size: 8)
                        }.tag(group.id)
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
                .pickerStyle(.menu)
            }

            // 버튼들
            HStack {
                Spacer()
                Button(L.buttonCancel) {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button(L.registerClipboardRegister) {
                    let asLast = selectedPosition == .bottom
                    store.registerClipboardAsCommand(
                        item,
                        asLast: asLast,
                        groupId: selectedGroupId,
                        terminalApp: selectedTerminalApp
                    )
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(width: 280)
    }
}
