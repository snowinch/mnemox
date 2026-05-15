import SwiftUI
import WebKit

struct BrowserView: View {
    @State private var urlString = "https://google.com"
    @State private var committedURL: URL? = URL(string: "https://google.com")

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            if let url = committedURL {
                WebViewRepresentable(url: url)
            }
        }
    }

    private var toolbar: some View {
        HStack(spacing: 6) {
            TextField("URL", text: $urlString)
                .font(.system(size: 11, design: .monospaced))
                .textFieldStyle(.plain)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .onSubmit { navigate() }

            Button("Go") { navigate() }
                .buttonStyle(.plain)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.blue)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
    }

    private func navigate() {
        var raw = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        if !raw.hasPrefix("http://") && !raw.hasPrefix("https://") {
            raw = "https://" + raw
        }
        committedURL = URL(string: raw)
    }
}

struct WebViewRepresentable: NSViewRepresentable {
    let url: URL

    func makeNSView(context: Context) -> WKWebView {
        WKWebView()
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        let request = URLRequest(url: url)
        if webView.url != url {
            webView.load(request)
        }
    }
}
