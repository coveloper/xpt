import ArgumentParser
import Foundation

struct Setup: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Install the post-checkout git hook into the current repo."
    )

    static let hookScript = """
    #!/bin/sh
    xmark _hook post-checkout "$1" "$2" "$3"
    """

    static let hookSnippet = #"xmark _hook post-checkout "$1" "$2" "$3""#

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
            xmark setup: A post-checkout hook already exists at .git/hooks/post-checkout.
            Add the following line to your existing hook to enable xmark:

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

        print("xmark: post-checkout hook installed at .git/hooks/post-checkout")
        print("Run 'xmark setup' again in any other repo you want to enable.")
    }

    private func configureGitignore(repoRoot: URL) throws {
        let gitignorePath = repoRoot.appendingPathComponent(".gitignore")
        let fileExists = FileManager.default.fileExists(atPath: gitignorePath.path)
        let existing = (try? String(contentsOf: gitignorePath, encoding: .utf8)) ?? ""
        let lines = existing.components(separatedBy: "\n")

        let needsXcuserdata = !lines.contains(where: { $0.contains("xcuserdata") })
        let needsXmarkConfig = !lines.contains(where: { $0.trimmingCharacters(in: .whitespaces) == ".xmark" })

        if needsXcuserdata || needsXmarkConfig {
            var updated = existing
            if !updated.hasSuffix("\n") && !updated.isEmpty { updated += "\n" }
            updated += "\n# xmark\n"
            if needsXcuserdata { updated += "xcuserdata/\n" }
            if needsXmarkConfig { updated += ".xmark\n" }
            try updated.write(to: gitignorePath, atomically: true, encoding: .utf8)

            if !fileExists {
                print("xmark: Created .gitignore with xcuserdata/ and .xmark")
            } else {
                var added: [String] = []
                if needsXcuserdata { added.append("xcuserdata/") }
                if needsXmarkConfig { added.append(".xmark") }
                print("xmark: Added \(added.joined(separator: " and ")) to .gitignore")
            }
        }

        // Warn about already-tracked files that should be untracked
        let tracked = (try? GitUtilities.run("git", "ls-files", "--cached")) ?? ""
        let trackedLines = tracked.components(separatedBy: "\n")
        let hasTrackedXcuserdata = trackedLines.contains(where: { $0.contains("xcuserdata/") })
        let hasTrackedXmarkConfig = trackedLines.contains(where: { $0 == ".xmark" })

        if hasTrackedXcuserdata || hasTrackedXmarkConfig {
            var paths: [String] = []
            if hasTrackedXcuserdata { paths.append("'*/xcuserdata/*'") }
            if hasTrackedXmarkConfig { paths.append(".xmark") }
            print("""
            xmark: Some files xmark manages are tracked by git. Run this to untrack them:

                git rm --cached -r \(paths.joined(separator: " "))

            Then commit the result so your team inherits the gitignore rules.
            """)
        }
    }
}
