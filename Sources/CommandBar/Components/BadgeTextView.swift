import SwiftUI

/// 백틱 패턴을 배지로 표시하는 SwiftUI 뷰
struct BadgeTextView: View {
    let text: String
    var font: Font = .caption.monospaced()
    var foregroundColor: Color = .secondary

    var body: some View {
        HStack(spacing: 2) {
            ForEach(Array(parseText().enumerated()), id: \.offset) { _, segment in
                if let badge = segment.badge {
                    BadgeView(type: badge.type, id: badge.id)
                } else {
                    Text(segment.text)
                        .font(font)
                        .foregroundStyle(foregroundColor)
                }
            }
        }
    }

    struct TextSegment {
        let text: String
        let badge: BadgeInfo?

        struct BadgeInfo {
            let type: String  // secure, id, var
            let id: String
        }
    }

    func parseText() -> [TextSegment] {
        var segments: [TextSegment] = []
        var remaining = text

        // 백틱 패턴: `type@id` 또는 `type#label`
        let pattern = "`(secure|page|var)[@#]([^`]+)`"
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return [TextSegment(text: text, badge: nil)]
        }

        while !remaining.isEmpty {
            let range = NSRange(remaining.startIndex..., in: remaining)
            if let match = regex.firstMatch(in: remaining, range: range),
               let fullRange = Range(match.range, in: remaining),
               let typeRange = Range(match.range(at: 1), in: remaining),
               let idRange = Range(match.range(at: 2), in: remaining) {

                // 매칭 전 텍스트
                let beforeText = String(remaining[remaining.startIndex..<fullRange.lowerBound])
                if !beforeText.isEmpty {
                    segments.append(TextSegment(text: beforeText, badge: nil))
                }

                // 배지
                let type = String(remaining[typeRange])
                let id = String(remaining[idRange])
                segments.append(TextSegment(text: "", badge: .init(type: type, id: id)))

                // 나머지
                remaining = String(remaining[fullRange.upperBound...])
            } else {
                // 더 이상 매칭 없음
                segments.append(TextSegment(text: remaining, badge: nil))
                break
            }
        }

        return segments
    }
}

/// 개별 배지 뷰
struct BadgeView: View {
    let type: String
    let id: String

    var color: Color {
        switch type {
        case "secure": return .pink
        case "page": return .blue
        case "var": return .green
        default: return .gray
        }
    }

    /// 표시할 텍스트 (라벨 있으면 #label, 없으면 @id)
    var displayText: String {
        let db = Database.shared
        switch type {
        case "secure":
            if let label = db.getSecureLabelById(id) {
                return "\(type)#\(label)"
            }
        case "page":
            if let label = db.getCommandLabelByShortId(id) {
                return "\(type)#\(label)"
            }
        case "var":
            if let label = db.getVariableLabelById(id) {
                return "\(type)#\(label)"
            }
        default:
            break
        }
        return "\(type)@\(id)"
    }

    var body: some View {
        Text(displayText)
            .font(.caption2.monospaced())
            .padding(.horizontal, 4)
            .padding(.vertical, 1)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .overlay(
                RoundedRectangle(cornerRadius: 3)
                    .stroke(color.opacity(0.4), lineWidth: 1)
            )
            .cornerRadius(3)
    }
}
