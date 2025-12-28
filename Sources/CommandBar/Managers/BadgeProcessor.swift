import Foundation
import AppKit

// MARK: - 배지 처리 결과

/// 배지 처리 결과
struct BadgeProcessResult {
    let text: String
    let error: String?
    let errorRange: NSRange?

    init(text: String, error: String? = nil, errorRange: NSRange? = nil) {
        self.text = text
        self.error = error
        self.errorRange = errorRange
    }

    var hasError: Bool { error != nil }
}

// MARK: - 통합 배지 처리 관리자

/// 모든 배지 타입(secure/command/var)의 처리를 통합 관리
class BadgeProcessor {
    static let shared = BadgeProcessor()

    private let db = Database.shared

    private init() {}

    // MARK: - 트리거 패턴

    /// 모든 배지 타입의 트리거 생성
    static func triggers(for type: BadgeType) -> [String] {
        let prefix = type.rawValue
        return [
            "{\(prefix):", "{\(prefix)#", "{\(prefix)@",
            "[\(prefix):", "[\(prefix)#", "[\(prefix)@"
        ]
    }

    /// ID 트리거 (@)
    static func idTriggers(for type: BadgeType) -> [String] {
        let prefix = type.rawValue
        return ["{\(prefix)@", "[\(prefix)@"]
    }

    /// 라벨 트리거 (#, :)
    static func labelTriggers(for type: BadgeType) -> [String] {
        let prefix = type.rawValue
        return ["{\(prefix):", "{\(prefix)#", "[\(prefix):", "[\(prefix)#"]
    }

    // MARK: - 저장 형식 변환

    /// 저장 전 처리: 모든 입력 패턴을 `type@id` 형식으로 변환
    /// - {type#label:value} → 암호화/저장 → `type@id`
    /// - {type#label} → 기존 참조 → `type@id`
    /// - {type:value} → 암호화/저장 → `type@id`
    func convertToStorageFormat(_ text: String) -> BadgeProcessResult {
        var result = text

        // 1. secure 처리: {secure#label:value}, {secure:value}, {secure#label}
        let secureResult = processSecurePatterns(&result)
        if secureResult.hasError {
            return secureResult
        }

        // 2. var 처리: {var#label:value}, {var#label}
        let varResult = processVarPatterns(&result)
        if varResult.hasError {
            return varResult
        }

        // 3. command 처리: {command#label} (command는 값 생성 없음, 참조만)
        let commandResult = processCommandPatterns(&result)
        if commandResult.hasError {
            return commandResult
        }

        return BadgeProcessResult(text: result)
    }

    // MARK: - Secure 패턴 처리

    private func processSecurePatterns(_ text: inout String) -> BadgeProcessResult {
        let secureManager = SecureValueManager.shared

        // 1. {secure#label:value} 또는 [secure#label:value]
        let labelValuePattern = "(?:\\{|\\[)secure#([^:}\\]]+):([^}\\]]+)(?:\\}|\\])"
        if let regex = try? NSRegularExpression(pattern: labelValuePattern) {
            let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text)).reversed()
            for match in matches {
                guard let fullRange = Range(match.range, in: text),
                      let labelRange = Range(match.range(at: 1), in: text),
                      let valueRange = Range(match.range(at: 2), in: text) else { continue }

                let label = String(text[labelRange])
                let value = String(text[valueRange])

                // 기존 라벨 확인
                if db.secureLabelExists(label) {
                    return BadgeProcessResult(
                        text: text,
                        error: "라벨 '\(label)'이(가) 이미 존재합니다.",
                        errorRange: match.range
                    )
                }

                // 암호화 및 저장
                guard let encrypted = secureManager.encrypt(value) else {
                    return BadgeProcessResult(text: text, error: "암호화 실패", errorRange: match.range)
                }
                db.insertSecureValue(id: encrypted.refId, encryptedValue: encrypted.encrypted,
                                    keyVersion: encrypted.keyVersion, label: label)

                text.replaceSubrange(fullRange, with: "`secure@\(encrypted.refId)`")
            }
        }

        // 2. {secure#label} 또는 [secure#label] (기존 참조)
        let labelOnlyPattern = "(?:\\{|\\[)secure#([^:}\\]]+)(?:\\}|\\])"
        if let regex = try? NSRegularExpression(pattern: labelOnlyPattern) {
            let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text)).reversed()
            for match in matches {
                guard let fullRange = Range(match.range, in: text),
                      let labelRange = Range(match.range(at: 1), in: text) else { continue }

                let label = String(text[labelRange])

                if let existingId = db.getSecureIdByLabel(label) {
                    text.replaceSubrange(fullRange, with: "`secure@\(existingId)`")
                } else {
                    return BadgeProcessResult(
                        text: text,
                        error: "라벨 '\(label)'을(를) 찾을 수 없습니다.",
                        errorRange: match.range
                    )
                }
            }
        }

        // 3. {secure:value} 또는 [secure:value] (라벨 없이)
        let valueOnlyPattern = "(?:\\{|\\[)secure:([^}\\]]+)(?:\\}|\\])"
        if let regex = try? NSRegularExpression(pattern: valueOnlyPattern) {
            let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text)).reversed()
            for match in matches {
                guard let fullRange = Range(match.range, in: text),
                      let valueRange = Range(match.range(at: 1), in: text) else { continue }

                let value = String(text[valueRange])

                guard let encrypted = secureManager.encrypt(value) else {
                    return BadgeProcessResult(text: text, error: "암호화 실패", errorRange: match.range)
                }
                db.insertSecureValue(id: encrypted.refId, encryptedValue: encrypted.encrypted,
                                    keyVersion: encrypted.keyVersion, label: nil)

                text.replaceSubrange(fullRange, with: "`secure@\(encrypted.refId)`")
            }
        }

        return BadgeProcessResult(text: text)
    }

    // MARK: - Var 패턴 처리

    private func processVarPatterns(_ text: inout String) -> BadgeProcessResult {
        // 1. {var#label:value} 또는 [var#label:value]
        let labelValuePattern = "(?:\\{|\\[)var#([^:}\\]]+):([^}\\]]+)(?:\\}|\\])"
        if let regex = try? NSRegularExpression(pattern: labelValuePattern) {
            let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text)).reversed()
            for match in matches {
                guard let fullRange = Range(match.range, in: text),
                      let labelRange = Range(match.range(at: 1), in: text),
                      let valueRange = Range(match.range(at: 2), in: text) else { continue }

                let label = String(text[labelRange])
                let value = String(text[valueRange])

                // 기존 라벨 확인
                if db.variableLabelExists(label) {
                    return BadgeProcessResult(
                        text: text,
                        error: "변수 라벨 '\(label)'이(가) 이미 존재합니다.",
                        errorRange: match.range
                    )
                }

                // 저장
                let varId = db.generateVariableId()
                db.insertVariable(id: varId, value: value, label: label)

                text.replaceSubrange(fullRange, with: "`var@\(varId)`")
            }
        }

        // 2. {var#label} 또는 [var#label] (기존 참조)
        let labelOnlyPattern = "(?:\\{|\\[)var#([^:}\\]]+)(?:\\}|\\])"
        if let regex = try? NSRegularExpression(pattern: labelOnlyPattern) {
            let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text)).reversed()
            for match in matches {
                guard let fullRange = Range(match.range, in: text),
                      let labelRange = Range(match.range(at: 1), in: text) else { continue }

                let label = String(text[labelRange])

                if let existingId = db.getVariableIdByLabel(label) {
                    text.replaceSubrange(fullRange, with: "`var@\(existingId)`")
                } else {
                    return BadgeProcessResult(
                        text: text,
                        error: "변수 '\(label)'을(를) 찾을 수 없습니다.",
                        errorRange: match.range
                    )
                }
            }
        }

        return BadgeProcessResult(text: text)
    }

    // MARK: - Command 패턴 처리

    private func processCommandPatterns(_ text: inout String) -> BadgeProcessResult {
        // {command#label} 또는 [command#label] (기존 참조만)
        let labelOnlyPattern = "(?:\\{|\\[)command#([^:}\\]]+)(?:\\}|\\])"
        if let regex = try? NSRegularExpression(pattern: labelOnlyPattern) {
            let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text)).reversed()
            for match in matches {
                guard let fullRange = Range(match.range, in: text),
                      let labelRange = Range(match.range(at: 1), in: text) else { continue }

                let label = String(text[labelRange])

                if let existingId = db.getCommandIdByLabel(label) {
                    text.replaceSubrange(fullRange, with: "`command@\(existingId)`")
                } else {
                    return BadgeProcessResult(
                        text: text,
                        error: "명령어 '\(label)'을(를) 찾을 수 없습니다.",
                        errorRange: match.range
                    )
                }
            }
        }

        return BadgeProcessResult(text: text)
    }

    // MARK: - 실행 형식 변환

    /// 실행 전 처리: `type@id` → 실제 값으로 치환
    func resolveForExecution(_ text: String) -> String {
        var result = text

        // `type@id` 또는 `type@id|path` 패턴
        let pattern = "`(secure|command|var)@([^`|]+)(?:\\|([^`]+))?`"
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return result
        }

        let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text)).reversed()

        for match in matches {
            guard let fullRange = Range(match.range, in: result),
                  let typeRange = Range(match.range(at: 1), in: result),
                  let idRange = Range(match.range(at: 2), in: result) else { continue }

            let typeStr = String(result[typeRange])
            let id = String(result[idRange])
            let jsonPath: String? = match.numberOfRanges > 3
                ? Range(match.range(at: 3), in: result).map { String(result[$0]) }
                : nil

            guard let type = BadgeType(rawValue: typeStr) else { continue }

            if let value = resolveValue(type: type, id: id, jsonPath: jsonPath) {
                result.replaceSubrange(fullRange, with: value)
            }
        }

        return result
    }

    /// 타입별 값 해석
    private func resolveValue(type: BadgeType, id: String, jsonPath: String?) -> String? {
        switch type {
        case .secure:
            return SecureValueManager.shared.decrypt(refId: id)

        case .variable:
            return db.getVariableValueById(id)

        case .command:
            // command는 마지막 실행 결과 사용
            if let response = db.getCommandLastResponse(id) {
                if let path = jsonPath, !path.isEmpty {
                    return extractJsonValue(from: response, path: path)
                }
                return response
            }
            return nil
        }
    }

    /// JSON path로 값 추출
    private func extractJsonValue(from jsonString: String, path: String) -> String? {
        guard let data = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) else { return nil }

        let parts = path.components(separatedBy: ".")
        var current: Any = json

        for part in parts {
            if let bracketRange = part.range(of: "["), let endBracket = part.range(of: "]") {
                let key = String(part[..<bracketRange.lowerBound])
                let indexStr = String(part[bracketRange.upperBound..<endBracket.lowerBound])
                guard let index = Int(indexStr),
                      let dict = current as? [String: Any] else { return nil }
                let arraySource: Any? = key.isEmpty ? current : dict[key]
                guard let array = arraySource as? [Any],
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

    // MARK: - 배지 표시 변환

    /// 텍스트를 배지로 변환 (NSMutableAttributedString)
    func convertToBadges(in attributedString: NSMutableAttributedString) {
        let text = attributedString.string

        // `type@id` 또는 `type@id|path` 패턴
        let pattern = "`(secure|command|var)@([^`]+)`"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return }

        let matches = regex.matches(in: text, range: NSRange(location: 0, length: text.utf16.count)).reversed()

        for match in matches {
            guard let typeRange = Range(match.range(at: 1), in: text),
                  let rawIdRange = Range(match.range(at: 2), in: text) else { continue }

            let typeStr = String(text[typeRange])
            let rawId = String(text[rawIdRange])

            guard let type = BadgeType(rawValue: typeStr) else { continue }

            // ID에서 path 분리
            let (pureId, jsonPath) = parseIdWithPath(rawId)

            // 라벨 조회
            let label = lookupLabel(type: type, id: pureId)

            // 원본 텍스트
            let originalText = "`\(typeStr)@\(rawId)`"

            // 배지 생성
            let attachment = BadgeTextAttachment(
                type: type,
                refId: pureId,
                label: label,
                originalText: originalText,
                jsonPath: jsonPath
            )

            let attachmentString = NSAttributedString(attachment: attachment)
            attributedString.replaceCharacters(in: match.range, with: attachmentString)
        }
    }

    /// 배지에서 텍스트로 변환 (저장용)
    func convertToText(from attributedString: NSAttributedString) -> String {
        var result = ""
        attributedString.enumerateAttributes(in: NSRange(location: 0, length: attributedString.length)) { attrs, range, _ in
            if let attachment = attrs[.attachment] as? BadgeTextAttachment {
                result += attachment.originalText
            } else {
                result += attributedString.attributedSubstring(from: range).string
            }
        }
        return result
    }

    // MARK: - 자동완성 제안

    /// 타입별 제안 목록 조회
    func getSuggestions(for type: BadgeType, isIdHint: Bool, filter: String) -> [String] {
        let maxSuggestions = 10

        if isIdHint {
            // ID 목록
            let allIds: [String]
            switch type {
            case .secure:
                allIds = SecureValueManager.shared.getAllRefIds()
            case .command:
                allIds = db.loadCommands().filter { !$0.isInTrash }.map { $0.id }
            case .variable:
                allIds = db.getAllVariableIds()
            }

            let filtered = allIds.filter { id in
                filter.isEmpty || id.lowercased().hasPrefix(filter.lowercased())
            }.prefix(maxSuggestions)
            return Array(filtered)
        } else {
            // 라벨 목록
            let allLabels: [String]
            switch type {
            case .secure:
                allLabels = SecureValueManager.shared.getAllLabels()
            case .command:
                allLabels = db.loadCommands().filter { !$0.isInTrash }.compactMap {
                    $0.label.isEmpty ? nil : $0.label
                }
            case .variable:
                allLabels = db.getAllVariableLabels()
            }

            let filtered = allLabels.filter { label in
                filter.isEmpty || label.lowercased().contains(filter.lowercased())
            }.prefix(maxSuggestions)
            return Array(filtered)
        }
    }

    /// command용 제안 (id, title 쌍)
    func getCommandSuggestions(filter: String) -> [(id: String, title: String)] {
        let commands = db.loadCommands().filter { !$0.isInTrash }
        let filtered = commands.filter { cmd in
            filter.isEmpty || cmd.label.lowercased().contains(filter.lowercased())
        }.prefix(10)
        return filtered.map { ($0.id, $0.label) }
    }

    // MARK: - 헬퍼 메서드

    /// 라벨 조회
    func lookupLabel(type: BadgeType, id: String) -> String? {
        switch type {
        case .secure: return db.getSecureLabelById(id)
        case .command: return db.getCommandLabelById(id)
        case .variable: return db.getVariableLabelById(id)
        }
    }

    /// 라벨로 ID 조회
    func lookupIdByLabel(type: BadgeType, label: String) -> String? {
        switch type {
        case .secure: return db.getSecureIdByLabel(label)
        case .command: return db.getCommandIdByLabel(label)
        case .variable: return db.getVariableIdByLabel(label)
        }
    }

    /// ID에서 path 분리
    func parseIdWithPath(_ rawId: String) -> (id: String, path: String?) {
        if rawId.contains("|") {
            let parts = rawId.split(separator: "|", maxSplits: 1)
            return (String(parts[0]), parts.count > 1 ? String(parts[1]) : nil)
        }
        return (rawId, nil)
    }

    /// 트리거에서 배지 타입 추출
    func detectBadgeType(from trigger: String) -> BadgeType? {
        for type in [BadgeType.secure, .command, .variable] {
            if trigger.contains(type.rawValue) {
                return type
            }
        }
        return nil
    }

    /// 트리거가 ID 힌트(@)인지 확인
    func isIdTrigger(_ trigger: String) -> Bool {
        trigger.contains("@")
    }

    // MARK: - 자동완성 트리거 감지

    /// 트리거 정보
    struct TriggerInfo {
        let type: BadgeType
        let trigger: String      // 원본 트리거 문자열 ({command:, [var#, 등)
        let filter: String       // 트리거 이후 입력된 필터 텍스트
        let isIdHint: Bool       // @ 트리거 여부
        let triggerStart: Int    // 트리거 시작 위치
    }

    /// 커서 위치에서 배지 트리거 감지
    func detectBadgeTrigger(in text: String, cursorPosition: Int) -> TriggerInfo? {
        guard cursorPosition > 0, cursorPosition <= text.count else { return nil }

        let index = text.index(text.startIndex, offsetBy: cursorPosition)
        let beforeCursor = String(text[..<index])

        // 모든 배지 타입 검사
        for type in [BadgeType.command, .variable, .secure] {
            let allTriggers = Self.triggers(for: type)

            for trigger in allTriggers {
                if let range = beforeCursor.range(of: trigger, options: .backwards) {
                    let afterTrigger = String(beforeCursor[range.upperBound...])
                    let endChar = trigger.hasPrefix("{") ? "}" : "]"

                    // 트리거가 닫히지 않았고, 공백이 없으면 활성 트리거
                    let containsEnd = afterTrigger.contains(endChar)
                    let containsWhitespace = afterTrigger.contains(where: { $0.isWhitespace })

                    // secure는 공백 허용 (값 입력 때문)
                    let isValid = type == .secure
                        ? !containsEnd
                        : !containsEnd && !containsWhitespace

                    if isValid {
                        let triggerStart = text.distance(from: text.startIndex, to: range.lowerBound)
                        return TriggerInfo(
                            type: type,
                            trigger: trigger,
                            filter: afterTrigger,
                            isIdHint: trigger.contains("@"),
                            triggerStart: triggerStart
                        )
                    }
                }
            }
        }

        return nil
    }

    /// 제안 선택 시 대체 텍스트 생성
    /// 모든 타입을 `type@id` 형식으로 반환하여 즉시 배지로 표시
    func buildReplacement(for triggerInfo: TriggerInfo, suggestion: String, commandId: String? = nil) -> String {
        let type = triggerInfo.type

        // command는 항상 `command@id` 형식
        if type == .command {
            guard let id = commandId else { return "" }
            return "`command@\(id)`"
        }

        // var/secure: ID 조회 후 `type@id` 형식 반환
        if triggerInfo.isIdHint {
            // @로 ID 직접 입력한 경우
            return "`\(type.rawValue)@\(suggestion)`"
        } else {
            // #으로 라벨 입력한 경우 → ID 조회
            if let id = lookupIdByLabel(type: type, label: suggestion) {
                return "`\(type.rawValue)@\(id)`"
            }
            // ID 없으면 괄호 형식 유지 (저장 시 convertToStorageFormat에서 변환됨)
            let closingBracket = triggerInfo.trigger.hasPrefix("{") ? "}" : "]"
            let openingBracket = triggerInfo.trigger.hasPrefix("{") ? "{" : "["
            return "\(openingBracket)\(type.rawValue)#\(suggestion)\(closingBracket)"
        }
    }
}
