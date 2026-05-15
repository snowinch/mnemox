import SwiftUI

private struct FileNode: Identifiable {
    var id: URL { url }
    let url: URL
    let isDirectory: Bool
    var children: [FileNode]?
    var isExpanded = false
}

struct FilesView: View {
    @State private var topLevel: [FileNode] = []
    @State private var expandedDirs: Set<URL> = []

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            fileList
        }
        .onAppear { loadRoot() }
    }

    private var toolbar: some View {
        HStack {
            Label("Files", systemImage: "folder")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color(nsColor: .secondaryLabelColor))
            Spacer(minLength: 0)
            Button { loadRoot() } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 11))
                    .foregroundStyle(Color(nsColor: .tertiaryLabelColor))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    private var fileList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(flatRows()) { row in
                    fileRow(row)
                }
            }
            .padding(.vertical, 4)
        }
    }

    private func fileRow(_ row: FlatRow) -> some View {
        HStack(spacing: 4) {
            Color.clear.frame(width: CGFloat(row.depth) * 12)

            if row.isDirectory {
                Image(systemName: expandedDirs.contains(row.url) ? "chevron.down" : "chevron.right")
                    .font(.system(size: 8))
                    .foregroundStyle(Color(nsColor: .tertiaryLabelColor))
                    .frame(width: 10)
            } else {
                Color.clear.frame(width: 10)
            }

            Image(systemName: row.isDirectory ? "folder" : fileIcon(for: row.url))
                .font(.system(size: 11))
                .foregroundStyle(row.isDirectory ? Color.blue.opacity(0.8) : Color(nsColor: .secondaryLabelColor))
                .frame(width: 14)

            Text(row.url.lastPathComponent)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(Color(nsColor: .labelColor))
                .lineLimit(1)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .contentShape(Rectangle())
        .onTapGesture {
            if row.isDirectory {
                if expandedDirs.contains(row.url) {
                    expandedDirs.remove(row.url)
                } else {
                    expandedDirs.insert(row.url)
                    loadChildren(for: row.url)
                }
            }
        }
    }

    private struct FlatRow: Identifiable {
        let id: URL
        let url: URL
        let depth: Int
        let isDirectory: Bool
    }

    private func flatRows() -> [FlatRow] {
        var result: [FlatRow] = []
        func walk(_ nodes: [FileNode], depth: Int) {
            for node in nodes {
                result.append(FlatRow(id: node.url, url: node.url, depth: depth, isDirectory: node.isDirectory))
                if node.isDirectory && expandedDirs.contains(node.url) {
                    walk(node.children ?? [], depth: depth + 1)
                }
            }
        }
        walk(topLevel, depth: 0)
        return result
    }

    private func loadRoot() {
        let fm = FileManager.default
        let cwd = URL(fileURLWithPath: fm.currentDirectoryPath)
        topLevel = loadChildren(at: cwd)
    }

    private func loadChildren(for url: URL) {
        guard let idx = topLevel.firstIndex(where: { $0.url == url }) else { return }
        topLevel[idx].children = loadChildren(at: url)
    }

    private func loadChildren(at url: URL) -> [FileNode] {
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(at: url, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]) else { return [] }
        return contents
            .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
            .compactMap { child -> FileNode? in
                let isDir = (try? child.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
                return FileNode(url: child, isDirectory: isDir, children: isDir ? [] : nil)
            }
            .sorted { $0.isDirectory && !$1.isDirectory }
    }

    private func fileIcon(for url: URL) -> String {
        switch url.pathExtension.lowercased() {
        case "swift": return "swift"
        case "json": return "curlybraces"
        case "md": return "doc.text"
        case "sh": return "terminal"
        case "png", "jpg", "jpeg", "gif", "svg": return "photo"
        default: return "doc"
        }
    }
}
