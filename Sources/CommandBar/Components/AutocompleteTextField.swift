import SwiftUI
import AppKit

struct AutocompleteTextField: NSViewRepresentable {
    @Binding var text: String
    let placeholder: String
    let suggestions: [String]  // $ 트리거용 (환경 변수)
    var idSuggestions: [(id: String, title: String)] = []  // {id: 트리거용

    func makeNSView(context: Context) -> NSTextField {
        let textField = AutocompleteNSTextField()
        textField.placeholderString = placeholder
        textField.delegate = context.coordinator
        textField.focusRingType = .none
        textField.isBordered = true
        textField.bezelStyle = .roundedBezel
        // 단일 라인 설정 (줄바꿈 방지)
        textField.cell?.wraps = false
        textField.cell?.isScrollable = true
        textField.usesSingleLineMode = true
        textField.allowsEditingTextAttributes = true
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
            context.coordinator.applySyntaxHighlighting(to: nsView)
        }
        context.coordinator.suggestions = suggestions
        context.coordinator.idSuggestions = idSuggestions
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, suggestions: suggestions, idSuggestions: idSuggestions)
    }

    enum TriggerType {
        case dollar       // $VAR
        case idRef        // {id:xxx}
        case uuidRef      // {uuid:xxx}
        case varRef       // {var:xxx}
        case encryptRef   // {encrypt:xxx}
        case secureRef    // {secure:xxx}
        case none
    }

    class Coordinator: NSObject, NSTextFieldDelegate {
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

        func controlTextDidChange(_ obj: Notification) {
            guard let textField = obj.object as? AutocompleteNSTextField else { return }

            // {uuid:xxx} → {id:shortId} 자동 치환
            let currentText = textField.stringValue
            if currentText.contains("{uuid:") {
                let converted = Database.shared.convertUuidToShortId(in: currentText)
                if converted != currentText {
                    if let editor = textField.currentEditor() {
                        let cursorPos = editor.selectedRange.location
                        let diff = currentText.count - converted.count
                        textField.stringValue = converted
                        editor.selectedRange = NSRange(location: max(0, cursorPos - diff), length: 0)
                    } else {
                        textField.stringValue = converted
                    }
                }
            }

            text = textField.stringValue

            // 구문 강조 적용
            applySyntaxHighlighting(to: textField)

            // 트리거 타입 감지
            let trigger = detectTrigger(in: textField)
            currentTrigger = trigger

            if trigger != .none {
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

        private func detectTrigger(in textField: NSTextField) -> TriggerType {
            guard let editor = textField.currentEditor() else { return .none }
            let cursorPosition = editor.selectedRange.location
            let text = textField.stringValue

            guard cursorPosition > 0, cursorPosition <= text.count else { return .none }

            let beforeCursor = String(text.prefix(cursorPosition))

            // {id: 트리거 체크
            if let idRange = beforeCursor.range(of: "{id:", options: .backwards) {
                let afterTrigger = String(beforeCursor[idRange.upperBound...])
                if !afterTrigger.contains("}") && !afterTrigger.contains(where: { $0.isWhitespace }) {
                    return .idRef
                }
            }

            // {uuid: 트리거 체크
            if let uuidRange = beforeCursor.range(of: "{uuid:", options: .backwards) {
                let afterTrigger = String(beforeCursor[uuidRange.upperBound...])
                if !afterTrigger.contains("}") && !afterTrigger.contains(where: { $0.isWhitespace }) {
                    return .uuidRef
                }
            }

            // {var: 트리거 체크
            if let varRange = beforeCursor.range(of: "{var:", options: .backwards) {
                let afterTrigger = String(beforeCursor[varRange.upperBound...])
                if !afterTrigger.contains("}") && !afterTrigger.contains(where: { $0.isWhitespace }) {
                    return .varRef
                }
            }

            // {encrypt: 트리거 체크
            if let encryptRange = beforeCursor.range(of: "{encrypt:", options: .backwards) {
                let afterTrigger = String(beforeCursor[encryptRange.upperBound...])
                if !afterTrigger.contains("}") {
                    return .encryptRef
                }
            }

            // {secure: 트리거 체크
            if let secureRange = beforeCursor.range(of: "{secure:", options: .backwards) {
                let afterTrigger = String(beforeCursor[secureRange.upperBound...])
                if !afterTrigger.contains("}") && !afterTrigger.contains(where: { $0.isWhitespace }) {
                    return .secureRef
                }
            }

            // $ 트리거 체크
            if let lastDollar = beforeCursor.lastIndex(of: "$") {
                let afterDollar = String(beforeCursor[text.index(after: lastDollar)...])
                if !afterDollar.contains(where: { $0.isWhitespace || "()[]{}'\"`".contains($0) }) {
                    return .dollar
                }
            }

            return .none
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

        func getSuggestionsForCursor(in textField: NSTextField) -> [String] {
            guard let editor = textField.currentEditor() else { return [] }
            let cursorPosition = editor.selectedRange.location
            let text = textField.stringValue

            guard cursorPosition > 0, cursorPosition <= text.count else { return [] }

            let beforeCursor = String(text.prefix(cursorPosition))
            let maxSuggestions = 10

            switch currentTrigger {
            case .idRef:
                // {id: 이후 입력된 문자열로 필터링
                guard let idRange = beforeCursor.range(of: "{id:", options: .backwards) else { return [] }
                let afterTrigger = String(beforeCursor[idRange.upperBound...])
                let filtered = idSuggestions.filter { item in
                    afterTrigger.isEmpty ||
                    item.id.lowercased().hasPrefix(afterTrigger.lowercased()) ||
                    item.title.lowercased().contains(afterTrigger.lowercased())
                }.prefix(maxSuggestions)
                return filtered.map { "\($0.id): \($0.title)" }

            case .uuidRef:
                // {uuid: 이후 입력된 문자열로 필터링 (UUID로 표시)
                guard let uuidRange = beforeCursor.range(of: "{uuid:", options: .backwards) else { return [] }
                let afterTrigger = String(beforeCursor[uuidRange.upperBound...])
                // Database에서 전체 shortId 목록 가져오기
                let allShortIds = Database.shared.getAllShortIds()
                let filtered = allShortIds.filter { item in
                    afterTrigger.isEmpty ||
                    item.fullId.lowercased().hasPrefix(afterTrigger.lowercased()) ||
                    item.shortId.lowercased().hasPrefix(afterTrigger.lowercased())
                }.prefix(maxSuggestions)
                return filtered.map { "\($0.fullId): \($0.shortId)" }

            case .varRef:
                // {var: 이후 입력된 문자열로 필터링 (환경 변수)
                guard let varRange = beforeCursor.range(of: "{var:", options: .backwards) else { return [] }
                let afterTrigger = String(beforeCursor[varRange.upperBound...])
                let filtered = suggestions.filter { suggestion in
                    afterTrigger.isEmpty || suggestion.lowercased().hasPrefix(afterTrigger.lowercased())
                }.prefix(maxSuggestions)
                return Array(filtered)

            case .dollar:
                guard let lastDollar = beforeCursor.lastIndex(of: "$") else { return [] }
                let afterDollar = String(beforeCursor[text.index(after: lastDollar)...])
                if afterDollar.contains(where: { $0.isWhitespace || "()[]{}'\"`".contains($0) }) {
                    return []
                }
                let filtered = suggestions.filter { suggestion in
                    afterDollar.isEmpty || suggestion.lowercased().hasPrefix(afterDollar.lowercased())
                }.prefix(maxSuggestions)
                return Array(filtered)

            case .encryptRef:
                // {encrypt:는 사용자가 직접 입력하므로 자동완성 없음
                return []

            case .secureRef:
                // {secure: 이후 입력된 문자열로 필터링 (기존 secure value ID 목록)
                guard let secureRange = beforeCursor.range(of: "{secure:", options: .backwards) else { return [] }
                let afterTrigger = String(beforeCursor[secureRange.upperBound...])
                let allSecureIds = SecureValueManager.shared.getAllRefIds()
                let filtered = allSecureIds.filter { refId in
                    afterTrigger.isEmpty || refId.lowercased().hasPrefix(afterTrigger.lowercased())
                }.prefix(maxSuggestions)
                return Array(filtered)

            case .none:
                return []
            }
        }

        func insertSuggestion(_ suggestion: String, into textField: NSTextField) {
            guard let editor = textField.currentEditor() else { return }
            let cursorPosition = editor.selectedRange.location
            var text = textField.stringValue
            let beforeCursor = String(text.prefix(cursorPosition))
            let afterCursor = String(text.suffix(text.count - cursorPosition))

            switch currentTrigger {
            case .idRef:
                // {id: 위치 찾기
                guard let idRange = beforeCursor.range(of: "{id:", options: .backwards) else { return }
                let triggerStart = text.distance(from: text.startIndex, to: idRange.lowerBound)
                let beforeTrigger = String(text.prefix(triggerStart))

                // suggestion에서 ID 부분만 추출 (: 전까지)
                let idPart = suggestion.split(separator: ":").first.map(String.init) ?? suggestion

                text = beforeTrigger + "{id:" + idPart + "}" + afterCursor
                textField.stringValue = text
                self.text = text

                let newCursorPosition = triggerStart + 5 + idPart.count  // {id: + id + }
                editor.selectedRange = NSRange(location: newCursorPosition, length: 0)

            case .uuidRef:
                // {uuid: 위치 찾기
                guard let uuidRange = beforeCursor.range(of: "{uuid:", options: .backwards) else { return }
                let triggerStart = text.distance(from: text.startIndex, to: uuidRange.lowerBound)
                let beforeTrigger = String(text.prefix(triggerStart))

                // suggestion에서 UUID 부분만 추출 (: 전까지)
                let uuidPart = suggestion.split(separator: ":").first.map(String.init) ?? suggestion

                text = beforeTrigger + "{uuid:" + uuidPart + "}" + afterCursor
                textField.stringValue = text
                self.text = text

                let newCursorPosition = triggerStart + 7 + uuidPart.count  // {uuid: + uuid + }
                editor.selectedRange = NSRange(location: newCursorPosition, length: 0)

            case .varRef:
                // {var: 위치 찾기
                guard let varRange = beforeCursor.range(of: "{var:", options: .backwards) else { return }
                let triggerStart = text.distance(from: text.startIndex, to: varRange.lowerBound)
                let beforeTrigger = String(text.prefix(triggerStart))

                text = beforeTrigger + "{var:" + suggestion + "}" + afterCursor
                textField.stringValue = text
                self.text = text

                let newCursorPosition = triggerStart + 6 + suggestion.count  // {var: + name + }
                editor.selectedRange = NSRange(location: newCursorPosition, length: 0)

            case .dollar:
                guard let lastDollar = beforeCursor.lastIndex(of: "$") else { return }
                let dollarPosition = text.distance(from: text.startIndex, to: lastDollar)
                let beforeDollar = String(text.prefix(dollarPosition))

                text = beforeDollar + "$" + suggestion + afterCursor
                textField.stringValue = text
                self.text = text

                let newCursorPosition = dollarPosition + 1 + suggestion.count
                editor.selectedRange = NSRange(location: newCursorPosition, length: 0)

            case .encryptRef:
                // {encrypt: 자동완성 없음 (직접 입력)
                break

            case .secureRef:
                // {secure: 위치 찾기
                guard let secureRange = beforeCursor.range(of: "{secure:", options: .backwards) else { return }
                let triggerStart = text.distance(from: text.startIndex, to: secureRange.lowerBound)
                let beforeTrigger = String(text.prefix(triggerStart))

                text = beforeTrigger + "{secure:" + suggestion + "}" + afterCursor
                textField.stringValue = text
                self.text = text

                let newCursorPosition = triggerStart + 9 + suggestion.count  // {secure: + id + }
                editor.selectedRange = NSRange(location: newCursorPosition, length: 0)

            case .none:
                break
            }

            popupController.hide()
            applySyntaxHighlighting(to: textField)
        }

        func applySyntaxHighlighting(to textField: NSTextField) {
            let text = textField.stringValue
            guard !text.isEmpty else { return }

            let attributed = NSMutableAttributedString(string: text)
            let fullRange = NSRange(location: 0, length: text.utf16.count)
            let font = NSFont.systemFont(ofSize: NSFont.systemFontSize)

            // 기본 스타일
            attributed.addAttribute(.font, value: font, range: fullRange)
            attributed.addAttribute(.foregroundColor, value: NSColor.textColor, range: fullRange)

            // {id:xxx} 패턴 강조 (파란색 + 배경)
            if let idRegex = try? NSRegularExpression(pattern: "\\{id:[^}]+\\}") {
                let matches = idRegex.matches(in: text, range: fullRange)
                for match in matches {
                    attributed.addAttribute(.foregroundColor, value: NSColor.systemBlue, range: match.range)
                    attributed.addAttribute(.backgroundColor, value: NSColor.systemBlue.withAlphaComponent(0.15), range: match.range)
                }
            }

            // {var:xxx} 패턴 강조 (보라색 + 배경)
            if let varRegex = try? NSRegularExpression(pattern: "\\{var:[^}]+\\}") {
                let matches = varRegex.matches(in: text, range: fullRange)
                for match in matches {
                    attributed.addAttribute(.foregroundColor, value: NSColor.systemPurple, range: match.range)
                    attributed.addAttribute(.backgroundColor, value: NSColor.systemPurple.withAlphaComponent(0.15), range: match.range)
                }
            }

            // $VAR 패턴 강조 (초록색)
            if let dollarRegex = try? NSRegularExpression(pattern: "\\$[A-Za-z_][A-Za-z0-9_]*") {
                let matches = dollarRegex.matches(in: text, range: fullRange)
                for match in matches {
                    attributed.addAttribute(.foregroundColor, value: NSColor.systemGreen, range: match.range)
                }
            }

            // {encrypt:xxx} 패턴 강조 (빨간색 + 배경)
            if let encryptRegex = try? NSRegularExpression(pattern: "\\{encrypt:[^}]+\\}") {
                let matches = encryptRegex.matches(in: text, range: fullRange)
                for match in matches {
                    attributed.addAttribute(.foregroundColor, value: NSColor.systemRed, range: match.range)
                    attributed.addAttribute(.backgroundColor, value: NSColor.systemRed.withAlphaComponent(0.15), range: match.range)
                }
            }

            // {secure:xxx} 패턴 강조 (핑크색 + 배경)
            if let secureRegex = try? NSRegularExpression(pattern: "\\{secure:[^}]+\\}") {
                let matches = secureRegex.matches(in: text, range: fullRange)
                for match in matches {
                    attributed.addAttribute(.foregroundColor, value: NSColor.systemPink, range: match.range)
                    attributed.addAttribute(.backgroundColor, value: NSColor.systemPink.withAlphaComponent(0.15), range: match.range)
                }
            }

            // 커서 위치 저장
            let cursorPos = textField.currentEditor()?.selectedRange.location ?? text.count

            textField.attributedStringValue = attributed

            // 커서 위치 복원
            textField.currentEditor()?.selectedRange = NSRange(location: cursorPos, length: 0)
        }
    }
}

class AutocompleteNSTextField: NSTextField {
    var suggestionProvider: (() -> [String])?
    var onSuggestionSelected: ((String) -> Void)?

    override func keyDown(with event: NSEvent) {
        // Option+S: 선택된 텍스트를 {encrypt:}로 감싸기
        if event.modifierFlags.contains(.option) && event.charactersIgnoringModifiers == "s" {
            wrapSelectionWithEncrypt()
            return
        }
        // 기본 처리를 먼저 수행하도록 delegate에게 위임
        super.keyDown(with: event)
    }

    override func menu(for event: NSEvent) -> NSMenu? {
        let menu = super.menu(for: event) ?? NSMenu()

        // 선택된 텍스트가 있을 때만 암호화 메뉴 추가
        if let editor = currentEditor(), editor.selectedRange.length > 0 {
            menu.insertItem(NSMenuItem.separator(), at: 0)
            let encryptItem = NSMenuItem(title: "암호화 ({encrypt:})", action: #selector(wrapSelectionWithEncrypt), keyEquivalent: "s")
            encryptItem.keyEquivalentModifierMask = .option
            encryptItem.target = self
            menu.insertItem(encryptItem, at: 0)
        }

        return menu
    }

    @objc func wrapSelectionWithEncrypt() {
        guard let editor = currentEditor() else { return }
        let selectedRange = editor.selectedRange

        guard selectedRange.length > 0 else { return }

        let text = stringValue
        let nsText = text as NSString
        let selectedText = nsText.substring(with: selectedRange)

        // {encrypt:선택텍스트}로 치환
        let replacement = "{encrypt:\(selectedText)}"
        let beforeSelection = nsText.substring(to: selectedRange.location)
        let afterSelection = nsText.substring(from: selectedRange.location + selectedRange.length)

        stringValue = beforeSelection + replacement + afterSelection

        // 커서를 } 뒤로 이동
        let newCursorPos = selectedRange.location + replacement.count
        editor.selectedRange = NSRange(location: newCursorPos, length: 0)

        // delegate에게 변경 알림
        if let delegate = delegate as? NSTextFieldDelegate {
            delegate.controlTextDidChange?(Notification(name: NSControl.textDidChangeNotification, object: self))
        }
    }
}
