import ArgumentParser
import Foundation

public struct Save: ParsableCommand {
    public static let configuration = CommandConfiguration(
        abstract: "Save current breakpoints for the current (or named) branch."
    )

    @Option(name: .long, help: "Branch name to save as. Defaults to current branch.")
    public var branch: String?

    public init() {}

    public func run() throws {
        let repoRoot = try GitUtilities.repoRoot()
        let config = try RepoConfig.load(from: repoRoot)
        let projectURL = try PathUtilities.projectURL(repoRoot: repoRoot, configuredProject: config.project)
        let breakpointFile = PathUtilities.breakpointFileURL(projectURL: projectURL)

        guard FileManager.default.fileExists(atPath: breakpointFile.path) else {
            print("xpt save: No breakpoint file found at \(breakpointFile.path)")
            print("Open Xcode and set at least one breakpoint to create the file.")
            throw ExitCode.failure
        }

        let targetBranch = try branch ?? GitUtilities.currentBranch()
        let storage = try StorageManager(repoRoot: repoRoot)
        try storage.save(from: breakpointFile, branch: targetBranch)

        print("xpt: Breakpoints saved for branch '\(targetBranch)'.")
    }
}
