import SwiftUI

struct GroupEditSheet: View {
    @ObservedObject var store: CommandStore
    @Environment(\.dismiss) private var dismiss

    let existingGroup: Group?

    @State private var name: String = ""
    @State private var color: String = "blue"
    @State private var showDeleteConfirm = false
    @State private var deleteOption: DeleteOption = .merge
    @State private var mergeTargetGroupId: UUID = CommandStore.defaultGroupId

    private let colors = ["blue", "red", "green", "orange", "purple", "gray"]

    enum DeleteOption {
        case merge
        case delete
    }

    init(store: CommandStore, existingGroup: Group? = nil) {
        self.store = store
        self.existingGroup = existingGroup
        if let group = existingGroup {
            _name = State(initialValue: group.name)
            _color = State(initialValue: group.color)
        }
    }

    var isDefaultGroup: Bool {
        existingGroup?.id == CommandStore.defaultGroupId
    }

    var canDelete: Bool {
        existingGroup != nil && !isDefaultGroup && store.groups.count > 1
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(existingGroup == nil ? L.groupAddNew : L.groupEdit)
                .font(.headline)

            VStack(alignment: .leading, spacing: 4) {
                Text(L.groupNamePlaceholder)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("", text: $name)
                    .textFieldStyle(.roundedBorder)
                    .disabled(isDefaultGroup)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(L.groupColor)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack(spacing: 8) {
                    ForEach(colors, id: \.self) { c in
                        Circle()
                            .fill(colorFor(c))
                            .frame(width: 24, height: 24)
                            .overlay(
                                Circle()
                                    .stroke(color == c ? Color.primary : .clear, lineWidth: 2)
                            )
                            .onTapGesture { color = c }
                    }
                }
            }

            HStack {
                if canDelete {
                    Button(L.buttonDelete) {
                        showDeleteConfirm = true
                    }
                    .foregroundStyle(.red)
                }
                Spacer()
                Button(L.buttonCancel) { dismiss() }
                    .buttonStyle(HoverTextButtonStyle())
                Button(L.buttonSave) {
                    if let existing = existingGroup {
                        var updated = existing
                        updated.name = name
                        updated.color = color
                        store.updateGroup(updated)
                    } else {
                        let newGroup = Group(
                            name: name,
                            color: color,
                            order: store.groups.count
                        )
                        store.addGroup(newGroup)
                    }
                    dismiss()
                }
                .buttonStyle(HoverTextButtonStyle())
                .disabled(name.isEmpty)
            }
        }
        .padding()
        .frame(width: 280)
        .sheet(isPresented: $showDeleteConfirm) {
            deleteConfirmationView
        }
    }

    var deleteConfirmationView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(L.groupDeleteTitle)
                .font(.headline)

            VStack(alignment: .leading, spacing: 12) {
                // 옵션 1: 다른 그룹으로 이동
                HStack(spacing: 8) {
                    Button(action: { deleteOption = .merge }) {
                        Image(systemName: deleteOption == .merge ? "circle.fill" : "circle")
                            .foregroundStyle(deleteOption == .merge ? .blue : .secondary)
                    }
                    .buttonStyle(.plain)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(L.groupDeleteMerge)
                            .foregroundStyle(deleteOption == .merge ? .primary : .secondary)
                        if deleteOption == .merge {
                            Picker(L.groupSelectTarget, selection: $mergeTargetGroupId) {
                                ForEach(availableTargetGroups, id: \.id) { group in
                                    Text(group.name).tag(group.id)
                                }
                            }
                            .labelsHidden()
                            .frame(maxWidth: .infinity)
                        }
                    }
                }

                // 옵션 2: 명령어도 함께 삭제
                HStack(spacing: 8) {
                    Button(action: { deleteOption = .delete }) {
                        Image(systemName: deleteOption == .delete ? "circle.fill" : "circle")
                            .foregroundStyle(deleteOption == .delete ? .blue : .secondary)
                    }
                    .buttonStyle(.plain)

                    Text(L.groupDeleteWithCommands)
                        .foregroundStyle(deleteOption == .delete ? .primary : .secondary)
                }
            }

            HStack {
                Spacer()
                Button(L.buttonCancel) {
                    showDeleteConfirm = false
                }
                .buttonStyle(HoverTextButtonStyle())

                Button(L.buttonDelete) {
                    if let group = existingGroup {
                        if deleteOption == .merge {
                            store.deleteGroupAndMerge(group, to: mergeTargetGroupId)
                        } else {
                            store.deleteGroupWithCommands(group)
                        }
                    }
                    showDeleteConfirm = false
                    dismiss()
                }
                .buttonStyle(HoverTextButtonStyle())
                .foregroundStyle(.red)
            }
        }
        .padding()
        .frame(width: 320)
    }

    var availableTargetGroups: [Group] {
        store.groups.filter { $0.id != existingGroup?.id }
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
}
