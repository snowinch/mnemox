import SwiftUI
import Luminare

struct RootView: View {
    @Environment(AppState.self) private var state

    var body: some View {
        @Bindable var state = state
        LuminareView {
            LuminareDividedStack(.horizontal) {
                if state.sidebarVisible {
                    SidebarView()
                        .frame(width: 220)
                        .transition(.move(edge: .leading).combined(with: .opacity))
                }

                CenterView()
                    .frame(maxWidth: .infinity)

                if state.inspectorVisible {
                    InspectorView()
                        .frame(width: 380)
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
            .animation(.easeInOut(duration: 0.2), value: state.sidebarVisible)
            .animation(.easeInOut(duration: 0.2), value: state.inspectorVisible)
        }
        .luminareMinHeight(26)
        .luminareHorizontalPadding(6)
        .luminareCornerRadii(.init(6))
        .luminareButtonCornerRadii(.init(4))
        .luminareTint(overridingWith: .blue)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}
