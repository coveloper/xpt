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

    private func xcodeVersion() -> Int? {
        guard let output = try? GitUtilities.run("xcodebuild", "-version") else { return nil }
        let firstLine = output.components(separatedBy: "\n").first ?? ""
        guard firstLine.hasPrefix("Xcode ") else { return nil }
        let versionStr = String(firstLine.dropFirst("Xcode ".count))
        return Int(versionStr.components(separatedBy: ".").first ?? "")
    }

    private func configureGitignore(repoRoot: URL) throws {
        let gitignorePath = repoRoot.appendingPathComponent(".gitignore")
        let fileExists = FileManager.default.fileExists(atPath: gitignorePath.path)
        let existing = (try? String(contentsOf: gitignorePath, encoding: .utf8)) ?? ""
        let lines = existing.components(separatedBy: "\n")

        let version = xcodeVersion()
        let wantsNew    = version == nil || version! >= 16
        let wantsLegacy = version == nil || version! < 16

        // If any xcuserdata entry already exists, treat it as sufficient
        let hasBroadXcuserdata = lines.contains(where: { $0.contains("xcuserdata") })
        let hasNewPattern    = lines.contains("**/xcuserdata/*/xcdebugger/Breakpoints_v2.xcbkptlist")
        let hasLegacyPattern = lines.contains("**/xcuserdata/*/Breakpoints_v2.xcbkptlist")
        let needsXptConfig = !lines.contains(where: { $0.trimmingCharacters(in: .whitespaces) == ".xpt" })

        let needsNew    = !hasBroadXcuserdata && wantsNew    && !hasNewPattern
        let needsLegacy = !hasBroadXcuserdata && wantsLegacy && !hasLegacyPattern

        if needsNew || needsLegacy || needsXptConfig {
            var updated = existing
            if !updated.hasSuffix("\n") && !updated.isEmpty { updated += "\n" }
            if needsNew {
                updated += "\n# xpt — per-branch breakpoints (Xcode 16+)\n"
                updated += "**/xcuserdata/*/xcdebugger/Breakpoints_v2.xcbkptlist\n"
            }
            if needsLegacy {
                updated += "\n# xpt — per-branch breakpoints (Xcode 15 and earlier)\n"
                updated += "**/xcuserdata/*/Breakpoints_v2.xcbkptlist\n"
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

        // Warn about already-tracked files that should be untracked
        let tracked = (try? GitUtilities.run("git", "ls-files", "--cached")) ?? ""
        let trackedLines = tracked.components(separatedBy: "\n")
        let trackedBreakpoints = trackedLines.filter {
            $0.hasSuffix("Breakpoints_v2.xcbkptlist") && $0.contains("xcuserdata/")
        }
        let hasTrackedXmarkConfig = trackedLines.contains(where: { $0 == ".xpt" })

        if !trackedBreakpoints.isEmpty || hasTrackedXmarkConfig {
            var rmPaths: [String] = []
            if trackedBreakpoints.contains(where: { $0.contains("xcdebugger/") }) {
                rmPaths.append("'*/xcuserdata/*/xcdebugger/Breakpoints_v2.xcbkptlist'")
            }
            if trackedBreakpoints.contains(where: { !$0.contains("xcdebugger/") }) {
                rmPaths.append("'*/xcuserdata/*/Breakpoints_v2.xcbkptlist'")
            }
            if hasTrackedXmarkConfig { rmPaths.append(".xpt") }
            print("""
            xpt: Some files xpt manages are tracked by git. Run this to untrack them:

                git rm --cached -r \(rmPaths.joined(separator: " "))

            Then commit the result so your team inherits the gitignore rules.
            """)
        }
    }
}
