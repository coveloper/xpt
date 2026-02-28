import ArgumentParser
import Foundation

struct Restore: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Restore breakpoints for the current (or named) branch."
    )

    @Option(name: .long, help: "Branch name to restore from. Defaults to current branch.")
    var branch: String?

    func run() throws {
        let repoRoot = try GitUtilities.repoRoot()
        let config = try RepoConfig.load(from: repoRoot)
        let projectURL = try PathUtilities.projectURL(repoRoot: repoRoot, configuredProject: config.project)
        let breakpointFile = PathUtilities.breakpointFileURL(projectURL: projectURL)

        let targetBranch = try branch ?? GitUtilities.currentBranch()
        let storage = try StorageManager(repoRoot: repoRoot)

        warnIfXcodeRunning()

        do {
            try storage.restore(to: breakpointFile, branch: targetBranch)
            print("xmark: Breakpoints restored for branch '\(targetBranch)'.")
        } catch StorageError.noSnapshotFound {
            switch config.effectiveOnEmptyBranch {
            case .clear:
                try storage.clearBreakpoints(at: breakpointFile)
                print("xmark: No saved breakpoints for '\(targetBranch)' — cleared breakpoint file.")
            case .preserve:
                print("xmark: No saved breakpoints for '\(targetBranch)' — preserving existing breakpoints.")
            }
        }
    }

    private func warnIfXcodeRunning() {
        let result = try? GitUtilities.run("pgrep", "-x", "Xcode")
        if result != nil && !result!.isEmpty {
            print("xmark warning: Xcode is currently open. You may need to restart Xcode for restored breakpoints to take effect.")
        }
    }
}
