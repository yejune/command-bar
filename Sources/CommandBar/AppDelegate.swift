import SwiftUI
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        for window in NSApp.windows where window.canBecomeMain {
            window.standardWindowButton(.zoomButton)?.isHidden = true
            window.minSize = NSSize(width: 280, height: 300)
            setupTitlebarButtons(for: window)
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        // 종료 전 창 복원 (숨겨진 상태면 펼치기)
        if Settings.shared.isHidden {
            Settings.shared.showWindow()
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        // 독 아이콘 클릭 시 숨겨진 창 펼치기
        if Settings.shared.isHidden {
            Settings.shared.showWindow()
        }
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
            Button(action: { settings.autoHide.toggle() }) {
                Image(systemName: settings.autoHide ? "eye.slash" : "eye")
                    .font(.system(size: 11))
                    .foregroundStyle(settings.autoHide ? .primary : .secondary)
            }
            .buttonStyle(.borderless)
            .help(settings.autoHide ? L.settingsAutoHide + ": ON" : L.settingsAutoHide + ": OFF")

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
