import SwiftUI
import AppKit

// MARK: - Script Execution Window Controller
class ScriptExecutionWindowController {
    static var activeWindows: [UUID: NSWindow] = [:]

    static func show(command: Command, store: CommandStore) {
        // 이미 열린 창이 있으면 앞으로 가져오기
        if let existingWindow = activeWindows[command.id] {
            existingWindow.makeKeyAndOrderFront(nil)
            return
        }

        // 파라미터 개수에 따라 초기 높이 계산
        let paramCount = command.parameterInfos.count
        let baseHeight: CGFloat = 120  // 헤더 + 버튼
        let paramHeight: CGFloat = CGFloat(paramCount) * 55  // 파라미터 당 높이
        let initialHeight: CGFloat = baseHeight + paramHeight

        let contentView = ScriptExecutionView(
            command: command,
            store: store,
            onClose: {
                closeWindow(for: command.id)
            },
            onExecutionStarted: {
                expandWindow(for: command.id)
            }
        )

        let hostingController = NSHostingController(rootView: contentView)
        let panel = NSPanel(contentViewController: hostingController)

        panel.title = command.title
        panel.styleMask = [.titled, .closable, .resizable, .utilityWindow, .nonactivatingPanel]
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false

        let window = panel
        window.setContentSize(NSSize(width: 450, height: initialHeight))
        window.minSize = NSSize(width: 400, height: 150)

        // 메인 창 기준으로 위치
        if let mainWindow = NSApp.mainWindow ?? NSApp.windows.first {
            let mainFrame = mainWindow.frame
            let x = mainFrame.midX - 225
            let y = mainFrame.midY - initialHeight / 2
            window.setFrameOrigin(NSPoint(x: x, y: y))
        } else {
            window.center()
        }

        // 모달처럼 항상 앞에 고정
        window.level = .modalPanel

        // 창 닫힐 때 정리
        window.isReleasedWhenClosed = false
        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { _ in
            activeWindows.removeValue(forKey: command.id)
        }

        activeWindows[command.id] = window
        window.makeKeyAndOrderFront(nil)
    }

    static func expandWindow(for commandId: UUID) {
        guard let window = activeWindows[commandId] else { return }
        let currentFrame = window.frame
        let newHeight: CGFloat = 400
        let newY = currentFrame.origin.y - (newHeight - currentFrame.height)
        let newFrame = NSRect(x: currentFrame.origin.x, y: newY, width: currentFrame.width, height: newHeight)
        window.animator().setFrame(newFrame, display: true)
    }

    static func closeWindow(for commandId: UUID) {
        if let window = activeWindows[commandId] {
            window.close()
            activeWindows.removeValue(forKey: commandId)
        }
    }
}
