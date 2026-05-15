import SwiftUI
import Observation
import AppKit

enum DiffPresentation: String, CaseIterable, Identifiable {
    case split
    case unified

    var id: String { rawValue }

    var label: String {
        switch self {
        case .split: "Split"
        case .unified: "Unified"
        }
    }
}

@Observable @MainActor
final class DiffViewModel {
    var pendingChanges: [FileChange] = []
    var selectedChange: FileChange?
    var isApplying = false
    var presentation: DiffPresentation = .split

    func applyAggregatedResult(_ result: AggregatedResult) {
        pendingChanges = result.fileChanges
        selectedChange = result.fileChanges.first
    }

    func clear() {
        pendingChanges = []
        selectedChange = nil
    }

    func undo(change: FileChange) {
        pendingChanges.removeAll { $0.path == change.path }
        if selectedChange?.path == change.path {
            selectedChange = pendingChanges.first
        }
    }

    func applyAllChanges() {
        guard pendingChanges.isEmpty == false else {
            return
        }
        isApplying = true
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 150_000_000)
            pendingChanges.removeAll()
            selectedChange = nil
            isApplying = false
        }
    }

    func discardAll() {
        pendingChanges.removeAll()
        selectedChange = nil
    }

    func placeholderCreateBranch() {
        let alert = NSAlert()
        alert.messageText = "Create Branch & Commit"
        alert.informativeText = "Git automation will arrive in a later phase."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}

struct DiffView: View {
    @Bindable var model: DiffViewModel

    var body: some View {
        VStack(spacing: 0) {
            changePicker

            if let change = model.selectedChange {
                topBar(for: change)
                Divider()
                presentationBody(for: change)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                Divider()
                footer
            } else {
                EmptyState(
                    systemImage: "list.number",
                    title: "No pending changes",
                    subtitle: "When the main agent proposes edits, they appear here for review.",
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(minWidth: 360, idealWidth: 420)
    }

    private var changePicker: some View {
        Group {
            if model.pendingChanges.count > 1 {
                Picker(
                    "Pending file",
                    selection: Binding(
                        get: { model.selectedChange?.path.path ?? "" },
                        set: { path in
                            model.selectedChange = model.pendingChanges.first { $0.path.path == path }
                        },
                    ),
                ) {
                    ForEach(model.pendingChanges, id: \.path) { change in
                        Text(change.path.lastPathComponent).tag(change.path.path)
                    }
                }
                .labelsHidden()
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .accessibilityLabel("Select pending file change")
            }
        }
    }

    private func topBar(for change: FileChange) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(change.path.lastPathComponent)
                    .font(.headline)
                    .lineLimit(1)
                Text(changeTypeLabel(change.changeType))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()

            Picker("Layout", selection: $model.presentation) {
                ForEach(DiffPresentation.allCases) { mode in
                    Text(mode.label).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(maxWidth: 220)
            .accessibilityLabel("Diff layout")

            MnemoxButton(title: "Undo", systemImage: "arrow.uturn.left", role: .secondary) {
                model.undo(change: change)
            }
            .disabled(model.isApplying)
        }
        .padding(12)
    }

    private func presentationBody(for change: FileChange) -> some View {
        Group {
            switch model.presentation {
            case .split:
                splitDiff(change: change)
            case .unified:
                unifiedDiff(change: change)
            }
        }
        .padding(8)
    }

    private func splitDiff(change: FileChange) -> some View {
        HStack(alignment: .top, spacing: 0) {
            diffColumn(title: "Original", lines: lined(change.originalContent ?? ""), style: .removed)
            Divider()
            diffColumn(title: "Proposed", lines: lined(change.newContent), style: .added)
        }
    }

    private func unifiedDiff(change: FileChange) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 2) {
                ForEach(Array(unifiedRows(old: change.originalContent, new: change.newContent).enumerated()), id: \.offset) { _, row in
                    HStack(alignment: .top, spacing: 8) {
                        Text(row.leftNumber.map(String.init) ?? "")
                            .frame(width: 32, alignment: .trailing)
                            .foregroundStyle(.secondary)
                            .font(.system(.caption2, design: .monospaced))
                        Text(row.rightNumber.map(String.init) ?? "")
                            .frame(width: 32, alignment: .trailing)
                            .foregroundStyle(.secondary)
                            .font(.system(.caption2, design: .monospaced))
                        Text(row.text)
                            .font(.system(.callout, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(4)
                            .background(row.style.background)
                    }
                }
            }
        }
        .background(Color(nsColor: .textBackgroundColor))
    }

    private func diffColumn(title: String, lines: [String], style: LineTint) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.caption.weight(.semibold))
                .padding(.bottom, 6)
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                        HStack(alignment: .top, spacing: 6) {
                            Text("\(index + 1)")
                                .frame(width: 28, alignment: .trailing)
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundStyle(.secondary)
                            Text(line)
                                .font(.system(.callout, design: .monospaced))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(4)
                        .background(style.background)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(8)
    }

    private func lined(_ text: String) -> [String] {
        text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
    }

    private var footer: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                MnemoxButton(title: "Apply Changes", systemImage: "checkmark.circle.fill", role: .primary) {
                    model.applyAllChanges()
                }
                .disabled(model.pendingChanges.isEmpty || model.isApplying)

                MnemoxButton(title: "Discard", systemImage: "xmark.circle", role: .secondary) {
                    model.discardAll()
                }
                .disabled(model.pendingChanges.isEmpty || model.isApplying)

                Spacer()

                MnemoxButton(
                    title: "Create Branch & Commit",
                    systemImage: "arrow.triangle.branch",
                    role: .secondary,
                ) {
                    model.placeholderCreateBranch()
                }
                .disabled(model.pendingChanges.isEmpty)
            }
        }
        .padding(12)
    }

    private func changeTypeLabel(_ type: ChangeType) -> String {
        switch type {
        case .create: "New file"
        case .modify: "Modified"
        case .delete: "Deleted"
        }
    }
}
