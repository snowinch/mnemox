import Foundation

/// Persists reversible checkpoints beneath `.mnemox/snapshots`.
public struct SnapshotManager: Sendable {
    private let maximumRetainedSnapshots = 10

    public init() {}

    public func createSnapshot(root: URL) async throws -> ProjectSnapshot {
        let rootURL = root.standardizedFileURL
        guard FileManager.default.fileExists(atPath: rootURL.path) else {
            throw CoreIntelligenceError.missingRoot(rootURL)
        }

        let relatives = try ProjectScanner.trackedSourceFiles(root: rootURL)
        let id = makeSnapshotIdentifier(prefix: "snap")

        let fileSnapshots = try await hashSources(rootURL: rootURL, relatives: relatives)

        let plan = ExecutionPlan(action: "checkpoint", target: rootURL.path, steps: [])
        let snapshot = ProjectSnapshot(id: id, timestamp: Date(), files: fileSnapshots, agentPlan: plan, mxfLog: [])

        let snapshotDirectory = rootURL.appendingPathComponent(".mnemox/snapshots/\(id)", isDirectory: true)
        let payloadDirectory = snapshotDirectory.appendingPathComponent("files", isDirectory: true)

        try FileManager.default.createDirectory(at: payloadDirectory, withIntermediateDirectories: true)

        for relative in relatives {
            let sourceURL = rootURL.appendingPathComponent(relative)
            let destinationURL = payloadDirectory.appendingPathComponent(relative)
            try FileManager.default.createDirectory(at: destinationURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            guard FileManager.default.fileExists(atPath: sourceURL.path) else {
                continue
            }
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }
            try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
        }

        let manifestURL = snapshotDirectory.appendingPathComponent("manifest.json")
        try encodeManifest(snapshot).write(to: manifestURL, options: .atomic)

        try pruneSnapshots(rootURL: rootURL)

        return snapshot
    }

    public func restore(snapshot: ProjectSnapshot) async throws {
        let rootURL = URL(fileURLWithPath: snapshot.agentPlan.target).standardizedFileURL
        let snapshotDirectory = rootURL.appendingPathComponent(".mnemox/snapshots/\(snapshot.id)")
        let payloadDirectory = snapshotDirectory.appendingPathComponent("files")

        guard FileManager.default.fileExists(atPath: snapshotDirectory.path) else {
            throw CoreIntelligenceError.invalidManifest(snapshotDirectory)
        }

        let stagingRoot = rootURL.appendingPathComponent(".mnemox/.restore-stage-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: stagingRoot, withIntermediateDirectories: true)

        defer {
            try? FileManager.default.removeItem(at: stagingRoot)
        }

        for tracked in snapshot.files {
            let backupSource = payloadDirectory.appendingPathComponent(tracked.relativePath)
            guard FileManager.default.fileExists(atPath: backupSource.path) else {
                continue
            }
            let stagedTarget = stagingRoot.appendingPathComponent(tracked.relativePath)
            try FileManager.default.createDirectory(at: stagedTarget.deletingLastPathComponent(), withIntermediateDirectories: true)
            if FileManager.default.fileExists(atPath: stagedTarget.path) {
                try FileManager.default.removeItem(at: stagedTarget)
            }
            try FileManager.default.copyItem(at: backupSource, to: stagedTarget)
        }

        let enumerator = FileManager.default.enumerator(at: stagingRoot, includingPropertiesForKeys: nil)
        while let item = enumerator?.nextObject() as? URL {
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: item.path, isDirectory: &isDirectory),
                  isDirectory.boolValue == false else {
                continue
            }

            let relative = item.pathRelative(to: stagingRoot)
            let destination = rootURL.appendingPathComponent(relative)
            try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
            try atomicSwap(from: item, to: destination)
        }
    }

    public func listSnapshots(root: URL) -> [ProjectSnapshot] {
        let directory = root.standardizedFileURL.appendingPathComponent(".mnemox/snapshots")
        guard let contents = try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) else {
            return []
        }

        var snapshots: [ProjectSnapshot] = []
        for folder in contents {
            let manifest = folder.appendingPathComponent("manifest.json")
            guard let data = try? Data(contentsOf: manifest),
                  let decoded = try? decodeManifest(data) else {
                continue
            }
            snapshots.append(decoded)
        }

        return snapshots.sorted { lhs, rhs in
            lhs.timestamp > rhs.timestamp
        }
    }

    public func deleteSnapshot(_ snapshot: ProjectSnapshot) async throws {
        let rootURL = URL(fileURLWithPath: snapshot.agentPlan.target).standardizedFileURL
        let folder = rootURL.appendingPathComponent(".mnemox/snapshots/\(snapshot.id)")
        guard FileManager.default.fileExists(atPath: folder.path) else {
            return
        }
        try FileManager.default.removeItem(at: folder)
    }

    private func pruneSnapshots(rootURL: URL) throws {
        let directory = rootURL.appendingPathComponent(".mnemox/snapshots")
        guard let folders = try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) else {
            return
        }

        let decoded = folders.compactMap { url -> (URL, Date)? in
            let manifest = url.appendingPathComponent("manifest.json")
            guard let data = try? Data(contentsOf: manifest),
                  let snapshot = try? decodeManifest(data) else {
                return nil
            }
            return (url, snapshot.timestamp)
        }.sorted { $0.1 < $1.1 }

        guard decoded.count > maximumRetainedSnapshots else {
            return
        }

        let overflow = decoded.count - maximumRetainedSnapshots
        for index in 0 ..< overflow {
            try FileManager.default.removeItem(at: decoded[index].0)
        }
    }

    private func hashSources(rootURL: URL, relatives: [String]) async throws -> [ProjectSnapshot.FileSnapshot] {
        try await withThrowingTaskGroup(of: ProjectSnapshot.FileSnapshot.self) { group in
            for relative in relatives {
                group.addTask {
                    let url = rootURL.appendingPathComponent(relative)
                    let data = try Data(contentsOf: url)
                    let digest = CoreDigest.sha256Hex(for: data)
                    return ProjectSnapshot.FileSnapshot(relativePath: relative, sha256: digest)
                }
            }

            var rows: [ProjectSnapshot.FileSnapshot] = []
            while let next = try await group.next() {
                rows.append(next)
            }
            return rows.sorted { $0.relativePath < $1.relativePath }
        }
    }

    private func atomicSwap(from stagingFile: URL, to destination: URL) throws {
        let fileManager = FileManager.default
        let temporary = destination.deletingLastPathComponent()
            .appendingPathComponent(".mnemox-temp-\(UUID().uuidString)-\(destination.lastPathComponent)")

        if fileManager.fileExists(atPath: temporary.path) {
            try fileManager.removeItem(at: temporary)
        }

        try fileManager.copyItem(at: stagingFile, to: temporary)

        if fileManager.fileExists(atPath: destination.path) {
            try fileManager.removeItem(at: destination)
        }

        try fileManager.moveItem(at: temporary, to: destination)
    }

    private func decodeManifest(_ data: Data) throws -> ProjectSnapshot {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(ProjectSnapshot.self, from: data)
    }

    private func encodeManifest(_ snapshot: ProjectSnapshot) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(snapshot)
    }

    private func makeSnapshotIdentifier(prefix: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let stamp = formatter.string(from: Date()).replacingOccurrences(of: ":", with: "-")
        return "\(prefix)_\(stamp)"
    }
}
