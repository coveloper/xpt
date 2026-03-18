import Testing
import Foundation
@testable import xptCore

// MARK: - Helpers

private let minimalSnapshot = """
<?xml version="1.0" encoding="UTF-8"?>
<Bucket type="1" version="2.0"></Bucket>
""".data(using: .utf8)!

/// Creates a StorageManager wired to a temporary directory so tests don't
/// touch the real ~/.xpt/ storage.
private func makeStorage() throws -> (StorageManager, URL) {
    let tmp = FileManager.default.temporaryDirectory
        .appendingPathComponent("xptRenameTests-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
    return (StorageManager(repoDirectory: tmp), tmp)
}

// MARK: - Tests

@Suite("StorageManager.rename")
struct RenameTests {

    @Test("Happy path — snapshot file moves to new branch name")
    func happyPath() throws {
        let (storage, _) = try makeStorage()
        let oldURL = storage.snapshotURL(for: "feature/old")
        try FileManager.default.createDirectory(
            at: oldURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try minimalSnapshot.write(to: oldURL)

        try storage.rename(from: "feature/old", to: "feature/new")

        #expect(!FileManager.default.fileExists(atPath: oldURL.path))
        let newURL = storage.snapshotURL(for: "feature/new")
        #expect(FileManager.default.fileExists(atPath: newURL.path))
    }

    @Test("Old snapshot not found — throws noSnapshotFound")
    func oldNotFound() throws {
        let (storage, _) = try makeStorage()
        #expect(throws: StorageError.noSnapshotFound("feature/old")) {
            try storage.rename(from: "feature/old", to: "feature/new")
        }
    }

    @Test("New snapshot already exists — throws snapshotAlreadyExists")
    func newAlreadyExists() throws {
        let (storage, _) = try makeStorage()

        for branch in ["feature/old", "feature/new"] {
            let url = storage.snapshotURL(for: branch)
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try minimalSnapshot.write(to: url)
        }

        #expect(throws: StorageError.snapshotAlreadyExists("feature/new")) {
            try storage.rename(from: "feature/old", to: "feature/new")
        }
    }

    @Test("Invalid old branch name — throws invalidBranchName")
    func invalidOldName() throws {
        let (storage, _) = try makeStorage()
        #expect(throws: StorageError.invalidBranchName("")) {
            try storage.rename(from: "", to: "feature/new")
        }
    }

    @Test("Invalid new branch name — throws invalidBranchName")
    func invalidNewName() throws {
        let (storage, _) = try makeStorage()
        #expect(throws: StorageError.invalidBranchName("bad\0name")) {
            try storage.rename(from: "feature/old", to: "bad\0name")
        }
    }

    @Test("Same old and new name — throws snapshotAlreadyExists")
    func sameName() throws {
        let (storage, _) = try makeStorage()
        let url = storage.snapshotURL(for: "main")
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try minimalSnapshot.write(to: url)

        #expect(throws: StorageError.snapshotAlreadyExists("main")) {
            try storage.rename(from: "main", to: "main")
        }
    }

    @Test("Symlink at old path — throws symlinkDetected")
    func symlinkAtOldPath() throws {
        let (storage, tmp) = try makeStorage()
        let oldURL = storage.snapshotURL(for: "feature/old")
        // Create a real file to be the symlink target, then symlink to it
        let target = tmp.appendingPathComponent("real.xcbkptlist")
        try minimalSnapshot.write(to: target)
        try FileManager.default.createSymbolicLink(at: oldURL, withDestinationURL: target)

        #expect(throws: StorageError.symlinkDetected(oldURL.path)) {
            try storage.rename(from: "feature/old", to: "feature/new")
        }
    }

    @Test("Symlink at new path — throws symlinkDetected")
    func symlinkAtNewPath() throws {
        let (storage, tmp) = try makeStorage()
        // Create a real old snapshot
        let oldURL = storage.snapshotURL(for: "feature/old")
        try minimalSnapshot.write(to: oldURL)
        // Place a symlink at the new path
        let target = tmp.appendingPathComponent("real.xcbkptlist")
        try minimalSnapshot.write(to: target)
        let newURL = storage.snapshotURL(for: "feature/new")
        try FileManager.default.createSymbolicLink(at: newURL, withDestinationURL: target)

        #expect(throws: StorageError.symlinkDetected(newURL.path)) {
            try storage.rename(from: "feature/old", to: "feature/new")
        }
    }

    @Test("Renamed snapshot content is preserved")
    func contentPreserved() throws {
        let (storage, _) = try makeStorage()
        let oldURL = storage.snapshotURL(for: "feature/old")
        try FileManager.default.createDirectory(
            at: oldURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try minimalSnapshot.write(to: oldURL)

        try storage.rename(from: "feature/old", to: "feature/new")

        let newURL = storage.snapshotURL(for: "feature/new")
        let data = try Data(contentsOf: newURL)
        #expect(data == minimalSnapshot)
    }
}
