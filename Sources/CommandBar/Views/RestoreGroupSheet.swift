import SwiftUI

struct RestoreGroupSheet: View {
    @ObservedObject var store: CommandStore
    @Environment(\.dismiss) private var dismiss
    let command: Command
    @State private var selectedGroupId: UUID

    init(store: CommandStore, command: Command) {
        self.store = store
        self.command = command
        // 기존 그룹이 유효하면 선택, 아니면 기본 그룹
        let validGroupId = store.groups.contains(where: { $0.id == command.groupId })
            ? command.groupId
            : CommandStore.defaultGroupId
        _selectedGroupId = State(initialValue: validGroupId)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(L.trashRestore)
                .font(.headline)

            Text(command.title)
                .font(.subheadline)
                .foregroundStyle(.secondary)

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

            HStack {
                Spacer()
                Button(L.buttonCancel) {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button(L.trashRestore) {
                    store.restoreFromTrash(command, toGroupId: selectedGroupId)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(width: 280)
    }
}
