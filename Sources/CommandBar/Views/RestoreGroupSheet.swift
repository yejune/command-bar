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

    func colorFor(_ name: String) -> Color {
        switch name {
        case "blue": return .blue
        case "red": return .red
        case "green": return .green
        case "orange": return .orange
        case "purple": return .purple
        case "gray": return .gray
        default: return .gray
        }
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
                        HStack {
                            Circle().fill(colorFor(group.color)).frame(width: 8, height: 8)
                            Text(group.name)
                        }.tag(group.id)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
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
