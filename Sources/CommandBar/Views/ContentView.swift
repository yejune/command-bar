import SwiftUI

struct ContentView: View {
    @StateObject private var store = CommandStore()
    @ObservedObject private var settings = Settings.shared
    @State private var showAddSheet = false
    @State private var showSettings = false
    @State private var showingTrash = false
    @State private var showingHistory = false
    @State private var showingClipboard = false
    @State private var showingGroups = false
    @State private var showingSecure = false
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

    // 휴지통 서브탭 (0: 목록, 1: 히스토리, 2: 클립보드)
    @State private var trashSubTab: Int = 0

    // 검색 상태
    @State private var historySearchText = ""
    @State private var historySearchDate: Date? = nil
    @State private var historyDateCounts: [String: Int] = [:]
    @State private var clipboardSearchText = ""
    @State private var clipboardSearchDate: Date? = nil
    @State private var clipboardDateCounts: [String: Int] = [:]
    @State private var showClipboardFavoritesOnly = false

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

    var filteredClipboard: [ClipboardItem] {
        if showClipboardFavoritesOnly {
            return store.clipboardItems.filter { $0.isFavorite }
        }
        return store.clipboardItems
    }

    var body: some View {
        VStack(spacing: 0) {

            if showingHistory {
                // 히스토리 보기
                SubtitleBar(title: L.tabHistory) { }
                Divider()
                SearchBarView(
                    searchText: $historySearchText,
                    searchDate: $historySearchDate,
                    dateCounts: historyDateCounts,
                    onSearch: { performHistorySearch() },
                    onClear: {
                        historySearchText = ""
                        historySearchDate = nil
                        store.loadHistory()
                    },
                    showFavoritesOnly: .constant(false),
                    hasFavorites: false
                )
                .onAppear { historyDateCounts = Database.shared.getHistoryDateCounts() }
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
                                HStack(spacing: 2) {
                                    if item.output != nil {
                                        Button(action: {
                                            HistoryDetailWindowController.show(item: item)
                                        }) {
                                            Image(systemName: "doc.text.magnifyingglass")
                                        }
                                        .buttonStyle(SmallHoverButtonStyle())
                                    }
                                    Button(action: {
                                        store.deleteHistory(item)
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
                            .onAppear {
                                // 무한 스크롤: 마지막 항목이 나타나면 더 로드
                                if settings.useInfiniteScroll,
                                   item.id == store.history.last?.id,
                                   store.hasMoreHistory {
                                    store.loadMoreHistory()
                                }
                            }
                        }
                    }
                    .padding(8)

                    // 페이징 모드: 페이지 네비게이션
                    if !settings.useInfiniteScroll && store.historyTotalPages > 1 {
                        PaginationView(
                            currentPage: store.historyPage,
                            totalPages: store.historyTotalPages,
                            onPageChange: { store.goToHistoryPage($0) }
                        )
                    }
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
                SubtitleBar(title: "\(L.tabClipboard)(\(store.clipboardTotalCount))") {
                    Button(action: { showClipboardFavoritesOnly.toggle() }) {
                        Image(systemName: showClipboardFavoritesOnly ? "star.fill" : "star")
                            .foregroundStyle(showClipboardFavoritesOnly ? .yellow : .secondary)
                    }
                    .buttonStyle(SmallHoverButtonStyle())
                }
                Divider()
                SearchBarView(
                    searchText: $clipboardSearchText,
                    searchDate: $clipboardSearchDate,
                    dateCounts: clipboardDateCounts,
                    onSearch: { performClipboardSearch() },
                    onClear: {
                        clipboardSearchText = ""
                        clipboardSearchDate = nil
                        store.loadClipboard()
                    },
                    showFavoritesOnly: .constant(false),
                    hasFavorites: false
                )
                .onAppear { clipboardDateCounts = Database.shared.getClipboardDateCounts() }
                Divider()
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(filteredClipboard) { item in
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 4) {
                                        Button(action: {
                                            store.toggleClipboardFavorite(item)
                                        }) {
                                            Image(systemName: item.isFavorite ? "star.fill" : "star")
                                                .foregroundStyle(item.isFavorite ? .yellow : .gray.opacity(0.4))
                                        }
                                        .buttonStyle(SmallHoverButtonStyle())
                                        Text(item.preview)
                                            .lineLimit(1)
                                        if item.copyCount > 1 {
                                            Text("(\(item.copyCount)회)")
                                                .font(.caption)
                                                .foregroundStyle(.orange)
                                        }
                                    }
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
                            .onAppear {
                                // 무한 스크롤: 마지막 항목이 나타나면 더 로드
                                if settings.useInfiniteScroll,
                                   !showClipboardFavoritesOnly,
                                   item.id == store.clipboardItems.last?.id,
                                   store.hasMoreClipboard {
                                    store.loadMoreClipboard()
                                }
                            }
                        }
                    }
                    .padding(8)

                    // 페이징 모드: 페이지 네비게이션
                    if !settings.useInfiniteScroll && !showClipboardFavoritesOnly && store.clipboardTotalPages > 1 {
                        PaginationView(
                            currentPage: store.clipboardPage,
                            totalPages: store.clipboardTotalPages,
                            onPageChange: { store.goToClipboardPage($0) }
                        )
                    }
                }
                .background(Color.clear)
                .overlay {
                    if filteredClipboard.isEmpty {
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
            } else if showingSecure {
                // 암호화 값 관리
                SecureListView()
            } else if showingTrash {
                // 휴지통 보기
                SubtitleBar(title: L.tabTrash) {
                    Button(L.trashEmpty) {
                        if trashSubTab == 0 {
                            store.emptyTrash()
                        } else if trashSubTab == 1 {
                            store.emptyTrashHistory()
                        } else {
                            store.emptyTrashClipboard()
                        }
                    }
                    .font(.caption)
                    .buttonStyle(HoverButtonStyle())
                    .disabled(trashSubTab == 0 ? store.trashItems.isEmpty :
                              trashSubTab == 1 ? store.trashHistory.isEmpty :
                              store.trashClipboard.isEmpty)
                }
                Divider()
                // 서브탭 선택
                HStack(spacing: 8) {
                    Button(action: { trashSubTab = 0 }) {
                        Text("목록(\(store.trashItems.count))")
                            .font(.caption)
                            .foregroundStyle(trashSubTab == 0 ? .primary : .secondary)
                    }
                    .buttonStyle(SmallHoverButtonStyle())
                    Button(action: { trashSubTab = 1 }) {
                        Text("히스토리(\(store.trashHistoryCount))")
                            .font(.caption)
                            .foregroundStyle(trashSubTab == 1 ? .primary : .secondary)
                    }
                    .buttonStyle(SmallHoverButtonStyle())
                    Button(action: { trashSubTab = 2 }) {
                        Text("클립보드(\(store.trashClipboardCount))")
                            .font(.caption)
                            .foregroundStyle(trashSubTab == 2 ? .primary : .secondary)
                    }
                    .buttonStyle(SmallHoverButtonStyle())
                    Spacer()
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                Divider()

                if trashSubTab == 0 {
                    // 목록 (명령어) 휴지통
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
                                                Text(formatScheduleDate(date, repeatType: cmd.repeatType))
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
                } else if trashSubTab == 1 {
                    // 히스토리 휴지통
                    ScrollView {
                        LazyVStack(spacing: 4) {
                            ForEach(store.trashHistory) { item in
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(item.title)
                                            .lineLimit(1)
                                        Text(item.timestamp, format: .dateTime.month().day().hour().minute())
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    HStack(spacing: 2) {
                                        Button(action: {
                                            store.restoreHistoryItem(item)
                                        }) {
                                            Image(systemName: "arrow.uturn.backward")
                                                .foregroundStyle(.blue)
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
                        if store.trashHistory.isEmpty {
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
                    // 클립보드 휴지통
                    ScrollView {
                        LazyVStack(spacing: 4) {
                            ForEach(store.trashClipboard) { item in
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(item.preview)
                                            .lineLimit(1)
                                        Text(item.timestamp, format: .dateTime.month().day().hour().minute())
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    HStack(spacing: 2) {
                                        Button(action: {
                                            store.restoreClipboardItem(item)
                                        }) {
                                            Image(systemName: "arrow.uturn.backward")
                                                .foregroundStyle(.blue)
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
                        if store.trashClipboard.isEmpty {
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
                }
            } else {
                // 일반 리스트
                SubtitleBar(title: "\(L.tabCommands)(\(filteredItems.count))") {
                    Button(action: { showFavoritesOnly.toggle() }) {
                        Image(systemName: showFavoritesOnly ? "star.fill" : "star")
                            .foregroundStyle(showFavoritesOnly ? .yellow : .secondary)
                    }
                    .buttonStyle(SmallHoverButtonStyle())
                }
                Divider()
                // 그룹 선택 바
                HStack(spacing: 6) {
                    Text(L.groupTitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 30, alignment: .leading)

                    Picker("", selection: $selectedGroupId) {
                        Label {
                            let totalCount = store.commands.filter { !$0.isInTrash }.count
                            Text("  \(L.groupAll)(\(totalCount))")
                        } icon: {
                            colorCircleImage("gray", size: 8, leftShift: 2)
                        }.tag(nil as UUID?)

                        Divider()

                        ForEach(store.groups) { group in
                            Label {
                                let count = store.commands.filter { $0.groupId == group.id && !$0.isInTrash }.count
                                Text("  \(group.name)(\(count))")
                            } icon: {
                                colorCircleImage(group.color, size: 8, leftShift: 2)
                            }.tag(group.id as UUID?)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .frame(maxWidth: .infinity, alignment: .leading)

                    if let groupId = selectedGroupId,
                       let group = store.groups.first(where: { $0.id == groupId }) {
                        Button(action: { editingGroup = group }) {
                            Image(systemName: "pencil.circle")
                        }
                        .buttonStyle(SmallHoverButtonStyle())
                    } else {
                        Button(action: { showAddGroupSheet = true }) {
                            Image(systemName: "folder.badge.plus")
                        }
                        .buttonStyle(SmallHoverButtonStyle())
                    }
                }
                .frame(height: 24)
                .padding(.horizontal, 12)

                // 환경 선택 바 (API 명령이 있을 때만 표시)
                if store.commands.contains(where: { $0.executionType == .api && !$0.isInTrash }) {
                    Divider()
                    HStack(spacing: 6) {
                        Text(L.envTitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(width: 30, alignment: .leading)

                        Picker("", selection: Binding(
                            get: { store.activeEnvironmentId },
                            set: { newValue in
                                if let id = newValue {
                                    store.setActiveEnvironment(store.environments.first { $0.id == id })
                                } else {
                                    store.setActiveEnvironment(nil)
                                }
                            }
                        )) {
                            Label {
                                Text("  -")
                            } icon: {
                                colorCircleImage("gray", size: 8, leftShift: 2)
                            }.tag(nil as UUID?)

                            Divider()

                            ForEach(store.environments) { env in
                                Label {
                                    Text("  \(env.name)")
                                } icon: {
                                    colorCircleImage(env.color, size: 8, leftShift: 2)
                                }.tag(env.id as UUID?)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .frame(maxWidth: .infinity, alignment: .leading)

                        Button(action: {
                            EnvironmentManagerWindowController.show(store: store)
                        }) {
                            Image(systemName: "globe")
                        }
                        .buttonStyle(SmallHoverButtonStyle())
                    }
                    .frame(height: 24)
                    .padding(.horizontal, 12)
                }

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
                                onDoubleTap: {
                                    if Settings.shared.doubleClickToRun {
                                        handleRun(cmd)
                                    } else {
                                        editingCommand = cmd
                                    }
                                },
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
                Button(action: { showingTrash = false; showingHistory = false; showingClipboard = false; showingGroups = false; showingSecure = false }) {
                    ZStack {
                        Image(systemName: "doc.text")
                            .foregroundStyle(!showingTrash && !showingHistory && !showingClipboard && !showingGroups && !showingSecure ? .primary : .secondary)
                        if (showingTrash || showingHistory || showingClipboard || showingGroups || showingSecure) && hasActiveIndicator {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 6, height: 6)
                                .offset(x: 6, y: -6)
                        }
                    }
                }
                .buttonStyle(HoverButtonStyle())

                if !showingTrash && !showingHistory && !showingClipboard && !showingGroups && !showingSecure {
                    Button(action: { showAddSheet = true }) {
                        Image(systemName: "plus")
                    }
                    .buttonStyle(HoverButtonStyle())
                }

                Spacer()

                Button(action: { showingGroups = true; showingClipboard = false; showingHistory = false; showingTrash = false; showingSecure = false }) {
                    Image(systemName: store.groups.isEmpty ? "folder" : "folder.fill")
                        .foregroundStyle(showingGroups ? .primary : .secondary)
                }
                .buttonStyle(HoverButtonStyle())

                Button(action: { showingClipboard = true; showingHistory = false; showingTrash = false; showingGroups = false; showingSecure = false }) {
                    Image(systemName: store.clipboardItems.isEmpty ? "doc.on.clipboard" : "doc.on.clipboard.fill")
                        .foregroundStyle(showingClipboard ? .primary : .secondary)
                }
                .buttonStyle(HoverButtonStyle())

                Button(action: { showingHistory = true; showingTrash = false; showingClipboard = false; showingGroups = false; showingSecure = false }) {
                    Image(systemName: store.history.isEmpty ? "clock" : "clock.fill")
                        .foregroundStyle(showingHistory ? .primary : .secondary)
                }
                .buttonStyle(HoverButtonStyle())

                Button(action: { showingSecure = true; showingHistory = false; showingTrash = false; showingClipboard = false; showingGroups = false }) {
                    Image(systemName: "lock.fill")
                        .foregroundStyle(showingSecure ? .primary : .secondary)
                }
                .buttonStyle(HoverButtonStyle())

                Button(action: { showingTrash = true; showingHistory = false; showingClipboard = false; showingGroups = false; showingSecure = false; store.loadTrash() }) {
                    Image(systemName: store.trashItems.isEmpty && store.trashHistoryCount == 0 && store.trashClipboardCount == 0 ? "trash" : "trash.fill")
                        .foregroundStyle(showingTrash ? .primary : .secondary)
                }
                .buttonStyle(HoverButtonStyle())

                Button(action: { showSettings = true }) {
                    Image(systemName: "gearshape")
                        .foregroundStyle(.primary)
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
            editSheet(for: cmd)
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

    func snapToLeft() {
        guard let window = NSApp.keyWindow ?? NSApp.mainWindow, let screen = window.screen else { return }
        let visibleFrame = screen.visibleFrame
        let minWidth: CGFloat = 280
        let newFrame = NSRect(
            x: visibleFrame.minX,
            y: visibleFrame.minY,
            width: minWidth,
            height: visibleFrame.height
        )
        window.setFrame(newFrame, display: true, animate: false)
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

    func formatScheduleDate(_ date: Date, repeatType: RepeatType) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        switch repeatType {
        case .none:
            formatter.dateFormat = "M월 d일 E HH:mm"
            return formatter.string(from: date)
        case .daily:
            formatter.dateFormat = "HH:mm"
            return L.repeatDaily + ": " + formatter.string(from: date)
        case .weekly:
            formatter.dateFormat = "E HH:mm"
            return L.repeatWeekly + ": " + formatter.string(from: date)
        case .monthly:
            formatter.dateFormat = "d일 HH:mm"
            return L.repeatMonthly + ": " + formatter.string(from: date)
        }
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

    @ViewBuilder
    func editSheet(for cmd: Command) -> some View {
        EditCommandView(store: store, command: cmd, onRun: { command in
            self.handleRun(command)
        })
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

    func performHistorySearch() {
        if historySearchText.isEmpty && historySearchDate == nil {
            store.loadHistory()
        } else {
            let startDate = historySearchDate.map { Calendar.current.startOfDay(for: $0) }
            let endDate = historySearchDate.map { Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: $0))! }
            store.searchHistory(query: historySearchText, startDate: startDate, endDate: endDate)
        }
    }

    func performClipboardSearch() {
        if clipboardSearchText.isEmpty && clipboardSearchDate == nil {
            store.loadClipboard()
        } else {
            let startDate = clipboardSearchDate.map { Calendar.current.startOfDay(for: $0) }
            let endDate = clipboardSearchDate.map { Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: $0))! }
            store.searchClipboard(query: clipboardSearchText, startDate: startDate, endDate: endDate)
        }
    }
}

// MARK: - Search Bar

struct SearchBarView: View {
    @Binding var searchText: String
    @Binding var searchDate: Date?
    var dateCounts: [String: Int]
    var onSearch: () -> Void
    var onClear: () -> Void
    @Binding var showFavoritesOnly: Bool
    var hasFavorites: Bool = false

    @State private var showDatePicker = false

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .font(.caption)

            TextField(L.searchPlaceholder, text: $searchText)
                .textFieldStyle(.plain)
                .font(.caption)
                .onChange(of: searchText) { _, _ in
                    onSearch()
                }

            if let date = searchDate {
                Text(date, format: .dateTime.month().day())
                    .font(.caption)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(Color.accentColor.opacity(0.2))
                    .cornerRadius(4)
            }

            Button(action: {
                showDatePicker.toggle()
            }) {
                Image(systemName: "calendar")
                    .font(.caption)
                    .foregroundStyle(searchDate != nil ? .primary : .secondary)
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showDatePicker, arrowEdge: .bottom) {
                CalendarPickerView(
                    selectedDate: $searchDate,
                    dateCounts: dateCounts,
                    onSelect: { date in
                        searchDate = date
                        showDatePicker = false
                        onSearch()
                    }
                )
            }

            if hasFavorites {
                Button(action: { showFavoritesOnly.toggle() }) {
                    Image(systemName: showFavoritesOnly ? "star.fill" : "star")
                        .font(.caption)
                        .foregroundStyle(showFavoritesOnly ? .yellow : .secondary)
                }
                .buttonStyle(.plain)
            }

            if !searchText.isEmpty || searchDate != nil || showFavoritesOnly {
                Button(action: {
                    showFavoritesOnly = false
                    onClear()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(height: 24)
        .padding(.horizontal, 12)
    }
}

// MARK: - Subtitle Bar

struct SubtitleBar<Content: View>: View {
    let title: String
    @ViewBuilder let trailing: Content

    var body: some View {
        HStack {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            trailing
        }
        .frame(height: 22)
        .padding(.horizontal, 12)
    }
}
