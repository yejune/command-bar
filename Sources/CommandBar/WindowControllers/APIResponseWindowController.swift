import SwiftUI
import AppKit

// MARK: - API Response Window Controller
class APIResponseWindowController {
    static var activeWindows: [UUID: NSWindow] = [:]
    static var activeStates: [UUID: APIResponseState] = [:]

    static func showLoading(
        requestId: UUID,
        method: String,
        url: String,
        title: String
    ) -> APIResponseState {
        if let existingWindow = activeWindows[requestId] {
            existingWindow.makeKeyAndOrderFront(nil)
            return activeStates[requestId] ?? APIResponseState()
        }

        let state = APIResponseState()
        activeStates[requestId] = state

        let contentView = APIResponseView(
            method: method,
            url: url,
            state: state,
            onClose: { closeWindow(for: requestId) }
        )

        let hostingController = NSHostingController(rootView: contentView)
        let panel = NSPanel(contentViewController: hostingController)

        panel.title = title
        panel.styleMask = [.titled, .closable, .resizable, .utilityWindow, .nonactivatingPanel]
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false

        let window = panel
        window.setContentSize(NSSize(width: 600, height: 500))
        window.minSize = NSSize(width: 500, height: 400)

        if let mainWindow = NSApp.mainWindow ?? NSApp.windows.first {
            let mainFrame = mainWindow.frame
            let x = mainFrame.midX - 300
            let y = mainFrame.midY - 250
            window.setFrameOrigin(NSPoint(x: x, y: y))
        } else {
            window.center()
        }

        window.level = .modalPanel
        window.isReleasedWhenClosed = false
        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { _ in
            activeWindows.removeValue(forKey: requestId)
            activeStates.removeValue(forKey: requestId)
        }

        activeWindows[requestId] = window
        window.makeKeyAndOrderFront(nil)

        return state
    }

    static func closeWindow(for requestId: UUID) {
        if let window = activeWindows[requestId] {
            window.close()
            activeWindows.removeValue(forKey: requestId)
            activeStates.removeValue(forKey: requestId)
        }
    }
}
