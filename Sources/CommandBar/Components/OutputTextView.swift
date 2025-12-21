import SwiftUI
import AppKit

// 효율적인 텍스트 뷰 (NSTextView 래퍼)
struct OutputTextView: NSViewRepresentable {
    let text: String

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

        textView.string = text

        // 맨 아래로 스크롤
        if shouldScroll {
            textView.scrollToEndOfDocument(nil)
        }
    }
}
