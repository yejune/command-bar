import Foundation
import AppKit
import ApplicationServices

/// 사이드바 모드를 관리하는 매니저
/// CommandBar를 화면 좌측에 배치하고, 활성 앱 창을 나머지 영역에 배치
class SidebarModeManager {
    static let shared = SidebarModeManager()

    private init() {}

    /// CommandBar의 사이드바 너비
    private let sidebarWidth: CGFloat = 280

    /// 좌표계 변환: NSWindow (좌하단 원점) -> AXUIElement (좌상단 원점)
    private func convertNSRectToAXRect(_ nsRect: CGRect, screenHeight: CGFloat) -> CGRect {
        let axY = screenHeight - nsRect.origin.y - nsRect.size.height
        return CGRect(x: nsRect.origin.x, y: axY, width: nsRect.size.width, height: nsRect.size.height)
    }

    /// 창 배치 실행
    /// - Parameter commandBarOnLeft: true면 CommandBar 좌측, false면 우측
    func arrangeWindows(commandBarOnLeft: Bool = true) {
        // Accessibility 권한 확인
        let hasPermission = AccessibilityManager.shared.isAccessibilityEnabled
        NSLog("[SidebarMode] Accessibility permission: %d", hasPermission ? 1 : 0)

        guard hasPermission else {
            AccessibilityManager.shared.showPermissionAlert()
            return
        }

        guard let commandBarWindow = NSApp.windows.first(where: { $0.canBecomeMain }),
              let screen = commandBarWindow.screen else {
            print("CommandBar window not found")
            return
        }

        let visibleFrame = screen.visibleFrame
        let screenHeight = screen.frame.height

        // 1. CommandBar 배치 (NSWindow 좌표계)
        let commandBarFrame: NSRect
        if commandBarOnLeft {
            commandBarFrame = NSRect(
                x: visibleFrame.minX,
                y: visibleFrame.minY,
                width: sidebarWidth,
                height: visibleFrame.height
            )
        } else {
            commandBarFrame = NSRect(
                x: visibleFrame.maxX - sidebarWidth,
                y: visibleFrame.minY,
                width: sidebarWidth,
                height: visibleFrame.height
            )
        }
        commandBarWindow.setFrame(commandBarFrame, display: true, animate: true)

        // 2. CommandBar가 아닌 다른 앱 창 가져오기
        NSLog("[SidebarMode] Looking for non-CommandBar window...")
        guard let activeWindow = AccessibilityElement.getMostRecentNonCommandBarWindow() else {
            NSLog("[SidebarMode] No active window found")
            return
        }
        NSLog("[SidebarMode] Found window")

        // 3. 활성 앱 창을 나머지 영역에 배치
        let remainingX: CGFloat
        if commandBarOnLeft {
            remainingX = visibleFrame.minX + sidebarWidth
        } else {
            remainingX = visibleFrame.minX
        }

        // AXUIElement 좌표계로 변환하여 설정
        let axRemainingFrame = convertNSRectToAXRect(
            NSRect(
                x: remainingX,
                y: visibleFrame.minY,
                width: visibleFrame.width - sidebarWidth,
                height: visibleFrame.height
            ),
            screenHeight: screenHeight
        )

        NSLog("[SidebarMode] Setting window frame")
        activeWindow.setFrame(axRemainingFrame)
        NSLog("[SidebarMode] Frame set complete")
    }

    /// 화면 절반 영역에 창 배치
    /// - Parameters:
    ///   - onLeftSide: true면 화면 좌측 반, false면 우측 반
    ///   - commandBarFirst: true면 CommandBar가 앞(좌측), false면 활성 앱이 앞
    func arrangeWindowsInHalf(onLeftSide: Bool, commandBarFirst: Bool = true) {
        let hasPermission = AccessibilityManager.shared.isAccessibilityEnabled
        guard hasPermission else {
            AccessibilityManager.shared.showPermissionAlert()
            return
        }

        guard let commandBarWindow = NSApp.windows.first(where: { $0.canBecomeMain }),
              let screen = commandBarWindow.screen else { return }

        let visibleFrame = screen.visibleFrame
        let screenHeight = screen.frame.height
        let halfWidth = visibleFrame.width / 2

        // 화면 반 영역의 시작 X 좌표
        let halfStartX = onLeftSide ? visibleFrame.minX : visibleFrame.midX

        // CommandBar X 좌표와 활성 앱 X 좌표 계산
        let commandBarX: CGFloat
        let activeWindowX: CGFloat

        if commandBarFirst {
            // CommandBar가 앞 (좌측)
            commandBarX = halfStartX
            activeWindowX = halfStartX + sidebarWidth
        } else {
            // 활성 앱이 앞 (좌측)
            commandBarX = halfStartX + halfWidth - sidebarWidth
            activeWindowX = halfStartX
        }

        // 1. CommandBar 배치
        let commandBarFrame = NSRect(
            x: commandBarX,
            y: visibleFrame.minY,
            width: sidebarWidth,
            height: visibleFrame.height
        )
        commandBarWindow.setFrame(commandBarFrame, display: true, animate: true)

        // 2. 활성 앱 창 가져오기
        guard let activeWindow = AccessibilityElement.getMostRecentNonCommandBarWindow() else { return }

        // 3. 활성 앱 창을 나머지 영역에 배치
        let axRemainingFrame = convertNSRectToAXRect(
            NSRect(
                x: activeWindowX,
                y: visibleFrame.minY,
                width: halfWidth - sidebarWidth,
                height: visibleFrame.height
            ),
            screenHeight: screenHeight
        )
        activeWindow.setFrame(axRemainingFrame)
    }
}
