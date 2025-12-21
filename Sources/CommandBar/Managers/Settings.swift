import SwiftUI
import AppKit
import ServiceManagement

class Settings: ObservableObject {
    @Published var alwaysOnTop: Bool {
        didSet {
            UserDefaults.standard.set(alwaysOnTop, forKey: "alwaysOnTop")
            applyAlwaysOnTop()
        }
    }
    @Published var maxHistoryCount: Int {
        didSet {
            UserDefaults.standard.set(maxHistoryCount, forKey: "maxHistoryCount")
        }
    }
    @Published var launchAtLogin: Bool {
        didSet {
            UserDefaults.standard.set(launchAtLogin, forKey: "launchAtLogin")
            applyLaunchAtLogin()
        }
    }
    @Published var backgroundOpacity: Double {
        didSet {
            UserDefaults.standard.set(backgroundOpacity, forKey: "backgroundOpacity")
            applyBackgroundOpacity()
        }
    }
    @Published var notesFolderName: String {
        didSet {
            UserDefaults.standard.set(notesFolderName, forKey: "notesFolderName")
        }
    }
    @Published var maxClipboardCount: Int {
        didSet {
            UserDefaults.standard.set(maxClipboardCount, forKey: "maxClipboardCount")
        }
    }

    init() {
        self.alwaysOnTop = UserDefaults.standard.bool(forKey: "alwaysOnTop")
        let saved = UserDefaults.standard.integer(forKey: "maxHistoryCount")
        self.maxHistoryCount = saved > 0 ? saved : 100
        self.launchAtLogin = UserDefaults.standard.bool(forKey: "launchAtLogin")
        let savedOpacity = UserDefaults.standard.double(forKey: "backgroundOpacity")
        self.backgroundOpacity = savedOpacity > 0 ? savedOpacity : 1.0
        self.notesFolderName = UserDefaults.standard.string(forKey: "notesFolderName") ?? "클립보드 메모"
        let savedClipboardCount = UserDefaults.standard.integer(forKey: "maxClipboardCount")
        self.maxClipboardCount = savedClipboardCount > 0 ? savedClipboardCount : 10000
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
}
