import SwiftUI
import AppKit

// 효율적인 텍스트 뷰 (NSTextView 래퍼)
struct OutputTextView: NSViewRepresentable {
    let text: String

    /// 유니코드 이스케이프 시퀀스 디코딩 (\uXXXX → 한글)
    private var decodedText: String {
        // \uXXXX 패턴을 찾아서 유니코드로 변환
        var result = text
        let pattern = "\\\\u([0-9a-fA-F]{4})"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return text }

        let matches = regex.matches(in: result, range: NSRange(result.startIndex..., in: result)).reversed()
        for match in matches {
            guard let hexRange = Range(match.range(at: 1), in: result),
                  let fullRange = Range(match.range, in: result),
                  let codePoint = UInt32(String(result[hexRange]), radix: 16),
                  let scalar = Unicode.Scalar(codePoint) else { continue }
            result.replaceSubrange(fullRange, with: String(Character(scalar)))
        }
        return result
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        scrollView.drawsBackground = false
        scrollView.backgroundColor = .clear
        scrollView.contentInsets = NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        scrollView.scrollerInsets = NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        let textView = scrollView.documentView as! NSTextView
        textView.isEditable = false
        textView.isSelectable = true
        textView.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        textView.backgroundColor = .clear
        textView.drawsBackground = false
        textView.textColor = NSColor.labelColor
        textView.textContainerInset = .zero
        textView.textContainer?.lineFragmentPadding = 0
        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        let textView = nsView.documentView as! NSTextView
        let shouldScroll = textView.visibleRect.maxY >= textView.bounds.maxY - 20

        textView.string = decodedText

        // 맨 아래로 스크롤
        if shouldScroll {
            textView.scrollToEndOfDocument(nil)
        }
    }
}
