import ArgumentParser
import Foundation

struct Hook: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "_hook",
        abstract: "Internal: called by the git post-checkout hook.",
        shouldDisplay: false
    )

    @Argument(help: "Hook name (e.g. post-checkout)")
    var hookName: String

    @Argument(help: "Previous HEAD ref or SHA")
    var prevHead: String

    @Argument(help: "New HEAD ref or SHA")
    var newHead: String

    @Argument(help: "Branch switch flag: 1 = branch switch, 0 = file checkout")
    var flag: String

    func run() throws {
        // Only act on branch switches, not file checkouts
        guard flag == "1" else { return }

        let repoRoot = try GitUtilities.repoRoot()
        let config = try RepoConfig.load(from: repoRoot)
        let projectURL = try PathUtilities.projectURL(repoRoot: repoRoot, configuredProject: config.project)
        let breakpointFile = PathUtilities.breakpointFileURL(projectURL: projectURL)
        let storage = try StorageManager(repoRoot: repoRoot)

        // Resolve the new branch first — git symbolic-ref HEAD is always reliable
        // post-checkout because git has already moved HEAD.
        let newBranch = try GitUtilities.currentBranch()

        // Resolve the previous branch from prevHead SHA, excluding the new branch name
        // to handle the common case where both branches share the same tip commit
        // (e.g. immediately after `git checkout -b feature/x`).
        let previousBranch = resolvePreviousBranch(sha: prevHead, excluding: newBranch)

        // 1. Save breakpoints for the branch we're leaving (silent on success)
        if let prev = previousBranch, FileManager.default.fileExists(atPath: breakpointFile.path) {
            try storage.save(from: breakpointFile, branch: prev)
        }

        // 2. Restore breakpoints for the branch we're arriving on
        do {
            try storage.restore(to: breakpointFile, branch: newBranch)
        } catch StorageError.noSnapshotFound {
            switch config.effectiveOnEmptyBranch {
            case .clear:
                try storage.clearBreakpoints(at: breakpointFile)
            case .preserve:
                break // leave existing file untouched
            }
        } catch {
            fputs("xpt: restore failed for '\(newBranch)': \(error)\n", stderr)
        }

        // 3. Reload Xcode project so it picks up the new breakpoint file
        XcodeUtilities.reloadProject(projectURL: projectURL)
    }

    // MARK: - Previous branch resolution

    /// Resolves the branch name for a given SHA, excluding `currentBranch`.
    /// Returns nil if the branch cannot be reliably determined (non-fatal).
    private func resolvePreviousBranch(sha: String, excluding currentBranch: String) -> String? {
        // Ask git which local branches point to this SHA
        guard let output = try? GitUtilities.run(
            "git", "branch", "--points-at", sha, "--format=%(refname:short)"
        ) else { return nil }

        let candidates = output
            .split(separator: "\n")
            .map { String($0) }
            .filter { !$0.isEmpty && $0 != currentBranch }

        if let unique = candidates.first, candidates.count == 1 {
            return unique
        }

        // Multiple or zero candidates — fall back to name-rev
        return try? GitUtilities.branchName(for: sha)
    }
}
