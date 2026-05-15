import SwiftUI

struct GitDiffView: View {
    @State private var diff: String = ""
    @State private var isLoading = false

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if diff.isEmpty {
                emptyState
            } else {
                diffContent
            }
        }
        .onAppear { refreshDiff() }
    }

    private var toolbar: some View {
        HStack {
            Text("Git Diff")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color(nsColor: .secondaryLabelColor))
            Spacer(minLength: 0)
            Button {
                refreshDiff()
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 11))
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color(nsColor: .tertiaryLabelColor))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 24))
                .foregroundStyle(Color(nsColor: .tertiaryLabelColor))
            Text("Working tree clean")
                .font(.system(size: 12))
                .foregroundStyle(Color(nsColor: .tertiaryLabelColor))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var diffContent: some View {
        ScrollView {
            Text(diff)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(Color(nsColor: .labelColor))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
        }
    }

    private func refreshDiff() {
        isLoading = true
        DispatchQueue.global().async {
            let result = shell("git diff HEAD 2>/dev/null || echo ''")
            DispatchQueue.main.async {
                diff = result.trimmingCharacters(in: .whitespacesAndNewlines)
                isLoading = false
            }
        }
    }
}

@discardableResult
func shell(_ command: String) -> String {
    let task = Process()
    task.launchPath = "/bin/zsh"
    task.arguments = ["-c", command]
    let pipe = Pipe()
    task.standardOutput = pipe
    task.standardError = Pipe()
    try? task.run()
    task.waitUntilExit()
    return String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
}
