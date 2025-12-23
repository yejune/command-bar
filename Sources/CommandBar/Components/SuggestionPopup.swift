import SwiftUI
import AppKit

class SuggestionPopupController: NSViewController {
    private var popover: NSPopover?
    private var hostingView: NSHostingView<SuggestionListView>?
    private var targetView: NSView?
    private var suggestions: [String] = []
    private var selectedIndex: Int = 0
    private var onSelect: ((String) -> Void)?

    func show(
        relativeTo view: NSView,
        suggestions: [String],
        onSelect: @escaping (String) -> Void
    ) {
        guard !suggestions.isEmpty else {
            hide()
            return
        }

        self.targetView = view
        self.suggestions = suggestions
        self.selectedIndex = 0
        self.onSelect = onSelect

        let listView = SuggestionListView(
            suggestions: suggestions,
            selectedIndex: selectedIndex,
            onSelect: { [weak self] suggestion in
                self?.selectSuggestion(suggestion)
            }
        )

        if popover == nil {
            popover = NSPopover()
            popover?.behavior = .semitransient
            popover?.animates = false
        }

        hostingView = NSHostingView(rootView: listView)
        popover?.contentViewController = NSViewController()
        popover?.contentViewController?.view = hostingView!

        let maxHeight: CGFloat = min(CGFloat(suggestions.count) * 24 + 8, 200)
        popover?.contentSize = NSSize(width: 200, height: maxHeight)

        if let viewWindow = view.window,
           let viewSuper = view.superview {
            let viewFrame = viewSuper.convert(view.frame, to: nil)
            _ = viewWindow.convertToScreen(viewFrame)
            let popoverRect = NSRect(x: 0, y: 0, width: view.bounds.width, height: view.bounds.height)

            popover?.show(relativeTo: popoverRect, of: view, preferredEdge: .maxY)
        }
    }

    func hide() {
        popover?.close()
        popover = nil
        hostingView = nil
        targetView = nil
        suggestions = []
        selectedIndex = 0
        onSelect = nil
    }

    func moveSelectionUp() {
        guard !suggestions.isEmpty else { return }
        selectedIndex = (selectedIndex - 1 + suggestions.count) % suggestions.count
        updateView()
    }

    func moveSelectionDown() {
        guard !suggestions.isEmpty else { return }
        selectedIndex = (selectedIndex + 1) % suggestions.count
        updateView()
    }

    func selectCurrent() {
        guard selectedIndex < suggestions.count else { return }
        selectSuggestion(suggestions[selectedIndex])
    }

    private func selectSuggestion(_ suggestion: String) {
        onSelect?(suggestion)
        hide()
    }

    private func updateView() {
        guard let hostingView = hostingView else { return }
        let listView = SuggestionListView(
            suggestions: suggestions,
            selectedIndex: selectedIndex,
            onSelect: { [weak self] suggestion in
                self?.selectSuggestion(suggestion)
            }
        )
        hostingView.rootView = listView
    }

    var isVisible: Bool {
        popover?.isShown ?? false
    }
}

struct SuggestionListView: View {
    let suggestions: [String]
    let selectedIndex: Int
    let onSelect: (String) -> Void

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(Array(suggestions.enumerated()), id: \.offset) { index, suggestion in
                    Text(suggestion)
                        .font(.system(size: 12, design: .monospaced))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(index == selectedIndex ? Color.accentColor.opacity(0.3) : Color.clear)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            onSelect(suggestion)
                        }
                }
            }
        }
        .frame(maxHeight: 200)
        .padding(.vertical, 4)
    }
}
