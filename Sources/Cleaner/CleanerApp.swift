import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

@main
struct CleanerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var settings = Settings.shared
    @StateObject private var state = AppState()
    @StateObject private var updater = Updater()

    var body: some Scene {
        WindowGroup {
            ThemedRoot()
                .environmentObject(settings)
                .environmentObject(state)
                .environmentObject(updater)
                .frame(minWidth: 1000, minHeight: 640)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1200, height: 780)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandGroup(after: .appInfo) {
                Button(T("Nach Updates suchen …", "Check for Updates …")) { state.section = .settings; updater.check() }
            }
            CommandMenu("Scan") {
                Button(T("Neu scannen", "Rescan")) { state.startScan() }.keyboardShortcut("r", modifiers: .command)
            }
        }
    }
}
