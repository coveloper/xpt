import Foundation

public enum PathError: Error, CustomStringConvertible {
    case noProjectFound
    case multipleProjectsFound([String])
    case breakpointFileNotFound(String)
    case projectOutsideRepo(String)

    public var description: String {
        switch self {
        case .noProjectFound:
            return "No .xcworkspace or .xcodeproj found in the repo root. Run 'xpt config --set project=MyApp.xcworkspace' to configure one."
        case .multipleProjectsFound(let names):
            return "Multiple Xcode projects found: \(names.joined(separator: ", ")). Run 'xpt config --set project=<name>' to specify which to use."
        case .breakpointFileNotFound(let path):
            return "Breakpoint file not found at: \(path)"
        case .projectOutsideRepo(let name):
            return "Configured project '\(name)' resolves outside the repository root. Check your .xpt config file."
        }
    }
}

public enum PathUtilities {
    public static var username: String {
        ProcessInfo.processInfo.environment["USER"] ?? NSUserName()
    }

    // MARK: - Project file resolution

    /// Resolves the Xcode project file URL from config or by auto-discovery.
    public static func projectURL(repoRoot: URL, configuredProject: String?) throws -> URL {
        if let configured = configuredProject {
            let resolved = repoRoot.appendingPathComponent(configured).standardizedFileURL
            let root = repoRoot.standardizedFileURL
            // Prevent directory traversal: the configured project must remain inside the repo root.
            // e.g. a .xpt config with "project": "../../etc/passwd" must be rejected.
            let rootPrefix = root.path.hasSuffix("/") ? root.path : root.path + "/"
            guard resolved.path.hasPrefix(rootPrefix) else {
                throw PathError.projectOutsideRepo(configured)
            }
            return resolved
        }
        return try autoDetectProject(in: repoRoot)
    }

    static func autoDetectProject(in repoRoot: URL) throws -> URL {
        let fm = FileManager.default
        let contents = try fm.contentsOfDirectory(atPath: repoRoot.path)
        let name = try selectProject(from: contents)
        return repoRoot.appendingPathComponent(name)
    }

    static func selectProject(from candidates: [String]) throws -> String {
        let workspaces = candidates.filter { $0.hasSuffix(".xcworkspace") }
        let xcodeprojs = candidates.filter { $0.hasSuffix(".xcodeproj") }

        let realWorkspaces = workspaces.filter { ws in
            !xcodeprojs.contains(where: { proj in
                ws == proj.replacingOccurrences(of: ".xcodeproj", with: ".xcworkspace")
            })
        }

        let filtered = realWorkspaces.isEmpty ? xcodeprojs : realWorkspaces

        if filtered.isEmpty {
            throw PathError.noProjectFound
        }
        if filtered.count > 1 {
            throw PathError.multipleProjectsFound(filtered)
        }
        return filtered[0]
    }

    // MARK: - Breakpoint file path

    /// Returns the path to Breakpoints_v2.xcbkptlist inside the given project file.
    ///
    /// Xcode 16+ stores breakpoints in xcuserdata/<user>.xcuserdatad/xcdebugger/Breakpoints_v2.xcbkptlist.
    /// Older versions used xcuserdata/<user>.xcuserdatad/Breakpoints_v2.xcbkptlist directly.
    /// This function checks for the newer path first and falls back to the legacy path.
    public static func breakpointFileURL(projectURL: URL) -> URL {
        let userDataDir = projectURL
            .appendingPathComponent("xcuserdata")
            .appendingPathComponent("\(username).xcuserdatad")

        let newPath = userDataDir
            .appendingPathComponent("xcdebugger")
            .appendingPathComponent("Breakpoints_v2.xcbkptlist")

        let legacyPath = userDataDir
            .appendingPathComponent("Breakpoints_v2.xcbkptlist")

        // Prefer the newer xcdebugger/ path if it exists; fall back to legacy
        if FileManager.default.fileExists(atPath: newPath.path) {
            return newPath
        }
        if FileManager.default.fileExists(atPath: legacyPath.path) {
            return legacyPath
        }
        // Neither exists yet — default to the newer path so xpt creates it in the right place
        return newPath
    }
}
