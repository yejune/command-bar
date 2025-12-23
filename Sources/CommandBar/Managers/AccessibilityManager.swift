import Foundation
import AppKit
import ApplicationServices

/// Accessibility 권한 체크 및 요청을 담당하는 매니저
class AccessibilityManager {
    static let shared = AccessibilityManager()

    private init() {}

    /// Accessibility 권한이 허용되었는지 확인
    var isAccessibilityEnabled: Bool {
        return AXIsProcessTrusted()
    }

    /// Accessibility 권한 요청 (시스템 환경설정으로 유도)
    func requestAccessibilityPermission() {
        // 권한 요청 프롬프트를 표시하기 위한 옵션
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        AXIsProcessTrustedWithOptions(options)
    }

    /// 권한 확인 및 필요 시 요청 다이얼로그 표시
    /// - Returns: 권한이 허용되어 있으면 true, 아니면 false
    @discardableResult
    func checkAndRequestIfNeeded() -> Bool {
        if isAccessibilityEnabled {
            return true
        }

        // 권한 요청 다이얼로그 표시
        requestAccessibilityPermission()
        return false
    }

    /// 사용자에게 Accessibility 권한이 필요하다는 안내 알림 표시
    func showPermissionAlert() {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = L.accessibilityPermissionTitle
            alert.informativeText = L.accessibilityPermissionMessage
            alert.alertStyle = .warning
            alert.addButton(withTitle: L.accessibilityOpenSettings)
            alert.addButton(withTitle: L.buttonCancel)

            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                // 시스템 환경설정의 보안 및 개인 정보 보호 > 손쉬운 사용 열기
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                    NSWorkspace.shared.open(url)
                }
            }
        }
    }
}
