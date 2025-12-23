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
        window.level = .modalPanel
        window.hidesOnDeactivate = false  // 포커스 잃어도 숨기지 않음
        window.isReleasedWhenClosed = false
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isHidden = true

        let controller = HistoryDetailWindowController(window: window)
        window.delegate = controller
        shared = controller
        modalWindow = window

        // 자동 숨기기 방지
        Settings.shared.preventAutoHide = true

        // 창 표시 후 모달 실행
        window.makeKeyAndOrderFront(nil)
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
