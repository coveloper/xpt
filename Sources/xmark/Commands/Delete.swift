import ArgumentParser
import Foundation

struct Delete: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Remove the saved breakpoint set for a branch."
    )

    @Argument(help: "The branch whose saved breakpoints should be deleted.")
    var branch: String

    func run() throws {
        let repoRoot = try GitUtilities.repoRoot()
        let storage = try StorageManager(repoRoot: repoRoot)

        try storage.delete(branch: branch)
        print("xmark: Deleted saved breakpoints for branch '\(branch)'.")
    }
}
