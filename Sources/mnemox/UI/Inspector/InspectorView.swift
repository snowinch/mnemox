import SwiftUI

struct InspectorView: View {
    @Environment(AppState.self) private var state

    var body: some View {
        tabContent
            .background(Color(nsColor: .windowBackgroundColor))
            .frame(maxHeight: .infinity)
    }

    @ViewBuilder
    private var tabContent: some View {
        switch state.inspectorTab {
        case .git:      GitDiffView()
        case .browser:  BrowserView()
        case .terminal: TerminalView()
        case .files:    FilesView()
        }
    }
}
