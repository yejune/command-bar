import SwiftUI
import AppKit

// MARK: - API Response Panel Controller (NSPanel + worksWhenModal 방식)
class APIResponseWindowController {
    private static var panel: NSPanel?
    private static var isShowing = false
    private static var currentState: APIResponseState?
    private static var parentWindow: NSWindow?
    private static var parentWasIgnoringMouseEvents = false

    static func showLoading(
        requestId: UUID,
        method: String,
        url: String,
        title: String
    ) -> APIResponseState {
        // 이미 표시 중이면 기존 상태 반환
        if isShowing, let state = currentState {
            return state
        }

        guard let window = NSApp.keyWindow ?? NSApp.mainWindow else {
            return APIResponseState()
        }

        isShowing = true
        parentWindow = window

        // 부모 창의 마우스 이벤트 차단 (기존 상태 저장)
        parentWasIgnoringMouseEvents = window.ignoresMouseEvents
        window.ignoresMouseEvents = true

        let state = APIResponseState()
        currentState = state

        let contentView = APIResponseView(
            method: method,
            url: url,
            state: state,
            onClose: { close() }
        )

        let hostingController = NSHostingController(rootView: contentView)

        // NSPanel 생성
        let newPanel = NSPanel(contentViewController: hostingController)

        newPanel.title = title
        newPanel.styleMask = [.titled, .closable, .resizable]
        newPanel.setContentSize(NSSize(width: 600, height: 500))
        newPanel.minSize = NSSize(width: 500, height: 400)
        newPanel.isReleasedWhenClosed = false

        // NSPanel 설정
        newPanel.worksWhenModal = true
        newPanel.level = .modalPanel
        newPanel.hidesOnDeactivate = false

        panel = newPanel

        // 자동 숨기기 방지
        Settings.shared.preventAutoHide = true

        // 패널 닫힘 감지
        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: newPanel,
            queue: .main
        ) { _ in
            restoreParentWindow()
        }

        // 패널 표시
        newPanel.center()
        newPanel.makeKeyAndOrderFront(nil)

        return state
    }

    static func close() {
        panel?.close()
    }

    private static func restoreParentWindow() {
        // 부모 창 복원
        if let parent = parentWindow {
            parent.ignoresMouseEvents = parentWasIgnoringMouseEvents
        }

        // 자동 숨기기 방지 해제
        Settings.shared.preventAutoHide = false

        // 상태 초기화
        panel = nil
        parentWindow = nil
        isShowing = false
        currentState = nil
        parentWasIgnoringMouseEvents = false
    }
}
