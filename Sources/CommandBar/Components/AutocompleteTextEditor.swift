import SwiftUI
import AppKit

struct AutocompleteTextEditor: NSViewRepresentable {
    @Binding var text: String
    let suggestions: [String]  // $ 트리거용 (환경 변수)
    var idSuggestions: [(id: String, title: String)] = []  // {id: 트리거용

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        let textView = AutocompleteNSTextView()

        textView.isRichText = true
        textView.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        textView.typingAttributes = [
            .font: NSFont.monospacedSystemFont(ofSize: 12, weight: .regular),
            .foregroundColor: NSColor.textColor
        ]
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.delegate = context.coordinator

        textView.suggestionProvider = { [weak textView] in
            guard let tv = textView else { return [] }
            return context.coordinator.getSuggestionsForCursor(in: tv)
        }
        textView.onSuggestionSelected = { [weak textView] suggestion in
            guard let tv = textView else { return }
            context.coordinator.insertSuggestion(suggestion, into: tv)
        }

        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true

        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.containerSize = NSSize(width: scrollView.contentSize.width, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true

        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? NSTextView else { return }
        if textView.string != text {
            textView.string = text
        }
        context.coordinator.suggestions = suggestions
        context.coordinator.idSuggestions = idSuggestions
        // 구문 강조 적용
        context.coordinator.applySyntaxHighlighting(to: textView)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, suggestions: suggestions, idSuggestions: idSuggestions)
    }

    enum TriggerType {
        case dollar       // $VAR
        case idRef        // {id:xxx}
        case varRef       // {var:xxx}
        case none
    }

    class Coordinator: NSObject, NSTextViewDelegate {
        @Binding var text: String
        var suggestions: [String]
        var idSuggestions: [(id: String, title: String)]
        private let popupController = SuggestionPopupController()
        private var currentTrigger: TriggerType = .none

        init(text: Binding<String>, suggestions: [String], idSuggestions: [(id: String, title: String)]) {
            self._text = text
            self.suggestions = suggestions
            self.idSuggestions = idSuggestions
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? AutocompleteNSTextView else { return }

            // {uuid:xxx} → {id:shortId} 자동 치환
            let currentText = textView.string
            if currentText.contains("{uuid:") {
                let converted = Database.shared.convertUuidToShortId(in: currentText)
                if converted != currentText {
                    let cursorPos = textView.selectedRange().location
                    let diff = currentText.count - converted.count
                    textView.string = converted
                    textView.setSelectedRange(NSRange(location: max(0, cursorPos - diff), length: 0))
                }
            }

            text = textView.string

            // 구문 강조 적용
            applySyntaxHighlighting(to: textView)

            // 트리거 타입 감지
            let trigger = detectTrigger(in: textView)
            currentTrigger = trigger

            if trigger != .none {
                let filtered = getSuggestionsForCursor(in: textView)
                if !filtered.isEmpty {
                    popupController.show(
                        relativeTo: textView,
                        suggestions: filtered,
                        onSelect: { [weak self] suggestion in
                            self?.insertSuggestion(suggestion, into: textView)
                        }
                    )
                } else {
                    popupController.hide()
                }
            } else {
                popupController.hide()
            }
        }

        func applySyntaxHighlighting(to textView: NSTextView) {
            guard let textStorage = textView.textStorage else { return }
            let text = textView.string
            guard !text.isEmpty else { return }

            let fullRange = NSRange(location: 0, length: text.utf16.count)
            let selectedRange = textView.selectedRange()

            textStorage.beginEditing()

            // 기본 스타일 적용
            textStorage.addAttribute(.foregroundColor, value: NSColor.textColor, range: fullRange)
            textStorage.removeAttribute(.backgroundColor, range: fullRange)

            // {id:xxx} 패턴 강조 (파란색)
            if let idRegex = try? NSRegularExpression(pattern: "\\{id:[^}]+\\}") {
                let matches = idRegex.matches(in: text, range: fullRange)
                for match in matches {
                    textStorage.addAttribute(.foregroundColor, value: NSColor.systemBlue, range: match.range)
                    textStorage.addAttribute(.backgroundColor, value: NSColor.systemBlue.withAlphaComponent(0.15), range: match.range)
                }
            }

            // {var:xxx} 패턴 강조 (보라색)
            if let varRegex = try? NSRegularExpression(pattern: "\\{var:[^}]+\\}") {
                let matches = varRegex.matches(in: text, range: fullRange)
                for match in matches {
                    textStorage.addAttribute(.foregroundColor, value: NSColor.systemPurple, range: match.range)
                    textStorage.addAttribute(.backgroundColor, value: NSColor.systemPurple.withAlphaComponent(0.15), range: match.range)
                }
            }

            // $VAR 패턴 강조 (초록색)
            if let dollarRegex = try? NSRegularExpression(pattern: "\\$[A-Za-z_][A-Za-z0-9_]*") {
                let matches = dollarRegex.matches(in: text, range: fullRange)
                for match in matches {
                    textStorage.addAttribute(.foregroundColor, value: NSColor.systemGreen, range: match.range)
                }
            }

            textStorage.endEditing()

            // 커서 위치 복원
            textView.setSelectedRange(selectedRange)
        }

        private func detectTrigger(in textView: NSTextView) -> TriggerType {
            let cursorPosition = textView.selectedRange().location
            let text = textView.string

            guard cursorPosition > 0, cursorPosition <= text.count else { return .none }

            let index = text.index(text.startIndex, offsetBy: cursorPosition)
            let beforeCursor = String(text[..<index])

            // {id: 트리거 체크
            if let idRange = beforeCursor.range(of: "{id:", options: .backwards) {
                let afterTrigger = String(beforeCursor[idRange.upperBound...])
                if !afterTrigger.contains("}") && !afterTrigger.contains(where: { $0.isWhitespace }) {
                    return .idRef
                }
            }

            // {var: 트리거 체크
            if let varRange = beforeCursor.range(of: "{var:", options: .backwards) {
                let afterTrigger = String(beforeCursor[varRange.upperBound...])
                if !afterTrigger.contains("}") && !afterTrigger.contains(where: { $0.isWhitespace }) {
                    return .varRef
                }
            }

            // $ 트리거 체크
            if let lastDollar = beforeCursor.lastIndex(of: "$") {
                let afterDollar = String(beforeCursor[beforeCursor.index(after: lastDollar)...])
                if !afterDollar.contains(where: { $0.isWhitespace || "()[]{}'\"`".contains($0) }) {
                    return .dollar
                }
            }

            return .none
        }

        func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if popupController.isVisible {
                switch commandSelector {
                case #selector(NSResponder.moveUp(_:)):
                    popupController.moveSelectionUp()
                    return true
                case #selector(NSResponder.moveDown(_:)):
                    popupController.moveSelectionDown()
                    return true
                case #selector(NSResponder.insertTab(_:)):
                    popupController.selectCurrent()
                    return true
                case #selector(NSResponder.cancelOperation(_:)):
                    popupController.hide()
                    return true
                default:
                    break
                }
            }
            return false
        }

        func getSuggestionsForCursor(in textView: NSTextView) -> [String] {
            let cursorPosition = textView.selectedRange().location
            let text = textView.string

            guard cursorPosition > 0, cursorPosition <= text.count else { return [] }

            let index = text.index(text.startIndex, offsetBy: cursorPosition)
            let beforeCursor = String(text[..<index])
            let maxSuggestions = 10

            switch currentTrigger {
            case .idRef:
                guard let idRange = beforeCursor.range(of: "{id:", options: .backwards) else { return [] }
                let afterTrigger = String(beforeCursor[idRange.upperBound...])
                let filtered = idSuggestions.filter { item in
                    afterTrigger.isEmpty ||
                    item.id.lowercased().hasPrefix(afterTrigger.lowercased()) ||
                    item.title.lowercased().contains(afterTrigger.lowercased())
                }.prefix(maxSuggestions)
                return filtered.map { "\($0.id): \($0.title)" }

            case .varRef:
                guard let varRange = beforeCursor.range(of: "{var:", options: .backwards) else { return [] }
                let afterTrigger = String(beforeCursor[varRange.upperBound...])
                let filtered = suggestions.filter { suggestion in
                    afterTrigger.isEmpty || suggestion.lowercased().hasPrefix(afterTrigger.lowercased())
                }.prefix(maxSuggestions)
                return Array(filtered)

            case .dollar:
                guard let lastDollar = beforeCursor.lastIndex(of: "$") else { return [] }
                let afterDollar = String(beforeCursor[beforeCursor.index(after: lastDollar)...])
                if afterDollar.contains(where: { $0.isWhitespace || "()[]{}'\"`".contains($0) }) {
                    return []
                }
                let filtered = suggestions.filter { suggestion in
                    afterDollar.isEmpty || suggestion.lowercased().hasPrefix(afterDollar.lowercased())
                }.prefix(maxSuggestions)
                return Array(filtered)

            case .none:
                return []
            }
        }

        func insertSuggestion(_ suggestion: String, into textView: NSTextView) {
            let cursorPosition = textView.selectedRange().location
            let text = textView.string

            guard cursorPosition > 0, cursorPosition <= text.count else { return }

            let index = text.index(text.startIndex, offsetBy: cursorPosition)
            let beforeCursor = String(text[..<index])
            let afterCursor = String(text[index...])

            switch currentTrigger {
            case .idRef:
                guard let idRange = beforeCursor.range(of: "{id:", options: .backwards) else { return }
                let triggerStart = text.distance(from: text.startIndex, to: idRange.lowerBound)
                let beforeTrigger = String(text.prefix(triggerStart))
                let idPart = suggestion.split(separator: ":").first.map(String.init) ?? suggestion
                let newText = beforeTrigger + "{id:" + idPart + "}" + afterCursor
                textView.string = newText
                self.text = newText
                let newCursorPosition = triggerStart + 5 + idPart.count
                textView.setSelectedRange(NSRange(location: newCursorPosition, length: 0))

            case .varRef:
                guard let varRange = beforeCursor.range(of: "{var:", options: .backwards) else { return }
                let triggerStart = text.distance(from: text.startIndex, to: varRange.lowerBound)
                let beforeTrigger = String(text.prefix(triggerStart))
                let newText = beforeTrigger + "{var:" + suggestion + "}" + afterCursor
                textView.string = newText
                self.text = newText
                let newCursorPosition = triggerStart + 6 + suggestion.count
                textView.setSelectedRange(NSRange(location: newCursorPosition, length: 0))

            case .dollar:
                guard let lastDollar = beforeCursor.lastIndex(of: "$") else { return }
                let dollarPosition = text.distance(from: text.startIndex, to: lastDollar)
                let beforeDollar = String(text.prefix(dollarPosition))
                let newText = beforeDollar + "$" + suggestion + afterCursor
                textView.string = newText
                self.text = newText
                let newCursorPosition = dollarPosition + 1 + suggestion.count
                textView.setSelectedRange(NSRange(location: newCursorPosition, length: 0))

            case .none:
                break
            }

            popupController.hide()
            // 삽입 후 구문 강조 적용
            applySyntaxHighlighting(to: textView)
        }
    }
}

// MARK: - Custom NSTextView for Autocomplete
class AutocompleteNSTextView: NSTextView {
    var suggestionProvider: (() -> [String])?
    var onSuggestionSelected: ((String) -> Void)?
}
