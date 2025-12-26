import SwiftUI

/// 배지 편집 정보
struct BadgeEditInfo: Identifiable {
    let id = UUID()
    let badgeType: BadgeType
    let refId: String       // 순수 ID만 (path 제외)
    var label: String
    var jsonPath: String    // command 배지용
    var useJsonPath: Bool   // command 배지용
    var customOriginalText: String?  // 사용자 직접 편집용

    var originalText: String {
        if let custom = customOriginalText, !custom.isEmpty {
            return custom
        }
        if badgeType == .command && useJsonPath && !jsonPath.isEmpty {
            return "`command@\(refId)|\(jsonPath)`"
        }
        return "`\(badgeType.rawValue)@\(refId)`"
    }

    /// 순수 ID 추출 (path가 포함된 경우 분리)
    static func extractPureId(_ refIdWithPath: String) -> String {
        if refIdWithPath.contains("|") {
            return String(refIdWithPath.split(separator: "|", maxSplits: 1).first ?? Substring(refIdWithPath))
        }
        return refIdWithPath
    }
}

/// 배지 편집 시트
struct BadgeEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var badgeInfo: BadgeEditInfo?
    var onSave: ((BadgeEditInfo) -> Void)?

    @State private var newLabel: String = ""
    @State private var useJsonPath: Bool = false
    @State private var jsonPath: String = ""
    @State private var secureValue: String = ""  // secure 배지 복호화된 값 편집용
    @State private var variableValue: String = ""  // variable 배지 값 편집용

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 헤더
            HStack {
                if let type = badgeInfo?.badgeType {
                    Color(nsColor: type.color).opacity(0.2)
                        .frame(width: 24, height: 24)
                        .cornerRadius(4)
                        .overlay(
                            Text(type.rawValue.prefix(1).uppercased())
                                .font(.caption.bold())
                                .foregroundColor(Color(nsColor: type.color))
                        )
                }
                Text(L.badgeEditTitle)
                    .font(.headline)
                Spacer()
            }

            Divider()

            // 배지 정보
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Type:")
                        .foregroundStyle(.secondary)
                    Text(badgeInfo?.badgeType.rawValue ?? "")
                        .font(.system(.body, design: .monospaced))
                }
                HStack {
                    Text("ID:")
                        .foregroundStyle(.secondary)
                    Text(badgeInfo?.refId ?? "")
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                }
            }

            Divider()

            // 라벨 편집
            VStack(alignment: .leading, spacing: 4) {
                Text(L.badgeEditLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("", text: $newLabel)
                    .textFieldStyle(.roundedBorder)
            }

            // command 배지용 JSON path
            if badgeInfo?.badgeType == .command {
                Divider()

                Toggle(L.badgeEditUseJsonPath, isOn: $useJsonPath)

                if useJsonPath {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(L.badgeEditJsonPath)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("data.token", text: $jsonPath)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(.body, design: .monospaced))
                        Text(L.badgeEditJsonPathHint)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }

            Divider()

            // 실제 값 표시/편집
            VStack(alignment: .leading, spacing: 4) {
                Text(L.badgeEditActualValue)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                switch badgeInfo?.badgeType {
                case .secure:
                    // secure 배지: 편집 가능 (값 표시)
                    TextField("", text: $secureValue)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                    Text(L.badgeEditSecureValueHint)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                case .variable:
                    // variable 배지: 편집 가능
                    TextField("", text: $variableValue)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                    Text(L.badgeEditVariableValueHint)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                case .command:
                    // command 배지: 읽기 전용
                    if let value = commandDisplayValue {
                        Text(value)
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(.primary)
                            .textSelection(.enabled)
                            .lineLimit(3)
                    } else {
                        Text("-")
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(.tertiary)
                    }
                    // JSON path 사용시 추출된 값 표시
                    if useJsonPath && !jsonPath.isEmpty, let extracted = extractedJsonValue {
                        Divider()
                        Text("→ \(extracted)")
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                            .lineLimit(2)
                    }
                case .none:
                    Text("-")
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.tertiary)
                }
            }

            // 연결된 commands
            if !connectedCommands.isEmpty {
                Divider()
                VStack(alignment: .leading, spacing: 4) {
                    Text(L.badgeEditConnectedCommands)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    ForEach(connectedCommands, id: \.id) { cmd in
                        HStack(spacing: 4) {
                            Text(cmd.id)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(.secondary)
                            Text(cmd.label)
                                .font(.caption)
                        }
                    }
                }
            }

            Spacer()

            Divider()

            // 버튼
            HStack {
                Spacer()
                Button(L.buttonCancel) {
                    dismiss()
                }
                .buttonStyle(.borderless)

                Button(L.buttonSave) {
                    saveBadge()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .frame(width: 350, height: sheetHeight)
        .onAppear {
            if let info = badgeInfo {
                newLabel = info.label
                useJsonPath = info.useJsonPath
                jsonPath = info.jsonPath
                switch info.badgeType {
                case .secure:
                    secureValue = SecureValueManager.shared.decrypt(refId: info.refId) ?? ""
                case .variable:
                    variableValue = Database.shared.getVariableValueById(info.refId) ?? ""
                case .command:
                    break
                }
            }
        }
    }

    /// 연결된 commands (이 배지를 참조하는 명령어들)
    private var connectedCommands: [Command] {
        guard let info = badgeInfo else { return [] }
        let searchPattern = "`\(info.badgeType.rawValue)@\(info.refId)"
        return Database.shared.loadCommands().filter { cmd in
            cmd.command.contains(searchPattern) ||
            cmd.url.contains(searchPattern) ||
            cmd.bodyData.contains(searchPattern) ||
            cmd.headers.values.contains { $0.contains(searchPattern) } ||
            cmd.queryParams.values.contains { $0.contains(searchPattern) }
        }
    }

    /// command 배지 표시값 (유형별)
    private var commandDisplayValue: String? {
        guard let info = badgeInfo, info.badgeType == .command,
              let cmd = Database.shared.getCommandById(info.refId) else { return nil }

        switch cmd.executionType {
        case .terminal, .background, .script:
            // 명령어/스크립트 표시 (긴 경우 줄임)
            let lines = cmd.command.components(separatedBy: .newlines)
            if lines.count > 3 {
                return lines.prefix(3).joined(separator: "\n") + "\n..."
            }
            return cmd.command
        case .schedule:
            // 일정 날짜 표시
            if let date = cmd.scheduleDate {
                let formatter = DateFormatter()
                formatter.dateStyle = .medium
                formatter.timeStyle = .short
                var result = formatter.string(from: date)
                if cmd.repeatType != .none {
                    result += " (\(cmd.repeatType.rawValue))"
                }
                return result
            }
            return nil
        case .api:
            // curl 형태로 표시
            var curl = "curl -X \(cmd.httpMethod.rawValue) \"\(cmd.url)\""
            for (key, value) in cmd.headers {
                curl += " \\\n  -H \"\(key): \(value)\""
            }
            if !cmd.bodyData.isEmpty {
                curl += " \\\n  -d '\(cmd.bodyData.prefix(50))...'"
            }
            return curl
        }
    }

    /// JSON path로 추출된 값
    private var extractedJsonValue: String? {
        guard let info = badgeInfo, info.badgeType == .command,
              !jsonPath.isEmpty,
              let response = Database.shared.getCommandLastResponse(info.refId),
              let data = response.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) else { return nil }

        // JSON path 파싱 (예: "data.token" or "items[0].name")
        let parts = jsonPath.components(separatedBy: ".")
        var current: Any = json

        for part in parts {
            // 배열 인덱스 처리 (예: "items[0]")
            if let bracketRange = part.range(of: "["), let endBracket = part.range(of: "]") {
                let key = String(part[..<bracketRange.lowerBound])
                let indexStr = String(part[bracketRange.upperBound..<endBracket.lowerBound])
                guard let index = Int(indexStr),
                      let dict = current as? [String: Any],
                      let array = (key.isEmpty ? current : dict[key]) as? [Any],
                      index < array.count else { return nil }
                current = array[index]
            } else if let dict = current as? [String: Any], let value = dict[part] {
                current = value
            } else {
                return nil
            }
        }

        if let str = current as? String {
            return str
        } else if let num = current as? NSNumber {
            return num.stringValue
        } else if let data = try? JSONSerialization.data(withJSONObject: current),
                  let str = String(data: data, encoding: .utf8) {
            return str
        }
        return nil
    }

    /// 시트 높이 계산
    private var sheetHeight: CGFloat {
        var height: CGFloat = 350
        if badgeInfo?.badgeType == .command {
            height += 80  // JSON path 섹션
        }
        if !connectedCommands.isEmpty {
            height += CGFloat(min(connectedCommands.count, 5) * 20 + 40)
        }
        return height
    }

    private func saveBadge() {
        guard var info = badgeInfo else { return }

        // 라벨 업데이트 (DB)
        if newLabel != info.label {
            switch info.badgeType {
            case .secure:
                Database.shared.updateSecureLabel(id: info.refId, label: newLabel)
            case .command:
                Database.shared.updateCommandLabel(id: info.refId, label: newLabel)
            case .variable:
                Database.shared.updateVariableLabel(id: info.refId, label: newLabel)
            }
            info.label = newLabel
        }

        // 배지 값 업데이트
        switch info.badgeType {
        case .secure:
            if !secureValue.isEmpty {
                _ = SecureValueManager.shared.updateValue(refId: info.refId, newPlaintext: secureValue)
            }
        case .variable:
            Database.shared.updateVariableValue(id: info.refId, value: variableValue)
        case .command:
            break
        }

        info.useJsonPath = useJsonPath
        info.jsonPath = jsonPath

        onSave?(info)
        dismiss()
    }
}
