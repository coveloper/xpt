import Foundation
import CryptoKit

enum StorageError: Error, CustomStringConvertible {
    case noSnapshotFound(String)

    var description: String {
        switch self {
        case .noSnapshotFound(let branch):
            return "No saved breakpoints found for branch '\(branch)'."
        }
    }
}

struct StorageManager {
    let repoDirectory: URL

    // MARK: - Init

    init(repoRoot: URL) throws {
        let identifier = Self.repoIdentifier(repoRoot: repoRoot)
        let base = URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent(".xmark")
            .appendingPathComponent(identifier)
        try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        self.repoDirectory = base
    }

    // MARK: - Repo identifier

    private static func repoIdentifier(repoRoot: URL) -> String {
        let key: String
        if let remote = GitUtilities.remoteURL() {
            key = normalizeRemoteURL(remote)
        } else {
            key = repoRoot.standardizedFileURL.path
        }
        let digest = SHA256.hash(data: Data(key.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private static func normalizeRemoteURL(_ url: String) -> String {
        // Strip trailing .git and lowercase for stable hashing
        var normalized = url.lowercased()
        if normalized.hasSuffix(".git") {
            normalized = String(normalized.dropLast(4))
        }
        return normalized
    }

    // MARK: - Snapshot URL

    func snapshotURL(for branch: String) -> URL {
        // Branch names can contain '/' — use path components naturally
        let sanitized = sanitize(branch)
        return repoDirectory.appendingPathComponent(sanitized + ".xcbkptlist")
    }

    // MARK: - Save / Restore / Delete

    func save(from sourceURL: URL, branch: String) throws {
        let dest = snapshotURL(for: branch)
        try FileManager.default.createDirectory(
            at: dest.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        if FileManager.default.fileExists(atPath: dest.path) {
            try FileManager.default.removeItem(at: dest)
        }
        try FileManager.default.copyItem(at: sourceURL, to: dest)
    }

    func restore(to destinationURL: URL, branch: String) throws {
        let source = snapshotURL(for: branch)
        guard FileManager.default.fileExists(atPath: source.path) else {
            throw StorageError.noSnapshotFound(branch)
        }
        try FileManager.default.createDirectory(
            at: destinationURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try FileManager.default.removeItem(at: destinationURL)
        }
        try FileManager.default.copyItem(at: source, to: destinationURL)
    }

    func delete(branch: String) throws {
        let url = snapshotURL(for: branch)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw StorageError.noSnapshotFound(branch)
        }
        try FileManager.default.removeItem(at: url)
    }

    func clearBreakpoints(at destinationURL: URL) throws {
        try FileManager.default.createDirectory(
            at: destinationURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        // Write an empty (valid) breakpoint list
        let empty = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>Type</key>
            <string>XCBreakpointList</string>
            <key>Version</key>
            <string>2.0</string>
        </dict>
        </plist>
        """
        try empty.write(to: destinationURL, atomically: true, encoding: .utf8)
    }

    // MARK: - Listing

    struct SnapshotInfo {
        let branch: String
        let modifiedDate: Date
    }

    func allSnapshots() throws -> [SnapshotInfo] {
        let fm = FileManager.default
        guard fm.fileExists(atPath: repoDirectory.path) else { return [] }

        let urls = try fm.contentsOfDirectory(
            at: repoDirectory,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: .skipsHiddenFiles
        )

        return try urls
            .filter { $0.pathExtension == "xcbkptlist" }
            .map { url in
                let attrs = try url.resourceValues(forKeys: [.contentModificationDateKey])
                let date = attrs.contentModificationDate ?? Date.distantPast
                let branch = unsanitize(url.deletingPathExtension().lastPathComponent)
                return SnapshotInfo(branch: branch, modifiedDate: date)
            }
            .sorted { $0.modifiedDate > $1.modifiedDate }
    }

    // MARK: - Branch name sanitization

    /// Replaces filesystem-unsafe characters with safe equivalents.
    private func sanitize(_ branch: String) -> String {
        // Replace '/' with '__' to avoid unintended subdirectory creation
        branch.replacingOccurrences(of: "/", with: "__")
    }

    private func unsanitize(_ filename: String) -> String {
        filename.replacingOccurrences(of: "__", with: "/")
    }
}
