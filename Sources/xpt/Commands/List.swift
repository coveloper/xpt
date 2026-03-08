import ArgumentParser
import Foundation

struct List: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "list",
        abstract: "Show all saved breakpoint sets for this repo."
    )

    func run() throws {
        let repoRoot = try GitUtilities.repoRoot()
        let storage = try StorageManager(repoRoot: repoRoot)
        let snapshots = try storage.allSnapshots()

        let remoteURL = GitUtilities.remoteURL() ?? repoRoot.lastPathComponent
        print("Saved breakpoints for \(repoRoot.lastPathComponent) (\(remoteURL)):\n")

        if snapshots.isEmpty {
            print("  (none)")
            return
        }

        let formatter = RelativeDateFormatter()
        let maxLen = snapshots.map(\.branch.count).max() ?? 0

        for snapshot in snapshots {
            let padded = snapshot.branch.padding(toLength: max(maxLen, 20), withPad: " ", startingAt: 0)
            print("  \(padded)  (\(formatter.string(from: snapshot.modifiedDate)))")
        }
    }
}

// MARK: - Relative date formatting

private struct RelativeDateFormatter {
    let now = Date()

    func string(from date: Date) -> String {
        let seconds = Int(now.timeIntervalSince(date))
        switch seconds {
        case ..<60:
            return "just now"
        case 60..<3600:
            let m = seconds / 60
            return "\(m) minute\(m == 1 ? "" : "s") ago"
        case 3600..<86400:
            let h = seconds / 3600
            return "\(h) hour\(h == 1 ? "" : "s") ago"
        case 86400..<172800:
            return "yesterday"
        default:
            let d = seconds / 86400
            return "\(d) days ago"
        }
    }
}
