import ArgumentParser
import Foundation

public struct Hook: ParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "_hook",
        abstract: "Internal: called by the git post-checkout hook.",
        shouldDisplay: false
    )

    @Argument(help: "Hook name (e.g. post-checkout)")
    public var hookName: String

    @Argument(help: "Previous HEAD ref or SHA")
    public var prevHead: String

    @Argument(help: "New HEAD ref or SHA")
    public var newHead: String

    @Argument(help: "Branch switch flag: 1 = branch switch, 0 = file checkout")
    public var flag: String

    public init() {}

    public mutating func run() throws {
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

    /// Parses the previous branch name from a reflog entry of the form
    /// "checkout: moving from <prev> to <new>", excluding `currentBranch`.
    /// Returns nil if the entry is malformed or if prev equals currentBranch.
    static func parsePreviousBranch(fromReflogEntry entry: String, excluding currentBranch: String) -> String? {
        guard entry.hasPrefix("checkout: moving from ") else { return nil }
        let rest = String(entry.dropFirst("checkout: moving from ".count))
        guard let prev = rest.components(separatedBy: " to ").first,
              !prev.isEmpty, prev != currentBranch else { return nil }
        return prev
    }

    /// Resolves the branch name for the branch we just left, excluding `currentBranch`.
    /// Returns nil if the branch cannot be reliably determined (non-fatal).
    private func resolvePreviousBranch(sha: String, excluding currentBranch: String) -> String? {
        // Primary: read the most recent reflog entry for HEAD. git records every
        // checkout as "checkout: moving from <prev> to <new>", giving us the exact
        // branch names regardless of how many branches share the same SHA.
        if let entry = try? GitUtilities.run("git", "reflog", "-1", "HEAD", "--format=%gs"),
           let prev = Self.parsePreviousBranch(fromReflogEntry: entry, excluding: currentBranch) {
            return prev
        }

        // Fallback: ask git which local branches point to this SHA. Only reliable
        // when exactly one branch (other than currentBranch) matches.
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

        // Last resort: name-rev. Unreliable when multiple branches share the SHA.
        return try? GitUtilities.branchName(for: sha)
    }
}
