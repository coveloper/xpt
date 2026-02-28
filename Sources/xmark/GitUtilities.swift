import Foundation

enum GitError: Error, CustomStringConvertible {
    case notAGitRepo
    case commandFailed(String)
    case branchNotFound(String)

    var description: String {
        switch self {
        case .notAGitRepo:
            return "Not inside a git repository."
        case .commandFailed(let msg):
            return "Git command failed: \(msg)"
        case .branchNotFound(let ref):
            return "Could not resolve branch name for ref: \(ref)"
        }
    }
}

enum GitUtilities {
    // MARK: - Repo Root

    static func repoRoot() throws -> URL {
        let output = try run("git", "rev-parse", "--show-toplevel")
        return URL(fileURLWithPath: output)
    }

    // MARK: - Current Branch

    static func currentBranch() throws -> String {
        return try run("git", "symbolic-ref", "--short", "HEAD")
    }

    // MARK: - Branch from ref/SHA

    /// Resolves a branch name from a full ref or SHA (as passed by git hooks).
    static func branchName(for ref: String) throws -> String {
        // Try symbolic ref first (works when ref is a branch tip)
        if let name = try? run("git", "name-rev", "--name-only", "--no-undefined", ref) {
            // name-rev may return things like "main~1" — strip the suffix
            let clean = name.components(separatedBy: "~").first!
                           .components(separatedBy: "^").first!
            return clean
        }
        throw GitError.branchNotFound(ref)
    }

    // MARK: - Remote URL

    static func remoteURL(remote: String = "origin") -> String? {
        return try? run("git", "remote", "get-url", remote)
    }

    // MARK: - Shell runner

    @discardableResult
    static func run(_ args: String...) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = args

        let pipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = pipe
        process.standardError = errPipe

        try process.run()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
            let errMsg = String(data: errData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if errMsg.contains("not a git repository") {
                throw GitError.notAGitRepo
            }
            throw GitError.commandFailed(errMsg)
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }
}
