import SwiftUI
import Luminare

@main
struct MnemoxApp: App {
    @State private var state = AppState()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(state)
                .preferredColorScheme(.dark)
                .onAppear { state.load() }
        }
        .windowStyle(.hiddenTitleBar)
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
