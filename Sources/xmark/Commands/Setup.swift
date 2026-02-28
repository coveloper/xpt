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
}
