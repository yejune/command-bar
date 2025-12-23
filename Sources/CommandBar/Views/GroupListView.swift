import SwiftUI

struct GroupListView: View {
    @ObservedObject var store: CommandStore
    @State private var draggingItem: Group?
    @State private var showAddGroupSheet = false
    @State private var editingGroup: Group?

    func commandCount(for group: Group) -> Int {
        store.commands.filter { $0.groupId == group.id }.count
    }

    func isDefaultGroup(_ group: Group) -> Bool {
        group.id == CommandStore.defaultGroupId
    }

    var body: some View {
        VStack(spacing: 0) {
            headerView
            Divider()
            groupListView
        }
        .sheet(isPresented: $showAddGroupSheet) {
            GroupEditSheet(store: store)
        }
        .sheet(item: $editingGroup) { group in
            GroupEditSheet(store: store, existingGroup: group)
        }
    }

    var headerView: some View {
        HStack {
            Text(L.groupTitle)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Button(action: { showAddGroupSheet = true }) {
                Image(systemName: "plus")
            }
            .buttonStyle(SmallHoverButtonStyle())

            Text("\(store.groups.count)")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(height: 22)
        .padding(.horizontal, 12)
    }

    var groupListView: some View {
        ScrollView {
            LazyVStack(spacing: 4) {
                ForEach(store.groups) { group in
                    groupRow(for: group)
                }
            }
            .padding(8)
        }
        .background(Color.clear)
        .onDrop(of: [.text], isTargeted: nil) { _ in
            draggingItem = nil
            store.save()
            return true
        }
        .overlay {
            if store.groups.isEmpty {
                emptyView
            }
        }
    }

    func groupRow(for group: Group) -> some View {
        GroupRowView(
            group: group,
            commandCount: commandCount(for: group),
            isDefault: isDefaultGroup(group),
            isLastGroup: store.groups.count == 1,
            isDragging: draggingItem?.id == group.id,
            onEdit: { editingGroup = group },
            onDelete: {
                if !isDefaultGroup(group) && store.groups.count > 1 {
                    store.deleteGroupAndMerge(group, to: CommandStore.defaultGroupId)
                }
            }
        )
        .onDrag {
            draggingItem = group
            return NSItemProvider(object: group.id.uuidString as NSString)
        } preview: {
            Color.clear.frame(width: 1, height: 1)
        }
        .onDrop(of: [.text], delegate: GroupReorderDropDelegate(
            item: group,
            items: $store.groups,
            draggingItem: $draggingItem,
            onSave: { store.save() }
        ))
    }

    var emptyView: some View {
        VStack(spacing: 8) {
            Image(systemName: "folder")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text(L.groupNoGroups)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}
