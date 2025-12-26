import SwiftUI
import AppKit

// MARK: - Script Execution Panel Controller (NSPanel + worksWhenModal 방식)
class ScriptExecutionWindowController {
    private static var panel: NSPanel?
    private static var parentWindow: NSWindow?
    private static var isShowing = false

    static func show(command: Command, store: CommandStore) {
        guard !isShowing else { return }
        guard let parent = NSApp.keyWindow ?? NSApp.mainWindow else { return }

        isShowing = true
        parentWindow = parent

        // 파라미터 개수에 따라 초기 높이 계산
        let paramCount = command.parameterInfos.count
        let baseHeight: CGFloat = 120
        let paramHeight: CGFloat = CGFloat(paramCount) * 55
        let initialHeight: CGFloat = baseHeight + paramHeight

        let contentView = ScriptExecutionView(
            command: command,
            store: store,
            onClose: { close() },
            onExecutionStarted: { expandWindow() }
        )

        let hostingController = NSHostingController(rootView: contentView)
        let newPanel = NSPanel(contentViewController: hostingController)

        newPanel.title = command.label
        newPanel.styleMask = [.titled, .closable, .resizable]
        newPanel.setContentSize(NSSize(width: 450, height: initialHeight))
        newPanel.minSize = NSSize(width: 400, height: 150)
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
        newPanel.center()
        newPanel.makeKeyAndOrderFront(nil)
    }

    static func expandWindow() {
        guard let window = panel else { return }
        var frame = window.frame
        let newHeight: CGFloat = 400
        frame.size.height = newHeight
        window.setFrame(frame, display: true, animate: true)
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

        currentPanel.close()
        panel = nil
        parentWindow = nil
    }
}
