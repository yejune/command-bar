import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: Settings
    @ObservedObject var store: CommandStore
    @ObservedObject var languageManager = LanguageManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab = 0
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var showImportChoice = false
    @State private var pendingImportData: Data?

    private var tabTitles: [String] {
        [L.settingsGeneral, L.settingsClipboardTab, L.settingsBackup, L.settingsLanguage]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(L.settingsTitle)
                .font(.headline)
                .padding(.horizontal)
                .padding(.top)
                .padding(.bottom, 12)

            Divider()

            // 탭 UI
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    ForEach(Array(tabTitles.enumerated()), id: \.offset) { index, title in
                        Button(action: { selectedTab = index }) {
                            VStack(spacing: 0) {
                                Text(title)
                                    .foregroundColor(selectedTab == index ? .primary : .secondary)
                                    .padding(.bottom, 6)
                                Rectangle()
                                    .fill(selectedTab == index ? Color.accentColor : Color.clear)
                                    .frame(height: 2)
                            }
                        }
                        .buttonStyle(.plain)
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, 12)
                Divider()
            }
            .padding(.top, 8)

            // 탭 콘텐츠
            VStack(alignment: .leading, spacing: 0) {
                if selectedTab == 0 {
                    // 기본 설정
                    SettingRow(label: L.settingsAlwaysOnTop) {
                        Toggle("", isOn: $settings.alwaysOnTop)
                            .labelsHidden()
                    }
                    SettingDivider()
                    SettingRow(label: L.settingsLaunchAtLogin) {
                        Toggle("", isOn: $settings.launchAtLogin)
                            .labelsHidden()
                    }
                    SettingDivider()
                    SettingRow(label: L.settingsBackgroundOpacity) {
                        HStack(spacing: 8) {
                            Toggle("", isOn: $settings.useBackgroundOpacity)
                                .labelsHidden()
                            if settings.useBackgroundOpacity {
                                Slider(value: $settings.backgroundOpacity, in: 0.3...1.0, step: 0.1)
                                    .frame(width: 100)
                                Text("\(Int(settings.backgroundOpacity * 100))%")
                                    .foregroundStyle(.secondary)
                                    .frame(width: 35)
                            }
                        }
                    }
                    SettingDivider()
                    SettingRow(label: L.settingsAutoHide) {
                        Toggle("", isOn: $settings.autoHide)
                            .labelsHidden()
                    }
                    if settings.autoHide {
                        SettingRow(label: L.settingsHideOpacity) {
                            HStack(spacing: 8) {
                                Toggle("", isOn: $settings.useHideOpacity)
                                    .labelsHidden()
                                if settings.useHideOpacity {
                                    Slider(value: $settings.hideOpacity, in: 0.05...0.5, step: 0.05)
                                        .frame(width: 100)
                                    Text("\(Int(settings.hideOpacity * 100))%")
                                        .foregroundStyle(.secondary)
                                        .frame(width: 35)
                                }
                            }
                        }
                    }
                    SettingDivider()
                    SettingRow(label: L.settingsDoubleClickToRun) {
                        Toggle("", isOn: $settings.doubleClickToRun)
                            .labelsHidden()
                    }
                    SettingDivider()
                    SettingRow(label: L.settingsScrollMode) {
                        Picker("", selection: $settings.useInfiniteScroll) {
                            Text(L.settingsInfiniteScroll).tag(true)
                            Text(L.settingsPaging).tag(false)
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 150)
                    }
                    SettingRow(label: L.settingsPageSize) {
                        Picker("", selection: $settings.pageSize) {
                            Text("30").tag(30)
                            Text("50").tag(50)
                            Text("100").tag(100)
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 120)
                    }
                } else if selectedTab == 1 {
                    // 클립보드 설정
                    SettingRow(label: L.settingsNotesFolderName) {
                        TextField("", text: $settings.notesFolderName)
                            .frame(width: 150)
                            .textFieldStyle(.roundedBorder)
                    }
                } else if selectedTab == 2 {
                    // 백업 (가져오기/내보내기)
                    SettingRow(label: L.settingsBackupNote) {
                        HStack(spacing: 8) {
                            Button(L.settingsExportFile) { exportToFile() }
                            Button(L.settingsImportFile) { loadFromFile() }
                        }
                    }
                } else {
                    // 언어 설정
                    SettingRow(label: L.settingsLanguage) {
                        Picker("", selection: $languageManager.currentLanguage) {
                            ForEach(Language.allCases, id: \.self) { lang in
                                Text(lang.displayName).tag(lang)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 120)
                    }
                    SettingDivider()
                    SettingRow(label: L.settingsLanguagePack) {
                        HStack(spacing: 8) {
                            Button(L.settingsExportLanguagePack) { exportLanguagePack() }
                            Button(L.settingsImportLanguagePack) { importLanguagePack() }
                        }
                    }
                }
                Spacer()
            }
            .padding(12)

            Divider()

            HStack {
                Spacer()
                Button(L.buttonClose) {
                    dismiss()
                }
                .buttonStyle(HoverTextButtonStyle())
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
        }
        .frame(width: 320)
        .alert(L.notification, isPresented: $showAlert) {
            Button(L.buttonConfirm) {}
        } message: {
            Text(alertMessage)
        }
        .confirmationDialog(L.importDialogTitle, isPresented: $showImportChoice, titleVisibility: .visible) {
            Button(L.importMerge) {
                performImport(merge: true)
            }
            Button(L.importOverwrite) {
                performImport(merge: false)
            }
            Button(L.buttonCancel, role: .cancel) {
                pendingImportData = nil
            }
        }
    }

    func exportToFile() {
        guard let data = store.exportData(settings: settings),
              let json = String(data: data, encoding: .utf8) else {
            alertMessage = L.alertExportFailed
            showAlert = true
            return
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyMMdd_HHmmss"
        let filename = "commandbar_\(formatter.string(from: Date())).json"

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = filename

        if panel.runModal() == .OK, let url = panel.url {
            do {
                try json.write(to: url, atomically: true, encoding: .utf8)
                alertMessage = L.alertExportSuccess
                showAlert = true
            } catch {
                alertMessage = L.alertSaveFailed + ": \(error.localizedDescription)"
                showAlert = true
            }
        }
    }

    func exportToClipboard() {
        guard let data = store.exportData(settings: settings),
              let json = String(data: data, encoding: .utf8) else {
            alertMessage = L.alertExportFailed
            showAlert = true
            return
        }

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(json, forType: .string)
        alertMessage = L.alertCopiedToClipboard
        showAlert = true
    }

    func loadFromFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false

        if panel.runModal() == .OK, let url = panel.url {
            do {
                let data = try Data(contentsOf: url)
                // 유효성 검사
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                if (try? decoder.decode(ExportData.self, from: data)) != nil {
                    tryImport(data)
                } else {
                    alertMessage = L.alertInvalidFormat
                    showAlert = true
                }
            } catch {
                alertMessage = L.alertReadFailed
                showAlert = true
            }
        }
    }

    func loadFromClipboard() {
        guard let string = NSPasteboard.general.string(forType: .string),
              let data = string.data(using: .utf8) else {
            alertMessage = L.alertClipboardEmpty
            showAlert = true
            return
        }

        // 유효성 검사
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if (try? decoder.decode(ExportData.self, from: data)) != nil {
            tryImport(data)
        } else {
            alertMessage = L.alertInvalidFormat
            showAlert = true
        }
    }

    func tryImport(_ data: Data) {
        pendingImportData = data
        // 기존 데이터가 없으면 바로 가져오기
        if store.activeItems.isEmpty {
            performImport(merge: false)
        } else {
            showImportChoice = true
        }
    }

    func performImport(merge: Bool) {
        guard let data = pendingImportData else { return }
        if store.importData(data, settings: settings, merge: merge) {
            alertMessage = merge ? L.alertMergeComplete : L.alertOverwriteComplete
        } else {
            alertMessage = L.alertImportFailed
        }
        pendingImportData = nil
        showAlert = true
    }

    func exportLanguagePack() {
        guard let data = languageManager.exportLanguagePackTemplate(),
              let json = String(data: data, encoding: .utf8) else {
            alertMessage = L.alertExportFailed
            showAlert = true
            return
        }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "language_pack_template.json"

        if panel.runModal() == .OK, let url = panel.url {
            do {
                try json.write(to: url, atomically: true, encoding: .utf8)
                alertMessage = L.languagePackExportSuccess
                showAlert = true
            } catch {
                alertMessage = L.alertSaveFailed + ": \(error.localizedDescription)"
                showAlert = true
            }
        }
    }

    func importLanguagePack() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false

        if panel.runModal() == .OK, let url = panel.url {
            do {
                let data = try Data(contentsOf: url)
                if languageManager.importLanguagePack(from: data) {
                    alertMessage = L.languagePackImportSuccess
                } else {
                    alertMessage = L.languagePackInvalidFormat
                }
                showAlert = true
            } catch {
                alertMessage = L.alertReadFailed
                showAlert = true
            }
        }
    }
}

// 단축키 입력 캡처 뷰
struct ShortcutRecorderView: NSViewRepresentable {
    @Binding var shortcut: String

    func makeNSView(context: Context) -> ShortcutRecorderNSView {
        let view = ShortcutRecorderNSView()
        view.shortcut = shortcut
        view.onShortcutChange = { newShortcut in
            shortcut = newShortcut
        }
        return view
    }

    func updateNSView(_ nsView: ShortcutRecorderNSView, context: Context) {
        nsView.shortcut = shortcut
    }
}

class ShortcutRecorderNSView: NSView {
    var shortcut: String = "" {
        didSet {
            textField.stringValue = shortcut
        }
    }
    var onShortcutChange: ((String) -> Void)?
    private var isRecording = false
    private var localMonitor: Any?

    private lazy var textField: ClickableTextField = {
        let tf = ClickableTextField()
        tf.isEditable = false
        tf.isSelectable = false
        tf.isBezeled = true
        tf.bezelStyle = .roundedBezel
        tf.alignment = .center
        tf.font = .systemFont(ofSize: 12)
        tf.onMouseDown = { [weak self] in
            self?.startRecording()
        }
        return tf
    }()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    deinit {
        stopMonitor()
    }

    private func setup() {
        addSubview(textField)
        textField.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            textField.leadingAnchor.constraint(equalTo: leadingAnchor),
            textField.trailingAnchor.constraint(equalTo: trailingAnchor),
            textField.topAnchor.constraint(equalTo: topAnchor),
            textField.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    override var acceptsFirstResponder: Bool { true }

    override func mouseDown(with event: NSEvent) {
        startRecording()
    }

    override func keyDown(with event: NSEvent) {
        if isRecording {
            _ = handleKeyEvent(event)
        } else {
            super.keyDown(with: event)
        }
    }

    private func startRecording() {
        isRecording = true
        textField.stringValue = "..."
        textField.textColor = .secondaryLabelColor

        // First responder 설정
        window?.makeFirstResponder(self)

        // 로컬 이벤트 모니터 시작 (keyDown + flagsChanged)
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { [weak self] event in
            guard let self = self, self.isRecording else { return event }
            if event.type == .keyDown {
                return self.handleKeyEvent(event) ? nil : event
            }
            return event
        }
    }

    private func stopRecording() {
        isRecording = false
        textField.textColor = .labelColor
        stopMonitor()
    }

    private func stopMonitor() {
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }
    }

    private func handleKeyEvent(_ event: NSEvent) -> Bool {
        let modifiers = event.modifierFlags.intersection([.command, .option, .shift, .control])

        // ESC 키 = 취소
        if event.keyCode == 53 {
            textField.stringValue = shortcut
            stopRecording()
            return true
        }

        // 수정자 키만 누른 경우 무시
        guard !modifiers.isEmpty else { return false }

        // 단축키 문자열 생성
        var parts: [String] = []
        if modifiers.contains(.control) { parts.append("⌃") }
        if modifiers.contains(.option) { parts.append("⌥") }
        if modifiers.contains(.shift) { parts.append("⇧") }
        if modifiers.contains(.command) { parts.append("⌘") }

        // 키 문자 추가
        if let chars = event.charactersIgnoringModifiers?.uppercased(), !chars.isEmpty {
            let char = chars.first!
            // 알파벳과 숫자만 허용
            if char.isLetter || char.isNumber {
                parts.append(String(char))

                let newShortcut = parts.joined()
                shortcut = newShortcut
                textField.stringValue = newShortcut
                onShortcutChange?(newShortcut)

                stopRecording()
                return true
            }
        }
        return false
    }

    override func resignFirstResponder() -> Bool {
        if isRecording {
            textField.stringValue = shortcut
            stopRecording()
        }
        return super.resignFirstResponder()
    }
}

// 설정 행 컴포넌트
struct SettingRow<Content: View>: View {
    let label: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            content
        }
        .padding(.vertical, 8)
    }
}

// 설정 구분선
struct SettingDivider: View {
    var body: some View {
        Divider()
            .opacity(0.5)
    }
}

// 클릭 가능한 텍스트필드
class ClickableTextField: NSTextField {
    var onMouseDown: (() -> Void)?

    override func mouseDown(with event: NSEvent) {
        onMouseDown?()
    }
}
