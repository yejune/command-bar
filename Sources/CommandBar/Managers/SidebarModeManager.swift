import Foundation
import AppKit
import ApplicationServices

/// 사이드바 모드를 관리하는 매니저
/// CommandBar를 화면 좌측에 배치하고, 활성 앱 창을 나머지 영역에 배치
class SidebarModeManager {
    static let shared = SidebarModeManager()

    private init() {}

    /// 사이드바 모드 활성화 여부
    private(set) var isSidebarModeActive = false

    /// CommandBar의 사이드바 너비
    private let sidebarWidth: CGFloat = 280

    /// 좌표계 변환: NSWindow (좌하단 원점) -> AXUIElement (좌상단 원점)
    /// - Parameters:
    ///   - nsRect: NSWindow 좌표계의 프레임
    ///   - screenHeight: 스크린의 높이
    /// - Returns: AXUIElement 좌표계의 프레임
    private func convertNSRectToAXRect(_ nsRect: CGRect, screenHeight: CGFloat) -> CGRect {
        let axY = screenHeight - nsRect.origin.y - nsRect.size.height
        return CGRect(x: nsRect.origin.x, y: axY, width: nsRect.size.width, height: nsRect.size.height)
    }

    /// 좌표계 변환: AXUIElement (좌상단 원점) -> NSWindow (좌하단 원점)
    /// - Parameters:
    ///   - axRect: AXUIElement 좌표계의 프레임
    ///   - screenHeight: 스크린의 높이
    /// - Returns: NSWindow 좌표계의 프레임
    private func convertAXRectToNSRect(_ axRect: CGRect, screenHeight: CGFloat) -> CGRect {
        let nsY = screenHeight - axRect.origin.y - axRect.size.height
        return CGRect(x: axRect.origin.x, y: nsY, width: axRect.size.width, height: axRect.size.height)
    }

    /// 사이드바 모드 토글
    func toggleSidebarMode() {
        if isSidebarModeActive {
            deactivateSidebarMode()
        } else {
            activateSidebarMode()
        }
    }

    /// 사이드바 모드 활성화
    func activateSidebarMode() {
        // Accessibility 권한 확인
        guard AccessibilityManager.shared.isAccessibilityEnabled else {
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

        // 1. CommandBar를 좌측 사이드바로 배치 (NSWindow 좌표계)
        let commandBarFrame = NSRect(
            x: visibleFrame.minX,
            y: visibleFrame.minY,
            width: sidebarWidth,
            height: visibleFrame.height
        )
        commandBarWindow.setFrame(commandBarFrame, display: true, animate: true)

        // 2. 현재 활성 앱 창 가져오기 (CommandBar 제외)
        guard let frontmostApp = NSWorkspace.shared.frontmostApplication,
              frontmostApp.bundleIdentifier != Bundle.main.bundleIdentifier,
              let activeWindow = AccessibilityElement.getFrontmostWindow() else {
            print("No active window to arrange")
            isSidebarModeActive = true
            Settings.shared.disableAutoHideForSidebarMode()
            return
        }

        // 3. 활성 앱 창을 나머지 영역에 배치 (AXUIElement 좌표계)
        let remainingFrame = CGRect(
            x: visibleFrame.minX + sidebarWidth,
            y: 0, // AXUIElement는 좌상단 원점
            width: visibleFrame.width - sidebarWidth,
            height: visibleFrame.height
        )

        // AXUIElement 좌표계로 변환하여 설정
        let axRemainingFrame = convertNSRectToAXRect(
            NSRect(
                x: remainingFrame.minX,
                y: visibleFrame.minY,
                width: remainingFrame.width,
                height: remainingFrame.height
            ),
            screenHeight: screenHeight
        )

        activeWindow.setFrame(axRemainingFrame)

        isSidebarModeActive = true

        // 4. 자동 숨기기 비활성화
        Settings.shared.disableAutoHideForSidebarMode()

        print("Sidebar mode activated")
    }

    /// 사이드바 모드 비활성화
    func deactivateSidebarMode() {
        isSidebarModeActive = false

        // 자동 숨기기 재활성화 (이전 상태로)
        Settings.shared.restoreAutoHideAfterSidebarMode()

        print("Sidebar mode deactivated")
    }
}
