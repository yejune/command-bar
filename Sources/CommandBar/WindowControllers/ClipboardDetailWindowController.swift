import SwiftUI
import AppKit

// MARK: - Clipboard Detail Window Controller
class ClipboardDetailWindowController {
    static var activeWindows: [UUID: NSWindow] = [:]

    static func show(item: ClipboardItem, store: CommandStore, notesFolderName: String) {
        if let existingWindow = activeWindows[item.id] {
            existingWindow.makeKeyAndOrderFront(nil)
            return
        }

        let contentView = ClipboardDetailView(
            item: item,
            store: store,
            notesFolderName: notesFolderName,
            onClose: { closeWindow(for: item.id) }
        )

        let hostingController = NSHostingController(rootView: contentView)
        let panel = NSPanel(contentViewController: hostingController)

        panel.title = L.clipboardDetail
        panel.styleMask = [.titled, .closable, .resizable, .utilityWindow, .nonactivatingPanel]
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false

        let window = panel
        window.setContentSize(NSSize(width: 500, height: 400))
        window.minSize = NSSize(width: 300, height: 200)

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
