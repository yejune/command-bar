import SwiftUI

struct RestoreGroupSheet: View {
    @ObservedObject var store: CommandStore
    @Environment(\.dismiss) private var dismiss
    let command: Command
    @State private var selectedGroupSeq: Int?

    init(store: CommandStore, command: Command) {
        self.store = store
        self.command = command
        // 기존 그룹이 유효하면 선택, 아니면 기본 그룹
        let defaultSeq = CommandStore.defaultGroupSeq
        let validGroupSeq = store.groups.contains(where: { $0.seq == command.groupSeq })
            ? command.groupSeq
            : defaultSeq
        _selectedGroupSeq = State(initialValue: validGroupSeq)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(L.trashRestore)
                .font(.headline)

            Text(command.label)
                .font(.subheadline)
                .foregroundStyle(.secondary)

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

            HStack {
                Spacer()
                Button(L.buttonCancel) {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button(L.trashRestore) {
                    store.restoreFromTrash(command, toGroupSeq: selectedGroupSeq)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(width: 280)
    }
}
