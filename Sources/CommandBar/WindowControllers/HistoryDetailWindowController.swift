import SwiftUI
import AppKit

// MARK: - History Detail Panel Controller (NSPanel + worksWhenModal 방식)
class HistoryDetailWindowController {
    private static var panel: NSPanel?
    private static var parentWindow: NSWindow?
    private static var isShowing = false

    static func show(item: HistoryItem) {
        guard !isShowing else { return }
        guard let parent = NSApp.keyWindow ?? NSApp.mainWindow else { return }

        isShowing = true
        parentWindow = parent

        let contentView = HistoryOutputView(
            item: item,
            onClose: { close() }
        )

        let hostingController = NSHostingController(rootView: contentView)
        let newPanel = NSPanel(contentViewController: hostingController)

        newPanel.title = item.title
        newPanel.styleMask = [.titled, .closable, .resizable]
        newPanel.setContentSize(NSSize(width: 500, height: 400))
        newPanel.minSize = NSSize(width: 400, height: 300)
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
            close()
        }

        // 패널 표시
        newPanel.makeKeyAndOrderFront(nil)
    }

    static func close() {
        guard isShowing else { return }
        guard let currentPanel = panel else { return }
        isShowing = false  // 먼저 플래그 해제하여 재진입 방지

        // 알림 제거
        NotificationCenter.default.removeObserver(self, name: NSWindow.willCloseNotification, object: currentPanel)

        // 부모 창 복원
        if let parent = parentWindow {
            parent.ignoresMouseEvents = false
        }

        // 자동 숨기기 방지 해제
        Settings.shared.preventAutoHide = false

        // 패널 닫기
        currentPanel.close()

        panel = nil
        parentWindow = nil
    }
}
