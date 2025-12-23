import SwiftUI
import AppKit

// MARK: - Clipboard Detail Window Controller (리사이즈 가능한 모달)
class ClipboardDetailWindowController: NSWindowController, NSWindowDelegate {
    private static var shared: ClipboardDetailWindowController?
    private static var modalWindow: NSWindow?

    static func show(item: ClipboardItem, store: CommandStore, notesFolderName: String) {
        if shared != nil {
            modalWindow?.makeKeyAndOrderFront(nil)
            return
        }

        let contentView = ClipboardDetailView(
            item: item,
            store: store,
            notesFolderName: notesFolderName,
            onClose: { close() }
        )

        let hostingController = NSHostingController(rootView: contentView)
        let window = NSWindow(contentViewController: hostingController)

        window.title = L.clipboardDetail
        window.styleMask = [.titled, .closable, .resizable]
        window.setContentSize(NSSize(width: 500, height: 400))
        window.minSize = NSSize(width: 300, height: 200)
        window.center()

        let controller = ClipboardDetailWindowController(window: window)
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
        ClipboardDetailWindowController.shared = nil
        ClipboardDetailWindowController.modalWindow = nil
    }
}
