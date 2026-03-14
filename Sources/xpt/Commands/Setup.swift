import ArgumentParser
import Foundation

struct Setup: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Install the post-checkout git hook into the current repo."
    )

    static let hookSnippet = #"xpt _hook post-checkout "$1" "$2" "$3""#
    static let hookScript = "#!/bin/sh\n\(hookSnippet)\n"

    func run() throws {
        let repoRoot = try GitUtilities.repoRoot()

        // 1. Always manage .gitignore (idempotent)
        try configureGitignore(repoRoot: repoRoot)

        // 2. Hook installation
        let hookPath = repoRoot
            .appendingPathComponent(".git")
            .appendingPathComponent("hooks")
            .appendingPathComponent("post-checkout")

        if FileManager.default.fileExists(atPath: hookPath.path) {
            print("""
            xpt setup: A post-checkout hook already exists at .git/hooks/post-checkout.
            Add the following line to your existing hook to enable xpt:

                \(Self.hookSnippet)
            """)
            throw ExitCode.failure
        }

        // Write the hook
        try Self.hookScript.write(to: hookPath, atomically: true, encoding: .utf8)

        // Make it executable (chmod +x)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o755],
            ofItemAtPath: hookPath.path
        )

        print("xpt: post-checkout hook installed at .git/hooks/post-checkout")
        print("Run 'xpt setup' again in any other repo you want to enable.")
    }

    private func configureGitignore(repoRoot: URL) throws {
        let gitignorePath = repoRoot.appendingPathComponent(".gitignore")
        let fileExists = FileManager.default.fileExists(atPath: gitignorePath.path)
        let existing = (try? String(contentsOf: gitignorePath, encoding: .utf8)) ?? ""
        let lines = existing.components(separatedBy: "\n")

        // If any xcuserdata entry already exists, treat it as sufficient
        let hasXcuserdata = lines.contains(where: { $0.contains("xcuserdata") })
        let needsXptConfig = !lines.contains(where: { $0.trimmingCharacters(in: .whitespaces) == ".xpt" })

        if !hasXcuserdata || needsXptConfig {
            var updated = existing
            if !updated.hasSuffix("\n") && !updated.isEmpty { updated += "\n" }
            if !hasXcuserdata {
                updated += "\n# xpt — Xcode per-user data (breakpoints, workspace state)\n"
                updated += "**/xcuserdata/\n"
            }
            if needsXptConfig {
                updated += "\n# xpt — per-repo config\n"
                updated += ".xpt\n"
            }
            try updated.write(to: gitignorePath, atomically: true, encoding: .utf8)

            if !fileExists {
                print("xpt: Created .gitignore with xpt entries")
            } else {
                print("xpt: Added xpt entries to .gitignore")
            }
        }

        // Warn about already-tracked xcuserdata files that should be untracked
        let tracked = (try? GitUtilities.run("git", "ls-files", "--cached")) ?? ""
        let trackedLines = tracked.components(separatedBy: "\n")
        let trackedXcuserdata = trackedLines.filter { $0.contains("xcuserdata/") }
        let hasTrackedXptConfig = trackedLines.contains(where: { $0 == ".xpt" })

        if !trackedXcuserdata.isEmpty || hasTrackedXptConfig {
            var rmPaths: [String] = []
            if !trackedXcuserdata.isEmpty { rmPaths.append("'*/xcuserdata/'") }
            if hasTrackedXptConfig { rmPaths.append(".xpt") }
            print("""
            xpt: Some files xpt manages are tracked by git. Run this to untrack them:

                git rm --cached -r \(rmPaths.joined(separator: " "))

            Then commit the result so your team inherits the gitignore rules.
            """)
        }
    }
}
