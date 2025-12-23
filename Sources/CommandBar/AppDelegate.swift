import SwiftUI
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    private var didRestoreFrame = false

    func applicationDidBecomeActive(_ notification: Notification) {
        for window in NSApp.windows where window.canBecomeMain {
            window.standardWindowButton(.zoomButton)?.isHidden = true
            window.minSize = NSSize(width: 280, height: 300)
            setupTitlebarButtons(for: window)

            // 저장된 창 프레임 즉시 적용 (최초 1회)
            if !didRestoreFrame {
                if let frame = Settings.shared.storedWindowFrame {
                    window.setFrame(frame, display: false)
                }
                Settings.shared.finishRestoring()
                didRestoreFrame = true
            }
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
        accessoryView.frame = NSRect(x: 0, y: 0, width: 50, height: 22)

        let accessoryController = NSTitlebarAccessoryViewController()
        accessoryController.view = accessoryView
        accessoryController.layoutAttribute = .trailing

        window.addTitlebarAccessoryViewController(accessoryController)
    }
}

// MARK: - 레이아웃 아이콘
struct LayoutIcon: View {
    enum Layout {
        case fullLeft      // [▌        ] 사이드바 좌 | 창
        case fullRight     // [        ▐] 창 | 사이드바 우
        case halfLeftSW    // [▌ ][    ] 좌반: 사이드바|창
        case halfRightSW   // [    ][▌ ] 우반: 사이드바|창
        case halfLeftWS    // [ ▐][    ] 좌반: 창|사이드바
        case halfRightWS   // [    ][ ▐] 우반: 창|사이드바
        case snapLeft      // [▌]       좌측 고정
        case snapRight     //       [▐] 우측 고정
    }

    let layout: Layout
    let size: CGFloat

    private var sidebarRatio: CGFloat { 0.25 }

    var body: some View {
        Canvas { context, canvasSize in
            let w = canvasSize.width
            let h = canvasSize.height
            let gap: CGFloat = 1
            let cornerRadius: CGFloat = 1.5
            let sidebarWidth = w * sidebarRatio

            // 색상
            let strokeColor = Color.secondary.opacity(0.6)
            let sidebarColor = Color.primary.opacity(0.8)
            let windowColor = Color.secondary.opacity(0.3)

            switch layout {
            case .fullLeft:
                // [▌        ] 전체화면: 사이드바 좌 + 창 우
                drawRect(context, x: 0, y: 0, w: sidebarWidth, h: h, fill: sidebarColor, cornerRadius: cornerRadius)
                drawRect(context, x: sidebarWidth + gap, y: 0, w: w - sidebarWidth - gap, h: h, fill: windowColor, cornerRadius: cornerRadius)

            case .fullRight:
                // [        ▐] 전체화면: 창 좌 + 사이드바 우
                drawRect(context, x: 0, y: 0, w: w - sidebarWidth - gap, h: h, fill: windowColor, cornerRadius: cornerRadius)
                drawRect(context, x: w - sidebarWidth, y: 0, w: sidebarWidth, h: h, fill: sidebarColor, cornerRadius: cornerRadius)

            case .halfLeftSW:
                // [▌ ][    ] 좌반: 사이드바|창, 우반 빈 영역
                let halfW = (w - gap) / 2
                drawRect(context, x: 0, y: 0, w: sidebarWidth, h: h, fill: sidebarColor, cornerRadius: cornerRadius)
                drawRect(context, x: sidebarWidth + gap, y: 0, w: halfW - sidebarWidth - gap, h: h, fill: windowColor, cornerRadius: cornerRadius)
                drawRectStroke(context, x: halfW + gap, y: 0, w: halfW, h: h, stroke: strokeColor, cornerRadius: cornerRadius)

            case .halfRightSW:
                // [    ][▌ ] 좌반 빈 영역, 우반: 사이드바|창
                let halfW = (w - gap) / 2
                drawRectStroke(context, x: 0, y: 0, w: halfW, h: h, stroke: strokeColor, cornerRadius: cornerRadius)
                drawRect(context, x: halfW + gap, y: 0, w: sidebarWidth, h: h, fill: sidebarColor, cornerRadius: cornerRadius)
                drawRect(context, x: halfW + gap + sidebarWidth + gap, y: 0, w: halfW - sidebarWidth - gap, h: h, fill: windowColor, cornerRadius: cornerRadius)

            case .halfLeftWS:
                // [ ▐][    ] 좌반: 창|사이드바, 우반 빈 영역
                let halfW = (w - gap) / 2
                drawRect(context, x: 0, y: 0, w: halfW - sidebarWidth - gap, h: h, fill: windowColor, cornerRadius: cornerRadius)
                drawRect(context, x: halfW - sidebarWidth, y: 0, w: sidebarWidth, h: h, fill: sidebarColor, cornerRadius: cornerRadius)
                drawRectStroke(context, x: halfW + gap, y: 0, w: halfW, h: h, stroke: strokeColor, cornerRadius: cornerRadius)

            case .halfRightWS:
                // [    ][ ▐] 좌반 빈 영역, 우반: 창|사이드바
                let halfW = (w - gap) / 2
                drawRectStroke(context, x: 0, y: 0, w: halfW, h: h, stroke: strokeColor, cornerRadius: cornerRadius)
                drawRect(context, x: halfW + gap, y: 0, w: halfW - sidebarWidth - gap, h: h, fill: windowColor, cornerRadius: cornerRadius)
                drawRect(context, x: w - sidebarWidth, y: 0, w: sidebarWidth, h: h, fill: sidebarColor, cornerRadius: cornerRadius)

            case .snapLeft:
                // [▌]       좌측에 사이드바만
                drawRect(context, x: 0, y: 0, w: sidebarWidth, h: h, fill: sidebarColor, cornerRadius: cornerRadius)
                drawRectStroke(context, x: sidebarWidth + gap, y: 0, w: w - sidebarWidth - gap, h: h, stroke: strokeColor, cornerRadius: cornerRadius)

            case .snapRight:
                //       [▐] 우측에 사이드바만
                drawRectStroke(context, x: 0, y: 0, w: w - sidebarWidth - gap, h: h, stroke: strokeColor, cornerRadius: cornerRadius)
                drawRect(context, x: w - sidebarWidth, y: 0, w: sidebarWidth, h: h, fill: sidebarColor, cornerRadius: cornerRadius)
            }
        }
        .frame(width: size, height: size * 0.6)
    }

    private func drawRect(_ context: GraphicsContext, x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat, fill: Color, cornerRadius: CGFloat) {
        let rect = RoundedRectangle(cornerRadius: cornerRadius)
        context.fill(rect.path(in: CGRect(x: x, y: y, width: w, height: h)), with: .color(fill))
    }

    private func drawRectStroke(_ context: GraphicsContext, x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat, stroke: Color, cornerRadius: CGFloat) {
        let rect = RoundedRectangle(cornerRadius: cornerRadius)
        context.stroke(rect.path(in: CGRect(x: x, y: y, width: w, height: h)), with: .color(stroke), lineWidth: 0.5)
    }
}

// 타이틀바 버튼 뷰
struct TitlebarButtonsView: View {
    @ObservedObject private var settings = Settings.shared
    @State private var showLayoutPopover = false

    var body: some View {
        HStack(spacing: 2) {
            Button(action: { settings.autoHide.toggle() }) {
                Image(systemName: settings.autoHide ? "eye.slash" : "eye")
                    .font(.system(size: 11))
                    .foregroundStyle(settings.autoHide ? .primary : .secondary)
            }
            .buttonStyle(.borderless)
            .help(settings.autoHide ? L.settingsAutoHide + ": ON" : L.settingsAutoHide + ": OFF")

            Button(action: { showLayoutPopover.toggle() }) {
                Image(systemName: "menubar.rectangle")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.borderless)
            .popover(isPresented: $showLayoutPopover, arrowEdge: .bottom) {
                LayoutPopoverContent(isPresented: $showLayoutPopover)
            }
        }
        .padding(.trailing, 4)
    }

}

// 레이아웃 팝오버 내용
struct LayoutPopoverContent: View {
    @Binding var isPresented: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("전체 화면").font(.caption).foregroundStyle(.secondary).padding(.horizontal, 8).padding(.top, 8)
            LayoutButton(icon: .fullLeft, text: "사이드바 | 창") {
                SidebarModeManager.shared.arrangeWindows(commandBarOnLeft: true)
                isPresented = false
            }
            LayoutButton(icon: .fullRight, text: "창 | 사이드바") {
                SidebarModeManager.shared.arrangeWindows(commandBarOnLeft: false)
                isPresented = false
            }

            Divider().padding(.vertical, 4)

            Text("좌측 반").font(.caption).foregroundStyle(.secondary).padding(.horizontal, 8)
            LayoutButton(icon: .halfLeftSW, text: "사이드바 | 창") {
                SidebarModeManager.shared.arrangeWindowsInHalf(onLeftSide: true)
                isPresented = false
            }
            LayoutButton(icon: .halfLeftWS, text: "창 | 사이드바") {
                SidebarModeManager.shared.arrangeWindowsInHalf(onLeftSide: true, commandBarFirst: false)
                isPresented = false
            }

            Divider().padding(.vertical, 4)

            Text("우측 반").font(.caption).foregroundStyle(.secondary).padding(.horizontal, 8)
            LayoutButton(icon: .halfRightSW, text: "사이드바 | 창") {
                SidebarModeManager.shared.arrangeWindowsInHalf(onLeftSide: false)
                isPresented = false
            }
            LayoutButton(icon: .halfRightWS, text: "창 | 사이드바") {
                SidebarModeManager.shared.arrangeWindowsInHalf(onLeftSide: false, commandBarFirst: false)
                isPresented = false
            }

            Divider().padding(.vertical, 4)

            Text("사이드바만").font(.caption).foregroundStyle(.secondary).padding(.horizontal, 8)
            LayoutButton(icon: .snapLeft, text: "좌측 고정") {
                snapToLeft()
                isPresented = false
            }
            LayoutButton(icon: .snapRight, text: "우측 고정") {
                snapToRight()
                isPresented = false
            }
        }
        .padding(.vertical, 4)
        .frame(width: 160)
    }

    func snapToLeft() {
        guard let window = NSApp.keyWindow ?? NSApp.mainWindow, let screen = window.screen else { return }
        let visibleFrame = screen.visibleFrame
        let newFrame = NSRect(x: visibleFrame.minX, y: visibleFrame.minY, width: 280, height: visibleFrame.height)
        window.setFrame(newFrame, display: true, animate: true)
    }

    func snapToRight() {
        guard let window = NSApp.keyWindow ?? NSApp.mainWindow, let screen = window.screen else { return }
        let visibleFrame = screen.visibleFrame
        let newFrame = NSRect(x: visibleFrame.maxX - 280, y: visibleFrame.minY, width: 280, height: visibleFrame.height)
        window.setFrame(newFrame, display: true, animate: true)
    }
}

// 레이아웃 버튼
struct LayoutButton: View {
    let icon: LayoutIcon.Layout
    let text: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                LayoutIcon(layout: icon, size: 20)
                Text(text)
                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
