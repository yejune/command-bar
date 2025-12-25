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

        context.coordinator.suggestions = suggestions
        context.coordinator.idSuggestions = idSuggestions

        // 현재 plain text와 비교 (badge 변환 전)
        let currentPlainText = BadgeUtils.convertToText(from: textView.attributedString())

        // 현재 텍스트뷰에 변환되지 않은 백틱 패턴이 있는지 확인
        let displayedText = textView.string
        let hasUnconvertedInView = displayedText.contains("`secure@") || displayedText.contains("`page@") || displayedText.contains("`var@")

        // 텍스트가 다르거나 변환되지 않은 패턴이 있으면 업데이트
        if currentPlainText != text || hasUnconvertedInView {
            let fontSize: CGFloat = singleLine ? NSFont.systemFontSize : 12
            let font = singleLine ? NSFont.systemFont(ofSize: fontSize) : NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
            let attrString = NSMutableAttributedString(string: text, attributes: [
                .font: font,
                .foregroundColor: NSColor.textColor
            ])

            // 배지 패턴을 NSTextAttachment로 변환
            BadgeUtils.convertToBadges(in: attrString)

            // 커서 위치 저장
            let cursorPos = textView.selectedRange().location

            textView.textStorage?.setAttributedString(attrString)

            // 커서 위치 복원 (범위 내)
            let newPos = min(cursorPos, attrString.length)
            textView.setSelectedRange(NSRange(location: newPos, length: 0))
        }

        // 구문 강조 적용 (attachment 제외)
        context.coordinator.applySyntaxHighlighting(to: textView)

        if singleLine {
            let minWidth = nsView.contentSize.width
            textView.minSize = NSSize(width: minWidth, height: 20)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, suggestions: suggestions, idSuggestions: idSuggestions)
    }

    enum TriggerType {
        case dollar       // $VAR
        case pageRef      // {page:xxx} 또는 {page#label}
        case varRef       // {var:xxx}
        case secureRef    // {secure:xxx} - 입력용
        case lockedRef    // {secure:xxx} - 저장된 형태
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

        // NSTextAttachment 기반 배지 시스템 사용 (BadgeUtils)

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

            // attributedString에서 원본 텍스트 추출하여 바인딩 업데이트
            let storageText = BadgeUtils.convertToText(from: textView.attributedString())
            text = storageText

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

            // 화살표 키로 이동 중이면 자동 선택 건너뛰기
            if textView.isArrowKeyMoving {
                textView.isArrowKeyMoving = false
                return
            }

            // 배지 블록 내부에 커서가 있으면 전체 선택
            let selectedRange = textView.selectedRange()
            if selectedRange.length == 0 {
                if let blockRange = findBadgeBlockAt(position: selectedRange.location, in: textView) {
                    textView.setSelectedRange(blockRange)
                    return
                }
            }

            // singleLine 모드: 커서 이동 시 스크롤
            if textView.singleLineMode {
                textView.scrollRangeToVisible(textView.selectedRange())
            }
        }

        /// NSTextAttachment 위치에서 배지 블록 찾기 (NSTextAttachment는 단일 문자)
        /// 커서가 attachment 위에 있을 때만 반환 (바로 뒤에 있을 때는 nil)
        private func findBadgeBlockAt(position: Int, in textView: NSTextView) -> NSRange? {
            guard let textStorage = textView.textStorage else { return nil }
            let length = textStorage.length
            guard position >= 0 && position < length else { return nil }

            // 현재 위치가 attachment인지 확인
            let attrs = textStorage.attributes(at: position, effectiveRange: nil)
            if attrs[.attachment] is BadgeTextAttachment {
                return NSRange(location: position, length: 1)
            }
            return nil
        }

        /// NSTextAttachment 보호 - attachment는 단일 문자로 처리되어 자동 보호됨
        func textView(_ textView: NSTextView, shouldChangeTextIn affectedCharRange: NSRange, replacementString: String?) -> Bool {
            // NSTextAttachment는 단일 replacement 문자(\u{FFFC})로 표현되어
            // 부분 편집이 불가능하므로 별도 보호 로직 불필요
            return true
        }

        func applySyntaxHighlighting(to textView: NSTextView) {
            guard let textStorage = textView.textStorage else { return }
            let text = textView.string
            guard !text.isEmpty else { return }

            let fullRange = NSRange(location: 0, length: text.utf16.count)
            let selectedRange = textView.selectedRange()

            // attachment 위치 수집 (덮어쓰지 않기 위해)
            var attachmentPositions = Set<Int>()
            textStorage.enumerateAttribute(.attachment, in: fullRange) { value, range, _ in
                if value != nil {
                    for i in range.location..<(range.location + range.length) {
                        attachmentPositions.insert(i)
                    }
                }
            }

            textStorage.beginEditing()

            // 기본 스타일 적용 (attachment 위치 제외)
            let font = textView.font ?? NSFont.systemFont(ofSize: NSFont.systemFontSize)
            for i in 0..<text.utf16.count {
                if !attachmentPositions.contains(i) {
                    let range = NSRange(location: i, length: 1)
                    textStorage.addAttribute(.foregroundColor, value: NSColor.textColor, range: range)
                    textStorage.addAttribute(.font, value: font, range: range)
                    textStorage.removeAttribute(.backgroundColor, range: range)
                }
            }

            // $VAR 패턴 강조 (초록색) - 입력용
            if let dollarRegex = try? NSRegularExpression(pattern: "\\$[A-Za-z_][A-Za-z0-9_]*") {
                let matches = dollarRegex.matches(in: text, range: fullRange)
                for match in matches {
                    textStorage.addAttribute(.foregroundColor, value: NSColor.systemGreen, range: match.range)
                }
            }

            // 입력 패턴 강조: {secure:xxx}, {page:xxx}, {var:xxx} 등
            let inputPatterns: [(pattern: String, color: NSColor)] = [
                ("\\{secure[#:]?[^}]*\\}", .systemPink),
                ("\\{page[#:]?[^}]*\\}", .systemBlue),
                ("\\{var[#:]?[^}]*\\}", .systemGreen)
            ]
            for (pattern, color) in inputPatterns {
                if let regex = try? NSRegularExpression(pattern: pattern) {
                    let matches = regex.matches(in: text, range: fullRange)
                    for match in matches {
                        textStorage.addAttribute(.foregroundColor, value: color, range: match.range)
                        textStorage.addAttribute(.backgroundColor, value: color.withAlphaComponent(0.15), range: match.range)
                    }
                }
            }

            // NSTextAttachment는 이미 배지 스타일이 적용되어 있음 (BadgeTextAttachment)

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

            // {page: 또는 {page# 트리거 체크
            let pageTriggers = ["{page:", "{page#"]
            for trigger in pageTriggers {
                if let pageRange = beforeCursor.range(of: trigger, options: .backwards) {
                    let afterTrigger = String(beforeCursor[pageRange.upperBound...])
                    if !afterTrigger.contains("}") && !afterTrigger.contains(where: { $0.isWhitespace }) {
                        return .pageRef
                    }
                }
            }

            // {var: 또는 [var@ 또는 [var# 트리거 체크
            let varTriggers = ["{var:", "[var@", "[var#"]
            for trigger in varTriggers {
                if let varRange = beforeCursor.range(of: trigger, options: .backwards) {
                    let afterTrigger = String(beforeCursor[varRange.upperBound...])
                    let endChars = trigger.hasPrefix("{") ? "}" : "]"
                    if !afterTrigger.contains(endChars) && !afterTrigger.contains(where: { $0.isWhitespace }) {
                        return .varRef
                    }
                }
            }

            // {secure: 또는 [secure@ 또는 [secure# 트리거 체크
            let secureTriggers = ["{secure:", "[secure@", "[secure#"]
            for trigger in secureTriggers {
                if let secureRange = beforeCursor.range(of: trigger, options: .backwards) {
                    let afterTrigger = String(beforeCursor[secureRange.upperBound...])
                    let endChars = trigger.hasPrefix("{") ? "}" : "]"
                    if !afterTrigger.contains(endChars) {
                        return .secureRef
                    }
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
                case #selector(NSResponder.insertTab(_:)),
                     #selector(NSResponder.insertNewline(_:)):  // Enter 키 추가
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
            case .pageRef:
                // {page: 또는 {page# 찾기
                let pageTriggers = ["{page:", "{page#"]
                var afterTrigger = ""
                for trigger in pageTriggers {
                    if let range = beforeCursor.range(of: trigger, options: .backwards) {
                        afterTrigger = String(beforeCursor[range.upperBound...])
                        break
                    }
                }
                // idSuggestions에서 라벨(title)로 필터링
                let filtered = idSuggestions.filter { item in
                    afterTrigger.isEmpty ||
                    item.title.lowercased().contains(afterTrigger.lowercased())
                }.prefix(maxSuggestions)
                return filtered.map { $0.title }  // 라벨만 반환

            case .varRef:
                // {var: 또는 [var@ 또는 [var# 찾기
                var afterTrigger = ""
                var isIdHint = false  // @는 ID, #는 라벨

                if let range = beforeCursor.range(of: "[var@", options: .backwards) {
                    afterTrigger = String(beforeCursor[range.upperBound...])
                    isIdHint = true
                } else if let range = beforeCursor.range(of: "[var#", options: .backwards) {
                    afterTrigger = String(beforeCursor[range.upperBound...])
                    isIdHint = false
                } else if let range = beforeCursor.range(of: "{var:", options: .backwards) {
                    afterTrigger = String(beforeCursor[range.upperBound...])
                    isIdHint = false  // 기본은 라벨
                }

                if isIdHint {
                    // ID 목록 조회
                    let allVarIds = Database.shared.getAllVariableIds()
                    let filtered = allVarIds.filter { id in
                        afterTrigger.isEmpty || id.lowercased().hasPrefix(afterTrigger.lowercased())
                    }.prefix(maxSuggestions)
                    return Array(filtered)
                } else {
                    // 라벨 목록 조회
                    let allVarLabels = Database.shared.getAllVariableLabels()
                    let filtered = allVarLabels.filter { label in
                        afterTrigger.isEmpty || label.lowercased().hasPrefix(afterTrigger.lowercased())
                    }.prefix(maxSuggestions)
                    return Array(filtered)
                }

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
                // {secure: 또는 [secure@ 또는 [secure# 찾기
                var afterTrigger = ""
                var isIdHint = false  // @는 ID, #는 라벨

                if let range = beforeCursor.range(of: "[secure@", options: .backwards) {
                    afterTrigger = String(beforeCursor[range.upperBound...])
                    isIdHint = true
                } else if let range = beforeCursor.range(of: "[secure#", options: .backwards) {
                    afterTrigger = String(beforeCursor[range.upperBound...])
                    isIdHint = false
                } else if let range = beforeCursor.range(of: "{secure:", options: .backwards) {
                    afterTrigger = String(beforeCursor[range.upperBound...])
                    isIdHint = false  // 기본은 라벨
                }

                if isIdHint {
                    // ID 목록 조회
                    let allSecureIds = Database.shared.getAllSecureIds()
                    let filtered = allSecureIds.filter { id in
                        afterTrigger.isEmpty || id.lowercased().hasPrefix(afterTrigger.lowercased())
                    }.prefix(maxSuggestions)
                    return Array(filtered)
                } else {
                    // 라벨 목록 조회
                    let allLabels = SecureValueManager.shared.getAllLabels()
                    let filtered = allLabels.filter { label in
                        afterTrigger.isEmpty || label.lowercased().hasPrefix(afterTrigger.lowercased())
                    }.prefix(maxSuggestions)
                    return Array(filtered)
                }

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
            case .pageRef:
                // {page: 또는 {page# 찾기
                let pageTriggers = ["{page:", "{page#"]
                var triggerRange: Range<String.Index>?
                for trigger in pageTriggers {
                    if let range = beforeCursor.range(of: trigger, options: .backwards) {
                        triggerRange = range
                        break
                    }
                }
                guard let pageRange = triggerRange else { return }
                let triggerStart = text.distance(from: text.startIndex, to: pageRange.lowerBound)
                let beforeTrigger = String(text.prefix(triggerStart))
                // 라벨로 shortId 조회
                if let shortId = Database.shared.getShortIdByLabel(suggestion) {
                    // `page@shortId` 형태로 저장 (배지로 변환됨)
                    let newText = beforeTrigger + "`page@\(shortId)`" + afterCursor
                    textView.string = newText
                    self.text = newText
                    let newCursorPosition = triggerStart + 8 + shortId.count  // `page@ + shortId + `
                    textView.setSelectedRange(NSRange(location: newCursorPosition, length: 0))
                }

            case .varRef:
                guard let varRange = beforeCursor.range(of: "{var:", options: .backwards) else { return }
                let triggerStart = text.distance(from: text.startIndex, to: varRange.lowerBound)
                let beforeTrigger = String(text.prefix(triggerStart))
                let newText = beforeTrigger + "[var#" + suggestion + "]" + afterCursor
                textView.string = newText
                self.text = newText  // 입력 형식 그대로 저장
                let newCursorPosition = triggerStart + 5 + suggestion.count  // [var# + suggestion + ]
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
                // {secure: → [secure#라벨] 형태로 변환 (기존 라벨 선택 시)
                guard let secureRange = beforeCursor.range(of: "{secure:", options: .backwards) else { return }
                let triggerStart = text.distance(from: text.startIndex, to: secureRange.lowerBound)
                let beforeTrigger = String(text.prefix(triggerStart))
                let newText = beforeTrigger + "[secure#\(suggestion)]" + afterCursor
                textView.string = newText
                self.text = newText  // 입력 형식 그대로 저장
                let newCursorPosition = triggerStart + 9 + suggestion.count  // [secure# + label + ]
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
    var isArrowKeyMoving: Bool = false  // 화살표 키로 이동 중 플래그

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

        // 오른쪽 화살표 - attachment 건너뛰기
        if event.keyCode == 124 {  // Right arrow
            let pos = selectedRange().location
            if let storage = textStorage, pos < storage.length {
                let attrs = storage.attributes(at: pos, effectiveRange: nil)
                if attrs[.attachment] is BadgeTextAttachment {
                    // attachment 다음으로 이동
                    isArrowKeyMoving = true
                    setSelectedRange(NSRange(location: pos + 1, length: 0))
                    return
                }
            }
            isArrowKeyMoving = true
        }

        // 왼쪽 화살표 - attachment 건너뛰기
        if event.keyCode == 123 {  // Left arrow
            let pos = selectedRange().location
            if let storage = textStorage, pos > 0 {
                // 바로 앞 위치가 attachment인지 확인
                let prevPos = pos - 1
                if prevPos < storage.length {
                    let attrs = storage.attributes(at: prevPos, effectiveRange: nil)
                    if attrs[.attachment] is BadgeTextAttachment {
                        // attachment 앞으로 건너뛰기
                        isArrowKeyMoving = true
                        setSelectedRange(NSRange(location: prevPos, length: 0))
                        return
                    }
                }
            }
            isArrowKeyMoving = true
        }

        super.keyDown(with: event)
    }

    /// 복사 시 attachment를 원본 텍스트로 변환
    override func copy(_ sender: Any?) {
        guard let textStorage = textStorage else {
            print("[Copy] No textStorage, using super")
            super.copy(sender)
            return
        }

        let range = selectedRange()
        print("[Copy] Selected range: \(range)")
        guard range.length > 0 else {
            print("[Copy] Empty selection, using super")
            super.copy(sender)
            return
        }

        // 선택된 범위의 텍스트를 원본 형식으로 변환
        let selectedAttrString = textStorage.attributedSubstring(from: range)
        let plainText = BadgeUtils.convertToText(from: selectedAttrString)
        print("[Copy] Converted text: \(plainText)")

        // 클립보드에 복사
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(plainText, forType: .string)
        print("[Copy] Copied to clipboard")
    }

    /// 잘라내기 시 attachment를 원본 텍스트로 변환
    override func cut(_ sender: Any?) {
        copy(sender)
        deleteBackward(sender)
    }

    /// 붙여넣기 시 singleLine이면 줄바꿈 제거
    override func paste(_ sender: Any?) {
        if singleLineMode {
            let pasteboard = NSPasteboard.general
            if let text = pasteboard.string(forType: .string) {
                // 줄바꿈을 공백으로 치환
                let singleLineText = text.replacingOccurrences(of: "\n", with: " ")
                    .replacingOccurrences(of: "\r", with: "")
                insertText(singleLineText, replacementRange: selectedRange())
                return
            }
        }
        super.paste(sender)
    }

    override func draw(_ dirtyRect: NSRect) {
        // NSTextAttachment가 배지 렌더링 처리
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

        // {secure:...} 또는 [secure#...] 패턴 찾기
        let patterns = ["\\{secure:[^}]*\\}", "\\[secure#[^\\]]*\\]"]
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
