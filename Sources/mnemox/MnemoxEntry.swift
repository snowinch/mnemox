import Foundation

// The SwiftUI application uses `@main struct MnemoxApp` for lifecycle entry.
// This file remains as a stable SPM compilation anchor without a second `@main`.

enum MnemoxProcessBootstrap {
    static let bundleIdentifier = Bundle.main.bundleIdentifier ?? "dev.mnemox"
}
