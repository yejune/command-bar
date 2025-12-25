import SwiftUI
import AppKit

struct AutocompleteTextEditor: NSViewRepresentable {
    @Binding var text: String
    let suggestions: [String]  // $ 트리거용 (환경 변수)
    var idSuggestions: [(id: String, title: String)] = []  // {id: 트리거용
    var singleLine: Bool = false  // 한 줄 모드 (Enter 무시, 스크롤 없음)
    var placeholder: String = ""  // 플레이스홀더

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        let textView = AutocompleteNSTextView()

        textView.isRichText = true
        let fontSize: CGFloat = singleLine ? NSFont.systemFontSize : 12
        let font = singleLine ? NSFont.systemFont(ofSize: fontSize) : NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        textView.font = font
        textView.typingAttributes = [
            .font: font,
            .foregroundColor: NSColor.textColor
        ]
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.allowsUndo = true
        textView.delegate = context.coordinator
        textView.singleLineMode = singleLine
        textView.placeholderString = placeholder

        textView.suggestionProvider = { [weak textView] in
            guard let tv = textView else { return [] }
            return context.coordinator.getSuggestionsForCursor(in: tv)
        }
        textView.onSuggestionSelected = { [weak textView] suggestion in
            guard let tv = textView else { return }
            context.coordinator.insertSuggestion(suggestion, into: tv)
        }

        scrollView.documentView = textView
        scrollView.borderType = singleLine ? .bezelBorder : .noBorder
        scrollView.hasVerticalScroller = !singleLine
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true

        if singleLine {
            // 한 줄 모드: 가로 스크롤 + 커서 따라가기 (스크롤바 숨김)
            scrollView.drawsBackground = true
            scrollView.hasHorizontalScroller = false
            scrollView.hasVerticalScroller = false
            scrollView.horizontalScrollElasticity = .none

            textView.drawsBackground = true
            textView.backgroundColor = .textBackgroundColor

            // 핵심: 가로 확장 가능, 세로 고정
            textView.isVerticallyResizable = false
            textView.isHorizontallyResizable = true
            textView.autoresizingMask = [.width]

            // minSize로 최소 너비 보장, maxSize로 확장 허용
            textView.minSize = NSSize(width: 0, height: 20)
            textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: 20)

            // 텍스트 컨테이너: word wrap 비활성화
            textView.textContainer?.containerSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: 20)
            textView.textContainer?.widthTracksTextView = false
            textView.textContainer?.lineFragmentPadding = 4
            textView.textContainerInset = NSSize(width: 0, height: 3)
        } else {
            textView.minSize = NSSize(width: 0, height: 0)
            textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
            textView.isVerticallyResizable = true
            textView.isHorizontallyResizable = false
            textView.autoresizingMask = [.width]
            textView.textContainer?.containerSize = NSSize(width: scrollView.contentSize.width, height: CGFloat.greatestFiniteMagnitude)
            textView.textContainer?.widthTracksTextView = true
        }

        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? AutocompleteNSTextView else { return }
        if textView.string != text {
            textView.string = text
        }
        context.coordinator.suggestions = suggestions
        context.coordinator.idSuggestions = idSuggestions

        // 구문 강조 적용
        context.coordinator.applySyntaxHighlighting(to: textView)

        if singleLine {
            // singleLine 모드: minSize로 최소 너비 보장
            let minWidth = nsView.contentSize.width
            textView.minSize = NSSize(width: minWidth, height: 20)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, suggestions: suggestions, idSuggestions: idSuggestions)
    }

    enum TriggerType {
        case dollar       // $VAR
        case idRef        // {id:xxx}
        case uuidRef      // {uuid:xxx}
        case varRef       // {var:xxx}
        case secureRef    // {secure:xxx} - 입력용
        case lockedRef    // {🔒:#xxx} - 저장된 형태
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

            // singleLine 모드: 커서 위치로 스크롤
            if textView.singleLineMode {
                textView.scrollRangeToVisible(textView.selectedRange())
            }

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

        func textViewDidChangeSelection(_ notification: Notification) {
            guard let textView = notification.object as? AutocompleteNSTextView else { return }

            // {🔒:id} 블록 내부에 커서가 있으면 전체 선택
            let selectedRange = textView.selectedRange()
            if selectedRange.length == 0 {
                if let blockRange = findLockedBlockAt(position: selectedRange.location, in: textView.string) {
                    textView.setSelectedRange(blockRange)
                    return
                }
            }

            // singleLine 모드: 커서 이동 시 스크롤
            if textView.singleLineMode {
                textView.scrollRangeToVisible(textView.selectedRange())
            }
        }

        /// {🔒:id} 블록을 찾음
        private func findLockedBlockAt(position: Int, in text: String) -> NSRange? {
            guard let regex = try? NSRegularExpression(pattern: "\\{🔒:[^}]+\\}") else { return nil }
            let fullRange = NSRange(location: 0, length: text.utf16.count)
            let matches = regex.matches(in: text, range: fullRange)

            for match in matches {
                // 커서가 블록 내부에 있는지 확인 (시작과 끝 제외)
                if position > match.range.location && position < match.range.location + match.range.length {
                    return match.range
                }
            }
            return nil
        }

        /// {🔒:id} 블록 편집 방지
        func textView(_ textView: NSTextView, shouldChangeTextIn affectedCharRange: NSRange, replacementString: String?) -> Bool {
            let text = textView.string
            guard let regex = try? NSRegularExpression(pattern: "\\{🔒:[^}]+\\}") else { return true }
            let fullRange = NSRange(location: 0, length: text.utf16.count)
            let matches = regex.matches(in: text, range: fullRange)

            for match in matches {
                let blockStart = match.range.location
                let blockEnd = match.range.location + match.range.length

                // 블록 전체 삭제는 허용
                if affectedCharRange.location <= blockStart && affectedCharRange.location + affectedCharRange.length >= blockEnd {
                    continue
                }

                // 블록 내부 편집은 거부
                if affectedCharRange.location > blockStart && affectedCharRange.location < blockEnd {
                    return false
                }
                if affectedCharRange.location + affectedCharRange.length > blockStart && affectedCharRange.location + affectedCharRange.length < blockEnd {
                    return false
                }
            }
            return true
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

            // {secure:xxx} 패턴 강조 (빨간색 + 배경) - 저장 전 입력 형태
            if let secureInputRegex = try? NSRegularExpression(pattern: "\\{secure:[^}]+\\}") {
                let matches = secureInputRegex.matches(in: text, range: fullRange)
                for match in matches {
                    textStorage.addAttribute(.foregroundColor, value: NSColor.systemRed, range: match.range)
                    textStorage.addAttribute(.backgroundColor, value: NSColor.systemRed.withAlphaComponent(0.15), range: match.range)
                }
            }

            // {🔒:xxx} 패턴 강조 (핑크색 + 배경) - 저장된 형태
            if let secureRegex = try? NSRegularExpression(pattern: "\\{🔒:[^}]+\\}") {
                let matches = secureRegex.matches(in: text, range: fullRange)
                for match in matches {
                    textStorage.addAttribute(.foregroundColor, value: NSColor.systemPink, range: match.range)
                    textStorage.addAttribute(.backgroundColor, value: NSColor.systemPink.withAlphaComponent(0.15), range: match.range)
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

            // {secure: 트리거 체크
            if let secureRange = beforeCursor.range(of: "{secure:", options: .backwards) {
                let afterTrigger = String(beforeCursor[secureRange.upperBound...])
                if !afterTrigger.contains("}") {
                    return .secureRef
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

            case .uuidRef:
                guard let uuidRange = beforeCursor.range(of: "{uuid:", options: .backwards) else { return [] }
                let afterTrigger = String(beforeCursor[uuidRange.upperBound...])
                let allShortIds = Database.shared.getAllShortIds()
                let filtered = allShortIds.filter { item in
                    afterTrigger.isEmpty ||
                    item.fullId.lowercased().hasPrefix(afterTrigger.lowercased()) ||
                    item.shortId.lowercased().hasPrefix(afterTrigger.lowercased())
                }.prefix(maxSuggestions)
                return filtered.map { "\($0.fullId): \($0.shortId)" }

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

            case .secureRef:
                // {secure: 이후 기존 라벨 목록 자동완성
                let allLabels = SecureValueManager.shared.getAllLabels()
                guard let secureRange = beforeCursor.range(of: "{secure:", options: .backwards) else { return [] }
                let afterTrigger = String(beforeCursor[secureRange.upperBound...])
                let filtered = allLabels.filter { label in
                    afterTrigger.isEmpty || label.lowercased().hasPrefix(afterTrigger.lowercased())
                }.prefix(maxSuggestions)
                return Array(filtered)

            case .lockedRef:
                return []

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

            case .uuidRef:
                guard let uuidRange = beforeCursor.range(of: "{uuid:", options: .backwards) else { return }
                let triggerStart = text.distance(from: text.startIndex, to: uuidRange.lowerBound)
                let beforeTrigger = String(text.prefix(triggerStart))
                let uuidPart = suggestion.split(separator: ":").first.map(String.init) ?? suggestion
                let newText = beforeTrigger + "{uuid:" + uuidPart + "}" + afterCursor
                textView.string = newText
                self.text = newText
                let newCursorPosition = triggerStart + 7 + uuidPart.count
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

            case .secureRef:
                // {secure: → {🔒:라벨} 형태로 변환 (기존 라벨 선택 시)
                guard let secureRange = beforeCursor.range(of: "{secure:", options: .backwards) else { return }
                let triggerStart = text.distance(from: text.startIndex, to: secureRange.lowerBound)
                let beforeTrigger = String(text.prefix(triggerStart))
                let newText = beforeTrigger + "{🔒:\(suggestion)}" + afterCursor
                textView.string = newText
                self.text = newText
                let newCursorPosition = triggerStart + 4 + suggestion.count  // {🔒: + label + }
                textView.setSelectedRange(NSRange(location: newCursorPosition, length: 0))

            case .lockedRef:
                break

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
    var singleLineMode: Bool = false
    var placeholderString: String = ""

    override func keyDown(with event: NSEvent) {
        // Option+S: 선택된 텍스트를 {secure:}로 감싸기
        if event.modifierFlags.contains(.option) && event.charactersIgnoringModifiers == "s" {
            wrapSelectionWithSecure()
            return
        }
        // 한 줄 모드에서 Enter 무시
        if singleLineMode && event.keyCode == 36 {  // Return key
            return
        }
        super.keyDown(with: event)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        // 플레이스홀더 그리기
        if string.isEmpty && !placeholderString.isEmpty {
            let attrs: [NSAttributedString.Key: Any] = [
                .foregroundColor: NSColor.placeholderTextColor,
                .font: font ?? NSFont.systemFont(ofSize: NSFont.systemFontSize)
            ]
            let placeholderRect = bounds.insetBy(dx: textContainerInset.width + 5, dy: textContainerInset.height)
            placeholderString.draw(in: placeholderRect, withAttributes: attrs)
        }
    }

    override var needsDisplay: Bool {
        didSet {
            if string.isEmpty { super.needsDisplay = true }
        }
    }

    override func willOpenMenu(_ menu: NSMenu, with event: NSEvent) {
        // 기존 암호화 메뉴 제거 (중복 방지)
        menu.items.filter { $0.title.contains("암호화") }.forEach { menu.removeItem($0) }

        let range = selectedRange()
        let isEnabled = range.length > 0 && !isInsideSecureBlock(range)

        // 암호화 메뉴 추가
        let secureItem = NSMenuItem(title: "암호화", action: #selector(wrapSelectionWithSecure), keyEquivalent: "")
        secureItem.target = self
        secureItem.isEnabled = isEnabled

        menu.insertItem(secureItem, at: 0)
        menu.insertItem(NSMenuItem.separator(), at: 1)

        super.willOpenMenu(menu, with: event)
    }

    private func isInsideSecureBlock(_ range: NSRange) -> Bool {
        let text = string
        guard !text.isEmpty else { return false }

        // {secure:...} 또는 {🔒:...} 패턴 찾기
        let patterns = ["\\{secure:[^}]*\\}", "\\{🔒:[^}]*\\}"]
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern) {
                let matches = regex.matches(in: text, range: NSRange(location: 0, length: text.utf16.count))
                for match in matches {
                    let blockStart = match.range.location
                    let blockEnd = match.range.location + match.range.length
                    if range.location >= blockStart && range.location + range.length <= blockEnd {
                        return true
                    }
                }
            }
        }
        return false
    }

    @objc func wrapSelectionWithSecure() {
        let selectedRange = self.selectedRange()
        guard selectedRange.length > 0 else { return }

        let nsText = string as NSString
        let selectedText = nsText.substring(with: selectedRange)

        // {secure:선택텍스트}로 치환
        let replacement = "{secure:\(selectedText)}"

        if shouldChangeText(in: selectedRange, replacementString: replacement) {
            replaceCharacters(in: selectedRange, with: replacement)
            didChangeText()

            let newCursorPos = selectedRange.location + replacement.count
            setSelectedRange(NSRange(location: newCursorPos, length: 0))
        }
    }
}
