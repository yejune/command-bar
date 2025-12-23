import SwiftUI
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        for window in NSApp.windows {
            window.standardWindowButton(.zoomButton)?.isHidden = true
            setupTitlebarButtons(for: window)
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            for window in NSApp.windows {
                window.makeKeyAndOrderFront(self)
            }
        }
        return true
    }

    private func setupTitlebarButtons(for window: NSWindow) {
        // 이미 추가된 경우 스킵
        guard window.titlebarAccessoryViewControllers.isEmpty else { return }

        let accessoryView = NSHostingView(rootView: TitlebarButtonsView())
        accessoryView.frame = NSRect(x: 0, y: 0, width: 70, height: 22)

        let accessoryController = NSTitlebarAccessoryViewController()
        accessoryController.view = accessoryView
        accessoryController.layoutAttribute = .trailing

        window.addTitlebarAccessoryViewController(accessoryController)
    }
}

// 타이틀바 버튼 뷰
struct TitlebarButtonsView: View {
    @ObservedObject private var settings = Settings.shared

    var body: some View {
        HStack(spacing: 2) {
            Button(action: { Settings.shared.toggleHide() }) {
                Image(systemName: settings.isHidden ? "eye" : "eye.slash")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.borderless)
            .help(settings.isHidden ? L.showWindow : L.hideWindow)

            Button(action: { snapToLeft() }) {
                Image(systemName: "sidebar.left")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.borderless)
            .help(L.snapToLeft)

            Button(action: { snapToRight() }) {
                Image(systemName: "sidebar.right")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.borderless)
            .help(L.snapToRight)
        }
        .padding(.horizontal, 4)
    }

    func snapToLeft() {
        guard let window = NSApp.keyWindow ?? NSApp.mainWindow, let screen = window.screen else { return }
        let visibleFrame = screen.visibleFrame
        let minWidth: CGFloat = 280
        let newFrame = NSRect(
            x: visibleFrame.minX,
            y: visibleFrame.minY,
            width: minWidth,
            height: visibleFrame.height
        )
        window.setFrame(newFrame, display: true, animate: false)
    }

    func snapToRight() {
        guard let window = NSApp.keyWindow ?? NSApp.mainWindow, let screen = window.screen else { return }
        let visibleFrame = screen.visibleFrame
        let minWidth: CGFloat = 280
        let newFrame = NSRect(
            x: visibleFrame.maxX - minWidth,
            y: visibleFrame.minY,
            width: minWidth,
            height: visibleFrame.height
        )
        window.setFrame(newFrame, display: true, animate: false)
    }
}
