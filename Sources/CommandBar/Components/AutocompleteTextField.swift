import SwiftUI
import AppKit

struct AutocompleteTextField: NSViewRepresentable {
    @Binding var text: String
    let placeholder: String
    let suggestions: [String]

    func makeNSView(context: Context) -> NSTextField {
        let textField = AutocompleteNSTextField()
        textField.placeholderString = placeholder
        textField.delegate = context.coordinator
        textField.focusRingType = .none
        textField.isBordered = true
        textField.bezelStyle = .roundedBezel
        textField.suggestionProvider = { [weak textField] in
            guard let field = textField else { return [] }
            return context.coordinator.getSuggestionsForCursor(in: field)
        }
        textField.onSuggestionSelected = { [weak textField] suggestion in
            guard let field = textField else { return }
            context.coordinator.insertSuggestion(suggestion, into: field)
        }
        return textField
    }

    func updateNSView(_ nsView: NSTextField, context: Context) {
        if nsView.stringValue != text {
            nsView.stringValue = text
        }
        context.coordinator.suggestions = suggestions
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, suggestions: suggestions)
    }

    class Coordinator: NSObject, NSTextFieldDelegate {
        @Binding var text: String
        var suggestions: [String]
        private let popupController = SuggestionPopupController()

        init(text: Binding<String>, suggestions: [String]) {
            self._text = text
            self.suggestions = suggestions
        }

        func controlTextDidChange(_ obj: Notification) {
            guard let textField = obj.object as? AutocompleteNSTextField else { return }
            text = textField.stringValue

            // 커서 위치에서 $ 체크
            if shouldShowSuggestions(in: textField) {
                let filtered = getSuggestionsForCursor(in: textField)
                if !filtered.isEmpty {
                    popupController.show(
                        relativeTo: textField,
                        suggestions: filtered,
                        onSelect: { [weak self] suggestion in
                            self?.insertSuggestion(suggestion, into: textField)
                        }
                    )
                } else {
                    popupController.hide()
                }
            } else {
                popupController.hide()
            }
        }

        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if popupController.isVisible {
                switch commandSelector {
                case #selector(NSResponder.moveUp(_:)):
                    popupController.moveSelectionUp()
                    return true
                case #selector(NSResponder.moveDown(_:)):
                    popupController.moveSelectionDown()
                    return true
                case #selector(NSResponder.insertNewline(_:)), #selector(NSResponder.insertTab(_:)):
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

        private func shouldShowSuggestions(in textField: NSTextField) -> Bool {
            guard let editor = textField.currentEditor() else { return false }
            let cursorPosition = editor.selectedRange.location
            let text = textField.stringValue

            guard cursorPosition > 0, cursorPosition <= text.count else { return false }

            let index = text.index(text.startIndex, offsetBy: cursorPosition - 1)
            let charBeforeCursor = text[index]

            // $ 바로 입력했거나, $로 시작하는 단어 중간
            if charBeforeCursor == "$" {
                return true
            }

            // $ 이후 단어 입력 중
            let startIndex = text.startIndex
            let beforeCursor = String(text[startIndex..<text.index(text.startIndex, offsetBy: cursorPosition)])
            if let lastDollar = beforeCursor.lastIndex(of: "$") {
                let afterDollar = String(beforeCursor[text.index(after: lastDollar)...])
                // $ 이후 공백이나 특수문자 없으면 계속 자동완성
                return !afterDollar.contains(where: { $0.isWhitespace || "()[]{}'\"`".contains($0) })
            }

            return false
        }

        func getSuggestionsForCursor(in textField: NSTextField) -> [String] {
            guard let editor = textField.currentEditor() else { return [] }
            let cursorPosition = editor.selectedRange.location
            let text = textField.stringValue

            guard cursorPosition > 0, cursorPosition <= text.count else { return [] }

            let beforeCursor = String(text.prefix(cursorPosition))
            guard let lastDollar = beforeCursor.lastIndex(of: "$") else { return [] }

            let afterDollar = String(beforeCursor[text.index(after: lastDollar)...])

            // $ 이후 공백이나 특수문자 있으면 필터링 중단
            if afterDollar.contains(where: { $0.isWhitespace || "()[]{}'\"`".contains($0) }) {
                return []
            }

            // 필터링: afterDollar로 시작하는 항목만
            return suggestions.filter { suggestion in
                afterDollar.isEmpty || suggestion.lowercased().hasPrefix(afterDollar.lowercased())
            }
        }

        func insertSuggestion(_ suggestion: String, into textField: NSTextField) {
            guard let editor = textField.currentEditor() else { return }
            let cursorPosition = editor.selectedRange.location
            var text = textField.stringValue

            // $ 위치 찾기
            let beforeCursor = String(text.prefix(cursorPosition))
            guard let lastDollar = beforeCursor.lastIndex(of: "$") else { return }

            let dollarPosition = text.distance(from: text.startIndex, to: lastDollar)

            // $부터 커서까지 제거하고 $suggestion 삽입
            let beforeDollar = String(text.prefix(dollarPosition))
            let afterCursor = String(text.suffix(text.count - cursorPosition))

            text = beforeDollar + "$" + suggestion + afterCursor
            textField.stringValue = text
            self.text = text

            // 커서를 삽입한 변수명 끝으로 이동
            let newCursorPosition = dollarPosition + 1 + suggestion.count
            editor.selectedRange = NSRange(location: newCursorPosition, length: 0)

            popupController.hide()
        }
    }
}

class AutocompleteNSTextField: NSTextField {
    var suggestionProvider: (() -> [String])?
    var onSuggestionSelected: ((String) -> Void)?

    override func keyDown(with event: NSEvent) {
        // 기본 처리를 먼저 수행하도록 delegate에게 위임
        super.keyDown(with: event)
    }
}
