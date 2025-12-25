import AppKit

/// 배지 타입
enum BadgeType: String {
    case secure = "secure"
    case id = "id"
    case variable = "var"

    var color: NSColor {
        switch self {
        case .secure: return .systemPink
        case .id: return .systemBlue
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
    let label: String
    let originalText: String  // 원본 텍스트 (저장용)

    init(type: BadgeType, label: String, originalText: String) {
        self.badgeType = type
        self.label = label
        self.originalText = originalText
        super.init(data: nil, ofType: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func attachmentBounds(for textContainer: NSTextContainer?, proposedLineFragment lineFrag: CGRect, glyphPosition position: CGPoint, characterIndex charIndex: Int) -> CGRect {
        let font = NSFont.systemFont(ofSize: NSFont.systemFontSize)
        let displayText = "[\(badgeType.prefix)#\(label)]"
        let size = displayText.size(withAttributes: [.font: font])
        let padding: CGFloat = 8
        let height: CGFloat = font.ascender - font.descender + 4
        return CGRect(x: 0, y: font.descender - 2, width: size.width + padding, height: height)
    }

    override func image(forBounds imageBounds: CGRect, textContainer: NSTextContainer?, characterIndex charIndex: Int) -> NSImage? {
        let image = NSImage(size: imageBounds.size)
        image.lockFocus()

        let font = NSFont.systemFont(ofSize: NSFont.systemFontSize)
        let displayText = "[\(badgeType.prefix)#\(label)]"

        // 배경 (라운드 박스)
        let bgRect = NSRect(x: 1, y: 1, width: imageBounds.width - 2, height: imageBounds.height - 2)
        let bgPath = NSBezierPath(roundedRect: bgRect, xRadius: 4, yRadius: 4)
        badgeType.color.withAlphaComponent(0.2).setFill()
        bgPath.fill()

        // 테두리
        badgeType.color.withAlphaComponent(0.5).setStroke()
        bgPath.lineWidth = 1
        bgPath.stroke()

        // 텍스트
        let textRect = NSRect(x: 4, y: 2, width: imageBounds.width - 8, height: imageBounds.height - 4)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: badgeType.color
        ]
        displayText.draw(in: textRect, withAttributes: attributes)

        image.unlockFocus()
        return image
    }
}

/// 배지 유틸리티
struct BadgeUtils {
    /// 패턴 정의 (쉽게 변경 가능)
    static let securePattern = "\\{🔒:([^}]+)\\}"
    static let idPattern = "\\{id:([^}]+)\\}"
    static let varPattern = "\\{var:([^}]+)\\}"

    /// 텍스트에서 배지로 변환 (표시용)
    static func convertToBadges(in attributedString: NSMutableAttributedString) {
        let text = attributedString.string

        // secure 배지
        convertPattern(securePattern, type: .secure, in: attributedString, text: text)
        // id 배지
        convertPattern(idPattern, type: .id, in: attributedString, text: text)
        // var 배지
        convertPattern(varPattern, type: .variable, in: attributedString, text: text)
    }

    private static func convertPattern(_ pattern: String, type: BadgeType, in attributedString: NSMutableAttributedString, text: String) {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return }
        let fullRange = NSRange(location: 0, length: text.utf16.count)
        let matches = regex.matches(in: text, range: fullRange).reversed()

        for match in matches {
            guard let labelRange = Range(match.range(at: 1), in: text) else { continue }
            let label = String(text[labelRange])
            let originalText = (text as NSString).substring(with: match.range)

            let attachment = BadgeTextAttachment(type: type, label: label, originalText: originalText)
            let attachmentString = NSAttributedString(attachment: attachment)
            attributedString.replaceCharacters(in: match.range, with: attachmentString)
        }
    }

    /// 배지에서 텍스트로 변환 (저장용)
    static func convertToText(from attributedString: NSAttributedString) -> String {
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
}
