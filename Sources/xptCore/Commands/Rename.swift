import ArgumentParser

public struct Rename: ParsableCommand {
    public static let configuration = CommandConfiguration(
        abstract: "Rename a saved breakpoint snapshot to match a renamed branch."
    )

    @Argument(help: "The old branch name (snapshot to rename).")
    public var oldBranch: String

    @Argument(help: "The new branch name (what to rename the snapshot to).")
    public var newBranch: String

    public init() {}

    public mutating func run() throws {
        let repoRoot = try GitUtilities.repoRoot()
        let storage = try StorageManager(repoRoot: repoRoot)
        try storage.rename(from: oldBranch, to: newBranch)
        print("xpt: Renamed '\(oldBranch)' → '\(newBranch)'.")
    }
}
