import SwiftUI

struct AddCommandView: View {
    @ObservedObject var store: CommandStore
    @Environment(\.dismiss) private var dismiss

    @State private var label = ""
    @State private var command = ""
    @State private var groupSeq: Int? = nil
    @State private var executionType: ExecutionType = .terminal
    @State private var terminalApp: TerminalApp = .iterm2
    @State private var interval: String = "0"
    // 일정용
    @State private var scheduleDate = Date()
    @State private var repeatType: RepeatType = .none
    // 미리 알림
    @State private var remind5min = false
    @State private var remind30min = false
    @State private var remind1hour = false
    @State private var remind1day = false
    @State private var showParamHelp = false
    // API 요청용
    @State private var url = ""
    @State private var httpMethod: HTTPMethod = .get
    @State private var headers: [KeyValuePair] = []
    @State private var queryParams: [KeyValuePair] = []
    @State private var bodyType: BodyType = .none
    @State private var bodyData = ""
    @State private var bodyParams: [KeyValuePair] = []
    @State private var fileParams: [KeyValuePair] = []

    var isValid: Bool {
        if label.isEmpty { return false }
        switch executionType {
        case .terminal, .background, .script:
            return !command.isEmpty
        case .schedule:
            return true
        case .api:
            return !url.isEmpty
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
        VStack(alignment: .leading, spacing: 0) {
            Text(L.addNewItem)
                .font(.headline)
                .padding()

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(L.commandLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("", text: $label)
                    .textFieldStyle(.roundedBorder)
            }

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
                    Text("URL")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("https://api.example.com/endpoint", text: $url)
                        .textFieldStyle(.roundedBorder)
                }

                // HTTP Method
                VStack(alignment: .leading, spacing: 4) {
                    Text("HTTP Method")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Picker("", selection: $httpMethod) {
                        ForEach([HTTPMethod.get, .post, .put, .delete, .patch], id: \.self) { method in
                            Text(method.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }

                // Headers
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Headers")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("+") {
                            headers.append(KeyValuePair(key: "", value: ""))
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }

                    if !headers.isEmpty {
                        VStack(spacing: 8) {
                            ForEach(headers.indices, id: \.self) { index in
                                HStack(spacing: 8) {
                                    TextField("Key", text: $headers[index].key)
                                        .textFieldStyle(.roundedBorder)
                                        .frame(width: 120)
                                    TextField("Value", text: $headers[index].value)
                                        .textFieldStyle(.roundedBorder)
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
                        Text("Query Parameters")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("+") {
                            queryParams.append(KeyValuePair(key: "", value: ""))
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }

                    if !queryParams.isEmpty {
                        VStack(spacing: 8) {
                            ForEach(queryParams.indices, id: \.self) { index in
                                HStack(spacing: 8) {
                                    TextField("Key", text: $queryParams[index].key)
                                        .textFieldStyle(.roundedBorder)
                                        .frame(width: 120)
                                    TextField("Value", text: $queryParams[index].value)
                                        .textFieldStyle(.roundedBorder)
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
                        Text("Body Type")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Picker("", selection: $bodyType) {
                            ForEach([BodyType.none, .json, .formData, .multipart], id: \.self) { type in
                                Text(type.displayName)
                            }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                    }

                    // Body Data
                    if bodyType == .json {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Body Data (JSON)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            TextEditor(text: $bodyData)
                                .font(.body.monospaced())
                                .frame(height: 100)
                                .padding(4)
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
                                            TextField("Key", text: $bodyParams[index].key)
                                                .textFieldStyle(.roundedBorder)
                                                .frame(width: 120)
                                            TextField("Value", text: $bodyParams[index].value)
                                                .textFieldStyle(.roundedBorder)
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
                                            TextField("Key", text: $bodyParams[index].key)
                                                .textFieldStyle(.roundedBorder)
                                                .frame(width: 120)
                                            TextField("Value", text: $bodyParams[index].value)
                                                .textFieldStyle(.roundedBorder)
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
                    TextEditor(text: $command)
                        .font(.body.monospaced())
                        .frame(height: 80)
                        .padding(4)
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
                    // script는 명령어만 입력
                }
                }
                .padding()
            }

            Divider()

            HStack {
                Button(L.buttonCancel) {
                    dismiss()
                }
                .buttonStyle(HoverTextButtonStyle())
                Spacer()
                Button(L.buttonAdd) {
                    // Convert KeyValuePair arrays to dictionaries for API
                    let headersDict = Dictionary(uniqueKeysWithValues: headers.map { ($0.key, $0.value) })
                    let queryParamsDict = Dictionary(uniqueKeysWithValues: queryParams.map { ($0.key, $0.value) })
                    let fileParamsDict = Dictionary(uniqueKeysWithValues: fileParams.map { ($0.key, $0.value) })

                    // Prepare body data based on bodyType
                    var finalBodyData = ""
                    if executionType == .api && shouldShowBodyFields {
                        if bodyType == .json {
                            finalBodyData = bodyData
                        } else if bodyType == .formData || bodyType == .multipart {
                            // Convert bodyParams to JSON string
                            let formDataDict = Dictionary(uniqueKeysWithValues: bodyParams.map { ($0.key, $0.value) })
                            if let jsonData = try? JSONSerialization.data(withJSONObject: formDataDict, options: .prettyPrinted),
                               let jsonString = String(data: jsonData, encoding: .utf8) {
                                finalBodyData = jsonString
                            }
                        }
                    }

                    store.add(Command(
                        groupSeq: groupSeq,
                        label: label,
                        command: command,
                        executionType: executionType,
                        terminalApp: terminalApp,
                        interval: Int(interval) ?? 0,
                        scheduleDate: executionType == .schedule ? scheduleDate : nil,
                        repeatType: repeatType,
                        reminderTimes: reminderTimes,
                        url: executionType == .api ? url : "",
                        httpMethod: httpMethod,
                        headers: headersDict,
                        queryParams: queryParamsDict,
                        bodyType: bodyType,
                        bodyData: finalBodyData,
                        fileParams: fileParamsDict
                    ))
                    dismiss()
                }
                .buttonStyle(HoverTextButtonStyle())
                .disabled(!isValid)
            }
            .padding()
        }
        .frame(width: 450)
        .sheet(isPresented: $showParamHelp) {
            ParameterHelpView()
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
        case "yellow": return .yellow
        default: return .blue
        }
    }
}
