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
    @Published var hideShortcut: String {
        didSet {
            db.setSetting("hideShortcut", value: hideShortcut)
            registerHotKey()
        }
    }

    private var appearanceObserver: NSObjectProtocol?
    private var resizeObserver: NSObjectProtocol?
    private var mouseMonitor: Any?
    private var localMouseMonitor: Any?
    private var hotKeyRef: EventHotKeyRef?
    @Published var isHidden = false
    private var isAnimating = false
    private var savedWindowHeight: CGFloat = 0
    private var hideTimestamp: Date = .distantPast
    @Published var hotKeyRegistered = true

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
        self.hideShortcut = db.getSetting("hideShortcut") ?? "⌘⇧H"

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
                  !self.isHidden,
                  !self.isAnimating,
                  let window = notification.object as? NSWindow,
                  window.canBecomeMain,
                  window.frame.height >= 100 else { return }
            self.savedWindowHeight = window.frame.height
        }

        // 단축키 등록
        registerHotKey()

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
        if let monitor = mouseMonitor {
            NSEvent.removeMonitor(monitor)
        }
        unregisterHotKey()
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
            if self?.isHidden == true {
                self?.showWindow()
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

        // 다른 창이 열려있으면 무시
        let otherWindows = NSApp.windows.filter {
            $0.isVisible &&
            $0 != window &&
            $0.level == .normal &&
            $0.className != "NSStatusBarWindow" &&
            $0.className != "_NSPopoverWindow"
        }
        if !otherWindows.isEmpty { return }

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

        // 다른 창이 열려있으면 숨기지 않음 (메인 창, 상태바 메뉴 등 제외)
        let otherWindows = NSApp.windows.filter {
            $0.isVisible &&
            $0 != window &&
            $0.level == .normal &&
            $0.className != "NSStatusBarWindow" &&
            $0.className != "_NSPopoverWindow"
        }
        if !otherWindows.isEmpty { return }

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
                window.animator().alphaValue = 0.1
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

    // MARK: - Hot Key

    private func registerHotKey() {
        unregisterHotKey()

        // 간단한 단축키 파싱 (⌘⇧H 형태)
        guard let (keyCode, modifiers) = parseShortcut(hideShortcut) else {
            hotKeyRegistered = false
            return
        }

        var hotKeyID = EventHotKeyID()
        hotKeyID.signature = OSType(0x434D4442) // "CMDB"
        hotKeyID.id = 1

        let status = RegisterEventHotKey(
            UInt32(keyCode),
            UInt32(modifiers),
            hotKeyID,
            GetEventDispatcherTarget(),
            0,
            &hotKeyRef
        )

        if status == noErr {
            hotKeyRegistered = true
            // 핫키 이벤트 핸들러 설치
            var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
            InstallEventHandler(GetEventDispatcherTarget(), { (_, event, _) -> OSStatus in
                var hotKeyID = EventHotKeyID()
                GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID)

                if hotKeyID.id == 1 {
                    DispatchQueue.main.async {
                        Settings.shared.toggleHide()
                    }
                }
                return noErr
            }, 1, &eventType, nil, nil)
        } else {
            hotKeyRegistered = false
        }
    }

    private func unregisterHotKey() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
    }

    private func parseShortcut(_ shortcut: String) -> (keyCode: Int, modifiers: Int)? {
        var modifiers: Int = 0
        var keyChar: Character?

        for char in shortcut {
            switch char {
            case "⌘": modifiers |= cmdKey
            case "⇧": modifiers |= shiftKey
            case "⌥": modifiers |= optionKey
            case "⌃": modifiers |= controlKey
            default: keyChar = char
            }
        }

        guard let key = keyChar else { return nil }

        // 간단한 키 코드 매핑
        let keyCodeMap: [Character: Int] = [
            "A": kVK_ANSI_A, "B": kVK_ANSI_B, "C": kVK_ANSI_C, "D": kVK_ANSI_D,
            "E": kVK_ANSI_E, "F": kVK_ANSI_F, "G": kVK_ANSI_G, "H": kVK_ANSI_H,
            "I": kVK_ANSI_I, "J": kVK_ANSI_J, "K": kVK_ANSI_K, "L": kVK_ANSI_L,
            "M": kVK_ANSI_M, "N": kVK_ANSI_N, "O": kVK_ANSI_O, "P": kVK_ANSI_P,
            "Q": kVK_ANSI_Q, "R": kVK_ANSI_R, "S": kVK_ANSI_S, "T": kVK_ANSI_T,
            "U": kVK_ANSI_U, "V": kVK_ANSI_V, "W": kVK_ANSI_W, "X": kVK_ANSI_X,
            "Y": kVK_ANSI_Y, "Z": kVK_ANSI_Z
        ]

        guard let keyCode = keyCodeMap[Character(key.uppercased())] else { return nil }
        return (keyCode, modifiers)
    }
}
