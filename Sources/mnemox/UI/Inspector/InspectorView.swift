import SwiftUI

struct InspectorView: View {
    @Environment(AppState.self) private var state

    var body: some View {
        @Bindable var state = state
        VStack(spacing: 0) {
            tabBar
            Divider().opacity(0.3)
            tabContent
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .frame(maxHeight: .infinity)
    }

    private var tabBar: some View {
        HStack(spacing: 1) {
            ForEach(InspectorTab.allCases) { tab in
                tabBtn(tab)
            }
            Spacer(minLength: 0)
            Button {
                state.inspectorVisible = false
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9))
                    .foregroundStyle(Color(nsColor: .quaternaryLabelColor))
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .frame(height: 34)
    }

    private func tabBtn(_ tab: InspectorTab) -> some View {
        let sel = state.inspectorTab == tab
        return Button {
            state.inspectorTab = tab
        } label: {
            HStack(spacing: 3) {
                Image(systemName: tab.icon)
                    .font(.system(size: 10))
                Text(tab.label)
                    .font(.system(size: 11))
            }
            .foregroundStyle(sel ? Color(nsColor: .labelColor) : Color(nsColor: .quaternaryLabelColor))
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(sel ? Color.white.opacity(0.07) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .buttonStyle(.plain)
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
