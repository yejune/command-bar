import SwiftUI
import AppKit

// MARK: - History Detail Window Controller (리사이즈 가능한 모달)
class HistoryDetailWindowController: NSWindowController, NSWindowDelegate {
    private static var shared: HistoryDetailWindowController?
    private static var modalWindow: NSWindow?

    static func show(item: HistoryItem) {
        if shared != nil {
            modalWindow?.makeKeyAndOrderFront(nil)
            return
        }

        let contentView = HistoryOutputView(
            item: item,
            onClose: { close() }
        )

        let hostingController = NSHostingController(rootView: contentView)
        let window = NSWindow(contentViewController: hostingController)

        window.title = item.title
        window.styleMask = [.titled, .closable, .resizable]
        window.setContentSize(NSSize(width: 500, height: 400))
        window.minSize = NSSize(width: 400, height: 300)
        window.center()

        let controller = HistoryDetailWindowController(window: window)
        window.delegate = controller
        shared = controller
        modalWindow = window

        // 자동 숨기기 방지
        Settings.shared.preventAutoHide = true

        // 모달로 실행
        NSApp.runModal(for: window)
    }

    static func close() {
        NSApp.stopModal()
        modalWindow?.close()
    }

    func windowWillClose(_ notification: Notification) {
        NSApp.stopModal()
        Settings.shared.preventAutoHide = false
        HistoryDetailWindowController.shared = nil
        HistoryDetailWindowController.modalWindow = nil
    }
}
