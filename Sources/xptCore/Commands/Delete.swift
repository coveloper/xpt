import ArgumentParser
import Foundation

public struct Delete: ParsableCommand {
    public static let configuration = CommandConfiguration(
        abstract: "Remove the saved breakpoint set for a branch."
    )

    @Argument(help: "The branch whose saved breakpoints should be deleted.")
    public var branch: String

    public init() {}

    public func run() throws {
        let repoRoot = try GitUtilities.repoRoot()
        let storage = try StorageManager(repoRoot: repoRoot)

        try storage.delete(branch: branch)
        print("xpt: Deleted saved breakpoints for branch '\(branch)'.")
    }
}
