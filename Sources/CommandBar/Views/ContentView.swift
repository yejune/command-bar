import SwiftUI

struct ContentView: View {
    @StateObject private var store = CommandStore()
    @StateObject private var settings = Settings()
    @State private var showAddSheet = false
    @State private var showSettings = false
    @State private var showingTrash = false
    @State private var showingHistory = false
    @State private var showingClipboard = false
    @State private var showingGroups = false
    @State private var editingCommand: Command?
    @State private var selectedId: UUID?
    @State private var draggingItem: Command?
    @State private var selectedHistoryItem: HistoryItem?
    @State private var selectedClipboardItem: ClipboardItem?
    @State private var selectedGroupId: UUID? = nil  // nil = 전체
    @State private var showFavoritesOnly = false
    @State private var showAddGroupSheet = false
    @State private var editingGroup: Group? = nil
    @State private var restoringCommand: Command? = nil
    @State private var registeringClipboardItem: ClipboardItem? = nil
    @State private var apiCommandWithParameters: Command? = nil

    var hasActiveIndicator: Bool {
        store.activeItems.contains { cmd in
            cmd.isRunning || store.alertingCommandId == cmd.id
        }
    }

    var filteredItems: [Command] {
        let items = store.itemsForGroup(selectedGroupId)
        if showFavoritesOnly {
            return items.filter { $0.isFavorite }
        }
        return items
    }

    var body: some View {
        VStack(spacing: 0) {

            if showingHistory {
                // 히스토리 보기
                HStack {
                    Text(L.tabHistory)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    if !store.history.isEmpty {
                        Button(L.buttonClear) {
                            store.clearHistory()
                        }
                        .font(.caption)
                        .buttonStyle(HoverButtonStyle())
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                Divider()
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(store.history) { item in
                            HStack {
                                Image(systemName: historyTypeIcon(item.type))
                                    .foregroundStyle(historyTypeColor(item.type))
                                    .frame(width: 14)
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 4) {
                                        Text(item.title)
                                            .fontWeight(.medium)
                                        if item.count > 1 {
                                            Text("(\(item.count)회)")
                                                .font(.caption)
                                                .foregroundStyle(.orange)
                                        }
                                    }
                                    if let endTime = item.endTimestamp, item.count > 1 {
                                        Text("\(item.timestamp, format: .dateTime.hour().minute()) ~ \(endTime, format: .dateTime.hour().minute().second())")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    } else {
                                        Text(item.timestamp, format: .dateTime.month().day().hour().minute().second())
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                if item.output != nil {
                                    Button(action: {
                                        HistoryDetailWindowController.show(item: item)
                                    }) {
                                        Image(systemName: "doc.text.magnifyingglass")
                                    }
                                    .buttonStyle(SmallHoverButtonStyle())
                                }
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.gray.opacity(0.1))
                            )
                        }
                    }
                    .padding(8)
                }
                .background(Color.clear)
                .overlay {
                    if store.history.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "clock")
                                .font(.title2)
                                .foregroundStyle(.secondary)
                            Text(L.historyNoHistory)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            } else if showingClipboard {
                // 클립보드 보기
                HStack {
                    Text(L.tabClipboard)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    if !store.clipboardItems.isEmpty {
                        Button(L.buttonClear) {
                            store.clearClipboard()
                        }
                        .font(.caption)
                        .buttonStyle(HoverButtonStyle())
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                Divider()
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(store.clipboardItems) { item in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.preview)
                                        .lineLimit(2)
                                    Text(item.timestamp, format: .dateTime.month().day().hour().minute().second())
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                HStack(spacing: 2) {
                                    Button(action: {
                                        ClipboardDetailWindowController.show(item: item, store: store, notesFolderName: settings.notesFolderName)
                                    }) {
                                        Image(systemName: "doc.text.magnifyingglass")
                                    }
                                    .buttonStyle(SmallHoverButtonStyle())
                                    Button(action: {
                                        registeringClipboardItem = item
                                    }) {
                                        Image(systemName: "arrow.right.doc.on.clipboard")
                                    }
                                    .buttonStyle(SmallHoverButtonStyle())
                                    .help(L.registerClipboardTitle)
                                    Button(action: {
                                        store.sendToNotes(item, folderName: settings.notesFolderName)
                                    }) {
                                        Image(systemName: "note.text")
                                    }
                                    .buttonStyle(SmallHoverButtonStyle())
                                    .help(L.clipboardSendToNotes)
                                    Button(action: {
                                        store.removeClipboardItem(item)
                                    }) {
                                        Image(systemName: "trash")
                                            .foregroundStyle(.red)
                                    }
                                    .buttonStyle(SmallHoverButtonStyle())
                                }
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.gray.opacity(0.1))
                            )
                        }
                    }
                    .padding(8)
                }
                .background(Color.clear)
                .overlay {
                    if store.clipboardItems.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "doc.on.clipboard")
                                .font(.title2)
                                .foregroundStyle(.secondary)
                            Text(L.clipboardNoItems)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            } else if showingGroups {
                // 그룹 관리 페이지
                GroupListView(store: store)
            } else if showingTrash {
                // 휴지통 보기
                HStack {
                    Text(L.tabTrash)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    if !store.trashItems.isEmpty {
                        Button(L.trashEmpty) {
                            store.emptyTrash()
                        }
                        .font(.caption)
                        .buttonStyle(HoverButtonStyle())
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                Divider()
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(store.trashItems) { cmd in
                            HStack {
                                Image(systemName: trashItemIcon(cmd))
                                    .foregroundStyle(trashItemColor(cmd))
                                    .frame(width: 14)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(cmd.title)
                                    if cmd.executionType == .schedule {
                                        if let date = cmd.scheduleDate {
                                            Text(date, format: .dateTime.month().day().hour().minute())
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    } else if cmd.executionType == .api {
                                        Text(cmd.url)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                    } else {
                                        Text(cmd.command)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                    }
                                }
                                Spacer()
                                HStack(spacing: 2) {
                                    Button(action: {
                                        editingCommand = cmd
                                    }) {
                                        Image(systemName: "pencil")
                                    }
                                    .buttonStyle(SmallHoverButtonStyle())
                                    Button(action: {
                                        restoringCommand = cmd
                                    }) {
                                        Image(systemName: "arrow.uturn.backward")
                                            .foregroundStyle(.blue)
                                    }
                                    .buttonStyle(SmallHoverButtonStyle())
                                    Button(action: {
                                        store.deletePermanently(cmd)
                                    }) {
                                        Image(systemName: "xmark")
                                            .foregroundStyle(.red)
                                    }
                                    .buttonStyle(SmallHoverButtonStyle())
                                }
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.gray.opacity(0.1))
                            )
                        }
                    }
                    .padding(8)
                }
                .background(Color.clear)
                .overlay {
                    if store.trashItems.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "trash")
                                .font(.title2)
                                .foregroundStyle(.secondary)
                            Text(L.trashEmptyMessage)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            } else {
                // 일반 리스트
                HStack(spacing: 4) {
                    // 그룹 선택 Picker
                    Picker("", selection: $selectedGroupId) {
                        Label {
                            Text("  \(L.groupAll)")
                        } icon: {
                            colorCircleImage("gray", size: 8, leftShift: 2)
                        }.tag(nil as UUID?)

                        Divider()

                        ForEach(store.groups) { group in
                            Label {
                                Text("  \(group.name)")
                            } icon: {
                                colorCircleImage(group.color, size: 8, leftShift: 2)
                            }.tag(group.id as UUID?)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .padding(.leading, -4)

                    Button(action: { showFavoritesOnly.toggle() }) {
                        Image(systemName: showFavoritesOnly ? "star.fill" : "star")
                            .foregroundStyle(showFavoritesOnly ? .yellow : .secondary)
                    }
                    .buttonStyle(SmallHoverButtonStyle())

                    // 그룹 편집 버튼 (전체 선택이 아닐 때만)
                    if let groupId = selectedGroupId,
                       let group = store.groups.first(where: { $0.id == groupId }) {
                        Button(action: { editingGroup = group }) {
                            Image(systemName: "pencil.circle")
                        }
                        .buttonStyle(SmallHoverButtonStyle())
                    }

                    Spacer()

                    Text("\(filteredItems.count)")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                Divider()
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(filteredItems) { cmd in
                            CommandRowView(
                                cmd: cmd,
                                isSelected: selectedId == cmd.id,
                                isDragging: draggingItem?.id == cmd.id,
                                isAlerting: store.alertingCommandId == cmd.id,
                                onTap: {
                                    selectedId = cmd.id
                                    if cmd.alertState == .now {
                                        store.acknowledge(cmd)
                                    }
                                },
                                onDoubleTap: { handleRun(cmd) },
                                onEdit: { editingCommand = cmd },
                                onCopy: {
                                    store.duplicate(cmd)
                                },
                                onDelete: {
                                    store.moveToTrash(cmd)
                                },
                                onRun: { handleRun(cmd) },
                                onToggleFavorite: {
                                    selectedId = cmd.id
                                    store.toggleFavorite(cmd)
                                },
                                groups: store.groups,
                                onMoveToGroup: { groupId in
                                    store.moveToGroup(cmd, groupId: groupId)
                                }
                            )
                            .onDrag {
                                draggingItem = cmd
                                selectedId = cmd.id
                                return NSItemProvider(object: cmd.id.uuidString as NSString)
                            } preview: {
                                Color.clear.frame(width: 1, height: 1)
                            }
                            .onDrop(of: [.text], delegate: ReorderDropDelegate(
                                item: cmd,
                                items: $store.commands,
                                draggingItem: $draggingItem,
                                onSave: { store.save() }
                            ))
                        }
                    }
                    .padding(8)
                }
                .background(Color.clear)
                .contentShape(Rectangle())
                .onTapGesture {
                    selectedId = nil
                }
                .onDrop(of: [.text], isTargeted: nil) { _ in
                    draggingItem = nil
                    store.save()
                    return true
                }
                .onKeyPress(.return) {
                    if let id = selectedId, let cmd = store.commands.first(where: { $0.id == id }) {
                        store.run(cmd)
                        return .handled
                    }
                    return .ignored
                }
                .overlay {
                    if filteredItems.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "terminal")
                                .font(.title2)
                                .foregroundStyle(.secondary)
                            Text(L.commandNoCommands)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text(L.commandAddFirst)
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
            }

            Divider()

            HStack(spacing: 2) {
                Button(action: { showingTrash = false; showingHistory = false; showingClipboard = false; showingGroups = false }) {
                    ZStack {
                        Image(systemName: "doc.text")
                            .foregroundStyle(!showingTrash && !showingHistory && !showingClipboard && !showingGroups ? .primary : .secondary)
                        if (showingTrash || showingHistory || showingClipboard || showingGroups) && hasActiveIndicator {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 6, height: 6)
                                .offset(x: 6, y: -6)
                        }
                    }
                }
                .buttonStyle(HoverButtonStyle())

                if !showingTrash && !showingHistory && !showingClipboard && !showingGroups {
                    Button(action: { showAddSheet = true }) {
                        Image(systemName: "plus")
                    }
                    .buttonStyle(HoverButtonStyle())
                }

                Spacer()

                Button(action: { showingGroups = true; showingClipboard = false; showingHistory = false; showingTrash = false }) {
                    Image(systemName: store.groups.isEmpty ? "folder" : "folder.fill")
                        .foregroundStyle(showingGroups ? .primary : .secondary)
                }
                .buttonStyle(HoverButtonStyle())

                Button(action: { showingClipboard = true; showingHistory = false; showingTrash = false; showingGroups = false }) {
                    Image(systemName: store.clipboardItems.isEmpty ? "doc.on.clipboard" : "doc.on.clipboard.fill")
                        .foregroundStyle(showingClipboard ? .primary : .secondary)
                }
                .buttonStyle(HoverButtonStyle())

                Button(action: { showingHistory = true; showingTrash = false; showingClipboard = false; showingGroups = false }) {
                    Image(systemName: store.history.isEmpty ? "clock" : "clock.fill")
                        .foregroundStyle(showingHistory ? .primary : .secondary)
                }
                .buttonStyle(HoverButtonStyle())

                Button(action: { showingTrash = true; showingHistory = false; showingClipboard = false; showingGroups = false }) {
                    Image(systemName: store.trashItems.isEmpty ? "trash" : "trash.fill")
                        .foregroundStyle(showingTrash ? .primary : .secondary)
                }
                .buttonStyle(HoverButtonStyle())

                Button(action: { showSettings = true }) {
                    Image(systemName: "gearshape")
                        .foregroundStyle(.primary)
                }
                .buttonStyle(HoverButtonStyle())

                Button(action: {
                    DispatchQueue.main.async { snapToRight() }
                }) {
                    Image(systemName: "sidebar.right")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(HoverButtonStyle())
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
        .sheet(isPresented: $showAddSheet) {
            AddCommandView(store: store)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(settings: settings, store: store)
        }
        .sheet(item: $editingCommand) { cmd in
            EditCommandView(store: store, command: cmd)
        }
        .sheet(isPresented: $showAddGroupSheet) {
            GroupEditSheet(store: store)
        }
        .sheet(item: $editingGroup) { group in
            GroupEditSheet(store: store, existingGroup: group)
        }
        .sheet(item: $restoringCommand) { cmd in
            RestoreGroupSheet(store: store, command: cmd)
        }
        .sheet(item: $registeringClipboardItem) { item in
            RegisterClipboardSheet(store: store, item: item)
        }
        .sheet(item: $apiCommandWithParameters) { cmd in
            APIParameterInputView(command: cmd, store: store) { values in
                executeAPIWithParameters(cmd, values: values)
            }
        }
        .onAppear {
            settings.applyAlwaysOnTop()
            settings.applyBackgroundOpacity()
        }
        .onDrop(of: [.text], isTargeted: nil) { _ in
            if draggingItem != nil {
                draggingItem = nil
                store.save()
            }
            return true
        }
    }

    func snapToRight() {
        guard let window = NSApp.keyWindow ?? NSApp.mainWindow, let screen = window.screen else { return }
        let visibleFrame = screen.visibleFrame
        let minWidth: CGFloat = 280
        let newFrame = NSRect(
            x: visibleFrame.maxX - minWidth,
            y: visibleFrame.minY,
            width: minWidth,
            height: visibleFrame.height
        )
        window.setFrame(newFrame, display: true, animate: false)
    }

    func handleRun(_ cmd: Command) {
        if cmd.executionType == .script {
            ScriptExecutionWindowController.show(command: cmd, store: store)
        } else if cmd.executionType == .api {
            // API 명령어에 파라미터가 있는지 확인
            if cmd.hasAPIParameters {
                apiCommandWithParameters = cmd
            } else {
                executeAPICommand(cmd)
            }
        } else {
            store.run(cmd)
        }
    }

    func executeAPIWithParameters(_ cmd: Command, values: [String: String]) {
        // 파라미터 치환된 명령어로 실행
        let replacedCommand = cmd.apiCommandWith(values: values)
        executeAPICommand(replacedCommand)
    }

    func executeAPICommand(_ cmd: Command) {
        // 먼저 로딩 창 표시
        let state = APIResponseWindowController.showLoading(
            requestId: cmd.id,
            method: cmd.httpMethod.rawValue,
            url: cmd.url,
            title: cmd.title
        )

        Task {
            let startTime = Date()
            let result = await store.executeAPICommand(cmd)
            let executionTime = Date().timeIntervalSince(startTime)

            var statusCode = 0
            var headers: [String: String] = [:]
            var responseBody = ""

            if let httpResponse = result.response as? HTTPURLResponse {
                statusCode = httpResponse.statusCode
                for (key, value) in httpResponse.allHeaderFields {
                    if let keyString = key as? String, let valueString = value as? String {
                        headers[keyString] = valueString
                    }
                }
            }

            if let data = result.data {
                responseBody = String(data: data, encoding: .utf8) ?? "Unable to decode response"
            } else if let error = result.error {
                responseBody = "Error: \(error.localizedDescription)"
            }

            // 응답으로 state 업데이트
            await MainActor.run {
                state.update(
                    statusCode: statusCode,
                    headers: headers,
                    responseBody: responseBody,
                    executionTime: executionTime
                )
            }
        }
    }

    func historyTypeColor(_ type: HistoryType) -> Color {
        switch type {
        case .executed: return .blue
        case .background: return .orange
        case .script: return .green
        case .scheduleAlert: return .purple
        case .reminder: return .pink
        case .added: return .mint
        case .deleted: return .red
        case .restored: return .teal
        case .permanentlyDeleted: return .gray
        }
    }

    func historyTypeIcon(_ type: HistoryType) -> String {
        switch type {
        case .executed: return "terminal"
        case .background: return "arrow.clockwise"
        case .script: return "play.fill"
        case .scheduleAlert: return "calendar"
        case .reminder: return "bell.fill"
        case .added: return "plus.circle"
        case .deleted: return "trash"
        case .restored: return "arrow.uturn.backward"
        case .permanentlyDeleted: return "xmark.circle"
        }
    }

    func trashItemIcon(_ cmd: Command) -> String {
        switch cmd.executionType {
        case .terminal: return "terminal"
        case .background: return "arrow.clockwise"
        case .script: return "play.fill"
        case .schedule: return "calendar"
        case .api: return "network"
        }
    }

    func trashItemColor(_ cmd: Command) -> Color {
        switch cmd.executionType {
        case .terminal: return .blue
        case .background: return .orange
        case .script: return .green
        case .schedule: return .purple
        case .api: return .cyan
        }
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

    func colorEmoji(_ name: String) -> String {
        switch name {
        case "blue": return "🔵"
        case "red": return "🔴"
        case "green": return "🟢"
        case "orange": return "🟠"
        case "purple": return "🟣"
        case "gray": return "⚫"
        default: return "⚫"
        }
    }
}
