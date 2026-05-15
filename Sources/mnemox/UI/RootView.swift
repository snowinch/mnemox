import SwiftUI

struct RootView: View {
    @Environment(AppState.self) private var state

    var body: some View {
        @Bindable var state = state

        HStack(spacing: 0) {
            // --- COLONNA SIDEBAR ---
            if state.sidebarVisible {
                VStack(spacing: 0) {
                    HStack {
                        sidebarToggle(icon: "sidebar.left", active: true) {
                            state.sidebarVisible.toggle()
                        }
                        .padding(.leading, 84)
                        Spacer()
                    }
                    .frame(height: 38, alignment: .top)
                    .padding(.top, 3)
                    
                    SidebarView()
                }
                .frame(width: 216)
                
                Divider().ignoresSafeArea()
            }

            // --- COLONNA CENTRALE ---
            VStack(spacing: 0) {
                HStack(alignment: .top) {
                    if !state.sidebarVisible {
                        sidebarToggle(icon: "sidebar.left", active: false) {
                            state.sidebarVisible.toggle()
                        }
                        .padding(.leading, 84)
                    }
                    Spacer()
                    if !state.inspectorVisible {
                        sidebarToggle(icon: "sidebar.right", active: false) {
                            state.inspectorVisible.toggle()
                        }
                        .padding(.trailing, 12)
                    }
                }
                .frame(height: 38, alignment: .top)
                .padding(.top, 3)
                
                CenterView()
            }
            .frame(maxWidth: .infinity)

            // --- COLONNA INSPECTOR ---
            if state.inspectorVisible {
                Divider().ignoresSafeArea()

                VStack(spacing: 0) {
                    HStack(alignment: .top, spacing: 2) {
                        ForEach(InspectorTab.allCases) { tab in
                            inspectorTabBtn(tab)
                                .padding(.top, 5)
                        }
                        Spacer()
                        sidebarToggle(icon: "sidebar.right", active: true) {
                            state.inspectorVisible.toggle()
                        }
                        .padding(.trailing, 12)
                    }
                    .padding(.leading, 8)
                    .padding(.top, 3)
                    .frame(height: 38, alignment: .top)

                    Divider().opacity(0.3)
                    InspectorView()
                }
                .frame(width: 360)
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .ignoresSafeArea()
        // Rimossi tutti i modificatori .animation(...)
        .keyboardShortcut("b", modifiers: .command)
        .keyboardShortcut("r", modifiers: [.command, .shift])
    }

    private func inspectorTabBtn(_ tab: InspectorTab) -> some View {
        @Bindable var state = state
        let sel = state.inspectorTab == tab
        return Button { state.inspectorTab = tab } label: {
            HStack(spacing: 3) {
                Image(systemName: tab.icon).font(.system(size: 10))
                Text(tab.label).font(.system(size: 11))
            }
            .foregroundStyle(sel ? Color(nsColor: .labelColor) : Color(nsColor: .quaternaryLabelColor))
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(sel ? Color.white.opacity(0.07) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .buttonStyle(.plain)
    }

    private func sidebarToggle(icon: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(Font.system(size: 13, weight: Font.Weight.medium))
                .foregroundStyle(active 
                                 ? Color.primary.opacity(0.8) 
                                 : Color.secondary.opacity(0.6))
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}