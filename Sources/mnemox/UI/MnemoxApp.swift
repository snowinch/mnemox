import SwiftUI
import Luminare
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            sender.windows.first?.makeKeyAndOrderFront(nil)
        }
        return true
    }
}

@main
struct MnemoxApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var state = AppState()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(state)
                .preferredColorScheme(.dark)
                .onAppear { state.load() }
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unified(showsTitle: false))
        .defaultSize(width: 1440, height: 900)
        .commands { AppCommands(state: state) }
    }
}

struct AppCommands: Commands {
    let state: AppState

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("New Agent") { state.newAgent() }
                .keyboardShortcut("n", modifiers: .command)
        }
        CommandGroup(replacing: .sidebar) {
            Button("Toggle Sidebar") { state.sidebarVisible.toggle() }
                .keyboardShortcut("b", modifiers: .command)
            Button("Toggle Inspector") { state.inspectorVisible.toggle() }
                .keyboardShortcut("r", modifiers: [.command, .shift])
        }
    }
}
