import SwiftUI

struct EditCommandView: View {
    @ObservedObject var store: CommandStore
    @Environment(\.dismiss) private var dismiss

    let command: Command
    @State private var title: String
    @State private var commandText: String
    @State private var groupId: UUID
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

    init(store: CommandStore, command: Command) {
        self.store = store
        self.command = command
        _title = State(initialValue: command.title)
        _commandText = State(initialValue: command.command)
        _groupId = State(initialValue: command.groupId)
        _executionType = State(initialValue: command.executionType)
        _terminalApp = State(initialValue: command.terminalApp)
        _interval = State(initialValue: String(command.interval))
        _scheduleDate = State(initialValue: command.scheduleDate ?? Date())
        _repeatType = State(initialValue: command.repeatType)
        _remind5min = State(initialValue: command.reminderTimes.contains(300))
        _remind30min = State(initialValue: command.reminderTimes.contains(1800))
        _remind1hour = State(initialValue: command.reminderTimes.contains(3600))
        _remind1day = State(initialValue: command.reminderTimes.contains(86400))
    }

    var isValid: Bool {
        if title.isEmpty { return false }
        switch executionType {
        case .terminal, .background, .script:
            return !commandText.isEmpty
        case .schedule:
            return true
        }
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

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(L.commandEditTitle)
                .font(.headline)

            VStack(alignment: .leading, spacing: 4) {
                Text(L.commandTitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("", text: $title)
                    .textFieldStyle(.roundedBorder)
            }

            // 휴지통 아이템이 아닐 때만 그룹 선택 표시
            if !command.isInTrash {
                VStack(alignment: .leading, spacing: 4) {
                    Text(L.groupTitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Menu {
                        ForEach(store.groups) { group in
                            Button(action: { groupId = group.id }) {
                                HStack {
                                    Circle().fill(colorFor(group.color)).frame(width: 8, height: 8)
                                    Text(group.name)
                                    if groupId == group.id {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(colorFor(store.groups.first { $0.id == groupId }?.color ?? "gray"))
                                .frame(width: 8, height: 8)
                            Text(store.groups.first { $0.id == groupId }?.name ?? "")
                            Spacer()
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .padding(6)
                        .background(RoundedRectangle(cornerRadius: 6).stroke(Color.gray.opacity(0.3)))
                    }
                    .menuStyle(.borderlessButton)
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
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    Text(L.commandInput)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextEditor(text: $commandText)
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
                // script는 명령어만
            }

            HStack {
                Button(L.buttonCancel) {
                    dismiss()
                }
                .buttonStyle(HoverTextButtonStyle())
                Spacer()
                Button(L.buttonSave) {
                    var updated = command
                    updated.title = title
                    updated.command = commandText
                    updated.groupId = groupId
                    updated.executionType = executionType
                    updated.terminalApp = terminalApp
                    updated.interval = Int(interval) ?? 0
                    updated.scheduleDate = executionType == .schedule ? scheduleDate : nil
                    updated.repeatType = repeatType
                    updated.reminderTimes = reminderTimes
                    store.update(updated)
                    dismiss()
                }
                .buttonStyle(HoverTextButtonStyle())
                .disabled(!isValid)
            }
        }
        .padding()
        .frame(width: 350)
        .sheet(isPresented: $showParamHelp) {
            ParameterHelpView()
        }
    }
}
