import SwiftUI
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        for window in NSApp.windows {
            window.standardWindowButton(.miniaturizeButton)?.isHidden = true
            window.standardWindowButton(.zoomButton)?.isHidden = true
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            for window in NSApp.windows {
                window.makeKeyAndOrderFront(self)
            }
        }
        return true
    }
}

enum ExecutionType: String, Codable, CaseIterable {
    case terminal = "터미널"
    case background = "백그라운드"
    case schedule = "일정"
}

enum TerminalApp: String, Codable, CaseIterable {
    case iterm2 = "iTerm2"
    case terminal = "Terminal"
}

enum AlertState: String, Codable {
    case none = ""
    case dayBefore = "D-1"
    case hourBefore = "1시간 전"
    case fiveMinBefore = "5분 전"
    case now = "지금!"
    case passed = "지남"
}

struct Command: Identifiable, Codable {
    var id = UUID()
    var title: String
    var command: String
    var executionType: ExecutionType
    var terminalApp: TerminalApp = .iterm2
    var interval: Int = 0  // 초 단위, 0이면 수동
    var lastOutput: String?
    var isRunning: Bool = false
    // 일정용
    var scheduleDate: Date?
    var repeatInterval: Int = 0  // 초 단위, 0이면 반복 없음
    var alertState: AlertState = .none
    // 알림 시간 설정 (초 단위)
    var alertTimes: [Int] = [0, 300, 3600, 86400]  // 기본: 0, 5분, 1시간, 1일
    var alertedTimes: Set<Int> = []  // 이미 알림 준 시간들
    var acknowledged: Bool = false  // 클릭해서 확인함
    var isInTrash: Bool = false  // 휴지통에 있음
}

class Settings: ObservableObject {
    @Published var alwaysOnTop: Bool {
        didSet {
            UserDefaults.standard.set(alwaysOnTop, forKey: "alwaysOnTop")
            applyAlwaysOnTop()
        }
    }

    init() {
        self.alwaysOnTop = UserDefaults.standard.bool(forKey: "alwaysOnTop")
    }

    func applyAlwaysOnTop() {
        DispatchQueue.main.async {
            for window in NSApp.windows {
                window.level = self.alwaysOnTop ? .floating : .normal
            }
        }
    }
}

class CommandStore: ObservableObject {
    @Published var commands: [Command] = []
    @Published var alertingCommandId: UUID?  // 현재 알림 중인 명령
    private var timers: [UUID: Timer] = [:]
    private var scheduleCheckTimer: Timer?

    private let url = URL(fileURLWithPath: NSHomeDirectory())
        .appendingPathComponent(".command_bar_app")

    init() {
        load()
        startTimers()
        startScheduleChecker()
    }

    func startScheduleChecker() {
        scheduleCheckTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.checkSchedules()
        }
    }

    func checkSchedules() {
        let now = Date()
        for i in commands.indices where commands[i].executionType == .schedule {
            guard let date = commands[i].scheduleDate else { continue }

            let diff = date.timeIntervalSince(now)

            // 휴지통에 있으면 무시
            if commands[i].isInTrash { continue }

            // "지금!" 상태이고 아직 확인 안했으면 5초마다 알림
            if diff <= 0 && !commands[i].acknowledged {
                commands[i].alertState = .now
                // 5초마다 알림 (현재 시간의 초가 5로 나눠떨어지면)
                let seconds = Int(now.timeIntervalSince1970) % 5
                if seconds == 0 {
                    triggerAlert(for: commands[i])
                }
                continue
            }

            // 알림 시간 체크
            for alertTime in commands[i].alertTimes.sorted().reversed() {
                if diff <= Double(alertTime) + 30 && diff > Double(alertTime) - 30 {
                    // 이 알림 시간에 해당하고 아직 알림 안 줬으면
                    let alertKey = alertTime
                    if !commands[i].alertedTimes.contains(alertKey) {
                        commands[i].alertedTimes.insert(alertKey)
                        commands[i].alertState = alertStateFor(seconds: alertTime)
                        triggerAlert(for: commands[i])
                    }
                    break
                }
            }

            // 현재 상태 표시 업데이트
            if diff <= 0 {
                commands[i].alertState = .now
            } else {
                for alertTime in commands[i].alertTimes.sorted() {
                    if diff <= Double(alertTime) {
                        commands[i].alertState = alertStateFor(seconds: alertTime)
                        break
                    }
                }
            }
        }
    }

    func alertStateFor(seconds: Int) -> AlertState {
        switch seconds {
        case 0: return .now
        case 1...300: return .fiveMinBefore
        case 301...3600: return .hourBefore
        case 3601...86400: return .dayBefore
        default: return .none
        }
    }

    func triggerAlert(for cmd: Command) {
        DispatchQueue.main.async {
            // 강조 표시만 (포커스 이동 안 함)
            self.alertingCommandId = cmd.id
            // 3초 후 강조 해제
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                if self.alertingCommandId == cmd.id {
                    self.alertingCommandId = nil
                }
            }
        }
    }

    func startTimers() {
        for cmd in commands where cmd.executionType == .background && cmd.interval > 0 && !cmd.isInTrash {
            startTimer(for: cmd)
        }
    }

    func startTimer(for cmd: Command) {
        stopTimer(for: cmd.id)
        guard cmd.interval > 0 else { return }

        let timer = Timer.scheduledTimer(withTimeInterval: TimeInterval(cmd.interval), repeats: true) { [weak self] _ in
            self?.runInBackground(cmd)
        }
        timers[cmd.id] = timer
        runInBackground(cmd)  // 즉시 한 번 실행
    }

    func stopTimer(for id: UUID) {
        timers[id]?.invalidate()
        timers.removeValue(forKey: id)
    }

    func stopAllTimers() {
        for timer in timers.values {
            timer.invalidate()
        }
        timers.removeAll()
    }

    func load() {
        guard let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([Command].self, from: data) else { return }
        commands = decoded
    }

    func save() {
        guard let data = try? JSONEncoder().encode(commands) else { return }
        try? data.write(to: url)
    }

    func add(_ cmd: Command) {
        commands.append(cmd)
        save()
        if cmd.executionType == .background && cmd.interval > 0 {
            startTimer(for: cmd)
        }
    }

    func moveToTrash(at offsets: IndexSet) {
        for i in offsets {
            stopTimer(for: commands[i].id)
            commands[i].isInTrash = true
        }
        save()
    }

    func moveToTrash(_ cmd: Command) {
        if let i = commands.firstIndex(where: { $0.id == cmd.id }) {
            stopTimer(for: cmd.id)
            commands[i].isInTrash = true
            save()
        }
    }

    func restoreFromTrash(_ cmd: Command) {
        if let i = commands.firstIndex(where: { $0.id == cmd.id }) {
            commands[i].isInTrash = false
            save()
            if commands[i].executionType == .background && commands[i].interval > 0 {
                startTimer(for: commands[i])
            }
        }
    }

    func deletePermanently(_ cmd: Command) {
        stopTimer(for: cmd.id)
        commands.removeAll { $0.id == cmd.id }
        save()
    }

    func emptyTrash() {
        commands.removeAll { $0.isInTrash }
        save()
    }

    var trashItems: [Command] {
        commands.filter { $0.isInTrash }
    }

    var activeItems: [Command] {
        commands.filter { !$0.isInTrash }
    }

    func move(from source: IndexSet, to destination: Int) {
        commands.move(fromOffsets: source, toOffset: destination)
        save()
    }

    func update(_ cmd: Command) {
        if let i = commands.firstIndex(where: { $0.id == cmd.id }) {
            stopTimer(for: cmd.id)
            commands[i] = cmd
            commands[i].alertedTimes = []  // 알림 상태 초기화
            commands[i].alertState = .none
            commands[i].acknowledged = false
            save()
            if cmd.executionType == .background && cmd.interval > 0 {
                startTimer(for: cmd)
            }
        }
    }

    func acknowledge(_ cmd: Command) {
        if let i = commands.firstIndex(where: { $0.id == cmd.id }) {
            commands[i].acknowledged = true
            alertingCommandId = nil
            save()
        }
    }

    func run(_ cmd: Command) {
        switch cmd.executionType {
        case .terminal:
            let app = cmd.terminalApp == .iterm2 ? "iTerm" : "Terminal"
            runInTerminal(cmd, app: app)
        case .background:
            runInBackground(cmd)
        case .schedule:
            break  // 일정은 수동 실행 없음
        }
    }

    private func runInTerminal(_ cmd: Command, app: String) {
        let escaped = cmd.command.replacingOccurrences(of: "\"", with: "\\\"")
        let script: String

        if app == "iTerm" {
            script = """
            tell application "iTerm"
                activate
                if (count of windows) = 0 then
                    create window with default profile
                end if
                tell current session of current window
                    write text "\(escaped)"
                end tell
            end tell
            """
        } else {
            script = """
            tell application "Terminal"
                activate
                do script "\(escaped)"
            end tell
            """
        }

        var error: NSDictionary?
        NSAppleScript(source: script)?.executeAndReturnError(&error)
    }

    private func runInBackground(_ cmd: Command) {
        guard let index = commands.firstIndex(where: { $0.id == cmd.id }) else { return }

        commands[index].isRunning = true
        commands[index].lastOutput = nil

        DispatchQueue.global(qos: .userInitiated).async {
            let process = Process()
            let pipe = Pipe()

            process.executableURL = URL(fileURLWithPath: "/bin/zsh")
            process.arguments = ["-c", cmd.command]
            process.standardOutput = pipe
            process.standardError = pipe

            do {
                try process.run()
                process.waitUntilExit()

                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

                DispatchQueue.main.async {
                    if let i = self.commands.firstIndex(where: { $0.id == cmd.id }) {
                        self.commands[i].lastOutput = output
                        self.commands[i].isRunning = false
                        self.save()
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    if let i = self.commands.firstIndex(where: { $0.id == cmd.id }) {
                        self.commands[i].lastOutput = "Error: \(error.localizedDescription)"
                        self.commands[i].isRunning = false
                    }
                }
            }
        }
    }
}

struct ContentView: View {
    @StateObject private var store = CommandStore()
    @StateObject private var settings = Settings()
    @State private var showAddSheet = false
    @State private var showSettings = false
    @State private var showingTrash = false
    @State private var editingCommand: Command?
    @State private var selectedId: UUID?
    @State private var draggingItem: Command?

    var body: some View {
        VStack(spacing: 0) {

            if showingTrash {
                // 휴지통 보기
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(store.trashItems) { cmd in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(cmd.title)
                                    if cmd.executionType == .schedule {
                                        if let date = cmd.scheduleDate {
                                            Text(date, format: .dateTime.month().day().hour().minute())
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    } else {
                                        Text(cmd.command)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                    }
                                }
                                Spacer()
                                Button("복원") {
                                    store.restoreFromTrash(cmd)
                                }
                                .buttonStyle(.borderless)
                                Button(action: {
                                    store.deletePermanently(cmd)
                                }) {
                                    Image(systemName: "xmark")
                                        .foregroundStyle(.red)
                                }
                                .buttonStyle(.borderless)
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
                .background(Color(nsColor: .textBackgroundColor))
                .overlay {
                    if store.trashItems.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "trash")
                                .font(.title2)
                                .foregroundStyle(.secondary)
                            Text("휴지통이 비어있습니다")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            } else {
                // 일반 리스트
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(store.activeItems) { cmd in
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
                                onDoubleTap: { store.run(cmd) },
                                onEdit: { editingCommand = cmd },
                                onDelete: {
                                    store.moveToTrash(cmd)
                                },
                                onRun: { store.run(cmd) }
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
                .background(Color(nsColor: .textBackgroundColor))
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
                    if store.activeItems.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "terminal")
                                .font(.title2)
                                .foregroundStyle(.secondary)
                            Text("명령이 없습니다")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text("+ 버튼을 눌러 추가하세요")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
            }

            Divider()

            HStack {
                Button(action: { showingTrash = false }) {
                    Image(systemName: "doc.text")
                        .foregroundStyle(showingTrash ? .secondary : .primary)
                }
                .buttonStyle(.borderless)

                Button(action: { showAddSheet = true }) {
                    Image(systemName: "plus")
                        .foregroundStyle(showingTrash ? .secondary : .primary)
                }
                .buttonStyle(.borderless)
                .disabled(showingTrash)

                Spacer()

                Button(action: { showingTrash = true }) {
                    Image(systemName: store.trashItems.isEmpty ? "trash" : "trash.fill")
                        .foregroundStyle(showingTrash ? .primary : .secondary)
                }
                .buttonStyle(.borderless)

                Button(action: { showSettings = true }) {
                    Image(systemName: "gearshape")
                        .foregroundStyle(.primary)
                }
                .buttonStyle(.borderless)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
        .sheet(isPresented: $showAddSheet) {
            AddCommandView(store: store)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(settings: settings)
        }
        .sheet(item: $editingCommand) { cmd in
            EditCommandView(store: store, command: cmd)
        }
        .onAppear {
            settings.applyAlwaysOnTop()
        }
        .onDrop(of: [.text], isTargeted: nil) { _ in
            if draggingItem != nil {
                draggingItem = nil
                store.save()
            }
            return true
        }
    }
}

struct CommandRowView: View {
    let cmd: Command
    let isSelected: Bool
    let isDragging: Bool
    let isAlerting: Bool
    let onTap: () -> Void
    let onDoubleTap: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onRun: () -> Void

    @State private var shakeOffset: CGFloat = 0

    var typeColor: Color {
        switch cmd.executionType {
        case .terminal: return .blue
        case .background: return .orange
        case .schedule: return .purple
        }
    }

    var badgeText: String {
        switch cmd.executionType {
        case .terminal:
            return cmd.terminalApp.rawValue
        case .background:
            return cmd.interval > 0 ? "\(cmd.interval)초" : "수동"
        case .schedule:
            guard let date = cmd.scheduleDate else { return "일정" }
            let diff = date.timeIntervalSinceNow

            // 확인했으면 체크 표시
            if cmd.acknowledged {
                return "✓"
            }

            // 지난 시간 표시
            if diff < 0 {
                let passed = -diff
                if passed < 60 {
                    return "\(Int(passed))초 지남"
                } else if passed < 3600 {
                    return "\(Int(passed / 60))분 지남"
                } else if passed < 86400 {
                    return "\(Int(passed / 3600))시간 지남"
                } else {
                    return "\(Int(passed / 86400))일 지남"
                }
            }
            // 남은 시간 표시
            else if diff < 60 {
                return "\(Int(diff))초 남음"
            } else if diff < 3600 {
                return "\(Int(diff / 60))분 남음"
            } else if diff < 86400 {
                return "\(Int(diff / 3600))시간 남음"
            } else {
                return "\(Int(diff / 86400))일 남음"
            }
        }
    }

    var alertBadgeColor: Color {
        switch cmd.alertState {
        case .now: return .red
        case .fiveMinBefore: return .orange
        case .hourBefore: return .yellow
        case .dayBefore: return .green
        case .passed: return .gray
        case .none: return typeColor
        }
    }

    var badgeColor: Color {
        if cmd.executionType == .schedule {
            if cmd.acknowledged && cmd.alertState == .now {
                return .green  // 체크 표시일 때 초록색
            }
            if cmd.alertState != .none {
                return alertBadgeColor
            }
        }
        return typeColor
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(cmd.title)
                        .fontWeight(isAlerting ? .bold : .regular)
                    ProgressView()
                        .scaleEffect(0.5)
                        .frame(width: 12, height: 12)
                        .opacity(cmd.isRunning ? 1 : 0)
                }
                if cmd.executionType == .schedule {
                    if let date = cmd.scheduleDate {
                        Text(date, format: .dateTime.month().day().hour().minute())
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text(cmd.command)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                if cmd.executionType == .background {
                    Text(cmd.lastOutput ?? " ")
                        .font(.caption2.monospaced())
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            Spacer()
            Text(badgeText)
                .font(.caption2)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(badgeColor.opacity(0.2))
                .foregroundStyle(badgeColor)
                .cornerRadius(4)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isAlerting ? Color.red.opacity(0.3) : (isSelected ? Color.accentColor.opacity(0.2) : Color.clear))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(isAlerting ? Color.red : (isSelected ? Color.accentColor : Color.clear), lineWidth: isAlerting ? 2 : 1)
        )
        .offset(x: shakeOffset)
        .opacity(isDragging ? 0.5 : 1.0)
        .contentShape(Rectangle())
        .gesture(TapGesture(count: 2).onEnded { onDoubleTap() })
        .simultaneousGesture(TapGesture(count: 1).onEnded { onTap() })
        .overlay {
            RightClickMenu(
                onSelect: onTap,
                onRun: onRun,
                onEdit: onEdit,
                onDelete: onDelete
            )
        }
        .onChange(of: isAlerting) { _, newValue in
            if newValue {
                shake()
            }
        }
    }

    func shake() {
        withAnimation(.linear(duration: 0.05).repeatCount(10, autoreverses: true)) {
            shakeOffset = 5
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            shakeOffset = 0
        }
    }
}

struct RightClickMenu: NSViewRepresentable {
    let onSelect: () -> Void
    let onRun: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    func makeNSView(context: Context) -> NSView {
        let view = RightClickMenuView()
        view.onSelect = onSelect
        view.onRun = onRun
        view.onEdit = onEdit
        view.onDelete = onDelete
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        guard let view = nsView as? RightClickMenuView else { return }
        view.onSelect = onSelect
        view.onRun = onRun
        view.onEdit = onEdit
        view.onDelete = onDelete
    }

    class RightClickMenuView: NSView {
        var onSelect: (() -> Void)?
        var onRun: (() -> Void)?
        var onEdit: (() -> Void)?
        var onDelete: (() -> Void)?

        override func rightMouseDown(with event: NSEvent) {
            showMenu(with: event)
        }

        override func mouseDown(with event: NSEvent) {
            if event.modifierFlags.contains(.control) {
                showMenu(with: event)
            }
            // 왼쪽 클릭은 SwiftUI로 전달
        }

        override func hitTest(_ point: NSPoint) -> NSView? {
            // 우클릭만 이 뷰에서 처리
            if NSEvent.pressedMouseButtons & 0x2 != 0 {
                return super.hitTest(point)
            }
            // Control 키가 눌린 상태면 처리
            if NSEvent.modifierFlags.contains(.control) && NSEvent.pressedMouseButtons & 0x1 != 0 {
                return super.hitTest(point)
            }
            return nil
        }

        func showMenu(with event: NSEvent) {
            onSelect?()

            let menu = NSMenu()

            let runItem = NSMenuItem(title: "실행", action: #selector(runAction), keyEquivalent: "")
            runItem.target = self
            menu.addItem(runItem)

            let editItem = NSMenuItem(title: "수정", action: #selector(editAction), keyEquivalent: "")
            editItem.target = self
            menu.addItem(editItem)

            menu.addItem(NSMenuItem.separator())

            let deleteItem = NSMenuItem(title: "삭제", action: #selector(deleteAction), keyEquivalent: "")
            deleteItem.target = self
            menu.addItem(deleteItem)

            NSMenu.popUpContextMenu(menu, with: event, for: self)
        }

        @objc func runAction() { onRun?() }
        @objc func editAction() { onEdit?() }
        @objc func deleteAction() { onDelete?() }
    }
}

struct ReorderDropDelegate: DropDelegate {
    let item: Command
    @Binding var items: [Command]
    @Binding var draggingItem: Command?
    var onSave: () -> Void

    func performDrop(info: DropInfo) -> Bool {
        onSave()
        DispatchQueue.main.async {
            draggingItem = nil
        }
        return true
    }

    func dropEntered(info: DropInfo) {
        guard let dragging = draggingItem,
              dragging.id != item.id,
              let from = items.firstIndex(where: { $0.id == dragging.id }),
              let to = items.firstIndex(where: { $0.id == item.id }),
              from != to else { return }

        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            items.move(fromOffsets: IndexSet(integer: from), toOffset: to > from ? to + 1 : to)
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func dropExited(info: DropInfo) {
        // 드래그 취소 시에도 현재 상태 유지
    }

    func validateDrop(info: DropInfo) -> Bool {
        return draggingItem != nil
    }
}

struct AddCommandView: View {
    @ObservedObject var store: CommandStore
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var command = ""
    @State private var executionType: ExecutionType = .terminal
    @State private var terminalApp: TerminalApp = .iterm2
    @State private var interval: String = "0"
    // 일정용
    @State private var scheduleDate = Date()
    @State private var repeatInterval: String = "0"

    var isValid: Bool {
        if title.isEmpty { return false }
        switch executionType {
        case .terminal, .background:
            return !command.isEmpty
        case .schedule:
            return true
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("새 항목 추가")
                .font(.headline)

            VStack(alignment: .leading, spacing: 4) {
                Text("제목")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("", text: $title)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("실행 방식")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Picker("", selection: $executionType) {
                    ForEach(ExecutionType.allCases, id: \.self) {
                        Text($0.rawValue)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }

            if executionType == .schedule {
                VStack(alignment: .leading, spacing: 4) {
                    Text("날짜/시간")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    DatePicker("", selection: $scheduleDate, displayedComponents: [.date, .hourAndMinute])
                        .labelsHidden()
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("반복 주기 (초, 0이면 반복 안함)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("", text: $repeatInterval)
                        .textFieldStyle(.roundedBorder)
                }
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    Text("명령어")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextEditor(text: $command)
                        .font(.body.monospaced())
                        .frame(height: 80)
                        .padding(4)
                        .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.gray.opacity(0.3)))
                }

                if executionType == .terminal {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("터미널 앱")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Picker("", selection: $terminalApp) {
                            ForEach(TerminalApp.allCases, id: \.self) {
                                Text($0.rawValue)
                            }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                    }
                } else {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("주기 (초, 0이면 수동)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("", text: $interval)
                            .textFieldStyle(.roundedBorder)
                    }
                }
            }

            HStack {
                Button("취소") {
                    dismiss()
                }
                Spacer()
                Button("추가") {
                    store.add(Command(
                        title: title,
                        command: command,
                        executionType: executionType,
                        terminalApp: terminalApp,
                        interval: Int(interval) ?? 0,
                        scheduleDate: executionType == .schedule ? scheduleDate : nil,
                        repeatInterval: Int(repeatInterval) ?? 0
                    ))
                    dismiss()
                }
                .disabled(!isValid)
            }
        }
        .padding()
        .frame(width: 350)
    }
}

struct SettingsView: View {
    @ObservedObject var settings: Settings
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("설정")
                .font(.headline)

            Toggle("항상 위에 표시", isOn: $settings.alwaysOnTop)

            HStack {
                Spacer()
                Button("닫기") {
                    dismiss()
                }
            }
        }
        .padding()
        .frame(width: 350)
    }
}

struct TrashView: View {
    @ObservedObject var store: CommandStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("휴지통")
                    .font(.headline)
                Spacer()
                if !store.trashItems.isEmpty {
                    Button("비우기") {
                        store.emptyTrash()
                    }
                    .foregroundStyle(.red)
                }
            }

            if store.trashItems.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "trash")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    Text("휴지통이 비어있습니다")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(store.trashItems) { cmd in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(cmd.title)
                                    if cmd.executionType == .schedule {
                                        if let date = cmd.scheduleDate {
                                            Text(date, format: .dateTime.month().day().hour().minute())
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    } else {
                                        Text(cmd.command)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                    }
                                }
                                Spacer()
                                Button("복원") {
                                    store.restoreFromTrash(cmd)
                                }
                                .buttonStyle(.borderless)
                                Button(action: {
                                    store.deletePermanently(cmd)
                                }) {
                                    Image(systemName: "xmark")
                                        .foregroundStyle(.red)
                                }
                                .buttonStyle(.borderless)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.gray.opacity(0.1))
                            )
                        }
                    }
                }
                .frame(height: 200)
            }

            HStack {
                Spacer()
                Button("닫기") {
                    dismiss()
                }
            }
        }
        .padding()
        .frame(width: 350)
    }
}

struct EditCommandView: View {
    @ObservedObject var store: CommandStore
    @Environment(\.dismiss) private var dismiss

    let command: Command
    @State private var title: String
    @State private var commandText: String
    @State private var executionType: ExecutionType
    @State private var terminalApp: TerminalApp
    @State private var interval: String
    // 일정용
    @State private var scheduleDate: Date
    @State private var message: String
    @State private var repeatInterval: String

    init(store: CommandStore, command: Command) {
        self.store = store
        self.command = command
        _title = State(initialValue: command.title)
        _commandText = State(initialValue: command.command)
        _executionType = State(initialValue: command.executionType)
        _terminalApp = State(initialValue: command.terminalApp)
        _interval = State(initialValue: String(command.interval))
        _scheduleDate = State(initialValue: command.scheduleDate ?? Date())
        _message = State(initialValue: command.message ?? "")
        _repeatInterval = State(initialValue: String(command.repeatInterval))
    }

    var isValid: Bool {
        if title.isEmpty { return false }
        switch executionType {
        case .terminal, .background:
            return !commandText.isEmpty
        case .schedule:
            return !message.isEmpty
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("항목 수정")
                .font(.headline)

            VStack(alignment: .leading, spacing: 4) {
                Text("제목")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("", text: $title)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("실행 방식")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Picker("", selection: $executionType) {
                    ForEach(ExecutionType.allCases, id: \.self) {
                        Text($0.rawValue)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }

            if executionType == .schedule {
                VStack(alignment: .leading, spacing: 4) {
                    Text("날짜/시간")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    DatePicker("", selection: $scheduleDate, displayedComponents: [.date, .hourAndMinute])
                        .labelsHidden()
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("반복 주기 (초, 0이면 반복 안함)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("", text: $repeatInterval)
                        .textFieldStyle(.roundedBorder)
                }
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    Text("명령어")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextEditor(text: $commandText)
                        .font(.body.monospaced())
                        .frame(height: 80)
                        .padding(4)
                        .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.gray.opacity(0.3)))
                }

                if executionType == .terminal {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("터미널 앱")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Picker("", selection: $terminalApp) {
                            ForEach(TerminalApp.allCases, id: \.self) {
                                Text($0.rawValue)
                            }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                    }
                } else {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("주기 (초, 0이면 수동)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("", text: $interval)
                            .textFieldStyle(.roundedBorder)
                    }
                }
            }

            HStack {
                Button("취소") {
                    dismiss()
                }
                Spacer()
                Button("저장") {
                    var updated = command
                    updated.title = title
                    updated.command = commandText
                    updated.executionType = executionType
                    updated.terminalApp = terminalApp
                    updated.interval = Int(interval) ?? 0
                    updated.scheduleDate = executionType == .schedule ? scheduleDate : nil
                    updated.message = executionType == .schedule ? message : nil
                    updated.repeatInterval = Int(repeatInterval) ?? 0
                    store.update(updated)
                    dismiss()
                }
                .disabled(!isValid)
            }
        }
        .padding()
        .frame(width: 350)
    }
}

@main
struct CommandBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 280, minHeight: 300)
        }
        .windowStyle(.titleBar)
        .defaultSize(width: 300, height: 400)
    }
}
