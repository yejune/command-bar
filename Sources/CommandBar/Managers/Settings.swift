import SwiftUI
import AppKit
import ServiceManagement
import Carbon.HIToolbox

class Settings: ObservableObject {
    static let shared = Settings()
    private let db = Database.shared

    @Published var alwaysOnTop: Bool {
        didSet {
            db.setBoolSetting("alwaysOnTop", value: alwaysOnTop)
            applyAlwaysOnTop()
        }
    }
    @Published var launchAtLogin: Bool {
        didSet {
            db.setBoolSetting("launchAtLogin", value: launchAtLogin)
            applyLaunchAtLogin()
        }
    }
    @Published var useBackgroundOpacity: Bool {
        didSet {
            db.setBoolSetting("useBackgroundOpacity", value: useBackgroundOpacity)
            applyBackgroundOpacity()
        }
    }
    @Published var backgroundOpacity: Double {
        didSet {
            db.setDoubleSetting("backgroundOpacity", value: backgroundOpacity)
            if useBackgroundOpacity {
                applyBackgroundOpacity()
            }
        }
    }
    @Published var notesFolderName: String {
        didSet {
            db.setSetting("notesFolderName", value: notesFolderName)
        }
    }
    @Published var autoHide: Bool {
        didSet {
            db.setBoolSetting("autoHide", value: autoHide)
            applyAutoHide()
        }
    }
    @Published var useHideOpacity: Bool {
        didSet {
            db.setBoolSetting("useHideOpacity", value: useHideOpacity)
        }
    }
    @Published var hideOpacity: Double {
        didSet {
            db.setDoubleSetting("hideOpacity", value: hideOpacity)
        }
    }
    @Published var doubleClickToRun: Bool {
        didSet {
            db.setBoolSetting("doubleClickToRun", value: doubleClickToRun)
        }
    }

    private var appearanceObserver: NSObjectProtocol?
    private var resizeObserver: NSObjectProtocol?
    private var moveObserver: NSObjectProtocol?
    private var mouseMonitor: Any?
    private var localMouseMonitor: Any?
    @Published var isHidden = false
    private var isAnimating = false
    private var isRestoringFrame = true  // 시작 시 프레임 저장 방지
    private var savedWindowHeight: CGFloat = 0
    private var hideTimestamp: Date = .distantPast

    // 저장된 창 프레임 (앱 시작 시 즉시 사용)
    private(set) var storedWindowFrame: NSRect?

    init() {
        // UserDefaults에서 마이그레이션 (프로퍼티 초기화 전에 실행)
        Self.migrateFromUserDefaults(db: db)

        self.alwaysOnTop = db.getBoolSetting("alwaysOnTop", defaultValue: false)
        self.launchAtLogin = db.getBoolSetting("launchAtLogin", defaultValue: false)
        self.useBackgroundOpacity = db.getBoolSetting("useBackgroundOpacity", defaultValue: false)
        self.backgroundOpacity = db.getDoubleSetting("backgroundOpacity", defaultValue: 0.8)
        self.notesFolderName = db.getSetting("notesFolderName") ?? "클립보드 메모"
        self.autoHide = db.getBoolSetting("autoHide", defaultValue: false)
        self.useHideOpacity = db.getBoolSetting("useHideOpacity", defaultValue: true)
        self.hideOpacity = db.getDoubleSetting("hideOpacity", defaultValue: 0.1)
        self.doubleClickToRun = db.getBoolSetting("doubleClickToRun", defaultValue: true)

        // 저장된 창 프레임 로드
        let x = db.getDoubleSetting("windowX", defaultValue: -1)
        let y = db.getDoubleSetting("windowY", defaultValue: -1)
        let width = db.getDoubleSetting("windowWidth", defaultValue: 300)
        let height = db.getDoubleSetting("windowHeight", defaultValue: 400)
        if x >= 0 && y >= 0 && width >= 280 && height >= 300 {
            self.storedWindowFrame = NSRect(x: x, y: y, width: width, height: height)
            self.savedWindowHeight = CGFloat(height)
        }

        // 시스템 테마 변경 감지
        appearanceObserver = DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name("AppleInterfaceThemeChangedNotification"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.applyBackgroundOpacity()
        }

        // 창 리사이즈 감지 (수동 리사이즈 시 높이 저장)
        resizeObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didResizeNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self,
                  !self.isRestoringFrame,
                  !self.isHidden,
                  !self.isAnimating,
                  let window = notification.object as? NSWindow,
                  window.canBecomeMain,
                  window.frame.height >= 100 else { return }
            self.savedWindowHeight = window.frame.height
            self.saveWindowFrame(window.frame)
        }

        // 창 이동 감지
        moveObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didMoveNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self,
                  !self.isRestoringFrame,
                  !self.isHidden,
                  !self.isAnimating,
                  let window = notification.object as? NSWindow,
                  window.canBecomeMain else { return }
            self.saveWindowFrame(window.frame)
        }

        // isRestoringFrame 해제 (앱 시작 후 0.5초간 프레임 저장 방지)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.isRestoringFrame = false
        }

        // 자동 숨기기 적용
        if autoHide {
            applyAutoHide()
        }
    }

    private static func migrateFromUserDefaults(db: Database) {
        // 기존 UserDefaults에서 마이그레이션
        if db.getSetting("alwaysOnTop") == nil {
            if UserDefaults.standard.object(forKey: "alwaysOnTop") != nil {
                db.setBoolSetting("alwaysOnTop", value: UserDefaults.standard.bool(forKey: "alwaysOnTop"))
            }
            if UserDefaults.standard.object(forKey: "launchAtLogin") != nil {
                db.setBoolSetting("launchAtLogin", value: UserDefaults.standard.bool(forKey: "launchAtLogin"))
            }
            if UserDefaults.standard.object(forKey: "backgroundOpacity") != nil {
                let opacity = UserDefaults.standard.double(forKey: "backgroundOpacity")
                if opacity > 0 {
                    db.setDoubleSetting("backgroundOpacity", value: opacity)
                }
            }
            if let folderName = UserDefaults.standard.string(forKey: "notesFolderName") {
                db.setSetting("notesFolderName", value: folderName)
            }
        }
    }

    deinit {
        if let observer = appearanceObserver {
            DistributedNotificationCenter.default().removeObserver(observer)
        }
        if let observer = resizeObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        if let observer = moveObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        if let monitor = mouseMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }

    // MARK: - Window Frame

    private func saveWindowFrame(_ frame: NSRect) {
        db.setDoubleSetting("windowX", value: Double(frame.origin.x))
        db.setDoubleSetting("windowY", value: Double(frame.origin.y))
        db.setDoubleSetting("windowWidth", value: Double(frame.width))
        db.setDoubleSetting("windowHeight", value: Double(frame.height))
    }

    func applyAlwaysOnTop() {
        DispatchQueue.main.async {
            for window in NSApp.windows {
                window.level = self.alwaysOnTop ? .floating : .normal
            }
        }
    }

    func applyLaunchAtLogin() {
        do {
            if launchAtLogin {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            print("Failed to set launch at login: \(error)")
        }
    }

    func applyBackgroundOpacity() {
        DispatchQueue.main.async {
            let opacity = self.useBackgroundOpacity ? self.backgroundOpacity : 1.0
            for window in NSApp.windows where window.canBecomeMain {
                window.isOpaque = opacity >= 1.0
                window.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(opacity)
                // 숨기기 상태가 아닐 때만 alphaValue 적용
                if !self.isHidden {
                    window.alphaValue = opacity
                }
            }
        }
    }

    // MARK: - Auto Hide

    func applyAutoHide() {
        if autoHide {
            startMouseMonitor()
        } else {
            stopMouseMonitor()
            showWindow()
        }
    }

    private func startMouseMonitor() {
        stopMouseMonitor()
        // 글로벌 모니터 (앱 외부 이벤트)
        mouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .leftMouseDown]) { [weak self] event in
            self?.handleMouseEvent(event)
        }
        // 로컬 모니터 (앱 내부 이벤트) - 접힌 상태에서 클릭 또는 호버 시 펼치기
        localMouseMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .mouseMoved, .mouseEntered]) { [weak self] event in
            guard let self = self, self.isHidden else { return event }

            // 다른 창이 열려있으면 무시
            guard let mainWindow = NSApp.windows.first(where: { $0.canBecomeMain }) else { return event }

            // 시트가 열려있으면 무시
            if mainWindow.attachedSheet != nil { return event }

            // 다른 창이 열려있으면 무시 (모달, 패널 포함)
            let hasOtherWindow = NSApp.windows.contains {
                $0.isVisible &&
                $0 != mainWindow &&
                !$0.className.contains("StatusBar") &&
                !$0.className.contains("Popover") &&
                !$0.className.contains("_NSFullScreenTransition") &&
                $0.frame.width > 50
            }
            if !hasOtherWindow {
                self.showWindow()
            }
            return event
        }
    }

    private func stopMouseMonitor() {
        if let monitor = mouseMonitor {
            NSEvent.removeMonitor(monitor)
            mouseMonitor = nil
        }
        if let monitor = localMouseMonitor {
            NSEvent.removeMonitor(monitor)
            localMouseMonitor = nil
        }
    }

    private func handleMouseEvent(_ event: NSEvent) {
        guard let window = NSApp.windows.first(where: { $0.canBecomeMain }) else { return }

        // 모달이나 시트가 열려있으면 무시
        if window.attachedSheet != nil { return }

        // 다른 창이 열려있으면 무시 (모달, 패널 포함)
        let hasOtherWindow = NSApp.windows.contains {
            $0.isVisible &&
            $0 != window &&
            !$0.className.contains("StatusBar") &&
            !$0.className.contains("Popover") &&
            !$0.className.contains("_NSFullScreenTransition") &&
            $0.frame.width > 50
        }
        if hasOtherWindow { return }

        let mouseLocation = NSEvent.mouseLocation
        let windowFrame = window.frame

        if isHidden {
            // 접힌 상태: 타이틀바 위에 마우스가 오면 펼치기
            if windowFrame.contains(mouseLocation) {
                showWindow()
            }
        } else {
            // 펼쳐진 상태: 마우스가 창을 벗어나면 접기
            let expandedFrame = windowFrame.insetBy(dx: -10, dy: -10)
            if !expandedFrame.contains(mouseLocation) {
                hideWindow()
            }
        }
    }

    func hideWindow() {
        guard !isHidden, !isAnimating else { return }
        guard let window = NSApp.windows.first(where: { $0.canBecomeMain }) else { return }

        // 모달이나 시트가 열려있으면 숨기지 않음
        if window.attachedSheet != nil { return }

        // 다른 창이 열려있으면 숨기지 않음 (모달, 패널 포함)
        let hasOtherWindow = NSApp.windows.contains {
            $0.isVisible &&
            $0 != window &&
            !$0.className.contains("StatusBar") &&
            !$0.className.contains("Popover") &&
            !$0.className.contains("_NSFullScreenTransition") &&
            $0.frame.width > 50
        }
        if hasOtherWindow { return }

        let titlebarHeight: CGFloat = 28

        // 현재 높이 저장 (최초 1회만)
        if savedWindowHeight == 0 {
            savedWindowHeight = window.frame.height
        }

        // 최소 높이 제한 임시 해제
        window.minSize = NSSize(width: window.minSize.width, height: titlebarHeight)

        var newFrame = window.frame
        newFrame.origin.y += window.frame.height - titlebarHeight
        newFrame.size.height = titlebarHeight

        isAnimating = true
        NSAnimationContext.runAnimationGroup { [weak self] context in
            context.duration = 0.2
            window.animator().setFrame(newFrame, display: true)
            if self?.useHideOpacity == true {
                window.animator().alphaValue = self?.hideOpacity ?? 0.1
            }
        } completionHandler: { [weak self] in
            self?.isAnimating = false
        }

        isHidden = true
        hideTimestamp = Date()
    }

    func showWindow() {
        guard isHidden, !isAnimating, savedWindowHeight > 0 else { return }
        // 숨긴 직후 바로 펼쳐지는 것 방지 (0.3초)
        guard Date().timeIntervalSince(hideTimestamp) > 0.3 else { return }
        guard let window = NSApp.windows.first(where: { $0.canBecomeMain }) else { return }

        // 최소 높이 제한 먼저 복원
        window.minSize = NSSize(width: window.minSize.width, height: 28)

        // 원래 높이로 복원
        var newFrame = window.frame
        newFrame.origin.y -= savedWindowHeight - window.frame.height
        newFrame.size.height = savedWindowHeight

        isHidden = false
        isAnimating = true

        NSAnimationContext.runAnimationGroup { [weak self] context in
            context.duration = 0.2
            context.allowsImplicitAnimation = true
            window.animator().setFrame(newFrame, display: true)
            // 투명도 복원 (숨기기 투명도 사용 시에만)
            if self?.useHideOpacity == true {
                let originalAlpha = (self?.useBackgroundOpacity == true) ? (self?.backgroundOpacity ?? 1.0) : 1.0
                window.animator().alphaValue = originalAlpha
            }
        } completionHandler: { [weak self] in
            window.minSize = NSSize(width: window.minSize.width, height: 300)
            self?.isAnimating = false
        }
    }

    func toggleHide() {
        if isHidden {
            showWindow()
        } else {
            hideWindow()
        }
    }
}
