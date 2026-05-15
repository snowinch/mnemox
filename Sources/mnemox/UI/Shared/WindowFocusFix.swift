import SwiftUI
import AppKit

struct WindowFocusFix: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = FocusFixView()
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

private class FocusFixView: NSView {
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard let window else { return }
        DispatchQueue.main.async {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}
