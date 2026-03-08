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

        do {
            try storage.restore(to: breakpointFile, branch: targetBranch)
            print("xpt: Breakpoints restored for branch '\(targetBranch)'.")
        } catch StorageError.noSnapshotFound {
            switch config.effectiveOnEmptyBranch {
            case .clear:
                try storage.clearBreakpoints(at: breakpointFile)
                print("xpt: No saved breakpoints for '\(targetBranch)' — cleared breakpoint file.")
            case .preserve:
                print("xpt: No saved breakpoints for '\(targetBranch)' — preserving existing breakpoints.")
            }
        }

        if XcodeUtilities.isRunning {
            print("xpt: Reloading Xcode project...")
            XcodeUtilities.reloadProject(projectURL: projectURL)
        }
    }
}
