import SwiftUI
import Foundation

@Observable @MainActor
final class TerminalRunner {
    var output: String = ""
    var isRunning = false
    private var process: Process?

    func run(_ command: String) {
        output += "$ \(command)\n"
        isRunning = true
        let p = Process()
        p.launchPath = "/bin/zsh"
        p.arguments = ["-c", command]
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = pipe
        let handle = pipe.fileHandleForReading
        handle.readabilityHandler = { [weak self] fh in
            let data = fh.availableData
            guard !data.isEmpty, let str = String(data: data, encoding: .utf8) else { return }
            Task { @MainActor [weak self] in
                self?.output += str
            }
        }
        p.terminationHandler = { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.isRunning = false
                self?.output += "\n"
            }
        }
        try? p.run()
        process = p
    }

    func clear() { output = "" }
    func interrupt() { process?.interrupt() }
}

struct TerminalView: View {
    @State private var runner = TerminalRunner()
    @State private var command = ""
    @FocusState private var inputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            outputArea
            Divider()
            inputRow
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { inputFocused = true }
        }
    }

    private var toolbar: some View {
        HStack {
            Label("Terminal", systemImage: "terminal")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color(nsColor: .secondaryLabelColor))
            Spacer(minLength: 0)
            if runner.isRunning {
                Button {
                    runner.interrupt()
                } label: {
                    Image(systemName: "stop.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.red)
                }
                .buttonStyle(.plain)
            }
            Button {
                runner.clear()
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 11))
                    .foregroundStyle(Color(nsColor: .tertiaryLabelColor))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    private var outputArea: some View {
        ScrollViewReader { proxy in
            ScrollView {
                Text(runner.output.isEmpty ? " " : runner.output)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(Color(nsColor: .labelColor))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                    .id("end")
            }
            .onChange(of: runner.output) { _, _ in
                proxy.scrollTo("end", anchor: .bottom)
            }
        }
    }

    private var inputRow: some View {
        HStack(spacing: 6) {
            Text("$")
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(Color.green)

            TextField("", text: $command)
                .font(.system(size: 12, design: .monospaced))
                .textFieldStyle(.plain)
                .focused($inputFocused)
                .onSubmit {
                    let cmd = command.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !cmd.isEmpty else { return }
                    command = ""
                    runner.run(cmd)
                }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color(nsColor: .controlBackgroundColor))
    }
}
