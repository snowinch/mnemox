import SwiftUI

/// Multiline editor that starts at one line, grows with content, and scrolls past `maxHeight`.
struct GrowingTextEditor: View {
    @Binding var text: String
    var placeholder: String
    @FocusState.Binding var isFocused: Bool
    var fontSize: CGFloat = 12
    var minHeight: CGFloat = 22
    var maxHeight: CGFloat = 120
    var onKeyReturn: (KeyPress) -> KeyPress.Result

    @State private var measuredHeight: CGFloat = 22

    private var font: Font { .system(size: fontSize) }

    /// Matches macOS `TextEditor` text-container inset (plain style, hidden scroll background).
    private var contentInset: EdgeInsets {
        EdgeInsets(top: 5, leading: 5, bottom: 5, trailing: 5)
    }

    private var editorHeight: CGFloat {
        min(max(measuredHeight, minHeight), maxHeight)
    }

    private var isScrollable: Bool {
        measuredHeight > maxHeight
    }

    var body: some View {
        TextEditor(text: $text)
            .font(font)
            .scrollContentBackground(.hidden)
            .background(.clear)
            .focused($isFocused)
            .foregroundStyle(Color(nsColor: .labelColor))
            .frame(height: editorHeight)
            .scrollDisabled(!isScrollable)
            .onKeyPress(.return, phases: .down, action: onKeyReturn)
            .background(alignment: .topLeading) {
                measurementView
            }
            .overlay(alignment: .topLeading) {
                if text.isEmpty {
                    Text(placeholder)
                        .font(font)
                        .foregroundStyle(Color(nsColor: .quaternaryLabelColor))
                        .padding(contentInset)
                        .allowsHitTesting(false)
                }
            }
            .onPreferenceChange(TextHeightPreferenceKey.self) { measuredHeight = $0 }
    }

    /// Height probe only — lives in `.background` so it cannot expand the outer layout.
    private var measurementView: some View {
        Text(text.isEmpty ? " " : text)
            .font(font)
            .lineSpacing(0)
            .padding(contentInset)
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
            .background(
                GeometryReader { proxy in
                    Color.clear.preference(
                        key: TextHeightPreferenceKey.self,
                        value: proxy.size.height
                    )
                }
            )
            .hidden()
            .allowsHitTesting(false)
    }
}

private struct TextHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 22
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}
