import SwiftUI
import AppKit

// MARK: - History Detail Window Controller
class HistoryDetailWindowController {
    static var activeWindows: [UUID: NSWindow] = [:]

    static func show(item: HistoryItem) {
        if let existingWindow = activeWindows[item.id] {
            existingWindow.makeKeyAndOrderFront(nil)
            return
        }

        let contentView = HistoryOutputView(
            item: item,
            onClose: { closeWindow(for: item.id) }
        )

        let hostingController = NSHostingController(rootView: contentView)
        let panel = NSPanel(contentViewController: hostingController)

        panel.title = item.title
        panel.styleMask = [.titled, .closable, .resizable, .utilityWindow, .nonactivatingPanel]
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false

        let window = panel
        window.setContentSize(NSSize(width: 500, height: 400))
        window.minSize = NSSize(width: 400, height: 300)

        if let mainWindow = NSApp.mainWindow ?? NSApp.windows.first {
            let mainFrame = mainWindow.frame
            let x = mainFrame.midX - 250
            let y = mainFrame.midY - 200
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
            activeWindows.removeValue(forKey: item.id)
        }

        activeWindows[item.id] = window
        window.makeKeyAndOrderFront(nil)
    }

    static func closeWindow(for itemId: UUID) {
        if let window = activeWindows[itemId] {
            window.close()
            activeWindows.removeValue(forKey: itemId)
        }
    }
}
