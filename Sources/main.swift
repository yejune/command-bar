import SwiftUI
import WebKit
import AppKit

// MARK: - App Entry Point
@main
struct XTerminalApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appState = AppState.shared

    var body: some Scene {
        WindowGroup("XTerminal") {
            MainView()
                .environmentObject(appState)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1000, height: 600)

        Settings {
            SettingsView()
        }
    }
}

// MARK: - App Delegate
class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenuBar()
        NSApp.setActivationPolicy(.regular)
    }

    func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "terminal.fill", accessibilityDescription: "XTerminal")
        }

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "창 표시", action: #selector(showWindow), keyEquivalent: "1"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "종료", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem?.menu = menu
    }

    @objc func showWindow() {
        NSApp.activate(ignoringOtherApps: true)
    }
}

// MARK: - App State
class AppState: ObservableObject {
    static let shared = AppState()

    @Published var terminals: [TerminalSession] = []
    @Published var activeTerminalId: UUID?
    @Published var showLeftSidebar = true
    @Published var showRightSidebar = true

    @AppStorage("shortcutsFolder") var shortcutsFolderPath: String = ""

    var shortcutsFolder: URL {
        if shortcutsFolderPath.isEmpty {
            return FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent(".terminal-shortcuts")
        }
        return URL(fileURLWithPath: shortcutsFolderPath)
    }

    init() {
        addTerminal()
    }

    func addTerminal(name: String? = nil, directory: URL? = nil) {
        let session = TerminalSession(
            name: name ?? "Terminal \(terminals.count + 1)",
            directory: directory
        )
        terminals.append(session)
        activeTerminalId = session.id
    }

    func closeTerminal(_ id: UUID) {
        if let session = terminals.first(where: { $0.id == id }) {
            session.stop()
        }
        terminals.removeAll { $0.id == id }
        if activeTerminalId == id {
            activeTerminalId = terminals.last?.id
        }
        if terminals.isEmpty {
            addTerminal()
        }
    }

    var activeTerminal: TerminalSession? {
        terminals.first { $0.id == activeTerminalId }
    }
}

// MARK: - Terminal Session (PTY)
class TerminalSession: Identifiable, ObservableObject {
    let id = UUID()
    @Published var name: String
    var directory: URL?

    private var masterFd: Int32 = -1
    private var slaveFd: Int32 = -1
    private var pid: pid_t = 0
    private var readSource: DispatchSourceRead?

    var onOutput: ((String) -> Void)?

    init(name: String, directory: URL? = nil) {
        self.name = name
        self.directory = directory
    }

    func start() {
        var masterFd: Int32 = 0
        var slaveFd: Int32 = 0

        // PTY 생성
        if openpty(&masterFd, &slaveFd, nil, nil, nil) == -1 {
            print("openpty failed")
            return
        }

        self.masterFd = masterFd
        self.slaveFd = slaveFd

        // Fork
        pid = fork()

        if pid == 0 {
            // 자식 프로세스
            close(masterFd)

            // 세션 리더 설정
            setsid()

            // 제어 터미널 설정
            ioctl(slaveFd, TIOCSCTTY, 0)

            // 표준 입출력 연결
            dup2(slaveFd, STDIN_FILENO)
            dup2(slaveFd, STDOUT_FILENO)
            dup2(slaveFd, STDERR_FILENO)

            if slaveFd > STDERR_FILENO {
                close(slaveFd)
            }

            // 환경 변수 설정
            setenv("TERM", "xterm-256color", 1)
            setenv("LANG", "ko_KR.UTF-8", 1)
            setenv("LC_ALL", "ko_KR.UTF-8", 1)

            // 시작 디렉토리 변경
            if let dir = directory {
                chdir(dir.path)
            }

            // 쉘 실행
            let shell = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"
            execl(shell, shell, "-l", nil)
            exit(1)
        } else if pid > 0 {
            // 부모 프로세스
            close(slaveFd)

            // 논블로킹 설정
            let flags = fcntl(masterFd, F_GETFL)
            fcntl(masterFd, F_SETFL, flags | O_NONBLOCK)

            // 읽기 소스 설정
            readSource = DispatchSource.makeReadSource(fileDescriptor: masterFd, queue: .main)
            readSource?.setEventHandler { [weak self] in
                self?.readFromPty()
            }
            readSource?.resume()
        }
    }

    private func readFromPty() {
        var buffer = [UInt8](repeating: 0, count: 4096)
        let bytesRead = read(masterFd, &buffer, buffer.count)

        if bytesRead > 0 {
            if let output = String(bytes: buffer[0..<bytesRead], encoding: .utf8) {
                onOutput?(output)
            }
        }
    }

    func write(_ text: String) {
        guard masterFd != -1, let data = text.data(using: .utf8) else { return }
        data.withUnsafeBytes { ptr in
            _ = Darwin.write(masterFd, ptr.baseAddress, data.count)
        }
    }

    func resize(cols: Int, rows: Int) {
        guard masterFd != -1 else { return }
        var size = winsize()
        size.ws_col = UInt16(cols)
        size.ws_row = UInt16(rows)
        ioctl(masterFd, TIOCSWINSZ, &size)
    }

    func stop() {
        readSource?.cancel()
        readSource = nil

        if masterFd != -1 {
            close(masterFd)
            masterFd = -1
        }

        if pid > 0 {
            kill(pid, SIGTERM)
            pid = 0
        }
    }

    deinit {
        stop()
    }
}

// MARK: - Main View
struct MainView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        HSplitView {
            // 좌측: 터미널 리스트
            if appState.showLeftSidebar {
                TerminalListPanel()
                    .frame(minWidth: 150, idealWidth: 200, maxWidth: 300)
            }

            // 가운데: 터미널
            VStack(spacing: 0) {
                TerminalTabBar()
                Divider()

                if let session = appState.activeTerminal {
                    XTermView(session: session)
                } else {
                    Color.black
                }
            }
            .frame(minWidth: 400)

            // 우측: Shortcuts
            if appState.showRightSidebar {
                ShortcutsPanel()
                    .frame(minWidth: 180, idealWidth: 220, maxWidth: 350)
            }
        }
        .frame(minWidth: 700, minHeight: 400)
        .toolbar {
            ToolbarItemGroup(placement: .navigation) {
                Button(action: { appState.showLeftSidebar.toggle() }) {
                    Image(systemName: "sidebar.left")
                }
            }
            ToolbarItemGroup(placement: .primaryAction) {
                Button(action: { appState.showRightSidebar.toggle() }) {
                    Image(systemName: "sidebar.right")
                }
            }
        }
    }
}

// MARK: - XTerm WebView
struct XTermView: NSViewRepresentable {
    let session: TerminalSession

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.userContentController.add(context.coordinator, name: "input")
        config.userContentController.add(context.coordinator, name: "resize")

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        context.coordinator.webView = webView
        context.coordinator.session = session

        // HTML 로드
        if let htmlURL = Bundle.module.url(forResource: "terminal", withExtension: "html", subdirectory: "Resources") {
            webView.loadFileURL(htmlURL, allowingReadAccessTo: htmlURL.deletingLastPathComponent())
        }

        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        weak var webView: WKWebView?
        var session: TerminalSession?

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            // 터미널 시작
            session?.onOutput = { [weak self] output in
                self?.writeToTerminal(output)
            }
            session?.start()
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            switch message.name {
            case "input":
                if let text = message.body as? String {
                    session?.write(text)
                }
            case "resize":
                if let dict = message.body as? [String: Int],
                   let cols = dict["cols"],
                   let rows = dict["rows"] {
                    session?.resize(cols: cols, rows: rows)
                }
            default:
                break
            }
        }

        func writeToTerminal(_ text: String) {
            let escaped = text
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "'", with: "\\'")
                .replacingOccurrences(of: "\n", with: "\\n")
                .replacingOccurrences(of: "\r", with: "\\r")
            webView?.evaluateJavaScript("writeOutput('\(escaped)')")
        }
    }
}

// MARK: - Terminal List Panel
struct TerminalListPanel: View {
    @EnvironmentObject var appState: AppState
    @State private var showingAddSheet = false
    @State private var editingId: UUID?
    @State private var editingName = ""

    var body: some View {
        VStack(spacing: 0) {
            // 헤더
            HStack {
                Image(systemName: "terminal")
                    .foregroundColor(.green)
                Text("Terminals")
                    .font(.headline)
                Spacer()
                Button(action: { showingAddSheet = true }) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.accentColor)
                }
                .buttonStyle(.plain)
            }
            .padding(12)
            .background(.ultraThinMaterial)

            Divider()

            // 리스트
            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(appState.terminals) { session in
                        TerminalListItem(
                            session: session,
                            isActive: session.id == appState.activeTerminalId,
                            isEditing: editingId == session.id,
                            editingName: $editingName,
                            onSelect: { appState.activeTerminalId = session.id },
                            onStartRename: {
                                editingId = session.id
                                editingName = session.name
                            },
                            onEndRename: {
                                if !editingName.isEmpty {
                                    session.name = editingName
                                }
                                editingId = nil
                            },
                            onDelete: { appState.closeTerminal(session.id) }
                        )
                    }
                }
                .padding(8)
            }
        }
        .background(.ultraThinMaterial)
        .sheet(isPresented: $showingAddSheet) {
            NewTerminalSheet()
        }
    }
}

struct TerminalListItem: View {
    @ObservedObject var session: TerminalSession
    let isActive: Bool
    let isEditing: Bool
    @Binding var editingName: String
    let onSelect: () -> Void
    let onStartRename: () -> Void
    let onEndRename: () -> Void
    let onDelete: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "terminal")
                .foregroundColor(isActive ? .green : .secondary)

            if isEditing {
                TextField("", text: $editingName, onCommit: onEndRename)
                    .textFieldStyle(.plain)
            } else {
                Text(session.name)
                    .lineLimit(1)
            }

            Spacer()

            if isHovered && !isEditing {
                Button(action: onStartRename) {
                    Image(systemName: "pencil")
                        .font(.caption)
                }
                .buttonStyle(.plain)

                Button(action: onDelete) {
                    Image(systemName: "xmark")
                        .font(.caption)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(isActive ? Color.accentColor.opacity(0.2) : (isHovered ? Color.secondary.opacity(0.1) : Color.clear))
        .cornerRadius(6)
        .onHover { isHovered = $0 }
        .onTapGesture { onSelect() }
        .onTapGesture(count: 2) { onStartRename() }
    }
}

// MARK: - New Terminal Sheet
struct NewTerminalSheet: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    @State private var name = ""
    @State private var selectedPath = FileManager.default.homeDirectoryForCurrentUser

    var body: some View {
        VStack(spacing: 16) {
            Text("새 터미널")
                .font(.headline)

            TextField("이름", text: $name)
                .textFieldStyle(.roundedBorder)

            HStack {
                Text("폴더:")
                Text(selectedPath.path)
                    .lineLimit(1)
                    .truncationMode(.head)
                Spacer()
                Button("선택...") { selectFolder() }
            }

            HStack {
                Button("취소") { dismiss() }
                Spacer()
                Button("생성") {
                    appState.addTerminal(
                        name: name.isEmpty ? nil : name,
                        directory: selectedPath
                    )
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 350)
        .onAppear {
            name = "Terminal \(appState.terminals.count + 1)"
        }
    }

    func selectFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        if panel.runModal() == .OK, let url = panel.url {
            selectedPath = url
        }
    }
}

// MARK: - Terminal Tab Bar
struct TerminalTabBar: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        HStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 2) {
                    ForEach(appState.terminals) { session in
                        TabItem(session: session, isActive: session.id == appState.activeTerminalId)
                    }
                }
                .padding(.horizontal, 8)
            }
            Spacer()
            Button(action: { appState.addTerminal() }) {
                Image(systemName: "plus")
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
        }
        .frame(height: 36)
        .background(.ultraThinMaterial)
    }
}

struct TabItem: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var session: TerminalSession
    let isActive: Bool
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "terminal")
                .font(.caption)
            Text(session.name)
                .font(.system(size: 12))
                .lineLimit(1)
            if appState.terminals.count > 1 {
                Button(action: { appState.closeTerminal(session.id) }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 8, weight: .bold))
                }
                .buttonStyle(.plain)
                .opacity(isHovered ? 1 : 0)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(isActive ? Color.accentColor.opacity(0.2) : (isHovered ? Color.secondary.opacity(0.1) : Color.clear))
        .cornerRadius(6)
        .onHover { isHovered = $0 }
        .onTapGesture { appState.activeTerminalId = session.id }
    }
}

// MARK: - Shortcuts Panel
struct ShortcutsPanel: View {
    @EnvironmentObject var appState: AppState
    @State private var shortcuts: [Shortcut] = []
    @State private var showingAddSheet = false
    @State private var hoveredId: UUID?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "bolt.fill")
                    .foregroundColor(.yellow)
                Text("Shortcuts")
                    .font(.headline)
                Spacer()
                Button(action: { showingAddSheet = true }) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.accentColor)
                }
                .buttonStyle(.plain)
            }
            .padding(12)
            .background(.ultraThinMaterial)

            Divider()

            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(shortcuts) { shortcut in
                        ShortcutRow(shortcut: shortcut, isHovered: hoveredId == shortcut.id) {
                            appState.activeTerminal?.write(shortcut.command + "\n")
                        }
                        .onHover { hoveredId = $0 ? shortcut.id : nil }
                    }
                }
                .padding(8)
            }
        }
        .background(.ultraThinMaterial)
        .onAppear { loadShortcuts() }
        .sheet(isPresented: $showingAddSheet) {
            ShortcutEditorSheet(onSave: { name, cmd in
                saveShortcut(name: name, command: cmd)
            })
        }
    }

    func loadShortcuts() {
        let folder = appState.shortcutsFolder
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

        guard let files = try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil) else { return }

        shortcuts = files
            .filter { $0.pathExtension == "sh" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
            .compactMap { file in
                guard let cmd = try? String(contentsOf: file, encoding: .utf8) else { return nil }
                return Shortcut(
                    name: file.deletingPathExtension().lastPathComponent,
                    command: cmd.trimmingCharacters(in: .whitespacesAndNewlines),
                    filePath: file
                )
            }
    }

    func saveShortcut(name: String, command: String) {
        let path = appState.shortcutsFolder.appendingPathComponent("\(name).sh")
        try? command.write(to: path, atomically: true, encoding: .utf8)
        loadShortcuts()
    }
}

struct Shortcut: Identifiable {
    let id = UUID()
    let name: String
    let command: String
    let filePath: URL
}

struct ShortcutRow: View {
    let shortcut: Shortcut
    let isHovered: Bool
    let onRun: () -> Void

    var body: some View {
        Button(action: onRun) {
            HStack {
                Image(systemName: "play.circle.fill")
                    .foregroundColor(isHovered ? .green : .secondary)
                Text(shortcut.name)
                    .lineLimit(1)
                Spacer()
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(isHovered ? Color.accentColor.opacity(0.1) : Color.clear)
        .cornerRadius(6)
    }
}

struct ShortcutEditorSheet: View {
    @Environment(\.dismiss) var dismiss
    @State private var name = ""
    @State private var command = ""
    let onSave: (String, String) -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text("새 단축키")
                .font(.headline)

            TextField("이름", text: $name)
                .textFieldStyle(.roundedBorder)

            TextEditor(text: $command)
                .font(.system(.body, design: .monospaced))
                .frame(height: 80)
                .border(Color.secondary.opacity(0.3))

            HStack {
                Button("취소") { dismiss() }
                Spacer()
                Button("추가") {
                    onSave(name, command)
                    dismiss()
                }
                .disabled(name.isEmpty || command.isEmpty)
            }
        }
        .padding(20)
        .frame(width: 350)
    }
}

// MARK: - Settings View
struct SettingsView: View {
    @AppStorage("shortcutsFolder") var shortcutsFolder = ""

    var body: some View {
        Form {
            Section("Shortcuts 폴더") {
                HStack {
                    TextField("경로", text: $shortcutsFolder)
                    Button("선택...") {
                        let panel = NSOpenPanel()
                        panel.canChooseDirectories = true
                        panel.canChooseFiles = false
                        if panel.runModal() == .OK, let url = panel.url {
                            shortcutsFolder = url.path
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 400, height: 150)
    }
}
