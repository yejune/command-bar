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
    @Published var backgroundOpacity: Double {
        didSet {
            db.setDoubleSetting("backgroundOpacity", value: backgroundOpacity)
            applyBackgroundOpacity()
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
    @Published var hideShortcut: String {
        didSet {
            db.setSetting("hideShortcut", value: hideShortcut)
            registerHotKey()
        }
    }

    private var appearanceObserver: NSObjectProtocol?
    private var mouseMonitor: Any?
    private var hotKeyRef: EventHotKeyRef?
    private var isHidden = false

    init() {
        // UserDefaults에서 마이그레이션 (프로퍼티 초기화 전에 실행)
        Self.migrateFromUserDefaults(db: db)

        self.alwaysOnTop = db.getBoolSetting("alwaysOnTop", defaultValue: false)
        self.launchAtLogin = db.getBoolSetting("launchAtLogin", defaultValue: false)
        self.backgroundOpacity = db.getDoubleSetting("backgroundOpacity", defaultValue: 1.0)
        self.notesFolderName = db.getSetting("notesFolderName") ?? "클립보드 메모"
        self.autoHide = db.getBoolSetting("autoHide", defaultValue: false)
        self.hideShortcut = db.getSetting("hideShortcut") ?? "⌘⇧H"

        // 시스템 테마 변경 감지
        appearanceObserver = DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name("AppleInterfaceThemeChangedNotification"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.applyBackgroundOpacity()
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
            for window in NSApp.windows where window.canBecomeMain {
                window.isOpaque = self.backgroundOpacity >= 1.0
                window.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(self.backgroundOpacity)
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
        mouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved]) { [weak self] event in
            self?.handleMouseMoved(event)
        }
    }

    private func stopMouseMonitor() {
        if let monitor = mouseMonitor {
            NSEvent.removeMonitor(monitor)
            mouseMonitor = nil
        }
    }

    private func handleMouseMoved(_ event: NSEvent) {
        guard let window = NSApp.mainWindow, let screen = window.screen else { return }

        let mouseLocation = NSEvent.mouseLocation
        let windowFrame = window.frame
        let screenFrame = screen.frame

        if isHidden {
            // 숨겨진 상태: 화면 가장자리에 마우스가 가면 표시
            let edgeThreshold: CGFloat = 5

            // 창이 왼쪽에 있었는지 오른쪽에 있었는지 확인
            let wasOnLeft = windowFrame.minX <= screenFrame.minX + 50
            let wasOnRight = windowFrame.maxX >= screenFrame.maxX - 50

            if wasOnLeft && mouseLocation.x <= screenFrame.minX + edgeThreshold {
                showWindow()
            } else if wasOnRight && mouseLocation.x >= screenFrame.maxX - edgeThreshold {
                showWindow()
            }
        } else {
            // 보이는 상태: 마우스가 창을 벗어나면 숨기기
            let expandedFrame = windowFrame.insetBy(dx: -20, dy: -20)
            if !expandedFrame.contains(mouseLocation) {
                hideWindow()
            }
        }
    }

    func hideWindow() {
        guard !isHidden, autoHide else { return }
        guard let window = NSApp.mainWindow, let screen = window.screen else { return }

        let windowFrame = window.frame
        let screenFrame = screen.visibleFrame

        // 창이 왼쪽에 가까운지 오른쪽에 가까운지 확인
        let distanceToLeft = windowFrame.minX - screenFrame.minX
        let distanceToRight = screenFrame.maxX - windowFrame.maxX

        var newFrame = windowFrame
        if distanceToLeft < distanceToRight {
            // 왼쪽으로 숨기기 (5px만 보이게)
            newFrame.origin.x = screenFrame.minX - windowFrame.width + 5
        } else {
            // 오른쪽으로 숨기기 (5px만 보이게)
            newFrame.origin.x = screenFrame.maxX - 5
        }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            window.animator().setFrame(newFrame, display: true)
        }

        isHidden = true
    }

    func showWindow() {
        guard isHidden else { return }
        guard let window = NSApp.mainWindow, let screen = window.screen else { return }

        let windowFrame = window.frame
        let screenFrame = screen.visibleFrame

        var newFrame = windowFrame

        // 화면 안으로 복원
        if windowFrame.minX < screenFrame.minX {
            newFrame.origin.x = screenFrame.minX
        } else if windowFrame.maxX > screenFrame.maxX {
            newFrame.origin.x = screenFrame.maxX - windowFrame.width
        }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            window.animator().setFrame(newFrame, display: true)
        }

        isHidden = false
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
        guard let (keyCode, modifiers) = parseShortcut(hideShortcut) else { return }

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
