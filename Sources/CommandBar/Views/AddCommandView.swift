import SwiftUI

struct AddCommandView: View {
    @ObservedObject var store: CommandStore
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var command = ""
    @State private var groupId: UUID = CommandStore.defaultGroupId
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

    var isValid: Bool {
        if title.isEmpty { return false }
        switch executionType {
        case .terminal, .background, .script:
            return !command.isEmpty
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
        VStack(alignment: .leading, spacing: 0) {
            Text(L.addNewItem)
                .font(.headline)
                .padding()

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(L.commandTitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("", text: $title)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(L.groupTitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Picker("", selection: $groupId) {
                    ForEach(store.groups) { group in
                        HStack {
                            Circle().fill(colorFor(group.color)).frame(width: 8, height: 8)
                            Text(group.name)
                        }.tag(group.id)
                    }
                }
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
                    store.add(Command(
                        groupId: groupId,
                        title: title,
                        command: command,
                        executionType: executionType,
                        terminalApp: terminalApp,
                        interval: Int(interval) ?? 0,
                        scheduleDate: executionType == .schedule ? scheduleDate : nil,
                        repeatType: repeatType,
                        reminderTimes: reminderTimes
                    ))
                    dismiss()
                }
                .buttonStyle(HoverTextButtonStyle())
                .disabled(!isValid)
            }
            .padding()
        }
        .frame(width: 350)
        .sheet(isPresented: $showParamHelp) {
            ParameterHelpView()
        }
    }
}
