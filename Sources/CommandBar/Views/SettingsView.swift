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
        [L.settingsGeneral, L.settingsHistoryTab, L.settingsClipboardTab, L.settingsBackup, L.settingsLanguage]
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

            // 탭 콘텐츠 (고정 높이)
            VStack(alignment: .leading, spacing: 0) {
                if selectedTab == 0 {
                    // 기본 설정
                    Toggle(L.settingsAlwaysOnTop, isOn: $settings.alwaysOnTop)
                        .frame(maxWidth: .infinity, minHeight: 24, alignment: .leading)
                    Toggle(L.settingsLaunchAtLogin, isOn: $settings.launchAtLogin)
                        .frame(maxWidth: .infinity, minHeight: 24, alignment: .leading)
                    HStack {
                        Text(L.settingsBackgroundOpacity)
                        Slider(value: $settings.backgroundOpacity, in: 0.3...1.0, step: 0.1)
                        Text("\(Int(settings.backgroundOpacity * 100))%")
                            .frame(width: 40)
                    }
                    .frame(maxWidth: .infinity, minHeight: 24, alignment: .leading)
                } else if selectedTab == 1 {
                    // 히스토리 설정
                    HStack {
                        Text(L.settingsMaxCount)
                        Spacer()
                        TextField("", value: $settings.maxHistoryCount, format: .number)
                            .frame(width: 80)
                            .textFieldStyle(.roundedBorder)
                    }
                    .frame(maxWidth: .infinity, minHeight: 24, alignment: .leading)
                } else if selectedTab == 2 {
                    // 클립보드 설정
                    HStack {
                        Text(L.settingsMaxCount)
                        Spacer()
                        TextField("", value: $settings.maxClipboardCount, format: .number)
                            .frame(width: 80)
                            .textFieldStyle(.roundedBorder)
                    }
                    .frame(maxWidth: .infinity, minHeight: 24, alignment: .leading)
                    HStack {
                        Text(L.settingsNotesFolderName)
                        Spacer()
                        TextField("", text: $settings.notesFolderName)
                            .frame(width: 120)
                            .textFieldStyle(.roundedBorder)
                    }
                    .frame(maxWidth: .infinity, minHeight: 24, alignment: .leading)
                } else if selectedTab == 3 {
                    // 백업 (가져오기/내보내기)
                    Text(L.settingsBackupNote)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 24, alignment: .leading)
                    HStack(spacing: 8) {
                        Button(L.settingsExportFile) { exportToFile() }
                        Button(L.settingsImportFile) { loadFromFile() }
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, minHeight: 24, alignment: .leading)
                } else {
                    // 언어 설정
                    HStack {
                        Text(L.settingsLanguage)
                        Spacer()
                        Picker("", selection: $languageManager.currentLanguage) {
                            ForEach(Language.allCases, id: \.self) { lang in
                                Text(lang.displayName).tag(lang)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 100)
                    }
                    .frame(maxWidth: .infinity, minHeight: 24, alignment: .leading)
                    HStack(spacing: 8) {
                        Button(L.settingsExportLanguagePack) { exportLanguagePack() }
                        Button(L.settingsImportLanguagePack) { importLanguagePack() }
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, minHeight: 24, alignment: .leading)
                }
                Spacer()
            }
            .frame(height: 90)
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
