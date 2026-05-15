import SwiftUI
import AppKit

enum LineTint {
    case neutral
    case added
    case removed

    var background: Color {
        switch self {
        case .neutral: Color(nsColor: .textBackgroundColor)
        case .added: Color(nsColor: .systemGreen).opacity(0.18)
        case .removed: Color(nsColor: .systemRed).opacity(0.18)
        }
    }
}

struct UnifiedRow {
    let leftNumber: Int?
    let rightNumber: Int?
    let text: String
    let style: LineTint
}

func unifiedRows(old: String?, new: String) -> [UnifiedRow] {
    let left = (old ?? "").split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
    let right = new.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
    let count = max(left.count, right.count)
    var rows: [UnifiedRow] = []

    for index in 0..<count {
        let l = index < left.count ? left[index] : nil
        let r = index < right.count ? right[index] : nil
        switch (l, r) {
        case let (oldLine?, newLine?):
            if oldLine == newLine {
                rows.append(UnifiedRow(leftNumber: index + 1, rightNumber: index + 1, text: newLine, style: .neutral))
            } else {
                if oldLine.isEmpty == false {
                    rows.append(UnifiedRow(leftNumber: index + 1, rightNumber: nil, text: "- \(oldLine)", style: .removed))
                }
                if newLine.isEmpty == false {
                    rows.append(UnifiedRow(leftNumber: nil, rightNumber: index + 1, text: "+ \(newLine)", style: .added))
                }
            }
        case let (oldLine?, nil):
            rows.append(UnifiedRow(leftNumber: index + 1, rightNumber: nil, text: "- \(oldLine)", style: .removed))
        case let (nil, newLine?):
            rows.append(UnifiedRow(leftNumber: nil, rightNumber: index + 1, text: "+ \(newLine)", style: .added))
        case (nil, nil):
            break
        }
    }

    return rows
}
