import SwiftUI

@main
struct CommandBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 280, minHeight: 300)
        }
        .windowStyle(.titleBar)
        .defaultSize(width: 300, height: 400)
    }
}
