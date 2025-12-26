import SwiftUI
import AppKit

struct EditCommandView: View {
    @ObservedObject var store: CommandStore
    @Environment(\.dismiss) private var dismiss

    let command: Command
    var onRun: ((Command) -> Void)? = nil
    @State private var label: String
    @State private var commandText: String
    @State private var groupSeq: Int?
    @State private var executionType: ExecutionType
    @State private var terminalApp: TerminalApp
    @State private var interval: String
    // 일정용
    @State private var scheduleDate: Date
    @State private var repeatType: RepeatType
    // 미리 알림
    @State private var showParamHelp = false
    @State private var remind5min: Bool
    @State private var remind30min: Bool
    @State private var remind1hour: Bool
    @State private var remind1day: Bool
    // API용
    @State private var apiUrl: String
    @State private var httpMethod: HTTPMethod
    @State private var headers: [KeyValuePair]
    @State private var queryParams: [KeyValuePair]
    @State private var bodyType: BodyType
    @State private var bodyData: String
    @State private var bodyParams: [KeyValuePair]
    @State private var fileParams: [KeyValuePair]
    @State private var badgeEditInfo: BadgeEditInfo?
    @State private var originalBadgeText: String = ""

    init(store: CommandStore, command: Command, onRun: ((Command) -> Void)? = nil) {
        self.store = store
        self.command = command
        self.onRun = onRun
        _label = State(initialValue: command.label)
        _commandText = State(initialValue: command.command)
        _groupSeq = State(initialValue: command.groupSeq)
        _executionType = State(initialValue: command.executionType)
        _terminalApp = State(initialValue: command.terminalApp)
        _interval = State(initialValue: String(command.interval))
        _scheduleDate = State(initialValue: command.scheduleDate ?? Date())
        _repeatType = State(initialValue: command.repeatType)
        _remind5min = State(initialValue: command.reminderTimes.contains(300))
        _remind30min = State(initialValue: command.reminderTimes.contains(1800))
        _remind1hour = State(initialValue: command.reminderTimes.contains(3600))
        _remind1day = State(initialValue: command.reminderTimes.contains(86400))
        // API 필드 초기화
        _apiUrl = State(initialValue: command.url)
        _httpMethod = State(initialValue: command.httpMethod)
        _headers = State(initialValue: command.headers.map { KeyValuePair(key: $0.key, value: $0.value) })
        _queryParams = State(initialValue: command.queryParams.map { KeyValuePair(key: $0.key, value: $0.value) })
        _bodyType = State(initialValue: command.bodyType)
        _bodyData = State(initialValue: command.bodyData)

        // bodyParams 초기화: formData나 multipart일 때 bodyData JSON 파싱
        var initialBodyParams: [KeyValuePair] = []
        if (command.bodyType == .formData || command.bodyType == .multipart) && !command.bodyData.isEmpty {
            if let data = command.bodyData.data(using: .utf8),
               let dict = try? JSONSerialization.jsonObject(with: data) as? [String: String] {
                initialBodyParams = dict.map { KeyValuePair(key: $0.key, value: $0.value) }
            }
        }
        _bodyParams = State(initialValue: initialBodyParams)
        _fileParams = State(initialValue: command.fileParams.map { KeyValuePair(key: $0.key, value: $0.value) })
    }

    var isValid: Bool {
        if label.isEmpty { return false }
        switch executionType {
        case .terminal, .background, .script:
            return !commandText.isEmpty
        case .schedule:
            return true
        case .api:
            return !apiUrl.isEmpty
        }
    }

    var shouldShowBodyFields: Bool {
        httpMethod == .post || httpMethod == .put || httpMethod == .patch
    }

    func canRemind(seconds: Int) -> Bool {
        repeatType != .none || scheduleDate.timeIntervalSinceNow > Double(seconds)
    }

    var reminderTimes: Set<Int> {
        var times: Set<Int> = []
        if remind5min { times.insert(300) }
        if remind30min { times.insert(1800) }
        if remind1hour { times.insert(3600) }
        if remind1day { times.insert(86400) }
        return times
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(L.commandEditTitle)
                    .font(.headline)
                Spacer()
                Button(action: copyId) {
                    Text(command.id)
                        .font(.caption2.monospaced())
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .help("ID 복사: {command@\(command.id)}")
            }

            Divider()

            VStack(alignment: .leading, spacing: 4) {
                Text(L.commandTitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("", text: $label)
                    .textFieldStyle(.roundedBorder)
            }

            // 휴지통 아이템이 아닐 때만 그룹 선택 표시
            if !command.isInTrash {
                VStack(alignment: .leading, spacing: 4) {
                    Text(L.groupTitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Picker("", selection: $groupSeq) {
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
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(L.executionMethod)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Picker("", selection: $executionType) {
                    ForEach(ExecutionType.allCases, id: \.self) {
                        Text($0.displayName)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }

            if executionType == .schedule {
                VStack(alignment: .leading, spacing: 4) {
                    Text(L.dateTime)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    DatePicker("", selection: $scheduleDate, displayedComponents: [.date, .hourAndMinute])
                        .labelsHidden()
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(L.commandRepeat)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Picker("", selection: $repeatType) {
                        ForEach(RepeatType.allCases, id: \.self) {
                            Text($0.displayName)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(L.commandReminders)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 12) {
                        Toggle("5" + L.minutesUnit, isOn: $remind5min)
                            .toggleStyle(.checkbox)
                            .disabled(!canRemind(seconds: 300))
                        Toggle("30" + L.minutesUnit, isOn: $remind30min)
                            .toggleStyle(.checkbox)
                            .disabled(!canRemind(seconds: 1800))
                        Toggle("1" + L.hoursUnit, isOn: $remind1hour)
                            .toggleStyle(.checkbox)
                            .disabled(!canRemind(seconds: 3600))
                        Toggle("1" + L.daysUnit, isOn: $remind1day)
                            .toggleStyle(.checkbox)
                            .disabled(!canRemind(seconds: 86400))
                    }
                }
            } else if executionType == .api {
                // 환경 관리 버튼
                HStack {
                    if let env = store.activeEnvironment {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(colorFor(env.color))
                                .frame(width: 8, height: 8)
                            Text(env.name)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Text(L.envSelectEnvironment)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button(action: {
                        EnvironmentManagerWindowController.show(store: store)
                    }) {
                        Label(L.envManage, systemImage: "globe")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                // API URL
                VStack(alignment: .leading, spacing: 4) {
                    Text(L.apiEndpoint)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    AutocompleteTextEditor(
                        text: $apiUrl,
                        suggestions: store.allEnvironmentVariableNames,
                        idSuggestions: store.allIdSuggestions,
                        singleLine: true,
                        placeholder: "https://api.example.com/endpoint",
                        onBadgeEdit: handleBadgeEdit
                    )
                    .frame(height: 24)
                }

                // HTTP Method
                VStack(alignment: .leading, spacing: 4) {
                    Text(L.apiMethod)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Picker("", selection: $httpMethod) {
                        ForEach(HTTPMethod.allCases, id: \.self) { method in
                            Text(method.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }

                // Headers
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(L.apiHeaders)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button(L.apiAddHeader) {
                            headers.append(KeyValuePair(key: "", value: ""))
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }

                    if !headers.isEmpty {
                        VStack(spacing: 8) {
                            ForEach(headers.indices, id: \.self) { index in
                                HStack(spacing: 8) {
                                    AutocompleteTextEditor(
                                        text: $headers[index].key,
                                        suggestions: store.allEnvironmentVariableNames,
                                        idSuggestions: store.allIdSuggestions,
                                        singleLine: true,
                                        placeholder: "Key",
                                        onBadgeEdit: handleBadgeEdit
                                    )
                                    .frame(width: 120, height: 24)
                                    AutocompleteTextEditor(
                                        text: $headers[index].value,
                                        suggestions: store.allEnvironmentVariableNames,
                                        idSuggestions: store.allIdSuggestions,
                                        singleLine: true,
                                        placeholder: "Value",
                                        onBadgeEdit: handleBadgeEdit
                                    )
                                    .frame(height: 24)
                                    Button(action: {
                                        headers.remove(at: index)
                                    }) {
                                        Image(systemName: "minus.circle.fill")
                                            .foregroundStyle(.red)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }

                // Query Parameters
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(L.apiQueryParams)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button(L.apiAddParam) {
                            queryParams.append(KeyValuePair(key: "", value: ""))
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }

                    if !queryParams.isEmpty {
                        VStack(spacing: 8) {
                            ForEach(queryParams.indices, id: \.self) { index in
                                HStack(spacing: 8) {
                                    AutocompleteTextEditor(
                                        text: $queryParams[index].key,
                                        suggestions: store.allEnvironmentVariableNames,
                                        idSuggestions: store.allIdSuggestions,
                                        singleLine: true,
                                        placeholder: "Key",
                                        onBadgeEdit: handleBadgeEdit
                                    )
                                    .frame(width: 120, height: 24)
                                    AutocompleteTextEditor(
                                        text: $queryParams[index].value,
                                        suggestions: store.allEnvironmentVariableNames,
                                        idSuggestions: store.allIdSuggestions,
                                        singleLine: true,
                                        placeholder: "Value",
                                        onBadgeEdit: handleBadgeEdit
                                    )
                                    .frame(height: 24)
                                    Button(action: {
                                        queryParams.remove(at: index)
                                    }) {
                                        Image(systemName: "minus.circle.fill")
                                            .foregroundStyle(.red)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }

                // Body Type (only for POST, PUT, PATCH)
                if shouldShowBodyFields {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(L.apiBodyType)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Picker("", selection: $bodyType) {
                            ForEach(BodyType.allCases, id: \.self) { type in
                                Text(type.displayName)
                            }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                    }

                    // Body Data
                    if bodyType == .json {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(L.apiBodyData)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            AutocompleteTextEditor(
                                text: $bodyData,
                                suggestions: store.allEnvironmentVariableNames,
                                idSuggestions: store.allIdSuggestions,
                                onBadgeEdit: handleBadgeEdit
                            )
                            .frame(height: 100)
                            .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.gray.opacity(0.3)))
                        }
                    } else if bodyType == .formData {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Form Data")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Button("+") {
                                    bodyParams.append(KeyValuePair(key: "", value: ""))
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }

                            if !bodyParams.isEmpty {
                                VStack(spacing: 8) {
                                    ForEach(bodyParams.indices, id: \.self) { index in
                                        HStack(spacing: 8) {
                                            AutocompleteTextEditor(
                                                text: $bodyParams[index].key,
                                                suggestions: store.allEnvironmentVariableNames,
                                                idSuggestions: store.allIdSuggestions,
                                                singleLine: true,
                                                placeholder: "Key",
                                                onBadgeEdit: handleBadgeEdit
                                            )
                                            .frame(width: 120, height: 24)
                                            AutocompleteTextEditor(
                                                text: $bodyParams[index].value,
                                                suggestions: store.allEnvironmentVariableNames,
                                                idSuggestions: store.allIdSuggestions,
                                                singleLine: true,
                                                placeholder: "Value",
                                                onBadgeEdit: handleBadgeEdit
                                            )
                                            .frame(height: 24)
                                            Button(action: {
                                                bodyParams.remove(at: index)
                                            }) {
                                                Image(systemName: "minus.circle.fill")
                                                    .foregroundStyle(.red)
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                }
                            }
                        }
                    } else if bodyType == .multipart {
                        // Text parameters
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Text Parameters")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Button("+") {
                                    bodyParams.append(KeyValuePair(key: "", value: ""))
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }

                            if !bodyParams.isEmpty {
                                VStack(spacing: 8) {
                                    ForEach(bodyParams.indices, id: \.self) { index in
                                        HStack(spacing: 8) {
                                            AutocompleteTextEditor(
                                                text: $bodyParams[index].key,
                                                suggestions: store.allEnvironmentVariableNames,
                                                idSuggestions: store.allIdSuggestions,
                                                singleLine: true,
                                                placeholder: "Key",
                                                onBadgeEdit: handleBadgeEdit
                                            )
                                            .frame(width: 120, height: 24)
                                            AutocompleteTextEditor(
                                                text: $bodyParams[index].value,
                                                suggestions: store.allEnvironmentVariableNames,
                                                idSuggestions: store.allIdSuggestions,
                                                singleLine: true,
                                                placeholder: "Value",
                                                onBadgeEdit: handleBadgeEdit
                                            )
                                            .frame(height: 24)
                                            Button(action: {
                                                bodyParams.remove(at: index)
                                            }) {
                                                Image(systemName: "minus.circle.fill")
                                                    .foregroundStyle(.red)
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                }
                            }
                        }

                        // File parameters
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("File Parameters")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Button("+") {
                                    fileParams.append(KeyValuePair(key: "", value: ""))
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }

                            if !fileParams.isEmpty {
                                VStack(spacing: 8) {
                                    ForEach(fileParams.indices, id: \.self) { index in
                                        HStack(spacing: 8) {
                                            TextField("Parameter", text: $fileParams[index].key)
                                                .textFieldStyle(.roundedBorder)
                                                .frame(width: 100)

                                            Button(action: {
                                                let panel = NSOpenPanel()
                                                panel.canChooseFiles = true
                                                panel.canChooseDirectories = false
                                                panel.allowsMultipleSelection = false
                                                if panel.runModal() == .OK, let url = panel.url {
                                                    fileParams[index].value = url.path
                                                }
                                            }) {
                                                Text("Choose File")
                                            }
                                            .buttonStyle(.bordered)
                                            .controlSize(.small)

                                            Text(fileParams[index].value.isEmpty ? "No file selected" : URL(fileURLWithPath: fileParams[index].value).lastPathComponent)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                                .lineLimit(1)
                                                .truncationMode(.middle)
                                                .frame(maxWidth: .infinity, alignment: .leading)

                                            Button(action: {
                                                fileParams.remove(at: index)
                                            }) {
                                                Image(systemName: "minus.circle.fill")
                                                    .foregroundStyle(.red)
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    Text(L.commandInput)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    AutocompleteTextEditor(
                        text: $commandText,
                        suggestions: store.allEnvironmentVariableNames,
                        idSuggestions: store.allIdSuggestions,
                        onBadgeEdit: handleBadgeEdit
                    )
                    .frame(height: 80)
                    .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.gray.opacity(0.3)))
                    if executionType == .script {
                        Button(action: { showParamHelp = true }) {
                            Text(L.commandHelpText)
                                .font(.caption)
                                .foregroundStyle(.blue)
                        }
                        .buttonStyle(.plain)
                    }
                }

                if executionType == .terminal {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(L.terminalAppLabel)
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
                } else if executionType == .background {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(L.intervalLabel)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("", text: $interval)
                            .textFieldStyle(.roundedBorder)
                        HStack(spacing: 4) {
                            ForEach([("10분", 600), ("1시간", 3600), ("6시간", 21600), ("12시간", 43200), ("24시간", 86400), ("7일", 604800)], id: \.0) { label, seconds in
                                Button(label) {
                                    interval = String(seconds)
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                        }
                    }
                }
                // script는 명령어만
            }

            Divider()

            HStack {
                Button(L.buttonCancel) {
                    dismiss()
                }
                .buttonStyle(HoverTextButtonStyle())
                Button("리셋") {
                    resetToOriginal()
                }
                .buttonStyle(HoverTextButtonStyle())
                Spacer()
                if let onRun = onRun {
                    Button(L.buttonRun) {
                        onRun(command)
                        dismiss()
                    }
                    .buttonStyle(HoverTextButtonStyle())
                }
                Button(L.buttonSave) {
                    var updated = command
                    updated.label = label
                    updated.command = commandText
                    updated.groupSeq = groupSeq
                    updated.executionType = executionType
                    updated.terminalApp = terminalApp
                    updated.interval = Int(interval) ?? 0
                    updated.scheduleDate = executionType == .schedule ? scheduleDate : nil
                    updated.repeatType = repeatType
                    updated.reminderTimes = reminderTimes
                    // API 필드 설정
                    if executionType == .api {
                        updated.url = apiUrl
                        updated.httpMethod = httpMethod
                        updated.headers = Dictionary(uniqueKeysWithValues: headers.map { ($0.key, $0.value) })
                        updated.queryParams = Dictionary(uniqueKeysWithValues: queryParams.map { ($0.key, $0.value) })
                        updated.bodyType = bodyType

                        // Prepare body data based on bodyType
                        var finalBodyData = bodyData
                        if bodyType == .formData || bodyType == .multipart {
                            // Convert bodyParams to JSON string
                            let formDataDict = Dictionary(uniqueKeysWithValues: bodyParams.map { ($0.key, $0.value) })
                            if let jsonData = try? JSONSerialization.data(withJSONObject: formDataDict, options: .prettyPrinted),
                               let jsonString = String(data: jsonData, encoding: .utf8) {
                                finalBodyData = jsonString
                            }
                        }
                        // {secure#label:value} → `secure@id` 변환
                        updated.bodyData = BadgeUtils.convertSecureInputInString(finalBodyData)
                        updated.fileParams = Dictionary(uniqueKeysWithValues: fileParams.map { ($0.key, $0.value) })
                    }
                    store.update(updated)
                    dismiss()
                }
                .buttonStyle(HoverTextButtonStyle())
                .disabled(!isValid)
            }
        }
        .padding()
        .frame(width: 450)
        .sheet(isPresented: $showParamHelp) {
            ParameterHelpView()
        }
        .sheet(item: $badgeEditInfo) { info in
            BadgeEditSheet(badgeInfo: $badgeEditInfo) { updatedInfo in
                // 모든 텍스트 필드에서 기존 배지를 새 배지로 교체
                let oldText = originalBadgeText
                let newText = updatedInfo.originalText
                if oldText != newText {
                    apiUrl = apiUrl.replacingOccurrences(of: oldText, with: newText)
                    bodyData = bodyData.replacingOccurrences(of: oldText, with: newText)
                    commandText = commandText.replacingOccurrences(of: oldText, with: newText)
                    // headers, queryParams, bodyParams 업데이트
                    headers = headers.map { pair in
                        var p = pair
                        p.value = p.value.replacingOccurrences(of: oldText, with: newText)
                        return p
                    }
                    queryParams = queryParams.map { pair in
                        var p = pair
                        p.value = p.value.replacingOccurrences(of: oldText, with: newText)
                        return p
                    }
                    bodyParams = bodyParams.map { pair in
                        var p = pair
                        p.value = p.value.replacingOccurrences(of: oldText, with: newText)
                        return p
                    }
                }
            }
        }
    }

    private func handleBadgeEdit(_ info: BadgeEditInfo) {
        originalBadgeText = info.originalText
        badgeEditInfo = info
    }

    func colorFor(_ name: String) -> Color {
        switch name {
        case "blue": return .blue
        case "red": return .red
        case "green": return .green
        case "orange": return .orange
        case "purple": return .purple
        case "gray": return .gray
        case "yellow": return .yellow
        default: return .blue
        }
    }

    func resetToOriginal() {
        label = command.label
        commandText = command.command
        groupSeq = command.groupSeq
        executionType = command.executionType
        terminalApp = command.terminalApp
        interval = String(command.interval)
        scheduleDate = command.scheduleDate ?? Date()
        repeatType = command.repeatType
        remind5min = command.reminderTimes.contains(300)
        remind30min = command.reminderTimes.contains(1800)
        remind1hour = command.reminderTimes.contains(3600)
        remind1day = command.reminderTimes.contains(86400)
        apiUrl = command.url
        httpMethod = command.httpMethod
        headers = command.headers.map { KeyValuePair(key: $0.key, value: $0.value) }
        queryParams = command.queryParams.map { KeyValuePair(key: $0.key, value: $0.value) }
        bodyType = command.bodyType
        bodyData = command.bodyData
        // bodyParams 초기화: formData나 multipart일 때 bodyData JSON 파싱
        if (command.bodyType == .formData || command.bodyType == .multipart) && !command.bodyData.isEmpty {
            if let data = command.bodyData.data(using: .utf8),
               let dict = try? JSONSerialization.jsonObject(with: data) as? [String: String] {
                bodyParams = dict.map { KeyValuePair(key: $0.key, value: $0.value) }
            } else {
                bodyParams = []
            }
        } else {
            bodyParams = []
        }
        fileParams = command.fileParams.map { KeyValuePair(key: $0.key, value: $0.value) }
    }

    func copyId() {
        let idString = "{command@\(command.id)}"
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(idString, forType: .string)
    }
}
