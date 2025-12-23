import SwiftUI
import AppKit

// MARK: - Script Execution Window Controller (리사이즈 가능한 모달)
class ScriptExecutionWindowController: NSWindowController, NSWindowDelegate {
    private static var shared: ScriptExecutionWindowController?
    private static var modalWindow: NSWindow?

    static func show(command: Command, store: CommandStore) {
        if shared != nil {
            modalWindow?.makeKeyAndOrderFront(nil)
            return
        }

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
        let window = NSWindow(contentViewController: hostingController)

        window.title = command.title
        window.styleMask = [.titled, .closable, .resizable]
        window.setContentSize(NSSize(width: 450, height: initialHeight))
        window.minSize = NSSize(width: 400, height: 150)
        window.center()
        window.level = .modalPanel
        window.hidesOnDeactivate = false  // 포커스 잃어도 숨기지 않음
        window.isReleasedWhenClosed = false
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isHidden = true

        let controller = ScriptExecutionWindowController(window: window)
        window.delegate = controller
        shared = controller
        modalWindow = window

        // 자동 숨기기 방지
        Settings.shared.preventAutoHide = true

        // 창 표시 후 모달 실행
        window.makeKeyAndOrderFront(nil)
        NSApp.runModal(for: window)
    }

    static func expandWindow() {
        guard let window = modalWindow else { return }
        let currentFrame = window.frame
        let newHeight: CGFloat = 400
        let newY = currentFrame.origin.y - (newHeight - currentFrame.height)
        let newFrame = NSRect(x: currentFrame.origin.x, y: newY, width: currentFrame.width, height: newHeight)
        window.animator().setFrame(newFrame, display: true)
    }

    static func close() {
        NSApp.stopModal()
        modalWindow?.close()
    }

    func windowWillClose(_ notification: Notification) {
        NSApp.stopModal()
        Settings.shared.preventAutoHide = false
        ScriptExecutionWindowController.shared = nil
        ScriptExecutionWindowController.modalWindow = nil
    }
}
