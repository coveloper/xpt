import Foundation
import CryptoKit

public enum StorageError: Error, CustomStringConvertible, Equatable {
    case noSnapshotFound(String)
    case symlinkDetected(String)
    case invalidBranchName(String)
    case invalidSnapshot(String)
    case snapshotAlreadyExists(String)

    public var description: String {
        switch self {
        case .noSnapshotFound(let branch):
            return "No saved breakpoints found for branch '\(branch)'."
        case .symlinkDetected(let path):
            return "Refusing to operate on '\(path)': it is a symbolic link. xpt does not follow symlinks for security."
        case .invalidBranchName(let branch):
            return "Invalid branch name '\(branch)': must not be empty or contain null bytes or newlines."
        case .invalidSnapshot(let path):
            return "Snapshot at '\(path)' is not a valid plist file and will not be restored. Delete it with 'xpt delete' and re-save if needed."
        case .snapshotAlreadyExists(let branch):
            return "A snapshot already exists for branch '\(branch)'. Delete it first with 'xpt delete \(branch)'."
        }
    }
}

public struct StorageManager {
    public let repoDirectory: URL

    // MARK: - Init

    public init(repoRoot: URL) throws {
        let identifier = Self.repoIdentifier(repoRoot: repoRoot)
        self.repoDirectory = URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent(".xpt")
            .appendingPathComponent(identifier)
    }

    /// Internal initializer for testing — injects a custom storage directory.
    init(repoDirectory: URL) {
        self.repoDirectory = repoDirectory
    }

    // MARK: - Repo identifier

    static func repoIdentifier(repoRoot: URL) -> String {
        let key: String
        if let remote = GitUtilities.remoteURL() {
            key = Self.normalizeRemoteURL(remote)
        } else {
            key = repoRoot.standardizedFileURL.path
        }
        let digest = SHA256.hash(data: Data(key.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    static func normalizeRemoteURL(_ url: String) -> String {
        // Strip trailing .git and lowercase for stable hashing
        var normalized = url.lowercased()
        if normalized.hasSuffix(".git") {
            normalized = String(normalized.dropLast(4))
        }
        return normalized
    }

    // MARK: - Snapshot URL

    public func snapshotURL(for branch: String) -> URL {
        // Branch names can contain '/' — use path components naturally
        let sanitized = Self.sanitize(branch)
        return repoDirectory.appendingPathComponent(sanitized + ".xcbkptlist")
    }

    // MARK: - Save / Restore / Delete

    public func save(from sourceURL: URL, branch: String) throws {
        try Self.validateBranchName(branch)
        let dest = snapshotURL(for: branch)
        try ensureParentDirectory(for: dest)
        // Refuse to overwrite a symlink in the storage directory. A symlink placed
        // there by an attacker could redirect the write to an arbitrary file.
        if Self.isSymlink(at: dest) {
            throw StorageError.symlinkDetected(dest.path)
        }
        try? FileManager.default.removeItem(at: dest)
        try FileManager.default.copyItem(at: sourceURL, to: dest)
    }

    public func restore(to destinationURL: URL, branch: String) throws {
        try Self.validateBranchName(branch)
        let source = snapshotURL(for: branch)
        guard FileManager.default.fileExists(atPath: source.path) else {
            throw StorageError.noSnapshotFound(branch)
        }
        // Refuse to read from a symlink in the storage directory. A symlink placed
        // there by an attacker could cause xpt to copy arbitrary file content into
        // the active Xcode project.
        if Self.isSymlink(at: source) {
            throw StorageError.symlinkDetected(source.path)
        }
        // Validate the snapshot is a well-formed plist before overwriting the live file.
        try Self.validatePlistFile(at: source)
        try ensureParentDirectory(for: destinationURL)
        // Refuse to overwrite a symlink at the destination. A symlink placed at the
        // breakpoint file location could redirect the write to an arbitrary file.
        if Self.isSymlink(at: destinationURL) {
            throw StorageError.symlinkDetected(destinationURL.path)
        }
        try? FileManager.default.removeItem(at: destinationURL)
        try FileManager.default.copyItem(at: source, to: destinationURL)
    }

    public func rename(from oldBranch: String, to newBranch: String) throws {
        try Self.validateBranchName(oldBranch)
        try Self.validateBranchName(newBranch)
        let oldURL = snapshotURL(for: oldBranch)
        let newURL = snapshotURL(for: newBranch)
        guard FileManager.default.fileExists(atPath: oldURL.path) else {
            throw StorageError.noSnapshotFound(oldBranch)
        }
        if Self.isSymlink(at: oldURL) {
            throw StorageError.symlinkDetected(oldURL.path)
        }
        if Self.isSymlink(at: newURL) {
            throw StorageError.symlinkDetected(newURL.path)
        }
        if FileManager.default.fileExists(atPath: newURL.path) {
            throw StorageError.snapshotAlreadyExists(newBranch)
        }
        try FileManager.default.moveItem(at: oldURL, to: newURL)
    }

    public func delete(branch: String) throws {
        try Self.validateBranchName(branch)
        let url = snapshotURL(for: branch)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw StorageError.noSnapshotFound(branch)
        }
        try FileManager.default.removeItem(at: url)
    }

    public func clearBreakpoints(at destinationURL: URL) throws {
        try ensureParentDirectory(for: destinationURL)
        // Refuse to overwrite a symlink at the destination (same protection as restore()).
        if Self.isSymlink(at: destinationURL) {
            throw StorageError.symlinkDetected(destinationURL.path)
        }
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

    public struct SnapshotInfo {
        public let branch: String
        public let modifiedDate: Date
    }

    public func allSnapshots() throws -> [SnapshotInfo] {
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
                let branch = Self.unsanitize(url.deletingPathExtension().lastPathComponent)
                return SnapshotInfo(branch: branch, modifiedDate: date)
            }
            .sorted { $0.modifiedDate > $1.modifiedDate }
    }

    // MARK: - Helpers

    private func ensureParentDirectory(for url: URL) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
    }

    /// Validates that the file at `url` is a well-formed Xcode breakpoint XML document.
    static func validatePlistFile(at url: URL) throws {
        let data = try Data(contentsOf: url)
        try validateXML(data: data)
    }

    /// Validates that `data` is well-formed XML with a `<Bucket>` root element.
    /// Empty data, non-XML bytes, and documents without a `<Bucket>` root are rejected.
    static func validateXML(data: Data) throws {
        guard !data.isEmpty else {
            throw StorageError.invalidSnapshot("<empty data>")
        }
        let doc: XMLDocument
        do {
            doc = try XMLDocument(data: data, options: [])
        } catch {
            throw StorageError.invalidSnapshot("<invalid xml>")
        }
        guard doc.rootElement()?.name == "Bucket" else {
            throw StorageError.invalidSnapshot("<not a Bucket document>")
        }
    }

    /// Validates that `branch` is safe to use as a storage key.
    /// Rejects empty strings, null bytes, and newlines — characters that could
    /// corrupt filesystem paths or git command arguments.
    static func validateBranchName(_ branch: String) throws {
        guard !branch.isEmpty,
              !branch.contains("\0"),
              !branch.contains("\n") else {
            throw StorageError.invalidBranchName(branch)
        }
    }

    /// Returns true if the item at `url` exists and is a symbolic link.
    /// Uses lstat-level attribute inspection, which does not follow the symlink.
    static func isSymlink(at url: URL) -> Bool {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path) else {
            return false
        }
        return attrs[.type] as? FileAttributeType == .typeSymbolicLink
    }

    // MARK: - Branch name sanitization

    /// Percent-encodes `branch` for safe use as a flat filename.
    ///
    /// Only `/` and `%` are encoded — everything else is preserved verbatim.
    /// `%` must be encoded first to avoid double-encoding it on round-trip.
    ///
    ///   "feature/login"  → "feature%2Flogin"
    ///   "foo%bar"        → "foo%25bar"
    ///
    /// This encoding is bijective: distinct branch names always produce distinct
    /// filenames, and unsanitize() is an exact inverse.
    static func sanitize(_ branch: String) -> String {
        branch
            .replacingOccurrences(of: "%", with: "%25")
            .replacingOccurrences(of: "/", with: "%2F")
    }

    static func unsanitize(_ filename: String) -> String {
        filename.removingPercentEncoding ?? filename
    }
}
