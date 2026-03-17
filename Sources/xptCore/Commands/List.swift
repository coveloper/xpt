import ArgumentParser
import Foundation

public struct List: ParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "list",
        abstract: "Show all saved breakpoint sets for this repo."
    )

    public init() {}

    public func run() throws {
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
