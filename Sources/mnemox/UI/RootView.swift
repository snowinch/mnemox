import SwiftUI

struct RootView: View {
    @Environment(AppState.self) private var state

    var body: some View {
        @Bindable var state = state

        HStack(spacing: 0) {
            if state.sidebarVisible {
                SidebarView()
                    .frame(width: 216)
                    .transition(.move(edge: .leading))
                Divider()
            }

            CenterView()
                .frame(maxWidth: .infinity)

            if state.inspectorVisible {
                Divider()
                InspectorView()
                    .frame(width: 360)
                    .transition(.move(edge: .trailing))
            }
        }
        .animation(.spring(duration: 0.22, bounce: 0), value: state.sidebarVisible)
        .animation(.spring(duration: 0.22, bounce: 0), value: state.inspectorVisible)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
        .background(WindowFocusFix())
        .toolbar {
            ToolbarItem(placement: .navigation) {
                sidebarToggle(icon: "sidebar.left", active: state.sidebarVisible) {
                    withAnimation(.spring(duration: 0.22, bounce: 0)) {
                        state.sidebarVisible.toggle()
                    }
                }
                .keyboardShortcut("b", modifiers: .command)
            }
            ToolbarItem(placement: .primaryAction) {
                sidebarToggle(icon: "sidebar.right", active: state.inspectorVisible) {
                    withAnimation(.spring(duration: 0.22, bounce: 0)) {
                        state.inspectorVisible.toggle()
                    }
                }
                .keyboardShortcut("r", modifiers: [.command, .shift])
            }
        }
    }

    private func sidebarToggle(icon: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .foregroundStyle(active
                                 ? Color(nsColor: .labelColor).opacity(0.75)
                                 : Color(nsColor: .tertiaryLabelColor))
        }
        .buttonStyle(.plain)
    }
}
