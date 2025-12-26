import AppKit

/// 배지 타입
enum BadgeType: String {
    case secure = "secure"
    case command = "command"
    case variable = "var"

    var color: NSColor {
        switch self {
        case .secure: return .systemPink
        case .command: return .systemBlue
        case .variable: return .systemGreen
        }
    }

    var prefix: String {
        return rawValue
    }
}

/// 배지 텍스트 첨부 - 라운드 박스 형태로 표시
class BadgeTextAttachment: NSTextAttachment {
    let badgeType: BadgeType
    let refId: String          // 참조 ID (항상 저장)
    let labelText: String?     // 라벨 (있으면 표시용)
    let originalText: String   // 원본 텍스트 (저장용): `type@id` 또는 `type@id|path`
    let jsonPath: String?      // JSON path (command만 해당)

    /// 표시 텍스트: type#label (path 있으면 type#label|path)
    var displayText: String {
        let label = labelText ?? refId
        if let path = jsonPath, !path.isEmpty {
            return "\(badgeType.prefix)#\(label)|\(path)"
        }
        return "\(badgeType.prefix)#\(label)"
    }

    init(type: BadgeType, refId: String, label: String?, originalText: String, jsonPath: String? = nil) {
        self.badgeType = type
        self.refId = refId
        self.labelText = label
        self.originalText = originalText
        // jsonPath: 직접 전달되거나 originalText에서 파싱
        if let path = jsonPath {
            self.jsonPath = path
        } else if originalText.contains("|") {
            let parts = originalText.dropFirst().dropLast().split(separator: "|", maxSplits: 1)
            self.jsonPath = parts.count > 1 ? String(parts[1]) : nil
        } else {
            self.jsonPath = nil
        }
        super.init(data: nil, ofType: nil)

        // 이미지를 미리 생성하여 설정
        let img = createBadgeImage()
        self.image = img

        // 수직 중앙 정렬을 위한 bounds 설정 (baseline 기준)
        let font = NSFont.systemFont(ofSize: NSFont.systemFontSize)
        let lineHeight = font.ascender - font.descender
        let yOffset = font.descender + (lineHeight - img.size.height) / 2
        self.bounds = CGRect(x: 0, y: yOffset, width: img.size.width, height: img.size.height)

        // 삼각형 버튼 등 기본 UI 비활성화
        self.attachmentCell = nil
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// 배지 이미지 생성
    private func createBadgeImage() -> NSImage {
        let font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
        let textSize = displayText.size(withAttributes: [.font: font])
        let padding: CGFloat = 8
        let height: CGFloat = font.ascender - font.descender + 4
        let imageSize = NSSize(width: textSize.width + padding, height: height)

        let image = NSImage(size: imageSize, flipped: false) { rect in
            // 배경 (라운드 박스)
            let bgRect = NSRect(x: 1, y: 1, width: rect.width - 2, height: rect.height - 2)
            let bgPath = NSBezierPath(roundedRect: bgRect, xRadius: 4, yRadius: 4)
            self.badgeType.color.withAlphaComponent(0.2).setFill()
            bgPath.fill()

            // 테두리
            self.badgeType.color.withAlphaComponent(0.5).setStroke()
            bgPath.lineWidth = 1
            bgPath.stroke()

            // 텍스트
            let textRect = NSRect(x: 4, y: 2, width: rect.width - 8, height: rect.height - 4)
            let attributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: self.badgeType.color
            ]
            self.displayText.draw(in: textRect, withAttributes: attributes)

            return true
        }
        return image
    }
}

/// 배지 유틸리티
struct BadgeUtils {
    /// {secure#label:value} 형식 - 라벨과 값 캡처
    private static let secureInputPattern = "\\{secure#([^:}]+):([^}]+)\\}"

    /// 지원 문법 생성 함수
    /// - `type@id` (백틱)
    /// - {type@id} (중괄호)
    /// - [type@id] (대괄호)
    private static func patterns(for typeStr: String) -> [String] {
        return [
            "`\(typeStr)@([^`]+)`",           // `type@id`
            "\\{\(typeStr)@([^}]+)\\}",       // {type@id}
            "\\[\(typeStr)@([^\\]]+)\\]"      // [type@id]
        ]
    }

    /// 텍스트에서 배지로 변환 (표시용)
    static func convertToBadges(in attributedString: NSMutableAttributedString) {
        let db = Database.shared

        // {secure#label:value} 형식 먼저 처리 (새로 저장하거나 기존 참조)
        convertSecureInput(in: attributedString)

        // 각 type에 대해 모든 문법 패턴 처리
        let typeConfigs: [(typeStr: String, type: BadgeType, lookup: (String) -> String?)] = [
            ("secure", .secure, { db.getSecureLabelById($0) }),
            ("command", .command, { db.getCommandLabelById($0) }),
            ("var", .variable, { db.getVariableLabelById($0) })
        ]

        for config in typeConfigs {
            for pattern in patterns(for: config.typeStr) {
                convertPattern(pattern, type: config.type, in: attributedString, labelLookup: config.lookup)
            }
        }
    }

    /// 문자열에서 `type@id` 형식을 [label] 형식으로 변환 (표시용)
    static func convertToDisplayString(_ text: String) -> String {
        let db = Database.shared
        var result = text

        // `secure@id` → [label]
        if let regex = try? NSRegularExpression(pattern: "`secure@([^`]+)`") {
            let matches = regex.matches(in: result, range: NSRange(result.startIndex..., in: result)).reversed()
            for match in matches {
                guard let fullRange = Range(match.range, in: result),
                      let idRange = Range(match.range(at: 1), in: result) else { continue }
                let id = String(result[idRange])
                let label = db.getSecureLabelById(id) ?? id
                result.replaceSubrange(fullRange, with: "[\(label)]")
            }
        }

        // `command@id` → [label]
        if let regex = try? NSRegularExpression(pattern: "`command@([^`]+)`") {
            let matches = regex.matches(in: result, range: NSRange(result.startIndex..., in: result)).reversed()
            for match in matches {
                guard let fullRange = Range(match.range, in: result),
                      let idRange = Range(match.range(at: 1), in: result) else { continue }
                let id = String(result[idRange])
                let label = db.getCommandLabelById(id) ?? id
                result.replaceSubrange(fullRange, with: "[\(label)]")
            }
        }

        // `var@id` → [label]
        if let regex = try? NSRegularExpression(pattern: "`var@([^`]+)`") {
            let matches = regex.matches(in: result, range: NSRange(result.startIndex..., in: result)).reversed()
            for match in matches {
                guard let fullRange = Range(match.range, in: result),
                      let idRange = Range(match.range(at: 1), in: result) else { continue }
                let id = String(result[idRange])
                let label = db.getVariableLabelById(id) ?? id
                result.replaceSubrange(fullRange, with: "[\(label)]")
            }
        }

        return result
    }

    /// 문자열에서 {secure#label:value} 형식을 `secure@id` 로 변환 (저장용)
    static func convertSecureInputInString(_ text: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: secureInputPattern) else { return text }
        let db = Database.shared

        var result = text
        let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text)).reversed()

        for match in matches {
            guard let fullRange = Range(match.range, in: result),
                  let labelRange = Range(match.range(at: 1), in: result),
                  let valueRange = Range(match.range(at: 2), in: result) else { continue }

            let label = String(result[labelRange])
            let value = String(result[valueRange])

            // 라벨로 기존 secure 찾기, 없으면 새로 저장
            let secureId: String
            if let existingId = db.getSecureIdByLabel(label) {
                secureId = existingId
            } else {
                // 새로 암호화하고 저장
                guard let encResult = SecureValueManager.shared.encrypt(value) else { continue }
                db.insertSecureValue(id: encResult.refId, encryptedValue: encResult.encrypted, keyVersion: encResult.keyVersion, label: label)
                secureId = encResult.refId
            }

            result.replaceSubrange(fullRange, with: "`secure@\(secureId)`")
        }
        return result
    }

    /// {secure#label:value} 형식 처리
    private static func convertSecureInput(in attributedString: NSMutableAttributedString) {
        guard let regex = try? NSRegularExpression(pattern: secureInputPattern) else { return }
        let db = Database.shared

        let text = attributedString.string
        let fullRange = NSRange(location: 0, length: text.utf16.count)
        let matches = regex.matches(in: text, range: fullRange).reversed()

        for match in matches {
            guard let labelRange = Range(match.range(at: 1), in: text),
                  let valueRange = Range(match.range(at: 2), in: text) else { continue }

            let label = String(text[labelRange])
            let value = String(text[valueRange])

            // 라벨로 기존 secure 찾기, 없으면 새로 저장
            let secureId: String
            if let existingId = db.getSecureIdByLabel(label) {
                secureId = existingId
            } else {
                // 새로 암호화하고 저장
                guard let result = SecureValueManager.shared.encrypt(value) else { continue }
                db.insertSecureValue(id: result.refId, encryptedValue: result.encrypted, keyVersion: result.keyVersion, label: label)
                secureId = result.refId
            }

            let originalText = "`secure@\(secureId)`"
            let attachment = BadgeTextAttachment(type: .secure, refId: secureId, label: label, originalText: originalText)
            let attachmentString = NSAttributedString(attachment: attachment)
            attributedString.replaceCharacters(in: match.range, with: attachmentString)
        }
    }

    private static func convertPattern(_ pattern: String, type: BadgeType, in attributedString: NSMutableAttributedString, labelLookup: (String) -> String?) {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return }

        // 매번 현재 텍스트에서 매칭 (이전 변환으로 변경될 수 있음)
        let text = attributedString.string
        let fullRange = NSRange(location: 0, length: text.utf16.count)
        let matches = regex.matches(in: text, range: fullRange).reversed()

        for match in matches {
            guard let refIdRange = Range(match.range(at: 1), in: text) else { continue }
            let rawRefId = String(text[refIdRange])

            // refId에서 path 분리 (예: abc123|data.token → abc123, data.token)
            let pureId: String
            let jsonPath: String?
            if rawRefId.contains("|") {
                let parts = rawRefId.split(separator: "|", maxSplits: 1)
                pureId = String(parts[0])
                jsonPath = parts.count > 1 ? String(parts[1]) : nil
            } else {
                pureId = rawRefId
                jsonPath = nil
            }

            // originalText는 항상 `type@id` 또는 `type@id|path` 형식으로 저장
            let typeString: String
            switch type {
            case .secure: typeString = "secure"
            case .command: typeString = "command"
            case .variable: typeString = "var"
            }
            let originalText = "`\(typeString)@\(rawRefId)`"
            let label = labelLookup(pureId)

            let attachment = BadgeTextAttachment(type: type, refId: pureId, label: label, originalText: originalText, jsonPath: jsonPath)
            let attachmentString = NSAttributedString(attachment: attachment)
            attributedString.replaceCharacters(in: match.range, with: attachmentString)
        }
    }

    /// 배지에서 텍스트로 변환 (저장용): 항상 `type@id` 형태
    static func convertToText(from attributedString: NSAttributedString) -> String {
        var result = ""
        attributedString.enumerateAttributes(in: NSRange(location: 0, length: attributedString.length)) { attrs, range, _ in
            if let attachment = attrs[.attachment] as? BadgeTextAttachment {
                result += attachment.originalText  // `type@id`
            } else {
                result += attributedString.attributedSubstring(from: range).string
            }
        }
        return result
    }

    /// attributedString에 BadgeTextAttachment가 있는지 확인
    static func hasAttachments(in attributedString: NSAttributedString) -> Bool {
        var found = false
        attributedString.enumerateAttribute(.attachment, in: NSRange(location: 0, length: attributedString.length)) { value, _, stop in
            if value is BadgeTextAttachment {
                found = true
                stop.pointee = true
            }
        }
        return found
    }
}
