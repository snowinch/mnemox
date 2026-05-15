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
            ToolbarItem(placement: .principal) {
                HStack {
                    toolbarToggle(icon: "sidebar.left", active: state.sidebarVisible) {
                        withAnimation(.spring(duration: 0.22, bounce: 0)) {
                            state.sidebarVisible.toggle()
                        }
                    }
                    .keyboardShortcut("b", modifiers: .command)

                    Spacer()

                    toolbarToggle(icon: "sidebar.right", active: state.inspectorVisible) {
                        withAnimation(.spring(duration: 0.22, bounce: 0)) {
                            state.inspectorVisible.toggle()
                        }
                    }
                    .keyboardShortcut("r", modifiers: [.command, .shift])
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func toolbarToggle(icon: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(active
                                 ? Color(nsColor: .labelColor).opacity(0.7)
                                 : Color(nsColor: .quaternaryLabelColor))
                .frame(width: 26, height: 20)
                .background(active ? Color.white.opacity(0.08) : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .buttonStyle(.plain)
    }
}
