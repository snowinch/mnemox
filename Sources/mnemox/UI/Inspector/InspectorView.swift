import SwiftUI
import Luminare

struct InspectorView: View {
    @Environment(AppState.self) private var state

    var body: some View {
        @Bindable var state = state
        VStack(spacing: 0) {
            tabBar
            Divider()
            tabContent
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .frame(maxHeight: .infinity)
    }

    private var tabBar: some View {
        HStack(spacing: 2) {
            ForEach(InspectorTab.allCases) { tab in
                inspectorTab(tab)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
    }

    private func inspectorTab(_ tab: InspectorTab) -> some View {
        @Bindable var state = state
        let isSelected = state.inspectorTab == tab
        return Button {
            state.inspectorTab = tab
        } label: {
            VStack(spacing: 3) {
                Image(systemName: tab.icon)
                    .font(.system(size: 12))
                Text(tab.label)
                    .font(.system(size: 9, weight: .medium))
            }
            .foregroundStyle(isSelected ? Color.blue : Color(nsColor: .tertiaryLabelColor))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(isSelected ? Color.blue.opacity(0.1) : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var tabContent: some View {
        switch state.inspectorTab {
        case .git:
            GitDiffView()
        case .browser:
            BrowserView()
        case .terminal:
            TerminalView()
        case .files:
            FilesView()
        }
    }
}
