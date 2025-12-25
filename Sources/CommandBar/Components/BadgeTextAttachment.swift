import AppKit

/// 배지 타입
enum BadgeType: String {
    case secure = "secure"
    case page = "page"
    case variable = "var"

    var color: NSColor {
        switch self {
        case .secure: return .systemPink
        case .page: return .systemBlue
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
    let originalText: String   // 원본 텍스트 (저장용): `type@id`

    /// 표시 텍스트: 라벨 있으면 #label, 없으면 @id
    var displayText: String {
        if let label = labelText {
            return "\(badgeType.prefix)#\(label)"
        }
        return "\(badgeType.prefix)@\(refId)"
    }

    init(type: BadgeType, refId: String, label: String?, originalText: String) {
        self.badgeType = type
        self.refId = refId
        self.labelText = label
        self.originalText = originalText
        super.init(data: nil, ofType: nil)

        // 이미지를 미리 생성하여 설정
        let img = createBadgeImage()
        self.image = img

        // 수직 중앙 정렬을 위한 bounds 설정 (baseline 기준)
        let font = NSFont.systemFont(ofSize: NSFont.systemFontSize)
        let lineHeight = font.ascender - font.descender
        let yOffset = font.descender + (lineHeight - img.size.height) / 2
        self.bounds = CGRect(x: 0, y: yOffset, width: img.size.width, height: img.size.height)
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
    /// 패턴 정의: 저장 형식 `type@id`
    static let securePattern = "`secure@([^`]+)`"
    static let pagePattern = "`page@([^`]+)`"
    static let varPattern = "`var@([^`]+)`"

    /// 텍스트에서 배지로 변환 (표시용)
    static func convertToBadges(in attributedString: NSMutableAttributedString) {
        let db = Database.shared

        // secure 배지 (라벨 조회)
        convertPattern(securePattern, type: .secure, in: attributedString) { refId in
            db.getSecureLabelById(refId)
        }
        // page 배지 (라벨 조회)
        convertPattern(pagePattern, type: .page, in: attributedString) { refId in
            db.getCommandLabelByShortId(refId)
        }
        // var 배지 (라벨 조회)
        convertPattern(varPattern, type: .variable, in: attributedString) { refId in
            db.getVariableLabelById(refId)
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
            let refId = String(text[refIdRange])
            let originalText = (text as NSString).substring(with: match.range)
            let label = labelLookup(refId)

            let attachment = BadgeTextAttachment(type: type, refId: refId, label: label, originalText: originalText)
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
