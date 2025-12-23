import Foundation
import AppKit
import ApplicationServices

/// AXUIElement를 래핑하여 창 위치/크기 제어를 쉽게 하는 클래스
class AccessibilityElement {
    let element: AXUIElement

    init(_ element: AXUIElement) {
        self.element = element
    }

    /// 현재 활성화된 앱의 frontmost 윈도우 가져오기
    static func getFrontmostWindow() -> AccessibilityElement? {
        guard let frontmostApp = NSWorkspace.shared.frontmostApplication else {
            return nil
        }

        let appElement = AXUIElementCreateApplication(frontmostApp.processIdentifier)
        var focusedWindow: CFTypeRef?

        // focusedWindow 속성 가져오기
        let result = AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &focusedWindow)

        if result == .success, let window = focusedWindow {
            return AccessibilityElement(window as! AXUIElement)
        }

        return nil
    }

    /// 창의 현재 위치 가져오기 (AXUIElement 좌표계: 좌상단 원점)
    var position: CGPoint? {
        get {
            var value: CFTypeRef?
            let result = AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &value)

            if result == .success, let axValue = value {
                var point = CGPoint.zero
                if AXValueGetValue(axValue as! AXValue, .cgPoint, &point) {
                    return point
                }
            }
            return nil
        }
        set {
            guard let newValue = newValue else { return }
            var point = newValue
            if let axValue = AXValueCreate(.cgPoint, &point) {
                AXUIElementSetAttributeValue(element, kAXPositionAttribute as CFString, axValue)
            }
        }
    }

    /// 창의 현재 크기 가져오기
    var size: CGSize? {
        get {
            var value: CFTypeRef?
            let result = AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &value)

            if result == .success, let axValue = value {
                var size = CGSize.zero
                if AXValueGetValue(axValue as! AXValue, .cgSize, &size) {
                    return size
                }
            }
            return nil
        }
        set {
            guard let newValue = newValue else { return }
            var size = newValue
            if let axValue = AXValueCreate(.cgSize, &size) {
                AXUIElementSetAttributeValue(element, kAXSizeAttribute as CFString, axValue)
            }
        }
    }

    /// 창의 현재 프레임 가져오기 (AXUIElement 좌표계)
    var frame: CGRect? {
        get {
            guard let position = position, let size = size else {
                return nil
            }
            return CGRect(origin: position, size: size)
        }
        set {
            guard let newValue = newValue else { return }
            position = newValue.origin
            size = newValue.size
        }
    }

    /// 창을 특정 프레임으로 설정 (애니메이션 없음)
    func setFrame(_ frame: CGRect) {
        self.frame = frame
    }

    /// 창을 특정 프레임으로 설정 (애니메이션 있음)
    /// - Parameters:
    ///   - frame: 목표 프레임 (AXUIElement 좌표계)
    ///   - duration: 애니메이션 시간 (초)
    func setFrame(_ frame: CGRect, animationDuration duration: TimeInterval) {
        guard let currentFrame = self.frame else {
            setFrame(frame)
            return
        }

        let steps = Int(duration * 60.0) // 60fps 기준
        let stepDuration = duration / Double(steps)

        for i in 0...steps {
            let progress = Double(i) / Double(steps)
            let interpolatedX = currentFrame.origin.x + (frame.origin.x - currentFrame.origin.x) * progress
            let interpolatedY = currentFrame.origin.y + (frame.origin.y - currentFrame.origin.y) * progress
            let interpolatedWidth = currentFrame.size.width + (frame.size.width - currentFrame.size.width) * progress
            let interpolatedHeight = currentFrame.size.height + (frame.size.height - currentFrame.size.height) * progress

            let interpolatedFrame = CGRect(
                x: interpolatedX,
                y: interpolatedY,
                width: interpolatedWidth,
                height: interpolatedHeight
            )

            DispatchQueue.main.asyncAfter(deadline: .now() + stepDuration * Double(i)) { [weak self] in
                self?.setFrame(interpolatedFrame)
            }
        }
    }

    /// 앱의 프로세스 이름 가져오기
    var processName: String? {
        // 앱 element로부터 타이틀 가져오기
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, kAXTitleAttribute as CFString, &value)

        if result == .success, let title = value as? String {
            return title
        }
        return nil
    }
}
