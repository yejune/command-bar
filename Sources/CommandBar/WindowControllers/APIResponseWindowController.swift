import SwiftUI
import AppKit

// MARK: - API Response Window Controller (리사이즈 가능한 모달)
class APIResponseWindowController: NSWindowController, NSWindowDelegate {
    private static var shared: APIResponseWindowController?
    private static var modalWindow: NSWindow?
    private static var currentState: APIResponseState?

    static func showLoading(
        requestId: UUID,
        method: String,
        url: String,
        title: String
    ) -> APIResponseState {
        if shared != nil {
            modalWindow?.makeKeyAndOrderFront(nil)
            return currentState ?? APIResponseState()
        }

        let state = APIResponseState()
        currentState = state

        let contentView = APIResponseView(
            method: method,
            url: url,
            state: state,
            onClose: { close() }
        )

        let hostingController = NSHostingController(rootView: contentView)
        let window = NSWindow(contentViewController: hostingController)

        window.title = title
        window.styleMask = [.titled, .closable, .resizable]
        window.setContentSize(NSSize(width: 600, height: 500))
        window.minSize = NSSize(width: 500, height: 400)
        window.center()
        window.level = .modalPanel
        window.hidesOnDeactivate = false  // 포커스 잃어도 숨기지 않음
        window.isReleasedWhenClosed = false
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isHidden = true

        let controller = APIResponseWindowController(window: window)
        window.delegate = controller
        shared = controller
        modalWindow = window

        // 자동 숨기기 방지
        Settings.shared.preventAutoHide = true

        // 창 표시 후 모달 실행 (비동기로 실행하여 상태 업데이트 가능)
        window.makeKeyAndOrderFront(nil)
        DispatchQueue.main.async {
            NSApp.runModal(for: window)
        }

        return state
    }

    static func close() {
        NSApp.stopModal()
        modalWindow?.close()
    }

    func windowWillClose(_ notification: Notification) {
        NSApp.stopModal()
        Settings.shared.preventAutoHide = false
        APIResponseWindowController.shared = nil
        APIResponseWindowController.modalWindow = nil
        APIResponseWindowController.currentState = nil
    }
}
