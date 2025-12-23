import SwiftUI
import AppKit

// MARK: - Clipboard Detail Panel Controller (NSPanel + worksWhenModal 방식)
class ClipboardDetailWindowController {
    private static var panel: NSPanel?
    private static var parentWindow: NSWindow?
    private static var isShowing = false

    static func show(item: ClipboardItem, store: CommandStore, notesFolderName: String) {
        guard !isShowing else { return }
        guard let parent = NSApp.keyWindow ?? NSApp.mainWindow else { return }

        isShowing = true
        parentWindow = parent

        let contentView = ClipboardDetailView(
            item: item,
            store: store,
            notesFolderName: notesFolderName,
            onClose: { close() }
        )

        let hostingController = NSHostingController(rootView: contentView)
        let newPanel = NSPanel(contentViewController: hostingController)

        newPanel.title = L.clipboardDetail
        newPanel.styleMask = [.titled, .closable, .resizable]
        newPanel.setContentSize(NSSize(width: 500, height: 400))
        newPanel.minSize = NSSize(width: 300, height: 200)
        newPanel.isReleasedWhenClosed = false

        // NSPanel 설정
        newPanel.worksWhenModal = true
        newPanel.level = .modalPanel
        newPanel.hidesOnDeactivate = false

        panel = newPanel

        // 자동 숨기기 방지
        Settings.shared.preventAutoHide = true

        // 부모 창 클릭 차단
        parent.ignoresMouseEvents = true

        // 패널 닫힘 감지
        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: newPanel,
            queue: .main
        ) { _ in
            cleanup()
        }

        // 패널 표시
        newPanel.center()
        newPanel.makeKeyAndOrderFront(nil)
    }

    static func close() {
        panel?.close()
    }

    private static func cleanup() {
        // 부모 창 복원
        if let parent = parentWindow {
            parent.ignoresMouseEvents = false
        }

        // 자동 숨기기 방지 해제
        Settings.shared.preventAutoHide = false

        panel = nil
        parentWindow = nil
        isShowing = false

        // Observer 제거는 필요 없음 (object가 nil이 되면 자동 제거됨)
    }
}
